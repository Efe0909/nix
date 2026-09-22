{ config, lib, pkgs, ... }:

# Cloudflare DNS kayitlari — DEKLARATIF, tek kaynak tunel ingress'i.
#
# modules/cloudflared.nix'teki her ingress hostname'i icin bu makine her
# `nixos-rebuild switch`'te (ve acilista) Cloudflare API'sine sorar ve kaydi
# `<TUNEL-UUID>.cfargotunnel.com` CNAME'ine (proxied) getirir. Yeni hostname =
# ingress'e tek satir; DNS elle tiklanmaz, `cloudflared tunnel route dns`
# elle kosulmaz.
#
# Kayit zaten dogruysa DOKUNULMAZ. Yanlissa o ISIMDEKI butun kayitlar (A,
# AAAA, eski CNAME) silinip CNAME yazilir — ingress'te olan bir hostname
# bu makinenin tunelinin DISINDA bir yere gidemez. Ingress'te OLMAYAN
# kayitlara (MX, TXT, baska alt alan adlari) hic dokunulmaz.
#
# Pi ve VM ayni tuneli paylasiyor; ikisi de kosar, islem idempotent.
#
# SIR (bir kez, elle): Cloudflare panel -> My Profile -> API Tokens ->
# Create Token -> "Edit zone DNS" sablonu, Zone Resources: polonyum.com.
#   printf '%s' '<TOKEN>' | nix run github:ryantm/agenix -- -e cloudflare-dns-token.age
# (secrets/ icinde, secrets.nix'te alicilari tanimli). Dosya yoksa modul
# yalniz uyari verir, DNS elle kalir — derleme patlamaz.

let
  zone = "polonyum.com";
  secretFile = ../secrets/cloudflare-dns-token.age;
  enabled = builtins.pathExists secretFile;

  records = lib.concatLists (lib.mapAttrsToList
    (uuid: t: map (host: { inherit host; target = "${uuid}.cfargotunnel.com"; })
      (builtins.attrNames t.ingress))
    config.services.cloudflared.tunnels);
in
{
  config = lib.mkMerge [
    (lib.mkIf (!enabled) {
      warnings = [ "cloudflare-dns: secrets/cloudflare-dns-token.age yok — DNS kayitlari ELLE kaliyor (modules/cloudflare-dns.nix)" ];
    })

    (lib.mkIf enabled {
      age.secrets.cloudflare-dns-token.file = secretFile;

      systemd.services.cloudflare-dns = {
        description = "Cloudflare DNS: tunel ingress hostlari -> CNAME";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        path = [ pkgs.curl pkgs.jq ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          DynamicUser = true;
          # Token root'a ait dosyadan systemd kimlik bilgisi olarak gelir;
          # surec root degil, ortamda/komut satirinda da gorunmez.
          LoadCredential = "token:${config.age.secrets.cloudflare-dns-token.path}";
          Restart = "on-failure";
          RestartSec = "30s";
        };
        # Script degisince (hostname eklendi/cikti) switch birimi yeniden kosar.
        script = ''
          set -euo pipefail
          T=$(< "$CREDENTIALS_DIRECTORY/token")
          API=https://api.cloudflare.com/client/v4
          api() { curl -fsS --retry 3 -H "Authorization: Bearer $T" -H "Content-Type: application/json" "$@"; }

          Z=$(api "$API/zones?name=${zone}" | jq -er '.result[0].id')

          ensure() {
            local host=$1 target=$2 recs
            recs=$(api "$API/zones/$Z/dns_records?name=$host&per_page=100")
            if jq -e --arg t "$target" \
                 '.result | length == 1 and .[0].type == "CNAME" and .[0].content == $t and .[0].proxied' \
                 <<<"$recs" >/dev/null; then
              echo "$host: dogru"
              return
            fi
            for id in $(jq -r '.result[].id' <<<"$recs"); do
              api -X DELETE "$API/zones/$Z/dns_records/$id" >/dev/null
            done
            api -X POST "$API/zones/$Z/dns_records" --data "$(jq -nc --arg n "$host" --arg c "$target" \
              '{type: "CNAME", name: $n, content: $c, proxied: true, ttl: 1}')" >/dev/null
            echo "$host: -> $target yazildi"
          }

          ${lib.concatMapStrings (r: "ensure ${lib.escapeShellArg r.host} ${lib.escapeShellArg r.target}\n") records}
        '';
      };
    })
  ];
}

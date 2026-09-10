{ lib, ... }:

# EkipTakip gercek vhost'lari.
#
# Uygulama artik konteynerde: modules/ekiptakip-app.nix docker compose
# yiginini kaldirir ve 127.0.0.1:8000'e baglar. Bu dosya sadece nginx
# yonlendirmesini kurar.
#
# Su an SADECE vmtest'e bagli (bkz. flake.nix). Gercek Pi'ye (evsunucu)
# tasima ayri bir is.
#
# Iki host TEK uvicorn surecine gidiyor — ayrim nginx'te degil, uygulamanin
# icinde Host basligina bakarak yapiliyor (mobil/masaustu ayrimi).

let
  # --- neden recommendedProxySettings kapatildi -------------------------
  # O ayar location'a `proxy_set_header X-Forwarded-Proto $scheme;` koyuyor.
  # Bizim zincirde TLS cloudflared'de bitiyor, cloudflared nginx'e DUZ HTTP
  # konusuyor (ingress: http://127.0.0.1:80), yani $scheme = "http".
  #
  # Sonucu Google girisinde patliyor: kimlik.py redirect_uri'yi
  # request.url_for ile kuruyor, uvicorn scheme'i X-Forwarded-Proto'dan
  # aliyor, Google'a http://app.polonyum.com/giris/callback gidiyor ve
  # kayitli https adresiyle uyusmuyor -> redirect_uri_mismatch.
  #
  # Ustune yazmak yetmiyor: nginx'te proxy_set_header ayni seviyede iki kez
  # tanimlanirsa baslik CIFT gider, hangisinin kazandigi belirsizdir. Bu
  # yuzden hazir seti hic dahil etmiyor, hepsini burada acikca yaziyoruz.
  proxyBasliklari = ''
    proxy_set_header Host              $host;    # iki alan adi ayrimi buna bagli
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;    # SABIT — yukaridaki nota bak
    proxy_http_version 1.1;
    proxy_set_header Connection        "";
    proxy_read_timeout 30s;
    proxy_send_timeout 30s;
    # 10 MB uygulama sinirina karsi marj: dosya + multipart cercevesi, ve
    # uygulamanin kendi erken-reddetme esiginin (~11 MB) biraz ustu — sinir
    # asan istek nginx'ten degil UYGULAMADAN donen anlasilir hatayi alsin.
    # Eskiden 2m'ydi: telefondan cekilen fotograf tipik 3-8 MB, yani her
    # yukleme nginx'te CIPLAK 413 alip journalctl'de HICBIR IZ birakmadan
    # kesiliyordu (teamtracker HANDOFF-NIX.md madde 1).
    client_max_body_size 12m;
  '';

  vhost = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:8000";
      # Bu location hazir basliklari ALMASIN; hepsi extraConfig'te.
      recommendedProxySettings = false;
      extraConfig = proxyBasliklari;
    };
  };
in
{
  services.nginx.virtualHosts = {
    "app.polonyum.com" = vhost;         # MOBIL yuz, kokte
    "dashboard.polonyum.com" = vhost;   # MASAUSTU
  };

  # hello.nix'te de ayni satir var — liste tipi oldugu icin catisma yok,
  # bu dosya tek basina da (hello.nix cikarilsa bile) calissin diye burada.
  networking.firewall.allowedTCPPorts = [ 80 ];
}

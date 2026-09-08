{ config, ... }:

# YALNIZCA evsunucu (gercek Pi) hedefi bunu import eder — bkz. flake.nix.
# vmtest'e bilerek eklenmedi: tunel gercek Cloudflare hesabina kayitli bir
# kimlik yaratiyor, atilip yeniden kurulan test VM'inden yaratmak anlamsiz.
#
# YEREL yonetimli tunel — UZAKTAN (token) DEGIL. Ingress kurallari
# Cloudflare panelinde tiklanmiyor, burada, git'te. Yeni hostname eklemek
# = tek satir + commit, panelde hicbir sey degismiyor.
#
# Eski kurulumdan iki ders, burada TEKRARLANMIYOR:
#   1) Unit Type=notify + TimeoutStartSec=15 idi; cloudflared READY
#      sinyalini vermedigi icin systemd her 20 saniyede olduruyordu
#      (restart sayaci 52'ye ciktı, tunel hic ayakta kalmadi). NixOS'un
#      services.cloudflared modulu bunu dogru kuruyor, elle systemd
#      birimi yazmiyoruz.
#   2) Token ExecStart'ta arguman olarak duruyordu, `ps` ciktisinda
#      herkese gorunuyordu. Burada credentialsFile agenix'ten geliyor,
#      hicbir yerde duz metin gorunmuyor.
#
# KURULUM (bir kere, elle, gercek Cloudflare hesabinla):
#   1. cloudflared tunnel login
#        Tarayicida Cloudflare hesabina giris ister, cert.pem üretir
#        (~/.cloudflared/cert.pem).
#   2. cloudflared tunnel create evsunucu
#        Yeni tunel yaratir, UUID doner, credentials JSON dosyasi uretir
#        (~/.cloudflared/<UUID>.json). Asagidaki <TUNEL-UUID>'yi bu UUID
#        ile degistir.
#   3. credentials JSON'i agenix ile sifrele:
#        age-keygen -o /tmp/vmkey.txt        # (host icin native anahtar,
#                                             #  ssh-to-age DEGIL — bkz.
#                                             #  sohbet: uyumsuzluk bulundu)
#        nix shell nixpkgs#age -c age -r <host-pubkey> -r <admin-pubkey> \
#          -o secrets/cloudflared-creds.age ~/.cloudflared/<UUID>.json
#   4. secrets/secrets.nix'e "cloudflared-creds.age".publicKeys = [ ... ];
#   5. age.secrets.cloudflared-creds.file = ../secrets/cloudflared-creds.age;
#      asagida zaten var, sadece secrets/ dizinini yeniden kurman lazim
#      (bugun secrets/ tamamen kaldirildi, native age-keygen ile bastan
#      kurulacak).

{
  age.secrets.cloudflared-creds = {
    file = ../secrets/cloudflared-creds.age;
    # owner varsayilan root — cloudflared servisi zaten root'a yakin
    # yetkiyle CAP_NET_BIND_SERVICE gerektirmiyor, DynamicUser kullanabilir,
    # o zaman owner'i o kullaniciya cek. Simdilik root okur, servis de root.
  };

  services.cloudflared = {
    enable = true;
    tunnels."45170328-7abe-4869-b12d-2d85cff85c30" = {
      credentialsFile = config.age.secrets.cloudflared-creds.path;
      default = "http_status:404";
      ingress = {
        # Ikisi de AYNI nginx'e (127.0.0.1:80) gidiyor — ayrim Host
        # basligina gore nginx/uygulamanin icinde yapiliyor, cloudflared
        # sadece tasiyici. Yeni hostname eklemek: tek satir + commit.
        "app.polonyum.com" = "http://127.0.0.1:80";
        "dashboard.polonyum.com" = "http://127.0.0.1:80";
      };
    };
  };

  systemd.services.cloudflared.onFailure = [ "notification@cloudflared.service" ];
}

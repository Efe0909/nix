{ config, pkgs, inputs, ... }:

# EkipTakip uygulamasi — Docker konteyner yigini (uygulama + PostgreSQL).
# nginx yonlendirmesi ayri dosyada: modules/nginx/ekiptakip.nix
#
# Zincir:
#   telefon -> Cloudflare -> cloudflared -> nginx :80 -> 127.0.0.1:8000
#                                                        (ekiptakip-app)
#                                                             |
#                                                        ekiptakip-db
#
# Kaynak agaci ELLE KLONLANMIYOR: flake input (bkz. flake.nix "teamtracker",
# flake = false). Boylece surum flake.lock'ta pinli ve commit'li — VM
# sifirdan kurulsa ayni surum gelir, guncelleme icin VM'de shell acilmaz:
#   nix flake update teamtracker && nixos-rebuild switch --flake .#vmtest
#
# Neden oci-containers degil de compose: konteyner tanimi zaten uygulamanin
# deposunda (docker-compose.prod.yml). Nix'e ikinci kez yazmak iki kaynak
# demek, biri sessizce eskir.

let
  # Salt-okunur store yolu. Docker build context olarak da bu kullaniliyor;
  # build yalnizca okudugu icin sorun degil.
  kaynak = inputs.teamtracker;

  sir = config.age.secrets."ekiptakip-env".path;

  # --env-file ve EKIPTAKIP_ENV_FILE AYNI dosyayi gostermeli, ikisi AYRI is
  # yapiyor:
  #   --env-file         -> compose dosyasindaki ${...} yerine koymalari
  #                         (POSTGRES_PASSWORD, DATABASE_URL kurulumu)
  #   EKIPTAKIP_ENV_FILE -> servisin env_file: alani (konteynerin ortami)
  # Yalnizca birini verirsen belirti sinsi olur: ya parola bos kalir ya
  # uygulama sirsiz acilmaya calisir. (Denendi: env_file: tek basina
  # interpolation'i BESLEMIYOR, sadece uyari verip bos birakiyor.)
  compose = "${pkgs.docker}/bin/docker compose "
          + "--env-file ${sir} "
          + "--project-name ekiptakip "        # proje adi store yolundan turemesin
          + "-f ${kaynak}/docker-compose.prod.yml";
in
{
  # --- sir ----------------------------------------------------------------
  # Icerigi: GOOGLE_CLIENT_ID/SECRET, EKIPTAKIP_SECRET_KEY,
  # POSTGRES_PASSWORD, alan adlari, APP_PORT=8000.
  # secrets/secrets.nix'te alicilari tanimli (admin + vmtest).
  age.secrets."ekiptakip-env" = {
    file = ../secrets/ekiptakip-env.age;
    # Compose'u root calistiriyor.
    mode = "0400";
    owner = "root";
    group = "root";
  };

  # --- servis -------------------------------------------------------------
  systemd.services.ekiptakip = {
    description = "EkipTakip (docker compose yigini)";
    after = [ "docker.service" "network-online.target" ];
    requires = [ "docker.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    # Store yolu her surumde degisir; birim de o zaman yeniden baslar.
    restartTriggers = [ kaynak ];

    path = [ pkgs.docker ];

    # `--env-file` YALNIZCA compose dosyasindaki ${...} yerine koymalari
    # besler; servisin `env_file:` alani ondan haberdar degil ve
    # ${EKIPTAKIP_ENV_FILE:-.env} varsayilana duser. Belirtisi:
    #   env file /nix/store/...-source/.env not found
    # Yani ikisi de gerekiyor ve AYNI dosyayi gostermeli.
    environment.EKIPTAKIP_ENV_FILE = sir;

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Ilk calistirmada imaj kurulur (pip install dahil), uzun surebilir.
      TimeoutStartSec = "900";
    };

    # --build: kaynak degisince yeni imaj kurulsun. Docker icerige gore
    # onbellekliyor, degismediyse anlik geciyor.
    script = "${compose} up -d --build";
    preStop = "${compose} down";
  };
}

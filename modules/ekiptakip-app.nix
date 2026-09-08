{ config, pkgs, lib, ... }:

# EkipTakip uygulamasi — Docker konteyner yigini (uygulama + PostgreSQL).
# nginx yonlendirmesi ayri dosyada: modules/nginx/ekiptakip.nix
#
# Zincir:
#   telefon -> Cloudflare -> cloudflared -> nginx :80 -> 127.0.0.1:8000
#                                                        (ekiptakip-app)
#                                                             |
#                                                        ekiptakip-db
#
# Neden oci-containers degil de compose: konteyner tanimi zaten uygulamanin
# deposunda (docker-compose.prod.yml). Nix'e ikinci kez yazmak iki kaynak
# demek, biri sessizce eskir.
#
# ILK KURULUM (bir kere, elle):
#   sudo mkdir -p /srv && sudo git clone https://github.com/Efe0909/teamtracker /srv/ekiptakip
# Guncelleme:
#   sudo git -C /srv/ekiptakip pull && sudo systemctl restart ekiptakip

let
  depo = "/srv/ekiptakip";
  sir = config.age.secrets."ekiptakip-env".path;

  # --env-file ve EKIPTAKIP_ENV_FILE AYNI dosyayi gostermeli, ikisi AYRI is
  # yapiyor:
  #   --env-file         -> compose dosyasindaki ${...} yerine koymalari
  #                         (POSTGRES_PASSWORD, DATABASE_URL kurulumu)
  #   EKIPTAKIP_ENV_FILE -> servisin env_file: alani (konteynerin ortami)
  # Yalnizca birini verirsen belirti sinsi olur: ya parola bos kalir ya
  # uygulama sirsiz acilmaya calisir. (Denendi: env_file: tek basina
  # interpolation'i BESLEMIYOR, sadece uyari verip bos birakiyor.)
  compose = "${pkgs.docker}/bin/docker compose --env-file ${sir} -f ${depo}/docker-compose.prod.yml";
in
{
  # --- sir ----------------------------------------------------------------
  # Icerigi: GOOGLE_CLIENT_ID/SECRET, EKIPTAKIP_SECRET_KEY,
  # POSTGRES_PASSWORD, alan adlari, APP_PORT=8000.
  # secrets/secrets.nix'te alicilari tanimli olmali (admin + vmtest).
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
    after = [ "docker.service" "network-online.target" "run-agenix.d.mount" ];
    requires = [ "docker.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    path = [ pkgs.docker pkgs.git ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = depo;
      # Ilk calistirmada imaj kurulur (pip install dahil), uzun surebilir.
      TimeoutStartSec = "900";
    };

    # --build: depo guncellendiginde yeni imaj kurulsun.
    script = "${compose} up -d --build";
    preStop = "${compose} down";
  };

  # Depo yoksa servis anlasilmaz bir docker hatasiyla duser; onceden soyle.
  systemd.services.ekiptakip.preStart = ''
    if [ ! -f ${depo}/docker-compose.prod.yml ]; then
      echo "EkipTakip deposu yok: ${depo}"
      echo "  sudo git clone https://github.com/Efe0909/teamtracker ${depo}"
      exit 1
    fi
  '';
}

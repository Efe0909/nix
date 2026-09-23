{ config, inputs, ... }:

# EkipTakip (Rust) — uygulama modulu teamtracker flake'inden gelir
# (teamtracker/deploy/module.nix: ikili + yerel PostgreSQL + systemd servisi).
# On yuz (React) ayni paketin icinde; nginx `services.ekiptakip.webRoot`'u verir.
# Burada yalniz makineye ozel iki sey var: sirrin nereden geldigi ve servisin
# acilmasi. nginx: modules/nginx/ekiptakip.nix (statik + /api vekili).
#
# ekiptakip-app.nix (docker compose) ve ekiptakip-media.nix (uid 10001 chown)
# yalniz teamtracker0.1'e ait; bu hedef onlari almaz.
{
  # Icerigi: GOOGLE_CLIENT_ID/SECRET, EKIPTAKIP_SECRET_KEY, alan adlari,
  # cerez alan adi. Eski compose'tan kalan POSTGRES_PASSWORD/APP_PORT
  # satirlari zararsiz — Rust ikilisi okumuyor. systemd EnvironmentFile'i
  # root okur, mod 0400 yeter.
  age.secrets."ekiptakip-env" = {
    file = ../secrets/ekiptakip-env.age;
    mode = "0400";
    owner = "root";
    group = "root";
  };

  # Ilk yonetici listesi (teamtracker KNOW-320): satir basina bir e-posta, her
  # acilista aktif admin. Servis kullanicisi 0400 root dosyayi okuyamaz; modul
  # onu systemd LoadCredential ile verir.
  age.secrets."ekiptakip-bootstrap-admins" = {
    file = ../secrets/ekiptakip-bootstrap-admins.age;
    mode = "0400";
    owner = "root";
    group = "root";
  };

  services.ekiptakip = {
    enable = true;
    bootstrapAdminsFile = config.age.secrets."ekiptakip-bootstrap-admins".path;
    # Mac'te derlenmis release (teamtracker backend/tools/release.sh). Bu
    # makine DERLEMEZ.
    package = inputs.teamtracker-alpha02.packages.aarch64-linux.default;
    environmentFile = config.age.secrets."ekiptakip-env".path;
  };
}

{ lib, ... }:

# YALNIZCA vmtest hedefi bunu import eder — gercek Pi'ye (evsunucu) SIZINTI YOK.
# EkipTakip'i buraya tasimak ayri, daha buyuk bir is (Postgres'e gecti,
# app.py + uvicorn servisi de lazim); bu dosya sadece nginx yonlendirmesini
# hazirliyor, boylece o is geldiginde tek yapilacak yeni bir systemd birimi
# eklemek olacak, nginx tarafi zaten calisir durumda olacak.
#
# `services.nginx.virtualHosts` attrsOf submodule oldugu icin buradaki iki
# yeni anahtar, configuration.nix'teki "_" catch-all ile CATISMAZ — farkli
# anahtarlar, sessizce birlesir.
#
# UYARI: 127.0.0.1:8000'de HENUZ HICBIR SEY DINLEMIYOR. curl/tarayici
# denemesi 502 Bad Gateway doner — bu BEKLENEN, nginx katmaninin dogru
# calistiginin kaniti. Backend (uvicorn + Postgres) ayri is.

{
  services.nginx.virtualHosts = {
    "dashboard.polonyum.com".locations."/" = {
      proxyPass = "http://127.0.0.1:8000";
    };
    "app.polonyum.com".locations."/" = {
      proxyPass = "http://127.0.0.1:8000";
    };
    # Gercek EkipTakip'te iki host TEK uvicorn surecine gidiyor, ayrim
    # nginx'te degil uygulama icinde Host basligina bakarak yapiliyor
    # (mobil/masaustu ayrimi). recommendedProxySettings zaten
    # `proxy_set_header Host $host;` ekliyor, ayrica yazmaya gerek yok.
  };

  # Port 80 configuration.nix'te SADECE tailscale0'a acik (gercek Pi'nin
  # guvenlik karari). Bu VM'de Mac'ten 192.168.64.8:80 ile test edebilmek
  # icin varsayilan arayuzde de acmak GEREKIYOR. Bu dosya zaten sadece
  # vmtest'e gittigi icin gercek Pi'nin karari etkilenmiyor.
  networking.firewall.allowedTCPPorts = [ 80 ];
}

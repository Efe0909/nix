{ lib, ... }:

# EkipTakip gercek vhost'lari. Uygulamanin kendisi (uvicorn, port 8000,
# app.py'nin kendi dokumantasyonuna gore) SENIN sorumlulugunda — bu dosya
# sadece nginx yonlendirmesini kurar.
#
# Su an SADECE vmtest'e bagli (bkz. flake.nix). Gercek Pi'ye (evsunucu)
# tasima ayri bir is.
#
# Iki host TEK uvicorn surecine gidiyor — ayrim nginx'te degil, uygulamanin
# icinde Host basligina bakarak yapiliyor (mobil/masaustu ayrimi, bkz.
# EkipTakip'in kendi CLAUDE.md'si). recommendedProxySettings zaten
# `proxy_set_header Host $host;` ekliyor, ayrica yazmaya gerek yok.

{
  services.nginx.virtualHosts = {
    "app.polonyum.com".locations."/" = {
      proxyPass = "http://127.0.0.1:8000";
    };
    "dashboard.polonyum.com".locations."/" = {
      proxyPass = "http://127.0.0.1:8000";
    };
  };

  # hello.nix'te de ayni satir var — liste tipi oldugu icin catisma yok,
  # bu dosya tek basina da (hello.nix cikarilsa bile) calissin diye burada.
  networking.firewall.allowedTCPPorts = [ 80 ];
}

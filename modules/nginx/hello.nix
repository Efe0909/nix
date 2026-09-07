{ lib, ... }:

# SABLON — gercek bir proje degil, ornek. YALNIZCA vmtest hedefi bunu
# import eder, gercek Pi'ye (evsunucu) sizinti yok. Yeni bir proje deploy
# ederken bu dosyayi kopyala, host adini/portu degistir.
#
# `services.nginx.virtualHosts` attrsOf submodule oldugu icin buradaki
# yeni anahtar, configuration.nix'teki "_" catch-all ile CATISMAZ —
# farkli anahtarlar, sessizce birlesir.
#
# UYARI: 127.0.0.1:3000'de HICBIR SEY DINLEMIYOR. curl/tarayici denemesi
# 502 Bad Gateway doner — bu BEKLENEN, nginx katmaninin dogru calistiginin
# kaniti. Arkasina gercek bir servis (systemd birimi ya da Docker container)
# baglamak ayri is.

{
  services.nginx.virtualHosts."hello.test".locations."/" = {
    proxyPass = "http://127.0.0.1:3000";
  };

  # Port 80 configuration.nix'te SADECE tailscale0'a acik (gercek Pi'nin
  # guvenlik karari). Bu VM'de Mac'ten 192.168.64.8:80 ile test edebilmek
  # icin varsayilan arayuzde de acmak GEREKIYOR. Bu dosya zaten sadece
  # vmtest'e gittigi icin gercek Pi'nin karari etkilenmiyor.
  networking.firewall.allowedTCPPorts = [ 80 ];
}

{ config, ... }:

# SABLON — gercek bir proje degil, ornek. Yeni bir proje deploy ederken
# bu dosyayi kopyala, isimleri/portu/domain'i degistir. "docker'la
# paketlersem" sorusunun cevabinin calisan hali.

{
  virtualisation.oci-containers.containers.hello = {
    # SABLON icin tag yeterli. GERCEK projede digest'e pinle:
    #   docker pull traefik/whoami
    #   docker inspect --format='{{index .RepoDigests 0}}' traefik/whoami
    # ciktiyi buraya yapistir (traefik/whoami@sha256:...).
    image = "traefik/whoami";

    # Sadece localhost — disariya nginx uzerinden gidiyor, container'in
    # kendisi disari acilmiyor. EkipTakip modulundeki ile ayni desen.
    ports = [ "127.0.0.1:8080:80" ];
  };

  services.nginx.virtualHosts."hello.test".locations."/" = {
    proxyPass = "http://127.0.0.1:8080";
  };

  # Port 80 configuration.nix'te SADECE tailscale0'a acik (gercek Pi'nin
  # guvenlik karari). Bu modul yalnizca vmtest'e gittigi icin varsayilan
  # arayuzde de acmak Pi'yi etkilemiyor, sadece Mac'ten test etmeyi kolaylastirir.
  networking.firewall.allowedTCPPorts = [ 80 ];
}

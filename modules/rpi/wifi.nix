{ config, ... }:

# eduroam (WPA2-Enterprise, PEAP + MSCHAPv2) — yalniz gercek Pi.
# Parola git'e girmez: agenix, NetworkManager'a ortam degiskeni olarak
# verilir ($EDUROAM_PASSWORD asagida profilde ikame edilir).
#
# secrets/eduroam-env.age icerigi tek satir:
#   EDUROAM_PASSWORD=<parola>
{
  age.secrets.eduroam-env.file = ../../secrets/eduroam-env.age;

  networking.networkmanager.ensureProfiles.environmentFiles =
    [ config.age.secrets.eduroam-env.path ];

  networking.networkmanager.ensureProfiles.profiles.eduroam = {
    connection = {
      id = "eduroam";
      type = "wifi";
      # interface-name YOK: NixOS arayuzu wlan0 degil "wld0" adlandiriyor
      # (ilk bootta profil bu yuzden eslesmedi, wifi hic denenmedi).
      autoconnect-priority = "10";   # kablo (100) onde, wifi yedek
    };
    wifi = { mode = "infrastructure"; ssid = "eduroam"; };
    wifi-security.key-mgmt = "wpa-eap";
    "802-1x" = {
      eap = "peap;";
      phase2-auth = "mschapv2";
      identity = "efe.atcali@ozu.edu.tr";
      password = "$EDUROAM_PASSWORD";
    };
    ipv4.method = "auto";
    ipv6.method = "auto";
  };
}

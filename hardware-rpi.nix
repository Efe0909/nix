{ ... }:

# Yalnizca GERCEK Pi hedefi bunu import eder. vmtest hedefi etmez —
# raspberry-pi-nix modulu QEMU/UTM'de anlamsiz (Pi'ye ozgu device tree +
# bootloader), o yuzden bu tek satir ayri dosyada: configuration.nix hem
# gercek makinede hem VM'de ORTAK kalsin diye.
{
  raspberry-pi-nix.board = "bcm2712";          # Pi 5
}

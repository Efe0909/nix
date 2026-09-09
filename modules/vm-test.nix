{ lib, ... }:

# YALNIZCA vmtest hedefi bunu import eder. Gercek Pi'de bu dosya YOK.
#
# configuration.nix'teki seylerden VM'de dogal olarak calismayanlari
# kapatir (HDD yok, gercek SD kart yok) ve UTM/QEMU'da rahat test
# icin kolaylik saglar (sifre girisi — SADECE burada, gercek makinede yok).

{
  # nixos-install sirasinda `nixos-generate-config --root /mnt` ile
  # uretilen GERCEK dosya — fileSystems."/" ve "/boot" buradan geliyor,
  # artik uydurma /dev/vda1 stub'i degil.
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = lib.mkForce "vmtest";

  # UEFI aarch64 VM'de standart bootloader. Gercek Pi'de raspberry-pi-nix
  # kendi bootloader'ini kuruyor, bu satirlar orada devreye girmiyor.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Boot menusunde en fazla 10 girdi. Bu VM gunde onlarca kez rebuild ediliyor
  # ve her `nixos-rebuild switch` yeni bir generation yaratiyor; sinir yokken
  # menu 40+ satira ciktı ve ESP (boot bolumu) her kernel+initrd ciftiyle
  # doluyordu.
  #
  # DIKKAT: bu yalnizca MENUYE yazilan girdi sayisini sinirlar. Eski
  # generation'lar nix store'da durmaya devam eder — onlari silen sey
  # nix.gc (configuration.nix). Ikisi ayri is.
  boot.loader.systemd-boot.configurationLimit = 10;

  # --- generation temizligi: VM'e ozel ------------------------------------
  # configuration.nix haftalik + 30 gun diyor; gercek Pi icin makul, bu VM
  # icin degil. Burada gunde onlarca rebuild oluyor, bir haftada yuzlerce
  # generation birikiyor.
  #
  # "Sil ama arsivle" diye bir orta yol YOK: generation bir symlink'tir
  # (/nix/var/nix/profiles/system-N-link) ve ayni zamanda bir GC KOKUDUR.
  # Symlink durdukca isaret ettigi kapanisin TAMAMI (kernel + initrd + sistem
  # closure'i, her biri yuz MB'lar) store'da tutulur. Symlink gidince kapanis
  # da gider. Arsivlemenin karsiligi "son N gunu tut".
  #
  # mkForce: configuration.nix'teki degerin uzerine yaziyor, YALNIZCA bu
  # makinede — gercek Pi'nin politikasi degismiyor.
  nix.gc.dates = lib.mkForce "daily";
  nix.gc.options = lib.mkForce "--delete-older-than 7d";

  # Kolay giris icin — SADECE VM'de. Gercek sistemde initialPassword
  # YOK, sadece SSH anahtari var.
  users.users.efe.initialPassword = "test";
  users.mutableUsers = true;

  # HDD yok -> restic + smartd (configuration.nix'te evsunucu.hddVar'a bagli)
  # kendiliginden devre disi kalsin. Kapatmazsan systemctl --failed dolar,
  # gercek arizadan ayirt etmek zorlasir.
  evsunucu.hddVar = false;
  services.samba.enable = lib.mkForce false;      # zaten kapali, acikca da kalsin

  # agenix'in acilista HANGI private key'e bakacagini soyluyor — bu satir
  # olmadan varsayilan SSH host key yollarini deniyordu, onlar ssh-to-age
  # uyumsuzlugu yuzunden calismiyordu ("no identity matched any of the
  # recipients", ilk gercek rebuild'de yakalandi). /etc/age/vmtest.key
  # native age-keygen ile uretildi, secrets.nix'te "vmtest" olarak
  # tanimli. msmtp gibi diger sirlar tanimlaninca da bunu kullanacak.
  age.identityPaths = [ "/etc/age/vmtest.key" ];

  # system.autoUpgrade VM'de anlamsiz — kendi kendine flake cekip
  # rebuild etmeye kalkmasin.
  system.autoUpgrade.enable = lib.mkForce false;
}

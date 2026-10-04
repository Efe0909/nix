{ ... }:

# Yalnizca GERCEK Pi hedefi bunu import eder (vmtest etmez — Pi'ye ozgu
# device tree + bootloader QEMU'da anlamsiz). Board secimi flake'teki
# `raspberry-pi-5.base` modulunde; burada yalniz donanim tercihleri.
#
# Firmware (start*.elf, bootloader dosyalari, device tree) Raspbian'dan
# KOPYALANMAZ: nixos-raspberrypi'nin raspberrypifw paketi /boot/firmware'e
# her switch'te yazar. Fan: Pi 5'in aktif sogutucusunu kernel'in device
# tree'sindeki cooling-fan dugumu surer, ek ayar gerekmez.
{
  # Bluetooth: bluetooth modulu import EDILMIYOR (bluez/servis yok,
  # configuration.nix'te hardware.bluetooth.enable = false); burada ek
  # olarak kernel'in BT surucusunu probe etmesini de kapatiyoruz.
  hardware.raspberry-pi.config.all.base-dt-params.krnbt = {
    enable = true;
    value = "off";
  };

  # Pi 5'te USB portlari RP1 cipinde ve surucusu bu kernel'de MODUL
  # (drivers/misc/rp1/rp1-pci); xhci/uas/usb-storage built-in. Initrd'de
  # rp1-pci yoksa USB disk hic gorunmez ve acilis "busybox"a duser —
  # ilk kurulumda tam bu yuzden dustu. kernelModules: stage-1'de ZORLA yukle.
  boot.initrd.kernelModules = [ "rp1-pci" ];

  # agenix bu native age anahtariyla cozer (ssh host key degil — ssh-to-age
  # uyumsuz, bkz. vm-test.nix). Kurulumda /mnt/etc/age/evsunucu.key olarak
  # konur; kaybolursa secrets/ `admin` anahtariyla yeniden sifrelenir.
  age.identityPaths = [ "/etc/age/evsunucu.key" ];

  # HDD'nin sonuna acilan iki bolum, ETIKETLE eslesir (USB disk adlari
  # sda/sdb kayabilir, etiket kaymaz). Veri bolumu `sata` configuration.nix'te.
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXROOT";
    fsType = "ext4";
    options = [ "noatime" ];
  };
  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    options = [ "noatime" "umask=0077" ];
  };
}

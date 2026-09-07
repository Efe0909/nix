# BU DOSYA nixos-generate-config TARAFINDAN URETILDI, elle degistirme.
# Bu belirli UTM VM'inin sanal diskine (UUID'lere) ozgu — VM'i silip
# yeniden yaratirsan UUID'ler degisir, bu dosyayi yeniden uretmen gerekir
# (`nixos-generate-config --root /mnt` VM icinden calistirilir).
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/profiles/qemu-guest.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "virtio_pci" "usbhid" "usb_storage" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/d48a744b-f4dd-4187-909b-27357b59b5a9";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/6BB8-3832";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}

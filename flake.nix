{
  description = "Efe ev sunucusu — Raspberry Pi 5";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Pi 5 vendor kernel + firmware. Kurulumun EN KIRILGAN parcasi: Pi 4
    # oturmus, Pi 5 daha yeni. Kurulumdan ONCE bunun o gunku surumunun
    # actigini dogrula; acmazsa alternatifi nixos-hardware'in
    # raspberry-pi/5 modulu.
    #
    # vmtest hedefi bunu HIC KULLANMAZ — asagida bkz.
    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";

    # Secrets. Makine secretsi icin: boot'ta cozulup /run/agenix altina
    # yazilir, servis oradan okur, klavyeye kimse dokunmaz.
    # Kisisel secrets `pass`te kalmaya devam eder — o insan icin, bu makine icin.
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, raspberry-pi-nix, agenix, ... }: {

    # ================================================================ GERCEK ==
    nixosConfigurations.evsunucu = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        raspberry-pi-nix.nixosModules.raspberry-pi
        agenix.nixosModules.default
        ./modules/rpi/hardware-rpi.nix
        ./modules/configuration.nix
        ./modules/cli.nix
        ./modules/cloudflared.nix
      ];
    };

    # Mac'ten dagitim:
    #   nixos-rebuild switch --flake .#evsunucu \
    #     --target-host efe@evsunucu --use-remote-sudo
    # Pi'de shell acmadan yonetim. Shell acmak zorunda kalmak = bir yerde
    # declarative olmayan bir sey var demektir.

    # ============================================================== VM TEST ==
    # UTM/QEMU'da genel aarch64 VM'de test icin. raspberry-pi-nix modulu
    # BILEREK YOK — Pi'ye ozgu device tree + bootloader, genel VM'de
    # anlamsiz/patlar. Bunun disinda evsunucu ile AYNI configuration.nix +
    # cli.nix'i kullanir, yani nginx/firewall/docker/samba/vim/tmux/bash
    # mantiginin TAMAMI burada gercekten test edilir.
    #
    # VM icinde (native aarch64-linux, cross-build derdi yok):
    #   nix build .#nixosConfigurations.vmtest.config.system.build.toplevel
    #     -> sadece evaluate + build, hicbir seye dokunmaz
    #   sudo nixos-rebuild switch --flake .#vmtest
    #     -> gercekten uygular, servisleri baslatir, boot'u test eder
    nixosConfigurations.vmtest = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        agenix.nixosModules.default
        ./modules/configuration.nix
        ./modules/cli.nix
        ./modules/vm-test.nix
        ./modules/nginx/hello.nix
      ];
    };
  };
}

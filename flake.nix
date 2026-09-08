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

    # EkipTakip uygulamasi. flake = false: o depoda flake.nix yok, sadece
    # kaynak agaci lazim (Dockerfile + docker-compose.prod.yml).
    #
    # Elle `git clone /srv/...` yerine bu: surum flake.lock'ta pinli ve
    # commit'li, yani VM sifirdan kurulsa AYNI surum gelir ve guncelleme
    # icin VM'de shell acmak gerekmez —
    #   nix flake update teamtracker && nixos-rebuild switch --flake .#vmtest
    teamtracker = {
      url = "github:Efe0909/teamtracker";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, raspberry-pi-nix, agenix, teamtracker, ... }@inputs: {

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
      # ekiptakip-app.nix `inputs.teamtracker` store yolunu okuyor.
      specialArgs = { inherit inputs; };
      modules = [
        agenix.nixosModules.default
        ./modules/configuration.nix
        ./modules/cli.nix
        ./modules/vm-test.nix
        ./modules/nginx/hello.nix
        ./modules/nginx/ekiptakip.nix
        ./modules/ekiptakip-app.nix
        ./modules/cloudflared.nix
      ];
    };
  };
}

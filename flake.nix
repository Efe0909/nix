{
  description = "Efe ev sunucusu — Raspberry Pi 5";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Pi 5 vendor kernel + firmware. Kurulumun EN KIRILGAN parcasi: Pi 4
    # oturmus, Pi 5 daha yeni. Kurulumdan ONCE bunun o gunku surumunun
    # actigini dogrula; acmazsa alternatifi nixos-hardware'in
    # raspberry-pi/5 modulu.
    #
    # VM hedefleri (teamtracker0.1 / teamtracker0.2) bunu HIC KULLANMAZ — asagida bkz.
    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";

    # Secrets. Makine secretsi icin: boot'ta cozulup /run/agenix altina
    # yazilir, servis oradan okur, klavyeye kimse dokunmaz.
    # Kisisel secrets `pass`te kalmaya devam eder — o insan icin, bu makine icin.
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    # EkipTakip — IKI SURUM, IKI GIRDI. Her biri kendi nixosConfiguration'ina
    # bagli; ikisi ayni VM'e ayri ayri kurulabilir (bir anda biri).
    #
    # alpha-0.1: Python + Docker compose. Kaynak agaci yeter (flake = false).
    # Commit URL'de PINLI: `nix flake update` onu YERINDEN OYNATMAZ — bu,
    # calistigi bilinen son 0.1 (teamtracker PR #32, Rust'tan onceki son main).
    teamtracker-alpha01 = {
      url = "github:Efe0909/teamtracker/e02d71d2266ebd428db6b9746221d626fe4025d3";
      flake = false;
    };

    # alpha-0.2: Rust API + React. Bir FLAKE: paketi (Mac'te derlenmis GitHub
    # release'i, deploy/release.nix) ve NixOS modulunu getiriyor. Makine
    # DERLEMEZ. Guncelleme:
    #   nix flake update teamtracker-alpha02
    # PR #35 birlesince url -> github:Efe0909/teamtracker (main).
    teamtracker-alpha02 = {
      url = "github:Efe0909/teamtracker/rust-backend-rewrite";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, raspberry-pi-nix, agenix, teamtracker-alpha02, ... }@inputs:
  let
    # VM tabani + surume ozel moduller. specialArgs: moduller
    # `inputs.teamtracker-alpha0X`'i okuyor.
    vmSystem = extra: nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        agenix.nixosModules.default
        ./modules/configuration.nix
        ./modules/cli.nix
        ./modules/vm-test.nix
        ./modules/nginx/hello.nix
        ./modules/cloudflared.nix
      ] ++ extra;
    };
  in {

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
    # UTM/QEMU'da genel aarch64 VM (192.168.64.8). raspberry-pi-nix modulu
    # BILEREK YOK — Pi'ye ozgu device tree + bootloader, genel VM'de
    # anlamsiz/patlar. Bunun disinda evsunucu ile AYNI configuration.nix +
    # cli.nix'i kullanir.
    #
    # Iki yapilandirma, AYNI VM, AYNI ortak taban (vmBase); fark yalniz
    # EkipTakip surumu. Birinden digerine gecis = bir switch; geri donus ayni.
    #   sudo nixos-rebuild switch --flake .#teamtracker0.1   # Python + Docker
    #   sudo nixos-rebuild switch --flake .#teamtracker0.2   # Rust + React
    # Mac'ten (VM derlemez, yalniz kopyalanir — 0.2 zaten hazir release):
    #   nixos-rebuild switch --flake .#teamtracker0.2 \
    #     --target-host efe@192.168.64.8 --sudo
    nixosConfigurations."teamtracker0.1" = vmSystem [
      ./modules/nginx/ekiptakip.nix
      ./modules/ekiptakip-app.nix
      ./modules/ekiptakip-media.nix
    ];

    nixosConfigurations."teamtracker0.2" = vmSystem [
      teamtracker-alpha02.nixosModules.default
      ./modules/nginx/ekiptakip-alpha02.nix
      ./modules/ekiptakip-alpha02.nix
    ];
  };
}

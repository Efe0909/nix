{
  description = "Efe ev sunucusu — Raspberry Pi 5";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Pi 5 vendor kernel + firmware + bootloader (kernelboot). Eski
    # nix-community/raspberry-pi-nix BIRAKILDI: pini Mart 2025'te kalmisti,
    # guncel nixpkgs'ta `attribute 'buildDTBs' missing` ile degerlendirme
    # bile olmuyordu. Bu girdi bakimli ve binary cache'i var
    # (nixos-raspberrypi.cachix.org) — Pi'de kernel DERLENMEZ.
    #
    # DIKKAT: kendi nixpkgs'ini (nixos-26.05) getiriyor; evsunucu ONUNLA
    # kurulur (cache isabeti icin `follows` YOK). VM hedefleri kendi
    # nixpkgs'inde (unstable) kalir ve bunu HIC KULLANMAZ.
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";

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
    #   nix flake update teamtracker-alpha02   # main'in guncel pini
    teamtracker-alpha02 = {
      url = "github:Efe0909/teamtracker";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Cache'siz kernel derlemesine dusmemek icin ZORUNLU: yoksa saatler surer.
  nixConfig = {
    extra-substituters = [ "https://nixos-raspberrypi.cachix.org" ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  outputs = { self, nixpkgs, nixos-raspberrypi, agenix, teamtracker-alpha02, ... }@inputs:
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
        # cloudflared + cloudflare-dns BILEREK YOK: tunel (45170328-…) artik
        # yalniz evsunucu'da. Ayni kimligi iki makine kullaninca trafik
        # ikisine dagiliyordu. VM'i yeniden internete acmak gerekirse yeni
        # bir tunel (cloudflared tunnel create) + ayri credentials sirri ac.
      ] ++ extra;
    };
  in {

    # ================================================================ GERCEK ==
    nixosConfigurations.evsunucu = nixos-raspberrypi.lib.nixosSystem {
      specialArgs = { inherit inputs nixos-raspberrypi; };
      modules = [
        nixos-raspberrypi.nixosModules.raspberry-pi-5.base
        agenix.nixosModules.default
        ./modules/rpi/hardware-rpi.nix
        ./modules/rpi/wifi.nix
        ./modules/configuration.nix
        ./modules/cli.nix
        ./modules/cloudflared.nix
        ./modules/cloudflare-dns.nix
        # EkipTakip 0.2 (Rust + React + yerel PostgreSQL, temiz veritabani).
        teamtracker-alpha02.nixosModules.default
        ./modules/nginx/ekiptakip-alpha02.nix
        ./modules/ekiptakip-alpha02.nix
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

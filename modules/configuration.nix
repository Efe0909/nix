{ config, pkgs, lib, ... }:

# Pi hedefinde de vmtest hedefinde de ORTAK olan config. Donanima ozgu
# tek satir (raspberry-pi-nix.board) hardware-rpi.nix'te, sadece gercek
# Pi hedefi onu import ediyor — bu dosya QEMU/UTM'de de sorunsuz build olsun.

{
  # vm-test.nix bunu false yapar: restic/smartd HDD'ye bagli, VM'de HDD yok.
  # services.restic.backups.<isim>'de .enable diye bir secenek YOK — tanim
  # varligi zaten "etkin" demek — o yuzden ozel bir anahtar tanimliyoruz,
  # override etmeye calismak yerine kosullu tanimliyoruz.
  options.evsunucu.hddVar = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "458GB SATA disk (backup + SMART hedefi) takili mi.";
  };

  config = {

  # ================================================================ DONANIM ==
  # Boot YENI SD KARTTAN. Kurulumda uretilen hardware-configuration.nix'i
  # buraya import et; asagidaki fileSystems yalnizca VERI diski icin.
  #
  # Kart secimi: High Endurance sinifi + A2. Eski kart boot'un ~110
  # saniyesini tek basina yiyordu (dev-mmcblk0p2.device 68sn) ve
  # "Card stuck being busy" veriyordu — yorulmustu, sonunda cikarildi.
  #
  # FILESYSTEM: ext4, btrfs DEGIL. Btrfs'in kopyala-yaz yapisi yazma
  # cogaltmasi uretir; SD kartta bu omru kisaltir. Snapshot korumasini
  # filesystem yerine HDD'ye restic backup'iyle aliyoruz (asagida).
  #
  # SD'ye yazmayi azaltan ayarlar (hepsi bilincli):
  #   - noatime (her okumada zaman damgasi yazilmaz)
  #   - /tmp tmpfs'te            -> boot.tmp.useTmpfs
  #   - swap dosyasi yok, zram   -> zramSwap
  #   - journald 200MB tavan     -> services.journald
  #   - nix store haftalik gc    -> nix.gc

  # 458GB SATA disk — BACKUP'LAR BURADA.
  # nofail HAYATI: bu satirin eksikligi 2026-08-30'da makineyi acilamaz
  # hale getirmisti. Disk yoksa local-fs.target dusuyor, ona bagli her sey
  # failure veriyordu. 10sn'de vazgecip devam etsin.
  #
  # VM'de bu disk hic yok — nofail sayesinde VM boot'ta da sorun cikarmaz,
  # sadece mount atlanir. restic ve smartd bu diske bagli oldugu icin
  # VM'de onlar failed gorunur; bu BEKLENEN, vm-test.nix'te kapatiliyor.
  fileSystems."/home/efe/sata" = {
    device = "/dev/disk/by-label/sata";
    fsType = "ext4";
    options = [ "noatime" "nofail" "x-systemd.device-timeout=10" ];
  };

  # SD/SSD asinmasini azalt: swap dosyasi yerine RAM sikistirmali swap.
  # Eski kurulumda 512MB swap dosyasi vardi ve HIC kullanilmamisti (0B).
  zramSwap.enable = true;
  boot.tmp.useTmpfs = true;                    # /tmp diske hic yazilmasin

  # ================================================================= KIMLIK ==
  networking.hostName = "evsunucu";            # eski adi: raspberrypi
  time.timeZone = "Europe/Istanbul";
  i18n.defaultLocale = "en_GB.UTF-8";
  console.keyMap = "us";

  users.users.efe = {
    isNormalUser = true;
    description = "Efe";
    shell = pkgs.bash;                         # chsh yok, shell burada secilir
    extraGroups = [ "wheel" "networkmanager" "docker" "dialout" ];
    openssh.authorizedKeys.keys = [
      # Anahtarlar yeniden uretilecek ("tekrar roll ederiz"). Yeni public
      # anahtari buraya yapistir — boylece makine yeniden kurulunca da gelir.
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGxJTpyOEW5RxylaJGa+HSj//2AnQx7MTgOK5a5kkk02 efe_arch_new"
    ];
  };
  security.sudo.wheelNeedsPassword = false;    # Debian'da da oyleydi

  # ==================================================================== AG ===
  networking.networkmanager.enable = true;

  # Ethernet birincil, wifi backup. Eski kurulumda kablo takili degildi ve
  # wifi ilisikilendirme + NetworkManager boot'tan ~118 saniye yiyordu.
  networking.networkmanager.ensureProfiles.profiles = {
    kablo = {
      # interface-name BILEREK yok: Pi 5'te NixOS'un verdigi ad "end0" da
      # olabilir "eth0" da. Tur eslesmesi yeterli ve kirilgan degil.
      # Kurulumdan sonra `ip -br a` ile dogrula.
      connection = { id = "kablo"; type = "ethernet";
                     autoconnect-priority = "100"; };
      ipv4.method = "auto";
      ipv6.method = "auto";
    };
    # Wifi parolasi git'e girmez — agenix'ten gelir.
    # wifi = { ... psk-flags = 1 ... };
  };

  # Sabit adres ROUTER'da DHCP rezervasyonu ile veriliyor (tek yerden
  # yonetim). Makinede statik IP tanimlanmiyor — ikisi birden olursa catisir.

  # Bekletmesin: cloudflared ve tailscaled kendi yeniden deneme dongulerine
  # sahip, nginx 0.0.0.0'a baglaniyor.
  systemd.services.NetworkManager-wait-online.enable = false;

  # mDNS: Samba'yi acarsan Finder'da kendiliginden gorunmesi buna bagli.
  # Su an NAS kullanilmadigi icin kapali; samba ile birlikte acilir.
  services.avahi.enable = false;

  # --- firewall ---
  # Debian'da HIC kural yoktu. NixOS'ta varsayilan her sey kapali; acilan
  # her port burada ACIKCA yaziyor.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];                  # SSH: LAN'dan da erisilebilsin
    # 80 SADECE tailnet uzerinden. Bugun oldugu gibi bir gunde LAN'dan
    # girebilmek can kurtarici oldugu icin 22 disarida birakildi.
    interfaces."tailscale0".allowedTCPPorts = [ 80 ];
    # Samba acilirsa: interfaces."tailscale0".allowedTCPPorts = [ 80 139 445 ];
  };

  services.tailscale.enable = true;

  # =================================================================== SSH ===
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;          # her yerde yalniz anahtar
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # ================================================================ SECRETS ==
  # agenix: secrets repoda ENCRYPTED durur, boot'ta /run/agenix altina cozulur.
  # secrets.nix icinde hangi anahtarin hangi secret'i acabilecegi yazar.
  age.secrets = {
    # Yollar ../secrets/... olacak — bu dosya modules/ altinda, secrets/ kokte.
    # Su an secrets/ dizini yok (denenip kaldirildi — ssh-to-age uyumsuzlugu
    # nedeniyle native age-keygen ile yeniden kurulacak, ayri bir is).
    # cloudflared-token.file = ../secrets/cloudflared-token.age;
    # wifi-psk.file          = ../secrets/wifi-psk.age;
    # smtp-sifre = { file = ../secrets/smtp.age; owner = "efe"; };
  };

  # ================================================================= NGINX ===
  # Simdilik dis dunyaya bir sey servis etmiyor; EkipTakip gelince burasi
  # dolacak. Iskeleti simdiden dogru kurmak, o gun tek satir eklemek demek.
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;

    virtualHosts."_" = {
      default = true;
      locations."/".return = "404";
    };

    # Yeni bir proje icin vhost eklerken sablon: modules/nginx/hello.nix
    # (su an sadece vmtest'e import ediliyor, bkz. flake.nix).
  };

  # CLOUDFLARED: modules/cloudflared.nix'te — sadece evsunucu (gercek Pi)
  # import ediyor, bkz. flake.nix. vmtest'e bilerek eklenmedi: her tunel
  # gercek Cloudflare hesabina kayitli bir kimlik yaratiyor, atilip
  # yeniden kurulan test VM'inden bunu yapmak anlamsiz olurdu.

  # ================================================================ DOCKER ===
  # Genel amacli — deploy islerinde lazim. Eski kurulumda 19 olu imaj 1GB
  # yer kapliyordu; temizlik artik konfigurasyonun parcasi.
  virtualisation.docker = {
    enable = true;
    autoPrune = { enable = true; dates = "weekly"; flags = [ "--all" ]; };
  };
  # NOT: --volumes BILEREK yok. 2026-08-30'da o bayrak polonyum'un
  # veritabani volume'unu sildi. Isimli volume'ler otomatik temizlige girmesin.

  # ================================================================= SAMBA ===
  # NAS aktif kullanimda degil ("gerekince bakarim"). Paket hazir, servis
  # kapali. Acmak icin: enable = true + avahi + firewall 139/445.
  services.samba = {
    enable = false;
    settings.sata = {
      path = "/home/efe/sata";
      browseable = "yes";
      "read only" = "no";
      "valid users" = "efe";
    };
  };

  # ================================================================ BACKUP ===
  # SD kartta btrfs snapshot YOK (yazma cogaltmasi karti yorar). Yerine:
  # degisken durumun tamami gunluk olarak HDD'ye restic ile backup'lanir.
  #
  # NixOS sistemin KENDISINI zaten geri alabiliyor (nixos-rebuild --rollback
  # + onceki nesiller). Rollback yapamadigi sey VERI — bu is onu kapatiyor.
  # 2026-08-30'daki polonyum volume kaybi tam bu bosluktan cikmisti.
  #
  # DIKKAT: backup HDD'nin uzerinde, HDD'nin baska kopyasi yok. Tek disk
  # arizasi hem veriyi hem backup'i goturur. 3-2-1 icin ucuncu bir hedef
  # (uzak sunucu / harici disk) eklenmeli — o ayri bir karar.
  services.restic.backups = lib.mkIf config.evsunucu.hddVar { yerel = {
    initialize = true;
    repository = "/home/efe/sata/yedek/evsunucu";
    passwordFile = "/run/agenix/restic-sifre";
    paths = [
      "/var/lib"        # servislerin durumu, veritabanlari
      "/home/efe"       # ev dizini
      "/etc/nixos"      # flake burada durmuyorsa da zarari yok
    ];
    exclude = [
      "/home/efe/sata"  # kendini backup'lamasin (sonsuz dongu)
      "/var/lib/docker" # imajlar yeniden cekilebilir
      "**/.cache"
    ];
    timerConfig = { OnCalendar = "daily"; Persistent = true; };
    pruneOpts = [ "--keep-daily 7" "--keep-weekly 4" "--keep-monthly 6" ];
  }; };
  systemd.services.restic-backups-yerel.onFailure = lib.mkIf config.evsunucu.hddVar
    [ "notification@restic-backups-yerel.service" ];

  # ======================================================= DISK SAGLIGI ======
  # 458GB'lik disk backup'lari tutuyor ve tek kopya. SMART izlemesi olmadan
  # olumunu goremezsin.
  services.smartd = lib.mkIf config.evsunucu.hddVar {
    enable = true;
    devices = [ { device = "/dev/sda"; } ];
    notifications.mail = {
      enable = true;
      recipient = "kadirefeatcali@gmail.com";
    };
  };

  # ========================================================= NOTIFICATION ====
  # BUGUNUN EN ONEMLI DERSI: cloudflared 2 ay, logrotate 2 ay sessizce
  # bozuktu. Kimse haber vermedigi icin kimse bilmiyordu.
  #
  # msmtp: exim4'un yerine gecer (o sadece localhost'ta mail biriktiriyordu,
  # kimse okumuyordu). Gmail uygulama parolasi agenix'te.
  programs.msmtp = {
    enable = true;
    accounts.default = {
      host = "smtp.gmail.com";
      port = 587;
      tls = true;
      tls_starttls = true;
      auth = true;
      from = "evsunucu@polonyum.com";
      user = "kadirefeatcali@gmail.com";
      passwordeval = "cat /run/agenix/smtp-sifre";   # agenix bu yola cozer
    };
  };

  # Herhangi bir unit dustugunde mail atan template unit.
  # %i = arizalanan unit'in adi; ExecStart'a arguman olarak GECIRILMELI
  # (scriptArgs yalnizca `script` ile calisir, ExecStart ile degil).
  systemd.services."notification@" = {
    description = "%i failure notification";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "ariza-bildir" ''
        set -u
        birim="$1"
        govde=$(
          printf 'To: kadirefeatcali@gmail.com\n'
          printf 'Subject: [evsunucu] %s FAILURE\n\n' "$birim"
          ${pkgs.systemd}/bin/systemctl status "$birim" --no-pager -l 2>&1 | head -20
          printf '\n--- son 40 satir log ---\n'
          ${pkgs.systemd}/bin/journalctl -u "$birim" -n 40 --no-pager 2>&1
        )
        printf '%s\n' "$govde" | ${pkgs.msmtp}/bin/msmtp -t
      ''} %i";
    };
  };

  # Izlenen unit'ler. Yenisini eklerken buraya da ekle.
  # DIKKAT: onFailure yalnizca ETKIN unit'lere verilebilir — kapali bir
  # servise atamak, ExecStart'i olmayan yarim bir unit uretir.
  systemd.services.nginx.onFailure      = [ "notification@nginx.service" ];
  systemd.services.tailscaled.onFailure = [ "notification@tailscaled.service" ];
  systemd.services.logrotate.onFailure  = [ "notification@logrotate.service" ];
  # cloudflared etkinlestirildiginde bu satiri da ac:
  # systemd.services.cloudflared.onFailure = [ "notification@cloudflared.service" ];

  # ================================================================ JOURNAL ==
  # Eski kurulumda 783MB'a cikmisti. Disk asinmasi ve yer icin sinirli.
  # extraConfig eski API'ydi, bu nixpkgs snapshot'inda kaldirilmis
  # (vmtest'te "no longer has any effect" assertion'i ile yakalandi).
  services.journald.settings.Journal = {
    SystemMaxUse = "200M";
    SystemMaxFileSize = "20M";
  };

  # ======================================================== OTOMATIK BAKIM ===
  system.autoUpgrade = {
    enable = true;
    flake = "github:Efe0909/nix";
    dates = "04:00";
    allowReboot = false;                       # kendi basina yeniden baslatma
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.settings.auto-optimise-store = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # ==================================================== ACIKCA KAPALI ========
  # Eski kurulumda aciktilar ve boot'tan ~67 saniye yiyorlardi. NixOS'ta
  # zaten varsayilan kapali; acikca yaziyorum ki bir daha "acik miydi?"
  # sorusu dogmasin.
  hardware.bluetooth.enable = false;
  services.printing.enable = false;
  # haveged, dphys-swapfile, rpi-eeprom-update, fake-hwclock, triggerhappy,
  # ModemManager, e2scrub_reap, sshswitch, udisks2, apparmor: NixOS'ta ya
  # varsayilan kapali ya da karsiligi yok. Tasinmadi.
  #
  # playit: tamamen dusuruldu. Oyun sunuculari Tailscale uzerinden.
  # exim4: msmtp ile degistirildi.
  # cloudflared-update.timer: DUSURULDU — surum sahipligi Nix'te.

  system.stateVersion = "25.05";               # KURULUM anindaki surum, sabit kalir
  };
}

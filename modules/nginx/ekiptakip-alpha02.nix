{ config, lib, ... }:

# EkipTakip gercek vhost'lari (alpha-0.2: Rust API + React).
#
# Uc host, AYNI statik on yuz + AYNI API:
#   polonyum.com            karsilama + giris
#   dashboard.polonyum.com  masaustu yuzu
#   app.polonyum.com        mobil yuzu
# Hangi sayfanin cizilecegine on yuz Host'a bakip karar verir. nginx:
#   /api/   -> Rust (127.0.0.1:<port>, services.ekiptakip — teamtracker flake'i)
#   diger   -> services.ekiptakip.webRoot (React derlemesi), SPA geri dusmesi
#
# Su an SADECE vmtest'e bagli (bkz. flake.nix). Gercek Pi'ye (evsunucu)
# tasima ayri bir is.
#

let
  # --- neden recommendedProxySettings kapatildi -------------------------
  # O ayar location'a `proxy_set_header X-Forwarded-Proto $scheme;` koyuyor.
  # Bizim zincirde TLS cloudflared'de bitiyor, cloudflared nginx'e DUZ HTTP
  # konusuyor (ingress: http://127.0.0.1:80), yani $scheme = "http".
  #
  # Sonucu Google girisinde patliyor: kimlik.py redirect_uri'yi
  # request.url_for ile kuruyor, uvicorn scheme'i X-Forwarded-Proto'dan
  # aliyor, Google'a http://app.polonyum.com/giris/callback gidiyor ve
  # kayitli https adresiyle uyusmuyor -> redirect_uri_mismatch.
  #
  # Ustune yazmak yetmiyor: nginx'te proxy_set_header ayni seviyede iki kez
  # tanimlanirsa baslik CIFT gider, hangisinin kazandigi belirsizdir. Bu
  # yuzden hazir seti hic dahil etmiyor, hepsini burada acikca yaziyoruz.
  proxyBasliklari = ''
    proxy_set_header Host              $host;    # iki alan adi ayrimi buna bagli
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;    # SABIT — yukaridaki nota bak
    proxy_http_version 1.1;
    proxy_set_header Connection        "";
    proxy_read_timeout 30s;
    proxy_send_timeout 30s;
    # 10 MB uygulama sinirina karsi marj: dosya + multipart cercevesi, ve
    # uygulamanin kendi erken-reddetme esiginin (~11 MB) biraz ustu — sinir
    # asan istek nginx'ten degil UYGULAMADAN donen anlasilir hatayi alsin.
    # Eskiden 2m'ydi: telefondan cekilen fotograf tipik 3-8 MB, yani her
    # yukleme nginx'te CIPLAK 413 alip journalctl'de HICBIR IZ birakmadan
    # kesiliyordu (teamtracker HANDOFF-NIX.md madde 1).
    client_max_body_size 12m;
  '';

  # Statik yanitlarin basliklari. add_header KALITIMI TUZAGI: bir location'da
  # tek bir add_header bile server seviyesindekileri SILER — o yuzden her
  # location bunu KENDISI ekliyor, server seviyesinde hic add_header yok.
  #
  # CSP: Vite derlemesi satir ici betik/stil uretmiyor, dis kaynak yok.
  # Google girisi bir YONLENDIRME (form degil), form-action'a girmiyor.
  guvenlikBasliklari = ''
    add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; font-src 'self'; object-src 'none'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'" always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options DENY always;
    add_header Referrer-Policy strict-origin-when-cross-origin always;
    add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;
  '';

  vhost = {
    # real_ip: zincir cloudflared -> nginx, cloudflared'in kendisi
    # 127.0.0.1'den baglaniyor (ingress: http://127.0.0.1:80). Bu satirlar
    # olmadan $remote_addr HERKES icin 127.0.0.1 olur — nginx'in gordugu TEK
    # peer cloudflared'dir. Sonuc: X-Real-IP sabit, giris hiz siniri
    # (backend/src/ratelimit.rs, dakikada 10) TUM siteyi TEK KOVAYA duser
    # (teamtracker TASK-199/KNOW-86).
    #
    # set_real_ip_from PEER adresine gore calisir: yalniz baglantinin
    # KENDISI 127.0.0.1'den geliyorsa CF-Connecting-IP'ye guvenilir. vmtest'te
    # port 80'e dogrudan vuran biri sahte baslik gonderse de yok sayilir.
    extraConfig = ''
      set_real_ip_from 127.0.0.1;
      real_ip_header CF-Connecting-IP;
    '';

    root = config.services.ekiptakip.webRoot;

    # SPA: bilinmeyen yol index.html'e duser, sayfayi on yuz secer.
    # index.html ONBELLEKLENMEZ: yeni surum derhal gorunsun.
    locations."/" = {
      tryFiles = "$uri /index.html";
      extraConfig = guvenlikBasliklari + ''
        add_header Cache-Control "no-cache" always;
      '';
    };

    # Vite ciktisi icerik ozetli (index-<hash>.js): sonsuza dek onbelleklenir.
    locations."/assets/" = {
      extraConfig = guvenlikBasliklari + ''
        add_header Cache-Control "public, max-age=31536000, immutable" always;
      '';
    };

    locations."/api/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.ekiptakip.port}";
      # Bu location hazir basliklari ALMASIN; hepsi extraConfig'te.
      recommendedProxySettings = false;
      extraConfig = proxyBasliklari + ''
        add_header X-Content-Type-Options nosniff always;
        add_header Cache-Control "no-store" always;
      '';
    };
  };
in
{
  services.nginx.virtualHosts = {
    "polonyum.com" = vhost;             # KARSILAMA + giris
    "app.polonyum.com" = vhost;         # MOBIL yuz
    "dashboard.polonyum.com" = vhost;   # MASAUSTU yuz
  };

  # configuration.nix port 80'i SADECE tailscale0'a acar — bu gercek Pi'nin
  # (evsunucu) guvenlik karari. Bu dosya YALNIZCA vmtest'e
  # gider (bkz. flake.nix modul listesi), gercek Pi'yi hic etkilemez. vmtest'te
  # varsayilan arayuzde de acmak BILEREK: Mac'ten 192.168.64.8:80 ile test
  # edebilmek icin gerekiyor — bu VM zaten Mac'in kendi sanal agi, disariya
  # kapali (UTM host-only/paylasimli ag), yani bu "LAN'a acik" anlaminda bir
  # genisleme degil.
  networking.firewall.allowedTCPPorts = [ 80 ];
}

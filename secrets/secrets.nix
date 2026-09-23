let
  admin = "age1v9zc6ysyyym68w45ussav66lnzhcnmfvsc87djldvd7dt9xsng3s6x6sqh";
  # Ayni kisi, Mac'in SSH anahtari (~/.ssh/id_ed25519): `agenix -e` -i'siz
  # calissin diye. Native anahtar (~/.config/age/keys.txt) de gecerli kalir.
  adminSsh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGxJTpyOEW5RxylaJGa+HSj//2AnQx7MTgOK5a5kkk02";
  # VM'in kendi native age kimligi — /etc/age/vmtest.key'de duruyor,
  # age.identityPaths (vm-test.nix) buraya isaret ediyor. ssh-to-age
  # DEGIL — o uyumsuz cikmisti, native age-keygen kullanildi.
  vmtest = "age16v3n5ap0v0d3a5pjhdsk9ajfrkhskqug0j04wt4qr2t7lqr8ggwsxrwu5l";
in
{
  "cloudflared-creds.age".publicKeys = [ admin adminSsh vmtest ];
  # EkipTakip .env: GOOGLE_CLIENT_ID/SECRET, EKIPTAKIP_SECRET_KEY,
  # POSTGRES_PASSWORD, alan adlari. modules/ekiptakip-app.nix okuyor.
  "ekiptakip-env.age".publicKeys = [ admin adminSsh vmtest ];
  # Cloudflare API token, yalniz polonyum.com Zone:DNS:Edit.
  # modules/cloudflare-dns.nix okuyor.
  "cloudflare-dns-token.age".publicKeys = [ admin adminSsh vmtest ];
  # EkipTakip ilk yonetici listesi (teamtracker KNOW-320): satir basina bir
  # e-posta, her acilista aktif admin yapilir. modules/ekiptakip-alpha02.nix
  # okuyacak — teamtracker pini `bootstrapAdminsFile` secenegini tasiyinca.
  "ekiptakip-bootstrap-admins.age".publicKeys = [ admin adminSsh vmtest ];
}

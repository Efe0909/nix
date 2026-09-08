let
  admin = "age1v9zc6ysyyym68w45ussav66lnzhcnmfvsc87djldvd7dt9xsng3s6x6sqh";
  # VM'in kendi native age kimligi — /etc/age/vmtest.key'de duruyor,
  # age.identityPaths (vm-test.nix) buraya isaret ediyor. ssh-to-age
  # DEGIL — o uyumsuz cikmisti, native age-keygen kullanildi.
  vmtest = "age16v3n5ap0v0d3a5pjhdsk9ajfrkhskqug0j04wt4qr2t7lqr8ggwsxrwu5l";
in
{
  "cloudflared-creds.age".publicKeys = [ admin vmtest ];
  # EkipTakip .env: GOOGLE_CLIENT_ID/SECRET, EKIPTAKIP_SECRET_KEY,
  # POSTGRES_PASSWORD, alan adlari. modules/ekiptakip-app.nix okuyor.
  "ekiptakip-env.age".publicKeys = [ admin vmtest ];
}

let
  # VM'in kendi SSH host key'i -> age. Boot'ta sirri BU makine cozebilsin diye.
  vmtest = "age180jtxw7qf5pxvlmlaxa8634d6h0dmthuclts3awn8ztp2wemyd6stgpwt6";
  # Efe'nin Mac'teki kisisel anahtari -> age. Sirri VM'e SSH atmadan,
  # Mac'ten duzenleyebilsin diye (agenix -e sirri makinede COZMEZ, sadece
  # editor acar; sifreleme/cozme MAC'te olur, VM sadece boot'ta OKUR).
  admin = "age1gkgs5tp5nnkv9juk4lfkv780aq6jv6pcgrmt547wpslqznwxc3zsccweja";
in
{
  "dummy.age".publicKeys = [ vmtest admin ];
}

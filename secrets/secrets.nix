let
  router = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA7jJlLTXRDqHfxl3bUnY3vfBXA7zokcV7OtmdHYCTw8 root@router";
in {
  "wireguard-private-key.age".publicKeys = [router];
}

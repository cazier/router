{...}: {
  imports = [
    ./ethernet.nix
    ./bond.nix
    ./bridge.nix
    ./vlans.nix
  ];

  systemd.network.wait-online.enable = false;
}

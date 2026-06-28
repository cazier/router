{...}: {
  imports = [
    ./ethernet.nix
    ./bond.nix
    ./bridge.nix
    ./vlans.nix
    ./wireguard.nix
  ];

  systemd.network.wait-online.enable = false;
}

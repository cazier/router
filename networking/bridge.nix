{
  lib,
  constants,
  ...
}: let
  inherit (constants) ethernets;
  bridgeIf = constants.interfaces.bridge;

  netdevs = {
    "10-${bridgeIf}" = {
      netdevConfig = {
        Name = bridgeIf;
        Kind = "bridge";
      };
      bridgeConfig.VLANFiltering = true;
    };
  };

  # Interfaces that attach directly to the bridge (e.g. vmbr0 from Proxmox)
  memberNetworks =
    lib.mapAttrs' (
      name: _:
        lib.nameValuePair "60-${name}" {
          inherit name;
          networkConfig = {
            Bridge = bridgeIf;
            DHCP = "no";
          };
          bridgeVLANs = map (id: {VLAN = id;}) constants.allVlanIds;
        }
    )
    (lib.filterAttrs (_: cfg: cfg ? bridge) ethernets);

  # Bridge itself: lists all VLAN sub-interfaces
  bridgeNetwork = {
    "40-${bridgeIf}" = {
      matchConfig.Name = bridgeIf;
      networkConfig.VLAN = map lib.custom.vlanIf (lib.lists.sort (a: b: a < b) constants.allVlanIds);
      bridgeVLANs = map (id: {VLAN = id;}) constants.allVlanIds;
    };
  };
in {
  systemd.network = {
    netdevs = netdevs;
    networks = memberNetworks // bridgeNetwork;
  };
}

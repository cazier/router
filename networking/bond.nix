{
  lib,
  constants,
  ...
}: let
  inherit (constants) ethernets;
  bondIf = constants.interfaces.bond;
  bridgeIf = constants.interfaces.bridge;

  netdevs = {
    "10-${bondIf}" = {
      netdevConfig = {
        Name = bondIf;
        Kind = "bond";
      };
      bondConfig = {
        Mode = constants.bond.mode;
        LACPTransmitRate = constants.bond.lacpRate;
        MIIMonitorSec = constants.bond.monitorInterval;
        TransmitHashPolicy = constants.bond.hashPolicy;
      };
    };
  };

  # Ethernet ports that are members of the bond
  memberNetworks =
    lib.mapAttrs' (
      name: _:
        lib.nameValuePair "30-${name}" {
          inherit name;
          networkConfig = {
            Bond = bondIf;
            DHCP = "no";
            IPv6PrivacyExtensions = "kernel";
          };
        }
    )
    (lib.filterAttrs (_: cfg: cfg ? bond) ethernets);

  # Bond itself joins the bridge
  bondNetwork = {
    "40-${bondIf}" = {
      matchConfig.Name = bondIf;
      networkConfig.Bridge = bridgeIf;
      bridgeVLANs = map (id: {VLAN = id;}) constants.allVlanIds;
    };
  };
in {
  systemd.network = {
    netdevs = netdevs;
    networks = memberNetworks // bondNetwork;
  };
}

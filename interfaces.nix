{
  lib,
  constants,
  ...
}: let
  inherit (constants) ethernets bond dhcp;
  inherit (constants.network) baseAddress baseSubnet;

  ethernetLinks =
    lib.mapAttrs' (
      name: cfg:
        lib.nameValuePair "00-${name}" {
          matchConfig.PermanentMACAddress = cfg.mac;
          linkConfig.Name = name;
        }
    )
    ethernets;

  ethernetNetworks = lib.mapAttrs' (
    name: cfg:
      lib.nameValuePair "00-${name}" ({
          name = name;
        }
        // (
          if cfg ? dhcp && cfg.dhcp
          then {
            DHCP = "ipv4";
          }
          else if cfg ? address
          then
            {
              address = [cfg.address];
            }
            // (lib.optionalAttrs (cfg ? gateway) {
              routes = [{Gateway = cfg.gateway;}];
              dns = constants.dns.upstream;
            })
          else {}
        ))
  ) (lib.filterAttrs (_: cfg: !(cfg ? bond) && !(cfg ? bridge)) ethernets);

  bondMemberNetworks = lib.mapAttrs' (
    name: cfg:
      lib.nameValuePair "30-${name}" {
        name = name;
        networkConfig = {
          Bond = cfg.bond;
          DHCP = "no";
          IPv6PrivacyExtensions = "kernel";
        };
      }
  ) (lib.filterAttrs (_: cfg: cfg ? bond) ethernets);

  bridgeMemberNetworks = lib.mapAttrs' (
    name: cfg:
      lib.nameValuePair "60-${name}" {
        name = name;
        networkConfig = {
          Bridge = cfg.bridge;
          DHCP = "no";
        };
        bridgeVLANs = map (id: {VLAN = id;}) constants.allVlanIds;
      }
  ) (lib.filterAttrs (_: cfg: cfg ? bridge) ethernets);

  bondDev = {
    "10-${constants.interfaces.bond}" = {
      netdevConfig = {
        Name = constants.interfaces.bond;
        Kind = "bond";
      };
      bondConfig = {
        Mode = bond.mode;
        LACPTransmitRate = bond.lacpRate;
        MIIMonitorSec = bond.monitorInterval;
        TransmitHashPolicy = bond.hashPolicy;
      };
    };
  };

  bondNetwork = {
    "40-${constants.interfaces.bond}" = {
      matchConfig.Name = constants.interfaces.bond;
      networkConfig.Bridge = constants.interfaces.bridge;
      bridgeVLANs = map (id: {VLAN = id;}) constants.allVlanIds;
    };
  };

  bridgeDev = {
    "10-${constants.interfaces.bridge}" = {
      netdevConfig = {
        Name = constants.interfaces.bridge;
        Kind = "bridge";
      };
      bridgeConfig.VLANFiltering = true;
    };
  };

  bridgeNetwork = {
    "40-${constants.interfaces.bridge}" = {
      matchConfig.Name = constants.interfaces.bridge;
      networkConfig.VLAN = map lib.custom.vlanIf (lib.lists.sort (p: q: p < q) constants.allVlanIds);
      bridgeVLANs = map (id: {VLAN = id;}) constants.allVlanIds;
    };
  };

  vlanDevs = lib.listToAttrs (map (
      id:
        lib.nameValuePair "20-${lib.custom.vlanIf id}" {
          netdevConfig = {
            Name = lib.custom.vlanIf id;
            Kind = "vlan";
          };
          vlanConfig.Id = id;
        }
    )
    constants.allVlanIds);

  vlanNetworks = lib.listToAttrs (map (
      id:
        lib.nameValuePair "50-${lib.custom.vlanIf id}" {
          matchConfig.Name = lib.custom.vlanIf id;
          networkConfig = {
            Address = lib.custom.updateIpAtOctet baseSubnet 3 id;
            DHCPServer = true;
          };
          dhcpServerConfig = {
            PoolOffset = dhcp.poolOffset;
            PoolSize = dhcp.poolSize;
            DNS = lib.custom.updateIpAtOctet baseAddress 3 id;
          };
        }
    )
    constants.allVlanIds);
in {
  systemd.network = {
    wait-online.enable = false;
    links = ethernetLinks;
    netdevs = bondDev // bridgeDev // vlanDevs;
    networks = ethernetNetworks // bondMemberNetworks // bridgeMemberNetworks // bondNetwork // bridgeNetwork // vlanNetworks;
  };
}

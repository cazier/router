{
  lib,
  constants,
  ...
}: let
  inherit (constants) dhcp;
  inherit (constants.network) baseAddress baseSubnet;

  netdevs = lib.listToAttrs (
    map (id:
      lib.nameValuePair "20-${lib.custom.vlanIf id}" {
        netdevConfig = {
          Name = lib.custom.vlanIf id;
          Kind = "vlan";
        };
        vlanConfig.Id = id;
      })
    constants.allVlanIds
  );

  networks = lib.listToAttrs (
    map (id:
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
      })
    constants.allVlanIds
  );
in {
  systemd.network = {
    netdevs = netdevs;
    networks = networks;
  };
}

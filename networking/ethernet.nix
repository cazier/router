{
  lib,
  constants,
  ...
}: let
  inherit (constants) ethernets;

  links =
    lib.mapAttrs' (
      name: cfg:
        lib.nameValuePair "00-${name}" {
          matchConfig.PermanentMACAddress = cfg.mac;
          linkConfig.Name = name;
        }
    )
    ethernets;

  networks =
    lib.mapAttrs' (
      name: cfg:
        lib.nameValuePair "00-${name}" (
          {inherit name;}
          // (
            if cfg ? dhcp && cfg.dhcp
            then {DHCP = "ipv4";}
            else if cfg ? address
            then
              {address = [cfg.address];}
              // (lib.optionalAttrs (cfg ? gateway) {
                routes = [{Gateway = cfg.gateway;}];
                dns = constants.dns.upstream;
              })
            else {}
          )
        )
    )
    (lib.filterAttrs (_: cfg: !(cfg ? bond) && !(cfg ? bridge)) ethernets);
in {
  systemd.network = {
    links = links;
    networks = networks;
  };
}

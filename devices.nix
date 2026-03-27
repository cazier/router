{lib, ...}: let
  custom = import ./utilities/custom_functions.nix {inherit lib;};

  vlanStickyMacs = {
    "78:20:51:78:cf:72" = {
      name = "PoE Switch";
      hostname = "switch";
      address = "192.168.1.2";
      vlans = [10 20 30 40 50 60 99];
    };
    "50:91:e3:0b:51:f0" = {
      name = "Office WiFi";
      hostname = "office-wifi";
      address = "192.168.1.3";
      vlans = [10 20 30 40 50 60 99];
    };
    "20:23:51:40:db:30" = {
      name = "Basement WiFi";
      hostname = "basement-wifi";
      address = "192.168.1.4";
      vlans = [10 20 30 40 50 60 99];
    };
  };

  vlans = lib.unique (lib.flatten (lib.mapAttrsToList (_: config: config.vlans) vlanStickyMacs));

  macs =
    lib.map (vlan: {
      name = "50-vlan0.${toString vlan}";
      value = {
        dhcpServerStaticLeases =
          lib.mapAttrsToList (
            mac: config: {
              Address = custom.updateIpAtOctet config.address 3 vlan;
              MACAddress = mac;
            }
          )
          vlanStickyMacs;
      };
    })
    vlans;
in {
  systemd.network.networks = lib.listToAttrs macs;
}

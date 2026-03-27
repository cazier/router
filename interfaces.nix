{lib, ...}: let
  custom = import ./utilities/custom_functions.nix {inherit lib;};

  baseAddress = "192.168.1.1";
  baseSubnet = "${baseAddress}/24";

  ethernets = {
    "wan0" = {
      mac = "a0:36:9f:41:e6:d7";
      config = {
        DHCP = "ipv4";
      };
    };
    "wan1" = {
      mac = "bc:24:11:13:05:c1";
      config = {
        address = ["192.168.1.21/24"];
        routes = [{Gateway = "192.168.1.1";}];
        dns = ["9.9.9.9"];
      };
    };
    "lan0" = {
      mac = "bc:24:11:ec:e1:83";
      config = {
        address = ["192.168.0.1/24"];
      };
    };
    "eth0" = {
      mac = "a0:36:9f:41:e6:d4";
      bond = "lagg0";
    };
    "eth1" = {
      mac = "a0:36:9f:41:e6:d5";
      bond = "lagg0";
    };
  };

  laggs = {
    switch = {
      id = "0";
      config = {
        LACPTransmitRate = "fast";
        MIIMonitorSec = "100ms";
        Mode = "802.3ad";
        TransmitHashPolicy = "layer2";
      };
    };
  };

  vlans = {
    HOME = rec {
      id = "10";
      tag = lib.toInt id;
      dhcp = true;
      lagg = "lagg0";
    };
    GUEST = rec {
      id = "20";
      tag = lib.toInt id;
      dhcp = true;
      lagg = "lagg0";
    };
    WORK = rec {
      id = "30";
      tag = lib.toInt id;
      dhcp = true;
      lagg = "lagg0";
    };
    IOT = rec {
      id = "40";
      tag = lib.toInt id;
      dhcp = true;
      lagg = "lagg0";
    };
    DEV = rec {
      id = "50";
      tag = lib.toInt id;
      dhcp = true;
      lagg = "lagg0";
    };
    DMZ = rec {
      id = "60";
      tag = lib.toInt id;
      dhcp = true;
      lagg = "lagg0";
    };
    MGMT = rec {
      id = "99";
      tag = lib.toInt id;
      dhcp = true;
      lagg = "lagg0";
    };
  };

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
      lib.nameValuePair "00-${name}" (
        {
          name = name;
        }
        // cfg.config
      )
  ) (lib.filterAttrs (_: value: value ? config) ethernets);

  laggDevs =
    lib.mapAttrs' (
      name: cfg:
        lib.nameValuePair "10-lagg${cfg.id}" {
          netdevConfig = {
            Name = "lagg${cfg.id}";
            Kind = "bond";
          };
          bondConfig = cfg.config;
        }
    )
    laggs;

  laggNetworks =
    lib.mapAttrs' (
      name: config:
        lib.nameValuePair "30-${name}" {
          name = name;
          networkConfig = {
            Bond = config.bond;
            DHCP = "no";
            IPv6PrivacyExtensions = "kernel";
          };
        }
    ) (lib.attrsets.filterAttrs (_: value: value ? bond) ethernets)
    // lib.mapAttrs' (
      _: config:
        lib.nameValuePair "40-lagg${config.id}" {
          matchConfig.Name = "lagg${config.id}";
          networkConfig = {
            Address = custom.updateSubnetMask (custom.updateIpAtOctet baseSubnet 3 98) 32;
            VLAN = lib.naturalSort (lib.mapAttrsToList (_: vlan: "vlan0.${vlan.id}") vlans);
          };
        }
    )
    laggs;

  vlanDevs =
    lib.mapAttrs' (
      name: cfg:
        lib.nameValuePair "20-vlan0.${cfg.id}" {
          netdevConfig = {
            Name = "vlan0.${cfg.id}";
            Kind = "vlan";
          };
          vlanConfig.Id = cfg.tag;
        }
    )
    vlans;

  vlanNetworks =
    lib.mapAttrs' (
      name: cfg:
        lib.nameValuePair "50-vlan0.${cfg.id}" {
          matchConfig.Name = "vlan0.${cfg.id}";
          networkConfig = {
            Address = custom.updateIpAtOctet baseSubnet 3 cfg.id;
            DHCPServer = true;
          };
          dhcpServerConfig = {
            PoolOffset = 100;
            PoolSize = 100;
            DNS = custom.updateIpAtOctet baseAddress 3 cfg.id;
          };
        }
    )
    vlans;
in {
  systemd.network = {
    wait-online.enable = false;

    links = ethernetLinks;
    netdevs = laggDevs // vlanDevs;
    networks = ethernetNetworks // laggNetworks // vlanNetworks;
  };
}

rec {
  network = {
    baseAddress = "192.168.1.1";
    baseSubnet = "192.168.1.1/24";
  };

  dns = {
    upstream = ["9.9.9.9"];
    bootstrap = ["9.9.9.10"];
  };

  interfaces = {
    bond = "lagg0";
    bridge = "int0";
    wan = "wan0";
    wireguard = "wg0";
  };

  ethernets = {
    wan0 = {
      mac = "a0:36:9f:41:e6:d6";
      dhcp = true;
    };
    eth0 = {
      mac = "a0:36:9f:41:e6:d4";
      bond = interfaces.bond;
    };
    eth1 = {
      mac = "a0:36:9f:41:e6:d5";
      bond = interfaces.bond;
    };
    vmbr0 = {
      mac = "bc:24:11:de:c4:80";
      bridge = interfaces.bridge;
    };
  };

  bond = {
    mode = "802.3ad";
    lacpRate = "fast";
    monitorInterval = "100ms";
    hashPolicy = "layer2";
  };

  vlans = {
    HOME = 10;
    GUEST = 20;
    WORK = 30;
    IOT = 40;
    DEV = 50;
    DMZ = 60;
    MGMT = 99;
  };

  allVlanIds = builtins.attrValues vlans;

  dhcp = {
    poolOffset = 100;
    poolSize = 100;
  };

  enableIPv6 = true;

  nflogGroup = 100;

  wireguard = {
    interface = interfaces.wireguard;
    port = 51820;
    address = "10.100.0.1/24";
    peers = [
      {
        publicKey = "9drfei4FNNDjMyDH9aknYvP2qU6O+KT8/jxc7DpSU2A=";
        ip = "10.100.0.2";
        vlan = vlans.HOME;
      }
    ];
  };

  portForwards = [
    # {
    #   port = 80;
    #   proto = "tcp";
    #   dest = "192.168.${toString vlans.DMZ}.10";
    # }
    # {
    #   port = 443;
    #   proto = "tcp";
    #   dest = "192.168.${toString vlans.DMZ}.10";
    # }
  ];
}

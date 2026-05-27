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
    wan = "wan1";
    bond = "lagg0";
  };

  ethernets = {
    wan0 = {
      mac = "a0:36:9f:41:e6:d7";
      dhcp = true;
    };
    wan1 = {
      mac = "bc:24:11:13:05:c1";
      address = "192.168.1.22/24";
      gateway = network.baseAddress;
    };
    lan0 = {
      mac = "bc:24:11:ec:e1:83";
      address = "192.168.0.1/24";
    };
    eth0 = {
      mac = "a0:36:9f:41:e6:d4";
      bond = interfaces.bond;
    };
    eth1 = {
      mac = "a0:36:9f:41:e6:d5";
      bond = interfaces.bond;
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
  enableFileLogs = true;

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

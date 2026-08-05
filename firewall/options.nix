{lib, ...}: let
  inherit
    (lib.types)
    attrsOf
    bool
    either
    enum
    int
    ints
    listOf
    nullOr
    port
    str
    submodule
    ;
  # Shared by router.firewall.input and router.firewall.forward: which interface(s) traffic
  # must (or must not) arrive on, and the verdict to apply on match.
  fromActionOptions = {
    from = lib.mkOption {
      type = nullOr (either str (listOf str));
      default = null;
      description = ''
        Ingress interface(s) traffic arrives on. This is mutally exclusive with `not_from`, and
        exactly one of the two must be set. The value is the name of a VLAN in
        `router.firewall.vlans` and/or "wan" for the WAN interface.
      '';
    };

    not_from = lib.mkOption {
      type = nullOr (either str (listOf str));
      default = null;
      description = ''
        Ingress interface(s) traffic must not arrive on. This is mutally exclusive with `from`,
        and exactly one of the two must be set. The value is the name of a VLAN in
        `router.firewall.vlans` and/or "wan" for the WAN interface.
      '';
    };

    action = lib.mkOption {
      type = enum ["accept" "drop"];
      default = "accept";
      description = "Action taken on the traffic";
    };
  };
in
  with lib; {
    options.router.firewall = {
      enable = {
        ipv4 = mkOption {
          type = bool;
          default = true;
          description = "Enable IPv4 firewall support. If this is disabled, all IPv4 WAN traffic will be blocked.";
        };

        ipv6 = mkOption {
          type = bool;
          default = true;
          description = "Enable IPv6 firewall support. If this is disabled, all IPv6 WAN traffic will be blocked.";
        };
      };

      wan = mkOption {
        type = str;
        description = "WAN interface name";
      };

      logging = {
        enable = mkOption {
          type = bool;
          default = true;
          description = "Enable ulogd logging with firewall-eye";
        };

        group = mkOption {
          type = int;
          default = 100;
          description = "NFLOG group number for ulogd";
        };

        databasePath = mkOption {
          type = str;
          default = "/var/log/ulogd.db";
          description = "Path for the ulogd sqlite database";
        };
      };

      vlans = mkOption {
        description = "VLAN information";
        default = {};
        type = attrsOf (submodule ({config, ...}: {
          options = {
            id = mkOption {
              type = ints.between 1 4094;
              description = "802.1Q VLAN ID";
            };

            interface = mkOption {
              type = str;
              default = "vlan0.${toString config.id}";
              description = "VLAN sub-interface name";
            };

            subnet = mkOption {
              type = str;
              default = "192.168.${toString config.id}.0/24";
              description = "IPv4 subnet routed on this VLAN";
            };
          };
        }));
      };

      extraInputRules = mkOption {
        type = listOf str;
        default = [];
        description = "Extra nftables rules appended to the inet filter input chain";
      };

      extraForwardRules = mkOption {
        type = listOf str;
        default = [];
        description = "Extra nftables rules appended to the inet filter forward chain";
      };

      input = mkOption {
        default = {};
        description = "Declarative rules for traffic destined to the router itself, identified by key";
        type = attrsOf (submodule {
          options =
            fromActionOptions
            // {
              protocol = mkOption {
                type = either (enum ["tcp" "udp"]) (listOf (enum ["tcp" "udp"]));
                description = "Only match traffic with this protocol(s)";
              };

              port = mkOption {
                type = either port (listOf port);
                description = "Only match traffic with this destination port(s)";
              };
            };
        });
      };

      forward = mkOption {
        default = {};
        description = "Declarative rules for traffic passing through the router, identified by key";
        type = attrsOf (submodule {
          options =
            fromActionOptions
            // {
              to = mkOption {
                type = nullOr (either str (listOf str));
                default = null;
                description = ''
                  Egress interface(s) traffic leaves from. This is mutally exclusive with `not_to`
                  and only one of the two can be set. The value is the name of a VLAN in
                  `router.firewall.vlans` and/or "wan" for the WAN interface. Leave blank (and
                  `not_to` blank) to match only on ingress interface.
                '';
              };

              not_to = mkOption {
                type = nullOr (either str (listOf str));
                default = null;
                description = ''
                  Egress interface(s) traffic must not leave from. This is mutally exclusive with
                  `to` and only one of the two can be set. The value is the name of a VLAN in
                  `router.firewall.vlans` and/or "wan" for the WAN interface. Leave blank (and
                  `to` blank) to match only on ingress interface.
                '';
              };

              dest = mkOption {
                type = nullOr str;
                default = null;
                description = "If set, only match traffic destined to this address/CIDR";
              };

              source = mkOption {
                type = nullOr str;
                default = null;
                description = "If set, only match traffic from this source address/CIDR";
              };

              protocol = mkOption {
                type = nullOr (either (enum ["tcp" "udp"]) (listOf (enum ["tcp" "udp"])));
                default = null;
                description = "If set, only match traffic with this protocol(s)";
              };

              port = mkOption {
                type = nullOr (either port (listOf port));
                default = null;
                description = "If set, only match traffic with this destination port(s)";
              };
            };
        });
      };

      portForwards = mkOption {
        default = [];
        description = "Port forwarding from the WAN interface to an internal host";
        type = listOf (submodule {
          options = {
            port = mkOption {
              type = port;
              description = "Destination port on the WAN side";
            };

            protocol = mkOption {
              type = either (enum ["tcp" "udp"]) (listOf (enum ["tcp" "udp"]));
              description = "Transport protocol(s)";
            };

            dest = mkOption {
              type = str;
              description = "Internal host address (and optional :port) to forward to";
            };
          };
        });
      };
    };
  }

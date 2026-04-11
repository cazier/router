{lib}: let
  constants = import ../constants.nix;
  rfc = import ./rfc.nix;

  WAN_IF = constants.interfaces.wan;
  DMZ_IF = lib.custom.vlanIf constants.vlans.DMZ;

  PRIVATE_NETS = lib.fw.nftablesSet rfc.privateNets;
  BOGONS = lib.fw.nftablesSet rfc.bogons;

  allVlanRules = builtins.concatStringsSep "\n" (
    builtins.attrValues (builtins.mapAttrs (lib.fw.vlanRules {
        wanIf = WAN_IF;
        privateNets = PRIVATE_NETS;
      })
      constants.vlans)
  );

  allDnatRules = builtins.concatStringsSep "\n" (map (lib.fw.dnatRule WAN_IF) constants.portForwards);
  allForwardRules = builtins.concatStringsSep "\n" (map (lib.fw.forwardRule {
      wanIf = WAN_IF;
      dmzIf = DMZ_IF;
    })
    constants.portForwards);

  _nat = [
    ''
            table ip nat {
                chain prerouting {
                    type nat hook prerouting priority dstnat; policy accept;

                    # Port forwards to DMZ
      ${allDnatRules}
                }

                chain postrouting {
                    type nat hook postrouting priority srcnat; policy accept;
                    oifname ${WAN_IF} masquerade
                }
            }
    ''
  ];

  _filter = [
    ''
            table ip filter {
                chain input {
                    type filter hook input priority filter; policy drop;

                    # Drop invalid packets early
                    ct state invalid drop

                    # Allow established/related connections
                    ct state established,related accept

                    # Allow loopback
                    iifname lo accept

                    # Drop bogon/martian source addresses on WAN
                    iifname ${WAN_IF} ip saddr ${BOGONS} drop

                    # Rate-limited ICMP (specific types only)
                    iifname ${WAN_IF} icmp type echo-request limit rate 5/second accept
                    iifname != ${WAN_IF} icmp type { echo-request, echo-reply, destination-unreachable, time-exceeded, parameter-problem } accept

                    # Allow traffic from internal VLANs to router
                    iifname != ${WAN_IF} accept

                    # Log and drop all other inbound WAN traffic
                    iifname ${WAN_IF} limit rate 10/second log prefix "fw-input-drop: " drop
                }

                chain forward {
                    type filter hook forward priority filter; policy drop;

                    # Drop invalid packets early
                    ct state invalid drop

                    # Allow established/related connections
                    ct state established,related accept

                    # Drop bogon/martian source addresses on WAN
                    iifname ${WAN_IF} ip saddr ${BOGONS} drop

                    # Rate limit new TCP connections (SYN flood protection)
                    tcp flags syn ct state new limit rate 100/second accept

                    # Allow port forwarded traffic to DMZ
      ${allForwardRules}

      ${allVlanRules}

                    # Log dropped forward traffic
                    limit rate 10/second log prefix "fw-forward-drop: "
                }
            }
    ''
  ];

  _filter6 = [
    ''
      table ip6 filter {
          chain input {
              type filter hook input priority filter; policy drop;

              # Drop invalid packets
              ct state invalid drop

              # Allow established/related connections
              ct state established,related accept

              # Allow loopback
              iifname lo accept

              # Allow ICMPv6 (required for IPv6 to function)
              iifname != ${WAN_IF} icmpv6 type { echo-request, echo-reply, nd-neighbor-solicit, nd-neighbor-advert, nd-router-solicit, nd-router-advert } accept

              # Allow internal traffic
              iifname != ${WAN_IF} accept

              # Log and drop WAN inbound
              iifname ${WAN_IF} limit rate 10/second log prefix "fw6-input-drop: " drop
          }

          chain forward {
              type filter hook forward priority filter; policy drop;

              # Drop invalid packets
              ct state invalid drop

              # Allow established/related connections
              ct state established,related accept

              # Log dropped traffic
              limit rate 10/second log prefix "fw6-forward-drop: "
          }
      }
    ''
  ];
in {
  ruleset = _nat ++ _filter ++ _filter6;
}

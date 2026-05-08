{lib}: let
  constants = import ../constants.nix;
  rfc = import ./rfc.nix;

  WAN_IF = constants.interfaces.wan;
  DMZ_IF = lib.custom.vlanIf constants.vlans.DMZ;
  NFLOG_GROUP = toString constants.nflogGroup;

  allVlanRules = builtins.concatStringsSep "\n" (
    builtins.attrValues (
      builtins.mapAttrs (lib.fw.vlanRules {
        wanIf = WAN_IF;
        privateNets = lib.fw.nftablesSet rfc.PRIVATE_NETWORKS;
      })
      constants.vlans
    )
  );

  portForwardDNATRules = builtins.concatStringsSep "\n" (
    map (lib.fw.portForwardDNATRules WAN_IF) constants.portForwards
  );
  portForwardFilterRules = builtins.concatStringsSep "\n" (
    map (lib.fw.portForwardFilterRule {
      wanIf = WAN_IF;
      dmzIf = DMZ_IF;
    })
    constants.portForwards
  );

  dropBogons =
    ''
      iifname ${WAN_IF} ip saddr ${lib.fw.nftablesSet rfc.IPV4_BOGONS} drop
    ''
    + lib.optionalString constants.enableIPv6 ''
      iifname ${WAN_IF} ip6 saddr ${lib.fw.nftablesSet rfc.IPV6_BOGONS} drop
    '';

  icmpInputRules =
    ''
      iifname ${WAN_IF} icmp type echo-request limit rate 5/second accept
      iifname != ${WAN_IF} icmp type { echo-request, echo-reply, destination-unreachable, time-exceeded, parameter-problem } accept
    ''
    + lib.optionalString constants.enableIPv6 ''
      icmpv6 type { nd-neighbor-solicit, nd-neighbor-advert } accept
      iifname ${WAN_IF} icmpv6 type { nd-router-advert, nd-router-solicit } accept
      iifname ${WAN_IF} icmpv6 type { destination-unreachable, packet-too-big, time-exceeded, parameter-problem } accept
      iifname ${WAN_IF} icmpv6 type echo-request limit rate 5/second accept
      iifname != ${WAN_IF} icmpv6 type { echo-request, echo-reply, destination-unreachable, packet-too-big, time-exceeded, parameter-problem, nd-router-solicit, nd-router-advert } accept
    '';

  icmpForwardRules = lib.optionalString constants.enableIPv6 ''
    icmpv6 type packet-too-big accept
  '';

  nat = ''
    # IPv4-only NAT table; inet is not used because IPv6 NAT is not needed
    table ip nat {
      # Runs before routing decisions; used for destination NAT (port forwarding)
      chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;

        # Rewrite destination address/port to redirect inbound WAN traffic to internal hosts
        ${portForwardDNATRules}
      }

      # Runs after routing decisions; used for source NAT on outbound traffic
      chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
        # Replace the source address of packets leaving via WAN with the router's WAN IP
        oifname ${WAN_IF} masquerade
      }
    }
  '';

  filter = ''
    # inet table applies to both IPv4 and IPv6 traffic
    table inet filter {
      # Handles packets destined for the router itself
      chain input {
        # Default policy: drop everything not explicitly accepted
        type filter hook input priority filter; policy drop;

        # Drop incoming traffic without a known connection
        ct state invalid drop

        # Accept incoming traffic with an associated outgoing traffic
        ct state established,related accept

        # Allow all traffic on loopback interface
        iifname lo accept

        # Drop packets from WAN with unroutable (bogon) source addresses
        ${dropBogons}
        # Allow ICMP/ICMPv6 for diagnostics and IPv6 neighbor discovery
        ${icmpInputRules}

        # Allow traffic from internal VLANs to router
        iifname != ${WAN_IF} accept

        # Log and drop all other inbound WAN traffic
        iifname ${WAN_IF} limit rate 10/second log group ${NFLOG_GROUP} prefix "fw-input-drop: " drop
      }

      # Handles packets being routed through the router between interfaces
      chain forward {
        # Default policy: drop everything not explicitly accepted
        type filter hook forward priority filter; policy drop;

        # Drop packets that do not match any valid connection state
        ct state invalid drop
        # Allow packets belonging to already-established or related connections
        ct state established,related accept

        # Drop packets from WAN with unroutable (bogon) source addresses
        ${dropBogons}
        # Allow ICMPv6 packet-too-big messages needed for Path MTU Discovery
        ${icmpForwardRules}

        # Rate limit new TCP connections (SYN flood protection)
        tcp flags syn ct state new limit rate 100/second accept

        # Allow forwarding of traffic for each configured port forward destination
        ${portForwardFilterRules}

        # VLAN rules: allow own subnet, block other private nets, allow WAN.
        # The oifname wan1 rule is protocol-agnostic and covers IPv6-to-WAN forwarding.
        ${allVlanRules}

        # Log dropped forward traffic
        limit rate 10/second log group ${NFLOG_GROUP} prefix "fw-forward-drop: "
      }
    }
  '';
in {
  ruleset = [
    nat
    filter
  ];
}

{lib}: let
  constants = import ../constants.nix;
  rfc = import ./rfc.nix;

  WAN_IF = constants.interfaces.wan;
  DMZ_IF = lib.custom.vlanIf constants.vlans.DMZ;
  MGMT_IF = lib.custom.vlanIf constants.vlans.MGMT;
  WG_IF = constants.wireguard.interface;
  WG_PORT = toString constants.wireguard.port;

  allVlanRules = builtins.concatStringsSep "\n" (
    builtins.attrValues (
      builtins.mapAttrs (lib.fw.vlanRules WAN_IF (lib.fw.nftablesSet rfc.PRIVATE_NETWORKS))
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
      iifname ${WAN_IF} ip saddr ${lib.fw.nftablesSet rfc.IPV4_BOGONS} limit rate 10/second ${lib.fw.mkLog "bogon" "drop"}
    ''
    + lib.optionalString constants.enableIPv6 ''
      iifname ${WAN_IF} ip6 saddr ${lib.fw.nftablesSet rfc.IPV6_BOGONS} limit rate 10/second ${lib.fw.mkLog "bogon" "drop"}
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

  wireguardInputRules = ''
    # WireGuard: allow VPN tunnel from WAN
    iifname ${WAN_IF} udp dport ${WG_PORT} ${lib.fw.mkLog "wg-tunnel" "accept"}
  '';

  wireguardForwardRules = builtins.concatStringsSep "\n" (
    map (peer: let
      vlanId = peer.vlan;
      vlanIf = lib.custom.vlanIf vlanId;
    in ''
      iifname ${WG_IF} ip saddr ${peer.ip} oifname { ${vlanIf}, ${WAN_IF} } ${lib.fw.mkLog "wg-peer" "accept"}
    '')
    constants.wireguard.peers
  );

  localInputRules = ''
    # DNS: all internal VLANs
    iifname != ${WAN_IF} tcp dport 53 ${lib.fw.mkLog "dns" "accept"}
    iifname != ${WAN_IF} udp dport 53 ${lib.fw.mkLog "dns" "accept"}

    # DHCP: all internal VLANs
    iifname != ${WAN_IF} udp dport 67 ${lib.fw.mkLog "dhcp" "accept"}

    # SSH: MGMT VLAN
    iifname ${MGMT_IF} tcp dport 22 ${lib.fw.mkLog "ssh" "accept"}

    # AdGuard Home admin UI: MGMT VLAN only
    iifname ${MGMT_IF} tcp dport 3000 ${lib.fw.mkLog "adguard" "accept"}

    # Omada controller: MGMT VLAN only
    iifname ${MGMT_IF} tcp dport { 8088, 8043, 8843 } ${lib.fw.mkLog "omada" "accept"}
    iifname ${MGMT_IF} udp dport { 27001, 29810 } ${lib.fw.mkLog "omada" "accept"}
    iifname ${MGMT_IF} tcp dport { 29811, 29812, 29813, 29814 } ${lib.fw.mkLog "omada" "accept"}

    # FireWalleye: MGMT VLAN only
    iifname ${MGMT_IF} tcp dport { 8000 } ${lib.fw.mkLog "firewalleye" "accept"}
  '';

  icmpForwardRules = lib.optionalString constants.enableIPv6 ''
    icmpv6 type packet-too-big accept
  '';

  nat = ''
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
        ct state invalid limit rate 10/second ${lib.fw.mkLog "ct-invalid" "drop"}

        # Accept incoming traffic with an associated outgoing traffic
        ct state established,related accept

        # Allow all traffic on loopback interface
        iifname lo accept

        # Drop packets from WAN with unroutable (bogon) source addresses
        ${dropBogons}
        # Allow ICMP/ICMPv6 for diagnostics and IPv6 neighbor discovery
        ${icmpInputRules}
        # Allow specific services from internal VLANs; all other router-destined traffic is dropped
        ${localInputRules}
        # Allow WireGuard from WAN
        ${wireguardInputRules}
        # Log and drop all other inbound traffic. The drop is technically redundant...
        limit rate 10/second ${lib.fw.mkLog "input" "drop"}
      }

      # Handles packets being routed through the router between interfaces
      chain forward {
        # Default policy: drop everything not explicitly accepted
        type filter hook forward priority filter; policy drop;

        # Drop packets that do not match any valid connection state
        ct state invalid limit rate 10/second ${lib.fw.mkLog "ct-invalid" "drop"}
        # Allow packets belonging to already-established or related connections
        ct state established,related accept

        # Drop packets from WAN with unroutable (bogon) source addresses
        ${dropBogons}
        # Allow ICMPv6 packet-too-big messages needed for Path MTU Discovery
        ${icmpForwardRules}

        # Rate limit new TCP connections (SYN flood protection)
        tcp flags syn ct state new limit rate 100/second ${lib.fw.mkLog "new-conn" "accept"}

        # Allow forwarding of traffic for each configured port forward destination
        ${portForwardFilterRules}

        # Allow WireGuard clients to route through the router
        ${wireguardForwardRules}

        # VLAN rules: allow own subnet, block other private nets, allow WAN.
        # The oifname wan1 rule is protocol-agnostic and covers IPv6-to-WAN forwarding.
        ${allVlanRules}

        # Log and drop all other forward traffic
        limit rate 10/second ${lib.fw.mkLog "forward" "drop"}
      }
    }
  '';
in {
  ruleset = [
    nat
    filter
  ];
}

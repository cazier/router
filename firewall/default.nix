{
  config,
  lib,
  ...
}: let
  cfg = config.router.firewall;
  rfc = import ./rfc.nix;

  # Create a logging entry with optional action. If the logging prefix contains an underscore (`_`), it is split and
  # only the part before the first underscore is included
  mkLog = prefix: action: let
    _prefix = builtins.head (lib.splitString "_" prefix);
    label =
      if action == null
      then _prefix
      else "${action}-${_prefix}";
  in
    "log group ${toString cfg.logging.group} prefix \"${label}\"" + lib.optionalString (action != null) " ${action}";

  # Create an nftables set from a list of data. (Note that even if there's only one item in the list, that's still
  # valid as a single-item set)
  toNFTSet = data: "{ ${builtins.concatStringsSep ", " (map toString (lib.flatten data))} }";

  # Wrapped function to resolve interface name(s) from a common value, handling ingress/egress interfaces, and whether
  # it's negated
  # i.e., the name `wan` resolves to the WAN interface's actual name, the DMZ VLAN resolves to vlan0.<DMZ VID>
  #       and if the keep flag is false, it's negated, so prepend `!=`
  _mkIfaceMatch = keyword: keep: iface: let
    resolveInterface = name:
      if name == "wan"
      then cfg.wan
      else if cfg.vlans ? ${name}
      then cfg.vlans.${name}.interface
      else name;
    negate = lib.optionalString (!keep) "!= ";
  in "${keyword} ${negate}${toNFTSet (map resolveInterface (lib.flatten iface))}";

  # Match ingress interface names
  mkIifaceMatch = _mkIfaceMatch "iifname";
  # Match egress interface names
  mkOifaceMatch = _mkIfaceMatch "oifname";

  # Pick whichever of a `<direction>`/`not_<direction>` pair is set on and then pass it through to the
  # appropriate interface matcher
  mkCompileInterface = function: entry: field: let
    keep = entry.${field} or null;
    omit = entry."not_${field}" or null;
  in
    if keep != null
    then function true keep
    else if omit != null
    then function false omit
    else null;

  nullableString = value: string:
    if value != null
    then string
    else "";

  # Rewrite the destination address/port of inbound WAN traffic to the port forward target
  portFortwardNatRules = lib.optionals cfg.enable.ipv4 (map (
      portForward: let
        proto = "meta l4proto ${toNFTSet portForward.protocol}";
        dport = "th dport ${toNFTSet portForward.port}";
      in "${mkIifaceMatch true "wan"} ${proto} ${dport} ${mkLog "dnat" null} dnat to ${portForward.dest}"
    )
    cfg.portForwards);

  preroutingRules = lib.flatten [
    portFortwardNatRules
  ];

  postRoutingRules = lib.flatten [
    # Replace the source address of packets leaving via WAN with the router's WAN IP
    "${mkOifaceMatch true "wan"} ${mkLog "masquerade" null} masquerade"
  ];

  natTable = ''
    table ip nat {
      # Runs before routing decisions; used for destination NAT (port forwarding)
      chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;
        ${builtins.concatStringsSep "\n    " preroutingRules}
      }

      # Runs after routing decisions; used for source NAT on outbound traffic
      chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
        ${builtins.concatStringsSep "\n    " postRoutingRules}
      }
    }
  '';

  # Block ALL traffic from each IP family if they're disabled
  blockIPFamilyRules = lib.flatten [
    (lib.optional (!cfg.enable.ipv4) "meta nfproto ipv4 ${mkLog "ipv4" "drop"}")
    (lib.optional (!cfg.enable.ipv6) "meta nfproto ipv6 ${mkLog "ipv6" "drop"}")
  ];

  # Connection-tracking rules shared by both chains
  connectionRules = lib.flatten [
    # Drop packets nftables can't associate with any known connection
    "ct state invalid limit rate 10/second ${mkLog "ct-invalid" "drop"}"
    # Allow return traffic for established connections
    "ct state established,related ${mkLog "ct" "accept"}"
  ];

  # Bogon (spoofed/invalid source address) drops shared by both chains
  dropBogonRules = lib.flatten [
    (lib.optionals cfg.enable.ipv4 [
      # Drop IPv4 packets from WAN whose source address is invalid
      "${mkIifaceMatch true "wan"} ip saddr ${toNFTSet rfc.IPV4_BOGONS} limit rate 10/second ${mkLog "bogon" "drop"}"
    ])
    (lib.optionals cfg.enable.ipv6 [
      # Same bogon check for IPv6 source addresses arriving from WAN
      "${mkIifaceMatch true "wan"} ip6 saddr ${toNFTSet rfc.IPV6_BOGONS} limit rate 10/second ${mkLog "bogon" "drop"}"
    ])
  ];

  # ICMP/ICMPv6 rules for traffic destined to the router itself
  icmpInputRules = let
    nominalIcmpTypes = ["echo-request" "echo-reply" "destination-unreachable" "time-exceeded" "parameter-problem"];
  in
    lib.flatten [
      (lib.optionals cfg.enable.ipv4 [
        # Allow (with a rate limit) ICMP ping on the WAN interface
        "${mkIifaceMatch true "wan"} icmp type echo-request limit rate 5/second ${mkLog "icmp" "accept"}"
        # Block most other ICMP packets on non-WAN interfaces
        "${mkIifaceMatch false "wan"} icmp type ${toNFTSet nominalIcmpTypes} ${mkLog "icmp" "accept"}"
      ])
      (lib.optionals cfg.enable.ipv6 [
        # Allow neighbor discovery (on all interfaces)
        "icmpv6 type ${toNFTSet ["nd-neighbor-solicit" "nd-neighbor-advert"]} ${mkLog "icmpv6" "accept"}"
        # Allow router discovery from WAN
        "${mkIifaceMatch true "wan"} icmpv6 type ${toNFTSet ["nd-router-advert" "nd-router-solicit"]} ${mkLog "icmpv6" "accept"}"
        # Allow standard ICMPv6 error handling from WAN
        "${mkIifaceMatch true "wan"} icmpv6 type ${toNFTSet ["destination-unreachable" "packet-too-big" "time-exceeded" "parameter-problem"]} ${mkLog "icmpv6" "accept"}"
        # Allow (with rate limit) ICMPv6 ping arriving from WAN
        "${mkIifaceMatch true "wan"} icmpv6 type echo-request limit rate 5/second ${mkLog "icmpv6" "accept"}"
        # Allow most other ICMPv6 packets on non-WAN interfaces
        "${mkIifaceMatch false "wan"} icmpv6 type ${toNFTSet nominalIcmpTypes ++ ["packet-too-big" "nd-router-solicit" "nd-router-advert"]} ${mkLog "icmpv6" "accept"}"
      ])
    ];

  # ICMPv6 rules for traffic passing through the router
  icmpForwardRules = lib.flatten [
    (lib.optionals cfg.enable.ipv6 [
      # PMTUD needs big ICMPv6 packets
      "icmpv6 type packet-too-big ${mkLog "icmpv6" "accept"}"
    ])
  ];

  # Per-VLAN isolation
  vlanForwardRules = lib.flatten [
    (lib.optionals cfg.enable.ipv4 (lib.concatMap (vlan: [
      # Allow VLANs to communicate with any other device within their own subnet
      "${mkIifaceMatch true vlan.interface} ip daddr ${vlan.subnet} ${mkLog "vlan" "accept"}"
      # Block VLANs from communicating with devices in *other* VLANs
      "${mkIifaceMatch true vlan.interface} ip daddr ${toNFTSet rfc.PRIVATE_NETWORKS} limit rate 10/second ${mkLog "vlan" "drop"}"
      # Allow VLANs to reach the general internet
      "${mkIifaceMatch true vlan.interface} ${mkOifaceMatch true "wan"} ${mkLog "vlan" "accept"}"
    ]) (lib.attrValues cfg.vlans)))
  ];

  compiledInputRules =
    lib.mapAttrsToList (
      name: entry:
        lib.concatStringsSep " " (
          lib.filter (x: x != "") (
            lib.flatten [
              # Match the entry's ingress interface
              (mkCompileInterface mkIifaceMatch entry "from")
              # Match protocols and destination ports, if provided
              (nullableString entry.protocol "meta l4proto ${toNFTSet entry.protocol}" + lib.optionalString (entry.port != null) " th dport ${toNFTSet entry.port}")
              # Extra raw statement(s), if provided
              (nullableString entry.extra entry.extra)
              # Log and apply the entry's configured verdict
              (mkLog name entry.action)
            ]
          )
        )
    )
    cfg.input;

  # Generate forward entries for port forwards to use in the filter.forward table
  portForwardEntries = builtins.listToAttrs (lib.imap0 (index: entry:
    lib.nameValuePair "portforward_${toString index}" {
      inherit (entry) dest protocol port;
      from = "wan";
      to = "DMZ";
      extra = "ct state new limit rate 25/second";
      action = "accept";
    })
  cfg.portForwards);

  compiledForwardRules =
    lib.mapAttrsToList (
      name: entry:
        lib.concatStringsSep " " (
          lib.filter (x: x != "") (
            lib.flatten [
              # Match the entry's ingress interface
              (mkCompileInterface mkIifaceMatch entry "from")
              # Match the entry's egress interface, if provided
              (mkCompileInterface mkOifaceMatch entry "to")
              # Match source address/CIDR, if provided
              (nullableString (entry.source or null) "ip saddr ${entry.source}")
              # Match destination address/CIDR, if provided
              (nullableString entry.dest "ip daddr ${entry.dest}")
              # Match protocols and destination ports, if provided
              (nullableString entry.protocol "meta l4proto ${toNFTSet entry.protocol}" + lib.optionalString (entry.port != null) " th dport ${toNFTSet entry.port}")
              # Extra raw statement(s), if provided
              (nullableString entry.extra entry.extra)
              # Log and apply the entry's configured verdict
              (mkLog name entry.action)
            ]
          )
        )
    )
    (cfg.forward // portForwardEntries);

  inputRules = lib.flatten [
    blockIPFamilyRules
    connectionRules
    # Always allow loopback traffic
    "iifname lo ${mkLog "lo" "accept"}"
    dropBogonRules
    icmpInputRules
    compiledInputRules
    cfg.extraInputRules
    # Drop and log everything not otherwise listed
    "limit rate 10/second ${mkLog "input" "drop"}"
  ];

  forwardRules = lib.flatten [
    blockIPFamilyRules
    connectionRules
    dropBogonRules
    icmpForwardRules
    vlanForwardRules
    compiledForwardRules
    cfg.extraForwardRules
    # Drop and log everything not otherwise listed
    "limit rate 10/second ${mkLog "forward" "drop"}"
  ];

  filterTable = ''
    table inet filter {
      # Handles packets destined for the router itself
      chain input {
        # Default policy: drop everything not explicitly accepted
        type filter hook input priority filter; policy drop;
        ${builtins.concatStringsSep "\n    " inputRules}
      }

      # Handles packets being routed through the router between interfaces
      chain forward {
        # Default policy: drop everything not explicitly accepted
        type filter hook forward priority filter; policy drop;
        ${builtins.concatStringsSep "\n    " forwardRules}
      }
    }
  '';
in {
  imports = [
    ./options.nix
    ./ulogd
  ];

  config = {
    assertions =
      lib.mapAttrsToList (name: entry: {
        assertion = (entry.from != null) != (entry.not_from != null);
        message = "router.firewall.input entry '${name}': exactly one of `from`/`not_from` must be set.";
      })
      cfg.input
      ++ lib.mapAttrsToList (name: entry: {
        assertion = (entry.from != null) != (entry.not_from != null);
        message = "router.firewall.forward entry '${name}': exactly one of `from`/`not_from` must be set.";
      })
      cfg.forward
      ++ lib.mapAttrsToList (name: entry: {
        assertion = !(entry.to != null && entry.not_to != null);
        message = "router.firewall.forward entry '${name}': `to` and `not_to` are mutually exclusive.";
      })
      cfg.forward;

    networking = lib.mkIf (cfg.enable.ipv4 || cfg.enable.ipv6) {
      firewall.enable = false;
      nftables = {
        enable = true;
        flushRuleset = true;
        checkRuleset = true;
        ruleset = natTable + filterTable;
      };
    };
  };
}

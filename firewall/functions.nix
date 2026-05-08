{lib, ...}: {
  # Convert a list to nftables set syntax: [ "a" "b" ] -> "{ a, b }"
  nftablesSet = list: "{ ${builtins.concatStringsSep ", " list} }";

  # Generate firewall rules for a VLAN: allow own subnet, block other private nets, allow WAN
  vlanRules = {
    wanIf,
    privateNets,
  }: name: id: ''
    # ${name} (VLAN ${toString id}): Allow internet and own subnet, block other VLANs
    iifname ${lib.custom.vlanIf id} ip daddr ${lib.custom.vlanNet id} accept
    iifname ${lib.custom.vlanIf id} ip daddr ${privateNets} drop
    iifname ${lib.custom.vlanIf id} oifname ${wanIf} accept
  '';

  # Generate DNAT rule for a port forward
  portForwardDNATRules = wanIf: pf: ''
    iifname ${wanIf} ${pf.proto} dport ${toString pf.port} dnat to ${pf.dest}
  '';

  # Generate forward allow rule for a port forward
  portForwardFilterRule = {
    wanIf,
    dmzIf,
  }: pf: ''
    iifname ${wanIf} oifname ${dmzIf} ip daddr ${pf.dest} ${pf.proto} dport ${toString pf.port} ct state new limit rate 25/second accept
  '';
}

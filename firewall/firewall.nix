let
  WAN_IF = "wan1";
  VLAN10_IF = "vlan0.10";

  VLAN10_NET = "192.168.10.0/24";

  _nat = [
    ''
      table ip nat {
          chain postrouting {
              type nat hook postrouting priority srcnat; policy accept;
              oifname ${WAN_IF} masquerade
          }
      }
    ''
  ];
in
{
  ruleset = _nat;

}

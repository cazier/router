{lib}: let
  replaceElemAt = list: idx: newElem:
    builtins.genList (i:
      if i == idx
      then newElem
      else builtins.elemAt list i) (builtins.length list);

  custom = {
    updateIpAtOctet = ip: octet: new:
      builtins.concatStringsSep "." (
        replaceElemAt (lib.splitString "." ip) (octet - 1) (builtins.toString new)
      );
    updateSubnetMask = address: mask:
      builtins.concatStringsSep "/" (
        replaceElemAt (lib.splitString "/" address) 1 (builtins.toString mask)
      );
    vlanIf = id: "vlan0.${toString id}";
    vlanNet = id: "192.168.${toString id}.0/24";
  };
in
  custom

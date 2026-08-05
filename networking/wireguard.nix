{
  config,
  constants,
  lib,
  ...
}: let
  cfg = config.router.firewall;

  wgIf = constants.interfaces.wireguard;
  inherit (constants) wireguard;

  indexedPeers = lib.imap0 (index: peer: {inherit index peer;}) wireguard.peers;

  wireguardForwardRules = builtins.listToAttrs (map (
      {
        index,
        peer,
      }: let
        vlanName = lib.findFirst (name: cfg.vlans.${name}.id == peer.vlan) null (builtins.attrNames cfg.vlans);
      in
        lib.nameValuePair "wg-peer_${toString index}" {
          from = wgIf;
          to = [vlanName "wan"];
          source = peer.ip;
        }
    )
    indexedPeers);

  netdevs = {
    "90-${wgIf}" = {
      netdevConfig = {
        Name = wgIf;
        Kind = "wireguard";
      };
      wireguardConfig = {
        PrivateKeyFile = config.age.secrets.wireguard-private-key.path;
        ListenPort = wireguard.port;
      };
      wireguardPeers =
        map ({
          index,
          peer,
        }: {
          PublicKey = peer.publicKey;
          AllowedIPs = "${peer.ip}/32";
          PresharedKeyFile = config.age.secrets."wireguard-peer-${toString index}-psk".path;
        })
        indexedPeers;
    };
  };

  networks = {
    "90-${wgIf}" = {
      matchConfig.Name = wgIf;
      address = [wireguard.address];
    };
  };

  pskSecrets = builtins.listToAttrs (map ({index, ...}: {
      name = "wireguard-peer-${toString index}-psk";
      value = {
        file = ../secrets/wireguard-peer-${toString index}-psk.age;
        owner = "systemd-network";
      };
    })
    indexedPeers);
in {
  router.firewall = {
    input."wireguard" = {
      from = "wan";
      protocol = "udp";
      port = wireguard.port;
    };

    forward = wireguardForwardRules;
  };

  age.secrets =
    {
      wireguard-private-key = {
        file = ../secrets/wireguard-private-key.age;
        owner = "systemd-network";
      };
    }
    // pskSecrets;

  systemd.network = {
    netdevs = netdevs;
    networks = networks;
  };
}

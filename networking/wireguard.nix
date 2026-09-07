{
  config,
  constants,
  lib,
  ...
}: let
  wgIf = constants.interfaces.wireguard;
  inherit (constants) wireguard;

  wireguardForwardRules =
    lib.mapAttrs' (
      name: peer:
        lib.nameValuePair "wg-peer_${name}" {
          from = wgIf;
          to = peer.vlans ++ ["wan"];
          source = peer.ip;
        }
    )
    wireguard.peers;

  netdevs = {
    "90-${wgIf}" = {
      netdevConfig = {
        Name = wgIf;
        Kind = "wireguard";
      };
      wireguardConfig = {
        PrivateKeyFile = config.sops.secrets.wireguard-private-key.path;
        ListenPort = wireguard.port;
      };
      wireguardPeers =
        lib.mapAttrsToList (name: peer: {
          PublicKey = peer.publicKey;
          AllowedIPs = "${peer.ip}/32";
          PresharedKeyFile = config.sops.secrets."wireguard-peer-${name}-psk".path;
        })
        wireguard.peers;
    };
  };

  networks = {
    "90-${wgIf}" = {
      matchConfig.Name = wgIf;
      address = [wireguard.address];
    };
  };

  pskSecrets =
    lib.mapAttrs' (name: _: {
      name = "wireguard-peer-${name}-psk";
      value = {
        sopsFile = ../secrets/wireguard.yaml;
        owner = "systemd-network";
      };
    })
    wireguard.peers;
in {
  router.firewall = {
    input."wireguard" = {
      from = "wan";
      protocol = "udp";
      port = wireguard.port;
      extra = "ct state new limit rate 10/second";
    };

    forward = wireguardForwardRules;
  };

  sops.secrets =
    {
      wireguard-private-key = {
        sopsFile = ../secrets/wireguard.yaml;
        owner = "systemd-network";
      };
    }
    // pskSecrets;

  systemd.network = {
    netdevs = netdevs;
    networks = networks;
  };
}

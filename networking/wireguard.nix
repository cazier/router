{
  config,
  constants,
  lib,
  ...
}: let
  wgIf = constants.interfaces.wireguard;
  inherit (constants) wireguard;

  indexedPeers = lib.imap0 (i: peer: {inherit i peer;}) wireguard.peers;

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
          i,
          peer,
        }: {
          PublicKey = peer.publicKey;
          AllowedIPs = "${peer.ip}/32";
          PresharedKeyFile = config.age.secrets."wireguard-peer-${toString i}-psk".path;
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

  pskSecrets = builtins.listToAttrs (map ({
      i,
      peer,
    }: {
      name = "wireguard-peer-${toString i}-psk";
      value = {
        file = ../secrets/wireguard-peer-${toString i}-psk.age;
        owner = "systemd-network";
      };
    })
    indexedPeers);
in {
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

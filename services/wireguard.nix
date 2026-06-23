{
  config,
  constants,
  ...
}: let
  wg = constants.wireguard;
in {
  age.secrets.wireguardPrivateKey = {
    file = ../secrets/wireguard-private-key.age;
    owner = "systemd-network";
  };

  systemd.network = {
    enable = true;
    netdevs."90-${wg.interface}" = {
      netdevConfig = {
        Kind = "wireguard";
        Name = wg.interface;
      };
      wireguardConfig = {
        PrivateKeyFile = config.age.secrets.wireguardPrivateKey.path;
        ListenPort = wg.port;
      };
      wireguardPeers =
        map (peer: {
          PublicKey = peer.publicKey;
          AllowedIPs = "${peer.ip}/32";
        })
        wg.peers;
    };

    networks."90-${wg.interface}" = {
      matchConfig.Name = wg.interface;
      address = [wg.address];
    };
  };
}

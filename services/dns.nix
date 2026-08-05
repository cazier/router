{
  pkgs,
  lib,
  constants,
  ...
}: let
  bcrypt = cleartext: (builtins.readFile (
    pkgs.runCommand "bcrypt" {} ''
      ${
        pkgs.python3.withPackages (ps: [ps.bcrypt])
      }/bin/python3 -c "import bcrypt; print(bcrypt.hashpw('${cleartext}'.encode('utf8'), bcrypt.gensalt()).decode('ascii'))" > $out
    ''
  ));

  bindHosts = lib.mapAttrsToList (_: id: "192.168.${toString id}.1") constants.vlans;
in {
  router.firewall.input = {
    "dns" = {
      not_from = "wan";
      protocol = ["tcp" "udp"];
      port = 53;
    };
    "adguard" = {
      from = "MGMT";
      protocol = "tcp";
      port = 3000;
    };
  };

  services.adguardhome = {
    enable = true;
    settings = {
      dns = {
        bind_hosts = bindHosts;
        upstream_dns = constants.dns.upstream;
        bootstrap_dns = constants.dns.bootstrap;
      };
      users = [
        {
          name = "admin";
          password = bcrypt "password";
        }
      ];
    };
  };
}

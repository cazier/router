{ pkgs, ... }:
let
  bcrypt =
    cleartext:
    (builtins.readFile (
      pkgs.runCommand "bcrypt" { } ''
        ${
          pkgs.python3.withPackages (ps: [ ps.bcrypt ])
        }/bin/python3 -c "import bcrypt; print(bcrypt.hashpw('${cleartext}'.encode('utf8'), bcrypt.gensalt()).decode('ascii'))" > $out
      ''
    ));
in
{
  services.adguardhome = {
    enable = true;
    settings = {
      dns = {
        bind_hosts = [
          "192.168.10.1"
          "192.168.20.1"
          "192.168.30.1"
          "192.168.40.1"
          "192.168.50.1"
          "192.168.60.1"
          "192.168.99.1"
        ];
        upstream_dns = [ "9.9.9.9" ];
        bootstrap_dns = [ "9.9.9.10" ];
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

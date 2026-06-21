{
  pkgs,
  lib,
  firewalleye,
  ...
}: let
  constants = import ../../constants.nix;

  dbPath = "/var/log/ulogd.db";
  schemaFile = ./schema.sql;

  firewalleyebin = pkgs.rustPlatform.buildRustPackage {
    pname = "firewalleye";
    version = "v0.5.0";
    src = firewalleye;
    cargoHash = "sha256-SSlqy8hfu1MKbkk72tiIfPI2nK78sDuuMPjzKiCY7GU=";
  };
in {
  services.ulogd = {
    enable = true;
    settings = {
      global.stack = [
        "log1:NFLOG,base1:BASE,ifi1:IFINDEX,ip2str1:IP2STR,db1:SQLITE3"
      ];

      log1.group = constants.nflogGroup;

      db1 = {
        db = dbPath;
        table = "log";
      };
    };
  };

  systemd.services.ulogd-db-init = {
    description = "Initialize firewall SQLite database";
    wantedBy = ["ulogd.service"];
    partOf = ["ulogd.service"];
    before = ["ulogd.service"];
    after = ["systemd-tmpfiles-setup.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "ulogd-db-init" ''
          rm -r ${dbPath}*
        ${pkgs.sqlite}/bin/sqlite3 ${dbPath} < ${schemaFile}
      '';
    };
  };

  systemd.services.ulogd-db-purge = {
    description = "Purge firewall log entries older than 24 hours";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "ulogd-db-purge" ''
        ${pkgs.sqlite}/bin/sqlite3 ${dbPath} \
          "DELETE FROM log WHERE oob_time_sec < strftime('%s', 'now') - 86400"
      '';
    };
  };

  systemd.services.firewalleye = {
    wantedBy = ["multi-user.target"];
    after = ["ulogd.service"];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${firewalleyebin}/bin/firewalleye --address 0.0.0.0 --port 8000 --db ${dbPath}";
      Restart = "on-failure";
    };
  };

  systemd.timers.ulogd-db-purge = {
    description = "Hourly purge of old firewall log entries";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };
}

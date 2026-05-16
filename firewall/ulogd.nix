{
  pkgs,
  lib,
  ...
}: let
  constants = import ../constants.nix;

  dbPath = "/var/log/ulogd/firewall.db";

  schemaFile = pkgs.writeText "log_schema.sql" ''
    CREATE TABLE IF NOT EXISTS log (
        oob_time_sec  INTEGER,
        oob_time_usec INTEGER,
        oob_prefix    TEXT,
        oob_in        TEXT,
        oob_out       TEXT,
        ip_saddr_str  TEXT,
        ip_daddr_str  TEXT,
        ip_protocol   INTEGER,
        ip_ttl        INTEGER,
        ip_totlen     INTEGER,
        tcp_sport     INTEGER,
        tcp_dport     INTEGER,
        udp_sport     INTEGER,
        udp_dport     INTEGER,
        icmp_type     INTEGER,
        icmp_code     INTEGER,
        raw_pktlen    INTEGER
    );
    CREATE INDEX IF NOT EXISTS log_time ON log (oob_time_sec);
    CREATE VIEW IF NOT EXISTS fw_events AS
        SELECT *,
            CASE WHEN instr(oob_prefix, 'drop') > 0 THEN 'drop' ELSE 'accept' END AS action
        FROM log;
    PRAGMA journal_mode = WAL;
  '';
in {
  services.ulogd = {
    enable = true;
    settings =
      {
        global.stack =
          ["log1:NFLOG,base1:BASE,ifi1:IFINDEX,ip2str1:IP2STR,db1:SQLITE3"]
          ++ lib.optionals constants.enableFileLogs [
            "log1:NFLOG,base1:BASE,ifi1:IFINDEX,ip2str1:IP2STR,print1:PRINTPKT,emu1:LOGEMU"
          ];

        log1.group = constants.nflogGroup;

        db1 = {
          db = dbPath;
          table = "log";
        };
      }
      // lib.optionalAttrs constants.enableFileLogs {
        emu1 = {
          file = "/var/log/ulogd/firewall.log";
          sync = 1;
        };
      };
  };

  services.logrotate = lib.mkIf constants.enableFileLogs {
    enable = true;
    settings.ulogd = {
      files = "/var/log/ulogd/firewall.log";
      rotate = 3;
      size = "10M";
      compress = true;
      delaycompress = true;
      missingok = true;
      notifempty = true;
      create = "0644 root root";
      postrotate = "systemctl reload ulogd 2>/dev/null || true";
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/log/ulogd 0755 root root -"
  ];

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

  systemd.timers.ulogd-db-purge = {
    description = "Hourly purge of old firewall log entries";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };
}

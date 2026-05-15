{...}: let
  constants = import ../constants.nix;
in {
  services.ulogd = {
    enable = true;
    settings = {
      global = {
        logfile = "/var/log/ulogd/ulogd.log";
        stack = "log1:NFLOG,base1:BASE,ifi1:IFINDEX,ip2str1:IP2STR,print1:PRINTPKT,emu1:LOGEMU";
      };

      log1.group = constants.nflogGroup;

      emu1 = {
        file = "/var/log/ulogd/firewall.log";
        sync = 1;
      };
    };
  };

  services.logrotate = {
    enable = true;
    settings.ulogd = {
      files = "/var/log/ulogd/*.log";
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
}

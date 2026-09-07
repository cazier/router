{pkgs, ...}: {
  sops = {
    # Each `sops.secrets.<name>` sets its own `sopsFile` (see networking/, services/).
    defaultSopsFile = ./wireguard.yaml;
    age = {
      keyFile = "/var/lib/sops/keyfile";
      # Only decrypt with the PQC keyfile; never an SSH host key
      sshKeyPaths = [];
    };
    gnupg.sshKeyPaths = [];
  };

  environment.systemPackages = with pkgs; [
    age
    sops
  ];
}

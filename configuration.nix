# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  pkgs,
  hostname,
  timezone,
  ...
}: {
  imports = [
    ./firewall
    ./services

    ./devices.nix
    ./interfaces.nix
    ./virtualization.nix
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  fileSystems = {
    "/".options = ["compress=zstd"];
    "/home".options = ["compress=zstd"];
    "/nix".options = [
      "compress=zstd"
      "noatime"
    ];
  };

  boot = {
    kernel.sysctl = {
      "net.ipv4.ip_forward" = 1;
      "net.ipv6.conf.all.forwarding" = 1;
    };
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelParams = ["console=ttyS0,115200n8"];
  };

  networking = {
    hostName = hostname;
    useDHCP = false;
    useNetworkd = true;
  };

  programs.nix-ld.enable = true;

  time.timeZone = timezone;

  users.users.brendan = {
    isNormalUser = true;
    extraGroups = ["wheel" "pcap"];
    shell = pkgs.zsh;
  };

  programs = {
    tcpdump. enable = true;
    zsh = {
      enable = true;
      enableCompletion = true;
    };
  };

  environment = {
    shells = with pkgs; [
      zsh
    ];

    systemPackages = with pkgs; [
      alejandra
      bat
      btop
      evil-helix
      git
      gitui
      nil
      nixd
      neovim
      tmux
      tree
      wireguard-tools

      (pkgs.writeShellApplication {
        name = "nor";
        text = ''
          nixos-rebuild --flake /etc/nixos/ "$@"
        '';
      })
    ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  system = {
    # copySystemConfiguration = true;
    stateVersion = "25.11";
  };
}

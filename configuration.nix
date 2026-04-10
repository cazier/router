# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./services

    ./devices.nix
    ./interfaces.nix
    ./virtualization.nix
    ./firewall.nix
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  fileSystems = {
    "/".options = [ "compress=zstd" ];
    "/home".options = [ "compress=zstd" ];
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
    kernelParams = [ "console=ttyS0,115200n8" ];
  };

  networking = {
    hostName = "router";
    useDHCP = false;
    useNetworkd = true;
  };

  time.timeZone = "America/New_York";

  users.users.brendan = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
  };

  environment = {
    shells = with pkgs; [
      zsh
    ];

    systemPackages = with pkgs; [
      alejandra
      bat
      helix
      git
      gitui
      nil
      tcpdump
      tree

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

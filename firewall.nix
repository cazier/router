{
  lib,
  config,
  pkgs,
  ...
}:

let
  rules = import ./firewall/firewall.nix;
in
{
  networking = {
    firewall.enable = false;
    nftables = {
      enable = true;
      flushRuleset = true;
      ruleset = builtins.concatStringsSep "\n" rules.ruleset;
    };
  };
}

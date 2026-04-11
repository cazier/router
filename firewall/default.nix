{lib, ...}: let
  rules = import ./firewall.nix {
    lib = lib.extend (final: prev: {
      fw = import ./functions.nix {lib = final;};
    });
  };
in {
  networking = {
    firewall.enable = false;
    nftables = {
      enable = true;
      flushRuleset = true;
      ruleset = builtins.concatStringsSep "\n" rules.ruleset;
    };
  };
}

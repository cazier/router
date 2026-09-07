{
  description = "NixOS-based firewall gateway and router";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05-small";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firewalleye = {
      url = "github:cazier/firewalleye/v0.5.0";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    sops-nix,
    firewalleye,
    ...
  }: let
    hostname = "router";
    timezone = "America/New_York";
    username = "brendan";
    constants = import ./constants.nix;

    system = "x86_64-linux";

    lib = nixpkgs.lib.extend (final: prev: {
      custom = import ./utilities/functions.nix {lib = final;};
    });
  in {
    nixosConfigurations = {
      router = lib.nixosSystem {
        inherit system lib;

        specialArgs = {
          inherit hostname username constants system timezone firewalleye;
        };

        modules = [
          ./configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager = {
              users."${username}" = import ./home.nix;
              extraSpecialArgs = {
                inherit username constants;
              };
            };
          }

          sops-nix.nixosModules.sops
        ];
      };
    };
  };
}

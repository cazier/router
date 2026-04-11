{
  description = "NixOS-based firewall gateway and router";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11-small";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  }: let
    hostname = "router";
    timezone = "America/New_York";
    username = "brendan";
    constants = import ./constants.nix;

    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    lib = nixpkgs.lib.extend (final: prev: {
      custom = import ./utilities/custom_functions.nix {lib = final;};
    });
  in {
    nixosConfigurations = {
      router = lib.nixosSystem {
        inherit system lib;

        specialArgs = {
          inherit hostname username constants timezone;
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
        ];
      };
    };
  };
}

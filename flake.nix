{
  description = "NixOS-based firewall gateway and router";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11-small";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    vscode-server.url = "github:nix-community/nixos-vscode-server";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable-small";

    firewalleye.url = "github:cazier/firewalleye/v0.5.0";
    firewalleye.flake = false;
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    vscode-server,
    firewalleye,
    ...
  }: let
    hostname = "router";
    timezone = "America/New_York";
    username = "brendan";
    constants = import ./constants.nix;

    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    unstable = nixpkgs-unstable.legacyPackages.${system};

    lib = nixpkgs.lib.extend (final: prev: {
      custom = import ./utilities/custom_functions.nix {lib = final;};
    });
  in {
    nixosConfigurations = {
      router = lib.nixosSystem {
        inherit system lib;

        specialArgs = {
          inherit hostname username constants timezone unstable firewalleye;
        };

        modules = [
          ./configuration.nix

          home-manager.nixosModules.home-manager
          {
            home-manager = {
              users."${username}" = import ./home.nix;
              extraSpecialArgs = {
                inherit username constants unstable;
              };
            };
          }

          vscode-server.nixosModules.default
          ({...}: {services.vscode-server.enable = true;})
        ];
      };
    };
  };
}

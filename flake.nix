{
  description = "NixOS-based firewall gateway and router";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-25.11-small";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      username = "brendan";

      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {

      nixosConfigurations = {
        router = lib.nixosSystem {
          inherit system;

          specialArgs = {
            inherit username;
          };

          modules = [
            ./configuration.nix

            home-manager.nixosModules.home-manager
            {
              home-manager = {
                users."${username}" = import ./home.nix;
                extraSpecialArgs = {
                  inherit username;
                };
              };
            }
          ];
        };
      };
    };
}

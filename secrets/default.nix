{
  agenix,
  pkgs,
  system,
  ...
}: {
  age.identityPaths = ["/var/lib/age/keyfile"];

  environment.systemPackages = [
    agenix.packages."${system}".default
  ];
}

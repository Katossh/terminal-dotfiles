{ pkgs, lib, ... }:

let
  packageRows =
    lib.filter
      (row: row != "" && !(lib.hasPrefix "#" row))
      (lib.splitString "\n" (builtins.readFile ../manifest/packages.tsv));

  nixpkgsRows = builtins.filter
    (row:
      let fields = lib.splitString "\t" row;
      in builtins.head fields == "nixpkgs")
    packageRows;

  packageNames = map
    (row: builtins.elemAt (lib.splitString "\t" row) 1)
    nixpkgsRows;

  packages = map (name: builtins.getAttr name pkgs) packageNames;
in
{
  # Import this module from configuration.nix or your NixOS flake module list.
  # Keep the login-shell choice explicit in your host configuration:
  # users.users.<name>.shell = pkgs.zsh;
  programs.zsh.enable = true;

  environment.systemPackages = packages;
}

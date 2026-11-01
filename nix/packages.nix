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

  resolvePackage = row:
    let
      fields = lib.splitString "\t" row;
      name = builtins.elemAt fields 1;
      class = builtins.elemAt fields 2;
    in
      if builtins.hasAttr name pkgs then
        builtins.getAttr name pkgs
      else if class == "optional" then
        null
      else
        throw "Required terminal package '${name}' is missing from this nixpkgs revision.";

  packages = builtins.filter (package: package != null) (map resolvePackage nixpkgsRows);
in
{
  # Import this module from configuration.nix or your NixOS flake modules.
  # Keep the login-shell choice explicit in your host configuration:
  # users.users.<name>.shell = pkgs.zsh;
  programs.zsh.enable = true;

  environment.systemPackages = packages;
}
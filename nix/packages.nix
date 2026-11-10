{ pkgs, lib, ... }:

let
  packageRows =
    lib.filter
      (row: row != "" && !(lib.hasPrefix "#" row))
      (lib.splitString "\n" (builtins.readFile ../manifest/packages.tsv));

  rowsFor = manager:
    builtins.filter
      (row:
        let fields = lib.splitString "\t" row;
        in builtins.head fields == manager)
      packageRows;

  resolvePackage = row:
    let
      fields = lib.splitString "\t" row;
      name = builtins.elemAt fields 1;
      class = builtins.elemAt fields 2;
      package = lib.attrByPath (lib.splitString "." name) null pkgs;
    in
      if package != null then
        package
      else if class == "optional" then
        null
      else
        throw "Required terminal package '${name}' is missing from this nixpkgs revision.";

  resolveRows = rows:
    builtins.filter (package: package != null) (map resolvePackage rows);

  packages = resolveRows (rowsFor "nixpkgs");
  fontPackages = resolveRows (rowsFor "nixpkgs-fonts");

  # The command-not-found handler uses this small, dependency-free Rust
  # executable for fuzzy ranking. Keep it in the same package integration as
  # the shell configuration so NixOS users receive it automatically.
  dotsSuggest = pkgs.rustPlatform.buildRustPackage {
    pname = "dots-suggest";
    version = "0.1.0";
    src = ../rust/dots-suggest;
    cargoLock.lockFile = ../rust/dots-suggest/Cargo.lock;
  };
in
{
  # Import this module from configuration.nix or your NixOS flake modules.
  # Keep the login-shell choice explicit in your host configuration:
  # users.users.<name>.shell = pkgs.zsh;
  programs.zsh.enable = true;

  environment.systemPackages = packages ++ [ dotsSuggest ];
  fonts.packages = fontPackages;
}

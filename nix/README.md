# NixOS configuration

This repository contains shared NixOS modules and a machine-specific host configuration.

## Starforge host

- `hosts/starforge/configuration.nix` is the actual host configuration.
- `hosts/starforge/hardware-configuration.nix` is generated and machine-specific. It contains disk identifiers and filesystem layout; never copy it to another computer.
- The host imports `../../packages.nix` and `../../niri.nix` using repository-relative paths.

Keep this repository private while it contains hardware configuration and disk identifiers.

To use this repository as the NixOS configuration source, back up `/etc/nixos/configuration.nix` and replace it with a wrapper (adjust the checkout path if necessary):

```sh
sudo cp -a /etc/nixos/configuration.nix /etc/nixos/configuration.nix.before-dotfiles

sudo tee /etc/nixos/configuration.nix >/dev/null <<'EOF'
{ ... }:

{
  imports = [
    /home/katossh/dotfiles/nix/hosts/starforge/configuration.nix
  ];
}
EOF
```

Build before activating:

```sh
sudo nixos-rebuild build
sudo nixos-rebuild switch
```

The host keeps SDDM and KDE Plasma enabled, with Niri installed as an additional session. Do not enable a second display manager.

## Shared modules

- `packages.nix` reads the terminal package inventory from `manifest/packages.tsv`.
- `niri.nix` enables `programs.niri`, installs the UI dependencies and fonts, configures PipeWire/WirePlumber, and relies on the NixOS Niri module for the session entry and portal defaults.
- The Niri module exposes a starter wallpaper set at `/etc/niri/wallpapers`. The picker also scans `~/Pictures/Wallpapers`, `~/Pictures/wallpapers`, and `$XDG_DATA_HOME/dots/wallpapers`.

The bundled starter wallpapers come from the NixOS Artwork package in nixpkgs. `simple-dark-gray` is CC0; `binary-black`, `binary-blue`, `catppuccin-mocha`, `nineish-catppuccin-mocha`, `waterfall`, and `moonscape` are CC-BY-SA-4.0. See [NixOS Artwork](https://github.com/NixOS/nixos-artwork) and the package metadata in [nixpkgs' wallpapers expression](https://github.com/NixOS/nixpkgs/blob/nixos-26.05/pkgs/data/misc/nixos-artwork/wallpapers.nix).

The referenced Niri Land repository is a visual and functional reference only. It contains no license file, so this repository does not redistribute its wallpapers or source configuration. The Rofi themes and helper scripts here are independent implementations.

## Applying user configuration

NixOS installs system packages, fonts, wallpaper assets, and the Niri session. The `dots` installer links user configuration and executable helpers:

```sh
cd ~/dotfiles
./bin/dots install --no-packages --yes
```

Run:

```sh
niri validate --config ~/.config/niri/config.kdl
```

The Rofi app drawer, wallpaper selector, and power menu use separate dark themes under `~/.config/rofi/themes`. The wallpaper selector generates cached thumbnails with ImageMagick and includes the NixOS-provided wallpapers automatically.

# NixOS configuration

This repository contains both shared NixOS modules and a machine-specific host configuration.

## Starforge host

- `hosts/starforge/configuration.nix` is the actual host configuration.
- `hosts/starforge/hardware-configuration.nix` is the generated, machine-specific hardware and filesystem configuration. It contains disk identifiers; do not copy it to another computer.
- The host imports `../../packages.nix` and `../../niri.nix` using repository-relative paths, so the checkout can live anywhere.

Keep this repository private while it contains the generated hardware configuration and disk UUIDs.

To make the repository configuration the system entry point, back up the current file and replace `/etc/nixos/configuration.nix` with a small wrapper. Adjust the path if the checkout is not at `/home/katossh/dotfiles`:

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

Then build before activating:

```sh
sudo nixos-rebuild build
sudo nixos-rebuild switch
```

The host keeps SDDM and KDE Plasma enabled, so the Niri session remains selectable alongside Plasma. Do not enable a second display manager.

## Shared modules

- `packages.nix` reads the terminal package inventory from `manifest/packages.tsv`.
- `niri.nix` enables `programs.niri`, installs the Niri desktop dependencies, configures Polkit and dconf, and relies on the NixOS Niri module for the session entry and portal defaults.

The host configuration deliberately does not repeat `programs.niri.enable`, portal setup, or shared Niri packages.

## Applying user configuration

NixOS installs system packages and the Niri session. The `dots` installer manages the user-level Niri, Waybar, Mako, and Rofi configuration:

```sh
cd ~/dotfiles
./bin/dots install --no-packages --yes
```

The terminal keybindings call `~/.local/bin/niri-terminal`. That helper prefers Kitty and falls back to Alacritty or Foot, checking the NixOS system and user profile paths as well as the normal `PATH`.

Run `niri validate --config ~/.config/niri/config.kdl` to validate the installed KDL file. Niri reloads user configuration when the file changes; otherwise log out and select Niri again.

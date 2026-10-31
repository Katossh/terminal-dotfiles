# NixOS modules

These modules are optional and leave display-manager selection to the host configuration.

Import both from your NixOS configuration:

```nix
{
  imports = [
    /home/your-user/dotfiles/nix/packages.nix
    /home/your-user/dotfiles/nix/niri.nix
  ];
}
```

Then run `sudo nixos-rebuild switch`.

- `packages.nix` reads the terminal package inventory from `manifest/packages.tsv`.
- `niri.nix` enables `programs.niri` and installs Niri's companion applications: Waybar, Mako, Rofi, swww, Kitty, PipeWire tools, and Xwayland support.

The NixOS Niri module provides the Niri session and portal integration. The host must still select/configure its display manager. This repository intentionally does not enable SDDM, GDM, greetd, or automatic login.

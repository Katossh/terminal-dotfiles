# NixOS package integration

This common profile provides one declarative NixOS module:

- `packages.nix` reads the `nixpkgs` rows from `../manifest/packages.tsv`.
- It enables Zsh and adds the common terminal/CLI package set to `environment.systemPackages`.
- It does not configure a desktop environment, compositor, display manager, hardware, bootloader, networking, or any host-specific settings.

Import the module from your own NixOS configuration (adjust the checkout path):

```nix
{
  imports = [
    /home/<user>/dotfiles/nix/packages.nix
  ];
}
```

Then review and apply your system configuration:

```sh
sudo nixos-rebuild build
sudo nixos-rebuild switch
```

The module keeps package installation declarative. On NixOS, `dots install --packages` prints the module path and does not edit `/etc/nixos` or run `nixos-rebuild` automatically.

Machine-specific host configurations and desktop profiles should be maintained separately from this common baseline.

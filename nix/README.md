# NixOS integration

There are two supported installation modes.

## User profile (installer)

Run the common installer as your normal user:

```sh
./bin/dots install --packages
```

On NixOS, this installs the package manifest's `nixpkgs` entries into the current user's Nix profile using `nix profile install`. It does not modify `/etc/nixos`, require root for the profile operation, or run `nixos-rebuild`.

## Declarative system packages (recommended for managed hosts)

Import the module from your NixOS configuration (adjust the checkout path):

```nix
{
  imports = [
    /home/<user>/terminal-dotfiles/nix/packages.nix
  ];
}
```

Then review and apply:

```sh
sudo nixos-rebuild build
sudo nixos-rebuild switch
```

The module reads the `nixpkgs` rows from `../manifest/packages.tsv`, enables Zsh and adds packages to `environment.systemPackages`. Alacritty is included as an optional package. `nixpkgs-fonts` rows are installed through `fonts.packages`: both JetBrainsMono Nerd Font and `noto-fonts-color-emoji` are required, with the latter used as the configured color-emoji fallback. Missing optional attributes are skipped; missing required attributes fail evaluation rather than silently omitting required dependencies.

Set the login shell in your host configuration if desired:

```nix
users.users.<name>.shell = pkgs.zsh;
```

Machine-specific host configuration, desktop environments, bootloader, networking and hardware remain outside this repository.

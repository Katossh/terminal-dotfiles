# Package list

Run the installer from a clone of this repository:

    ./install.sh
    ./install.sh --packages
    ./install.sh --all
    ./install.sh --dry-run --no-packages

## Package-manager support

| Package manager | Platform | Behavior |
|---|---|---|
| `apt` | Debian, Ubuntu, Linux Mint, Pop!_OS and related distributions | Refreshes APT metadata, installs core CLI tools, and checks optional packages. |
| `dnf` | Fedora, RHEL, Rocky Linux, AlmaLinux and related distributions | Refreshes repository metadata and checks optional packages. |
| `pacman` | Arch Linux, Manjaro, EndeavourOS and related distributions | Installs packages without triggering a full system upgrade. Keep the system updated using the distribution's normal workflow. |
| `zypper` | openSUSE and SUSE-family distributions | Refreshes repositories and installs available packages. |
| `apk` | Alpine Linux | Refreshes the package index and installs available packages. |
| `xbps` | Void Linux | Synchronizes repositories and installs available packages. |
| `pkg` | FreeBSD | Refreshes package metadata and installs available packages. |
| `brew` | macOS with Homebrew | Installs packages as the current user; the installer never invokes Homebrew through sudo. |
| NixOS module | NixOS | Package management remains declarative through `nix/packages.nix`. The installer does not edit `/etc/nixos` or run `nixos-rebuild`. |

The config-linking step is independent of package installation. If package installation fails, the links are still applied and the installer exits with an error so the package issue is visible. If the OS or package manager is not recognized, use `--no-packages` to install configs without attempting package changes.

## Core tools

| Purpose | Debian / Ubuntu | Fedora | Nixpkgs |
|---|---|---|---|
| Shell | zsh | zsh | zsh |
| Git | git | git | git |
| Terminal multiplexer | tmux | tmux | tmux |
| Fuzzy finder | fzf | fzf | fzf |
| Text search | ripgrep | ripgrep | ripgrep |
| Editor | neovim | neovim | neovim |
| Pager | less | less | less |
| Prompt | starship (if available) | starship (if available) | starship |
| Syntax-highlighted cat | bat (if available) | bat (if available) | bat |
| Fast file search | fd-find (binary is often `fdfind`) | fd-find (binary is often `fd`) | fd |

The core set also includes curl, unzip, and zip. On Linux, xdg-utils is treated as optional because only some desktop integrations need it. Other optional tools include btop, fastfetch, htop, eza, and lazygit; these are installed only when available in configured repositories.

## Optional desktop applications

The dotfiles include configurations for Waybar, Rofi, SwayNC, Cava, Qt themes, Kvantum, and other desktop tools. These settings are not linked by default, because dependencies vary by desktop environment and they are not required for a headless shell or WSL.

Use `./install.sh --desktop --no-packages` to link desktop settings without installing CLI packages. On macOS the Linux desktop settings are skipped. The installer does not install GUI applications automatically.

## NixOS

Review `nix/packages.nix`, import it into your NixOS configuration, and rebuild after reviewing the result. For example:

    imports = [ /path/to/dotfiles/nix/packages.nix ];

Then run:

    sudo nixos-rebuild switch

Configure a user's login shell declaratively with `users.users.<name>.shell = pkgs.zsh` if desired. The installer does not modify NixOS system configuration automatically.

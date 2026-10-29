# Package list

The automated installer is the recommended entry point:

    ./install.sh
    ./install.sh --packages
    ./install.sh --all

It detects Debian/Ubuntu and Fedora-family distributions, installs the core terminal tools, and checks availability before adding optional packages. On NixOS, use the declarative module at nix/packages.nix.

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
| Fast file search | fd-find (if available; binary is often fdfind) | fd-find (if available; binary is fd) | fd |

The installer also installs curl, unzip, zip, and xdg-utils. It adds optional CLI tools such as btop, fastfetch, htop, eza, and lazygit when they are available in the configured repositories.

## Optional desktop applications

The dotfiles include configurations for Waybar, Rofi, SwayNC, Cava, Qt themes, Kvantum, and other desktop tools. These are not installed automatically because the required programs vary between desktop environments and are not needed for a headless shell or WSL.

Use ./install.sh --desktop --no-packages to link these settings without installing CLI packages. The installer does not install GUI applications automatically.

## Historical note

The previous version of this file listed packages for macOS Homebrew. That list has been replaced with the cross-distribution package reference above.

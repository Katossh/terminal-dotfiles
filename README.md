# Dotfiles

Personal configuration for the shell, terminal tools, and optional Linux desktop applications. The installer supports Debian/Ubuntu and Fedora-family systems. NixOS is supported for linking configurations and uses a separate declarative Nix module for packages.

## Install

Clone the repository and run the installer:

    git clone https://github.com/Katossh/dotfiles.git "$HOME/dotfiles"
    cd "$HOME/dotfiles"
    ./install.sh

On an interactive terminal, the installer asks whether to install common CLI packages (default yes) and whether to link optional desktop-app configs (default no). Existing files are moved to a timestamped backup under ~/.dotfiles-backup/ before symlinks are created.

Useful modes:

    ./install.sh --dry-run --no-packages  # preview config links without changing anything
    ./install.sh --no-packages            # link configs only
    ./install.sh --packages               # install CLI prerequisites with apt or dnf
    ./install.sh --desktop                # include optional GUI/desktop application configs
    ./install.sh --all                    # packages + core + desktop config
    ./install.sh --default-shell          # optionally make Zsh the default login shell

The script does not change the default shell unless explicitly asked. On NixOS, it does not edit /etc/nixos or run a rebuild: review nix/packages.nix, import it into your NixOS configuration, and run sudo nixos-rebuild switch yourself. Configure a user's login shell declaratively with users.users.<name>.shell = pkgs.zsh if desired.

## What gets installed

### Core shell and terminal tools

- dots/zshenv → ~/.zshenv, including XDG paths and automatic discovery of the repository location.
- config/zsh/ → ~/.config/zsh/ — shell options, aliases, completion, prompt, and plugins.
- config/starship.toml, config/git/, config/bat/, config/fd/, config/ripgrep/.
- config/.tmux/ → ~/.tmux.conf and ~/.tmux.conf.local.
- config/kitty/, config/wezterm/, config/btop/, config/fastfetch/, and config/htop/.
- Executable helpers from bin/ → ~/.local/bin/.

### Optional desktop configs

Use --desktop to link configs for Kvantum, Thunar, AGS, Cava, GTK, MPV, PulseAudio, Qt settings, Rofi, Swappy, SwayNC, Wallust, Waybar, and Wlogout. This group targets a graphical Linux desktop and is not necessary for a headless WSL shell. Old Kvantum snapshots and version-specific Ghidra preferences/logs are intentionally excluded.

Hyprland itself is maintained separately in [Katossh/NixOS-Configuration](https://github.com/Katossh/NixOS-Configuration/tree/master/.config/hypr).

## Package handling

For Debian/Ubuntu, the installer uses apt-get; for Fedora-family systems it uses dnf. It installs core shell tools and adds optional packages only when they are available in configured repositories. Debian's batcat and fdfind command names are mapped to bat and fd in ~/.local/bin/ when necessary.

NixOS package installation stays declarative. The optional module at nix/packages.nix enables Zsh and installs common terminal utilities. Import it into your NixOS configuration and rebuild after reviewing it; the script never edits system configuration or executes nixos-rebuild automatically. See [resources/packages_list.md](./resources/packages_list.md) for the package matrix.

## Dependencies and local behavior

The Zsh setup expects Zsh, Starship, Git, FZF, ripgrep, tmux, Neovim, and the plugin sources included under config/zsh/.packages/. Starship initialization is conditional, so the shell can still start before it is installed. Shell history and completion caches live under XDG data/cache directories rather than inside the Git checkout.

The bin/ directory includes helpers for copying the current Git branch, extracting archives, previewing files with FZF, selecting Docker containers, selecting processes, and choosing projects. See [bin/README.md](./bin/README.md).

## Security

- Never commit API tokens, passwords, private keys, or machine-specific credentials.
- If a token has ever been committed, revoke/rotate it. Removing a current line does not remove it from Git history.
- Local-only values can go in the ignored config/zsh/zprofile.local file or be handled by a secret manager.

## Upstream sources

Third-party projects vendored under config/ are documented in [resources/upstream-sources.md](./resources/upstream-sources.md). They are tracked as regular files, not Git submodules.

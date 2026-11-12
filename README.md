# Terminal dotfiles

A manifest-driven terminal configuration manager for Linux, NixOS, BSD and macOS. It manages shell and terminal configuration, CLI/TUI tools, terminal emulators, shared helpers and application-specific themes.

## Quick start

~~~sh
git clone https://github.com/Katossh/terminal-dotfiles.git "$HOME/terminal-dotfiles"
cd "$HOME/terminal-dotfiles"

# Preview filesystem changes without installing packages or downloading upstream code.
./bin/dots install --dry-run --no-packages --yes

# Link configuration and download Oh My Zsh plus its plugins.
./bin/dots install --no-packages

# Or also install the recommended native packages.
./bin/dots install --packages
~~~

Run the installer as your normal user, never through sudo. Existing targets are backed up before managed links replace them. The installer is safe to re-run.

**Important:** --no-packages skips native OS package installation only. It does not skip Oh My Zsh or its plugin downloads. To skip every optional upstream download for an offline/config-only setup, set DOTS_SKIP_DOWNLOADS=1.

## What dots install does

1. Reads manifest/configs.tsv and links the selected configuration files and trees.
2. Backs up existing target paths rather than silently overwriting them.
3. Creates shared terminal theme adapters and links helper commands into ~/.local/bin.
4. Downloads Oh My Zsh and the required custom Zsh repositories into XDG_DATA_HOME (by default ~/.local/share). This happens even when the zsh executable is not installed or not in PATH.
5. Downloads the Catppuccin tmux plugin when tmux 3.2+ is available; the generated local palette remains a fallback.
6. Installs native packages only when --packages is selected (or accepted at the interactive prompt).

Git and network access to GitHub are required for framework/plugin downloads. Failed Zsh clones are retried, reported as installation errors, and cause a non-zero exit status. The installer validates the expected entry file/directory of every clone before accepting it.

## Documentation

- [Installation guide](docs/INSTALLATION.md) — prerequisites, install modes, platforms and NixOS.
- [Command reference](docs/COMMANDS.md) — commands, options, receipts and safety behavior.
- [Zsh setup](docs/ZSH.md) — framework, plugins, startup order, cache paths and updates.
- [Yazi setup](docs/YAZI.md) — Neovim opener, Catppuccin theme, config ownership and installation.
- [Troubleshooting](docs/TROUBLESHOOTING.md) — missing framework, incomplete downloads, PATH and network issues.
- [Upstream sources](resources/upstream-sources.md) — third-party projects and their runtime locations.

## Package installation

The installer detects the native package manager and supports apt (Debian/Ubuntu derivatives), dnf (Fedora/RHEL derivatives), pacman (Arch derivatives), zypper (openSUSE), apk (Alpine), xbps (Void), FreeBSD pkg, and Homebrew. Alacritty is an optional package for supported native package managers and Nixpkgs. Homebrew uses its Cask integration; the official Alacritty cask is currently disabled by Homebrew after failing its Gatekeeper check, so dots skips it rather than bypassing macOS security.

On NixOS, dots install --packages installs the packages declared in manifest/packages.tsv into the invoking user's Nix profile using nix profile install. On another Linux distribution, Nix is used as a fallback when no supported native package manager is detected but nix is available.

For declarative, system-wide NixOS packages, import nix/packages.nix from your host configuration:

~~~nix
{
  imports = [
    /home/<user>/terminal-dotfiles/nix/packages.nix
  ];
}
~~~

Then review and apply the host configuration:

~~~sh
sudo nixos-rebuild build
sudo nixos-rebuild switch
~~~

The module reads Nixpkgs packages from manifest/packages.tsv. It enables Zsh and adds declared CLI/TUI packages and Alacritty to environment.systemPackages; required missing attributes fail evaluation, while optional missing attributes are skipped. Entries under the nixpkgs-fonts package-manager key are added to fonts.packages, so NixOS registers them with fontconfig. JetBrainsMono Nerd Font is included as a required system font. Set the account's login shell in your host configuration, for example users.users.<name>.shell = pkgs.zsh.

On an unfamiliar distribution without a supported package manager or Nix, dots install --no-packages still links configurations and provisions Zsh from Git. Install the remaining CLI dependencies with that distribution's package manager.

## Personal overrides

Overrides live outside the repository under ~/.config/dots/overrides/. Mirror the component-relative path; for example, ~/.config/dots/overrides/zsh/aliases.zsh overrides the shared Zsh aliases, while ~/.config/dots/overrides/alacritty/alacritty.toml overrides Alacritty settings. ~/.config/dots/theme.local.env can override individual palette tokens.

Keep credentials, private keys and machine-specific secrets out of tracked files.

## Repository layout

- config/terminal/ — Zsh, Alacritty, Kitty, tmux, Yazi and CLI/TUI application settings.
- dots/ — shared shell environment configuration.
- bin/ — installer and portable helper commands.
- manifest/ — configuration and package inventories.
- themes/ — canonical Catppuccin palette and application adapters.
- nix/ — declarative NixOS package module.
- docs/ — installation, command, Zsh and troubleshooting guides.
- tests/ and .github/workflows/ — installer validation.

## Safety model

- Run dots as your normal user; privilege escalation is limited to native package-manager operations.
- --dry-run previews filesystem changes without modifying them.
- Existing targets are backed up before replacement.
- Native packages are not removed by default. uninstall --purge only removes packages recorded as newly installed by dots.
- Nix profile packages are managed by Nix and are not removed by uninstall --purge.
- health is read-only.
- Downloads are recorded in the installer state file and removed only when the recorded path and upstream origin match.

This is a personal configuration manager, not a security boundary. Review the scripts before running them.

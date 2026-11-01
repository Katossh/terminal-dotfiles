# Terminal dotfiles

A manifest-driven terminal configuration manager for Linux, NixOS, BSD and macOS. It manages shells, terminal emulators, tmux, CLI/TUI applications, shared helpers and one coherent terminal palette.

## Install

```sh
git clone https://github.com/Katossh/terminal-dotfiles.git "$HOME/terminal-dotfiles"
cd "$HOME/terminal-dotfiles"
./bin/dots install --packages
```

Use a preview first when installing on an existing machine:

```sh
./bin/dots install --dry-run --no-packages --yes
```

`bin/dots` is the only installer and command-line entry point. It links configurations without replacing existing files silently: collisions are moved into a managed backup area. Run it as your normal user, never through `sudo`.

## Package installation

The installer detects the native package manager and supports apt (Debian/Ubuntu derivatives), dnf (Fedora/RHEL derivatives), pacman (Arch derivatives), zypper (openSUSE), apk (Alpine), xbps (Void), FreeBSD `pkg`, and Homebrew. The configuration-linking step is independent of package installation.

On NixOS, `dots install --packages` installs the packages declared in `manifest/packages.tsv` into the invoking user's Nix profile using `nix profile install`. On another Linux distribution, Nix is also used as a fallback when no supported native package manager is detected but `nix` is available. This avoids trying to mutate an immutable NixOS system from an imperative shell script.

For declarative, system-wide NixOS packages, import `nix/packages.nix` from your host configuration instead:

```nix
{
  imports = [
    /home/<user>/terminal-dotfiles/nix/packages.nix
  ];
}
```

Then review and apply the host configuration:

```sh
sudo nixos-rebuild build
sudo nixos-rebuild switch
```

The module reads the same Nixpkgs entries from `manifest/packages.tsv`. It enables Zsh and adds the available packages to `environment.systemPackages`; required missing attributes fail evaluation, while optional missing attributes are skipped. Set the login shell explicitly in your host configuration, for example `users.users.<name>.shell = pkgs.zsh`.

On an unfamiliar distribution without one of the supported package managers or Nix, `dots install --no-packages` still installs the configuration links. Install the listed dependencies with that distribution's package manager.

## Commands

| Command | Purpose |
|---|---|
| `dots install` | Link configuration; interactively offer dependency installation. |
| `dots install --packages` | Link configuration and install declared dependencies. |
| `dots list` | List components and installation state. |
| `dots --health` | Diagnose missing sources, changed links and dependencies. |
| `dots backup` | Snapshot managed targets and personal overrides. |
| `dots restore [ID]` | Restore a snapshot, preserving current files in a safety copy. |
| `dots uninstall` | Remove only recorded links and restore collision backups. |
| `dots uninstall --purge` | Also remove native packages recorded as newly installed by dots. |
| `dots prune` | Remove broken managed links and stale state. |

Git remains responsible for updates and history: use `git pull`, `git status`, `git diff` and `git log`.

## Personal overrides

Personal overrides live outside the repository under `~/.config/dots/overrides/`. Mirror the component-relative path there; for example, `~/.config/dots/overrides/zsh/aliases.zsh` overrides the shared Zsh aliases. `~/.config/dots/theme.local.env` can override individual terminal palette tokens.

Existing untracked files are preserved by backing them up before a managed link is created. Never commit credentials or machine-specific secrets.

## Repository layout

- `config/terminal/` contains Zsh, Kitty, tmux and CLI/TUI application settings.
- `dots/` contains shared shell environment configuration.
- `bin/` contains the installer and portable helper commands.
- `manifest/` contains configuration and package inventories.
- `themes/` contains the canonical Catppuccin palette and application adapters.
- `nix/` provides the declarative NixOS package module.
- `tests/` and `.github/workflows/` validate the installer.

## Safety

- Run `dots` as your normal user; privilege escalation is limited to native package-manager operations.
- `--dry-run` previews changes without modifying the filesystem.
- Existing targets are backed up before replacement.
- Native packages are not removed by default. `--purge` is limited to packages recorded as newly installed by dots.
- Nix profile packages are managed by Nix and are not removed by `dots uninstall --purge`.
- `--health` is read-only.

This is a personal configuration manager, not a security boundary. Review the scripts before running them.
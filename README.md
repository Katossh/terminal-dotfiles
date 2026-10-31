# Dotfiles — terminal environment

A manifest-driven terminal configuration manager for Zsh, terminal tools, and CLI/TUI applications. The manager has no graphical-desktop installation path and does not depend on a window manager, Wayland, X11, Waybar, or Rofi.

## Install

```sh
git clone https://github.com/Katossh/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
./bin/dots install
```

On an interactive terminal, `dots install` asks whether to install recommended CLI packages (default yes). In a non-interactive session, packages are skipped unless `--packages` is explicit.

```sh
./bin/dots install --no-packages --yes
dots install --packages
dots install --dry-run --no-packages
dots list
dots --health
```

`bin/dots` is the only installer and command-line entry point. On the first run, invoke it from the checkout as shown above; it then links itself to `~/.local/bin/dots`. There is no separate bootstrap script.

## Commands

| Command | Purpose |
|---|---|
| `dots install` | Apply configurations from `manifest/configs.tsv`; optionally install declared packages. |
| `dots list` | List managed components and installation status. |
| `dots --health` | Diagnose missing sources, changed or broken links, generated adapters, and missing dependencies. It does not repair anything. |
| `dots backup` | Snapshot managed target paths and personal overrides. Prints a snapshot ID. |
| `dots restore [ID]` | Restore a snapshot (latest by default). Current paths are moved to a safety backup first. |
| `dots uninstall` | Remove only links recorded by dots, restore collision backups, and remove downloads recorded as installer-owned. |
| `dots uninstall --purge` | Additionally remove only native packages recorded as newly installed by dots. It does not run autoremove. |
| `dots prune` | Remove broken managed links, abandoned clone staging directories, and stale state records. |

Git remains responsible for repository updates and history: use `git pull`, `git status`, `git diff`, and `git log`. There is deliberately no `dots update` or `dots diff` wrapper.

## Configuration manifest

`manifest/configs.tsv` is the single inventory of managed configurations. Each row declares a component, source type (`file` or `tree`), repository source, destination namespace/path, and supported platform. `manifest/packages.tsv` is the corresponding package inventory.

The installer, listing, health checks, and CI all read the same manifest. There are no separate hardcoded UI or terminal component lists.

Application trees are linked file-by-file, not as one directory symlink. Existing conflicting files are moved to `~/.local/share/dots/backups/collisions/` before links are created. This preserves unrelated files in an existing application config directory and makes per-file overrides possible.

## Personal overrides

Personal overrides live outside the repository and take precedence over the matching shared file:

```text
~/.config/dots/
├── overrides/
│   ├── zsh/
│   │   └── aliases.zsh
│   ├── kitty/
│   │   └── kitty.conf
│   ├── tmux.conf
│   ├── tmux.conf.local
│   └── starship          # complete replacement for the single-file Starship component
└── theme.local.env
```

For directory components, mirror the repository-relative path under `overrides/<component>/`. For single-file components, use the component name as the override filename (for example `overrides/starship`). An override replaces that one file; dots does not attempt to merge arbitrary application-specific formats.

Existing untracked files such as `~/.config/zsh/zprofile.local` remain in place. Never put secrets or machine-specific credentials in the repository.

## Backups, restore, and uninstall

`dots backup` snapshots each manifest destination and the complete `~/.config/dots` directory, including overrides. Files and symlinks are preserved as such. The snapshot lives under `~/.local/share/dots/backups/snapshots/`.

`dots restore` first moves current destinations into a restore-safety directory, then restores the snapshot. Restoring an older snapshot can intentionally remove files created after that snapshot.

Every future standalone download is recorded in the installation receipt. Currently this includes the upstream Starship fallback binary and the pinned Catppuccin tmux plugin. Temporary installer scripts are removed immediately. Native packages are recorded only when they were not installed before the dots operation; `--purge` removes those explicitly recorded packages, without asking the package manager to autoremove shared dependencies.

Earlier installer versions did not keep complete ownership receipts. A pre-existing standalone binary in `~/.local/bin` therefore cannot always be attributed safely to the old installer; dots will not delete untracked files merely because their names look familiar.

## Centralized theming

`themes/palettes/catppuccin-mocha.env` is the canonical data-only palette (`NAME=#RRGGBB`). Terminal adapters consume it: Zsh/FZF read it directly, while dots generates Kitty and tmux native configuration files. `~/.config/dots/theme.local.env` can override individual palette tokens. Generated adapters should not be edited directly; use the palette override or an application-specific personal override.

The palette format is intentionally easy for a separate UI repository to consume. This terminal manager does not install, test, import, or otherwise depend on that repository.

## Scope and directory layout

- `config/terminal/` contains active shell, terminal, multiplexer, and CLI/TUI configurations.
- `bin/` contains optional helper commands, including `kp` (kept intentionally).
- `manifest/` contains component and package inventories.
- `themes/` contains the canonical palette and terminal adapters.
- `legacy/ui/` preserves the former desktop configurations while they await migration to a separate repository. Nothing under `legacy/ui/` is installed or tested by dots.
- `nix/packages.nix` is the NixOS package module. It reads the `nixpkgs` rows from `manifest/packages.tsv`, enables Zsh, and exposes the same recommended toolset declaratively.

Supported package managers are apt, dnf, pacman, zypper, apk, xbps, FreeBSD pkg, and Homebrew. NixOS is supported through the declarative module: run `./bin/dots install --packages`, add the printed module path to the `imports` list in your NixOS configuration, then run `sudo nixos-rebuild switch`. For example:

```nix
{
  imports = [
    /home/your-user/dotfiles/nix/packages.nix
  ];

  # Optional: make Zsh the login shell as well.
  users.users.your-user.shell = pkgs.zsh;
}
```

The module derives its package list from `manifest/packages.tsv`; there is no second manually maintained package list. `dots` never edits `/etc/nixos` or invokes a system rebuild. Other unsupported systems can still use configuration linking with `--no-packages`.

## Safety

- Run dots as your normal user, never through `sudo`.
- Package-manager operations alone use privilege escalation.
- `uninstall` preserves native packages by default; `--purge` is explicit.
- Existing files are backed up before replacement.
- `--health` is read-only; `--dry-run` previews installation, prune, restore, and uninstall operations.
- Review scripts before running them. This is a personal configuration manager, not a security boundary.
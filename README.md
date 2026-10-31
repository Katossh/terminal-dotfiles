# Dotfiles

A manifest-driven, cross-distro configuration manager for a terminal-focused development environment. The common profile provides the same baseline tools and configuration across supported Linux distributions, BSD, macOS, and NixOS.

## Install

```sh
git clone https://github.com/Katossh/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
./bin/dots install
```

On an interactive terminal, `dots install` asks whether to install the recommended CLI packages (default yes). In a non-interactive session, packages are skipped unless `--packages` is explicit.

```sh
./bin/dots install --no-packages --yes
dots install --packages
dots install --dry-run --no-packages
dots list
dots --health
```

`bin/dots` is the only installer and command-line entry point. On the first run, invoke it from the checkout; it then links itself to `~/.local/bin/dots`. There is no separate bootstrap installer.

## Scope

The `master` branch is the common baseline: shell, terminal, multiplexer, CLI/TUI configuration, shared helper commands, and package installation. It deliberately does not configure a desktop environment, compositor, window manager, display manager, or machine-specific hardware.

Desktop profiles and machine-specific system configurations belong in separate profiles. Applying the common baseline therefore does not impose a particular graphical session or alter an existing desktop setup.

## Commands

| Command | Purpose |
|---|---|
| `dots install` | Apply configurations from `manifest/configs.tsv`; optionally install declared packages. |
| `dots list` | List managed components and installation state. |
| `dots --health` | Diagnose missing sources, changed or broken links, generated adapters, and dependencies. |
| `dots backup` | Snapshot managed target paths and personal overrides. |
| `dots restore [ID]` | Restore a snapshot (latest by default), moving current paths to a safety backup first. |
| `dots uninstall` | Remove links recorded by dots, restore collision backups, and remove installer-owned downloads. |
| `dots uninstall --purge` | Also remove only native packages recorded as newly installed by dots. |
| `dots prune` | Remove broken managed links, abandoned clone staging directories, and stale state records. |

Git remains responsible for repository updates and history: use `git pull`, `git status`, `git diff`, and `git log`. There is deliberately no `dots update` or `dots diff` wrapper.

## Personal overrides

Personal overrides live outside the repository and take precedence over the matching shared file:

```text
~/.config/dots/
├── overrides/
│   ├── zsh/
│   │   └── aliases.zsh
│   ├── kitty/
│   │   └── kitty.conf
│   └── tmux.conf
└── theme.local.env
```

For directory components, mirror the repository-relative path under `overrides/<component>/`. For single-file components, use the component name as the override filename. An override replaces that file; dots does not merge arbitrary application-specific formats.

Existing untracked files remain untouched. Never put secrets or machine-specific credentials in the repository.

## Backups and uninstall

`dots backup` snapshots each manifest destination and the complete `~/.config/dots` directory, including overrides. Snapshots live under `~/.local/share/dots/backups/snapshots/`.

`dots restore` first moves current destinations into a safety directory, then restores the snapshot. Restoring an older snapshot can intentionally remove files created after it.

Native packages are recorded only when they were not installed before the dots operation. `--purge` removes only those explicitly recorded packages; it does not ask the package manager to autoremove shared dependencies.

## Centralized theming

`themes/palettes/catppuccin-mocha.env` is the canonical data-only terminal palette (`NAME=#RRGGBB`). Zsh/FZF read it directly, while dots generates Kitty and tmux adapters. `~/.config/dots/theme.local.env` can override individual palette tokens.

## Repository layout

- `config/terminal/` contains shell, terminal, multiplexer, and CLI/TUI configurations.
- `bin/` contains the common installer and portable helper commands.
- `manifest/` contains component and package inventories.
- `themes/` contains the canonical terminal palette and adapters.
- `nix/packages.nix` provides the declarative NixOS package module.

Native package managers supported by the installer are apt, dnf, pacman, zypper, apk, xbps, FreeBSD pkg, and Homebrew. NixOS is supported through the optional declarative package module.

## Safety

- Run dots as your normal user, never through `sudo`.
- Package-manager operations alone use privilege escalation.
- `uninstall` preserves native packages by default; `--purge` is explicit.
- Existing files are backed up before replacement.
- `--health` is read-only; `--dry-run` previews operations.
- Review scripts before running them. This is a personal configuration manager, not a security boundary.

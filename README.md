# Dotfiles

A manifest-driven configuration manager for a terminal-focused development environment and a Niri Wayland desktop. Terminal and desktop profiles share one installer, one component manifest, backups, personal overrides, health checks, and lifecycle commands.

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

`bin/dots` is the only installer and command-line entry point. On the first run, invoke it from the checkout; it then links itself to `~/.local/bin/dots`. There is no separate bootstrap installer.

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

## Desktop profile: Niri

The Linux desktop profile uses [Niri](https://github.com/niri-wm/niri), [Waybar](https://github.com/Alexays/Waybar), [Mako](https://github.com/emersion/mako), and [Rofi](https://github.com/davatorium/rofi). It is independently implemented with a Catppuccin Mocha palette, using [Niri Land](https://github.com/kianblakley/niri-land) as a functional and visual reference.

The profile includes gapless, borderless windows; Waybar hidden until the Niri overview opens; a full-screen dark application drawer with Papirus icons; a themed power menu; a thumbnail-based wallpaper picker; and volume notifications through Mako. On NixOS the picker includes a licensed starter pack under `/etc/niri/wallpapers`, and it also scans `~/Pictures/Wallpapers`, `~/Pictures/wallpapers`, and `$XDG_DATA_HOME/dots/wallpapers`.

The upstream Niri Land repository has no license file, so this repository does not redistribute its wallpapers or configuration files. The UI here is a clean implementation of the same features. NixOS artwork wallpapers are used for the default set; licensing and attribution are documented in [`nix/README.md`](nix/README.md).

| Action | Shortcut |
|---|---|
| Terminal | `Mod+Enter` |
| Application drawer | `Mod+D` |
| Wallpaper selector | `Mod+B` |
| Power menu | `Mod+P` |
| Toggle overview | `Mod+O` |
| Close window | `Mod+Q` |
| Screenshot | `Mod+Shift+S` |

The profile is Linux-only. Install dependencies using the distribution package manager, then run `dots install`. The helper scripts expect `rofi`, `swww`, `wpctl`, `notify-send`, `jq`, `magick` (ImageMagick), and `systemctl`. On NixOS, `nix/niri.nix` installs these dependencies, JetBrains Mono Nerd Font, Papirus icons, and the starter wallpapers.

### NixOS

The repository includes a machine-specific NixOS configuration for the `starforge` host:

- `nix/hosts/starforge/configuration.nix` contains host settings and imports shared modules with relative paths.
- `nix/hosts/starforge/hardware-configuration.nix` contains generated hardware, filesystem, and disk identifier settings. It must not be reused on another machine.

Keep the repository private while it contains host-specific disk identifiers. The host retains SDDM and KDE Plasma, with Niri installed as an additional session. The shared `nix/niri.nix` module enables Niri and its dependencies; it does not select a display manager.

See [`nix/README.md`](nix/README.md) for the safe `/etc/nixos/configuration.nix` wrapper and rebuild instructions. After rebuilding the system, apply user-level desktop configuration as your normal user:

```sh
./bin/dots install --no-packages --yes
```

The `Mod+Return` and `Mod+T` bindings use `bin/niri-terminal`, which tries Kitty first and falls back to Alacritty or Foot. NixOS and its system profile are supported explicitly.

## Personal overrides

Personal overrides live outside the repository and take precedence over the matching shared file:

```text
~/.config/dots/
├── overrides/
│   ├── zsh/
│   │   └── aliases.zsh
│   ├── kitty/
│   │   └── kitty.conf
│   ├── niri/
│   │   └── config.kdl
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

The Niri profile uses a coordinated Catppuccin Mocha palette and the normal per-file override mechanism.

## Repository layout

- `config/terminal/` contains shell, terminal, multiplexer, and CLI/TUI configurations.
- `config/ui/` contains active Linux desktop configurations for Niri, Waybar, Mako, and Rofi.
- `bin/` contains the installer and helper commands, including `kp` and the `niri-*` utilities.
- `manifest/` contains component and package inventories.
- `themes/` contains the canonical terminal palette and adapters.
- `nix/packages.nix` provides the declarative terminal package module.
- `nix/niri.nix` provides the NixOS Niri desktop module.

Native package managers supported for the terminal profile are apt, dnf, pacman, zypper, apk, xbps, FreeBSD pkg, and Homebrew. NixOS is supported through the optional declarative modules.

## Safety

- Run dots as your normal user, never through `sudo`.
- Package-manager operations alone use privilege escalation.
- `uninstall` preserves native packages by default; `--purge` is explicit.
- Existing files are backed up before replacement.
- `--health` is read-only; `--dry-run` previews operations.
- Review scripts before running them. This is a personal configuration manager, not a security boundary.

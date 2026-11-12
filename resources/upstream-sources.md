# Vendored upstream sources

The current `master` tree contains the following third-party projects as regular tracked files/directories. They were historically listed in `.gitmodules`, but no Git submodule entries are present in the current tree. These links are kept here for attribution, license review, and future updates.

| Local path | Upstream project |
|---|---|
| `config/terminal/bat/themes/oceanic-next-color-scheme` | [voronianski/oceanic-next-color-scheme](https://github.com/voronianski/oceanic-next-color-scheme) |
| `config/terminal/bat/themes/material-theme` | [equinusocio/material-theme](https://github.com/equinusocio/material-theme) |
| `config/terminal/kitty/kitty_grab` | [yurikhan/kitty_grab](https://github.com/yurikhan/kitty_grab) |
| `config/terminal/alacritty/catppuccin-frappe.toml` | [catppuccin/alacritty](https://github.com/catppuccin/alacritty) — Catppuccin Frappé (MIT; license included beside the theme) |
| `config/terminal/yazi/theme.toml` | [catppuccin/yazi](https://github.com/catppuccin/yazi) — Catppuccin Frappé Sapphire |
| `config/terminal/yazi/Catppuccin-frappe.tmTheme` | [catppuccin/bat](https://github.com/catppuccin/bat) — Frappé syntax highlighting |

## Runtime-managed Zsh sources

These repositories are installed by `dots install` into the user's XDG data directory and are not committed to this repository.

| Runtime path | Upstream project |
|---|---|
| `$XDG_DATA_HOME/oh-my-zsh` | [ohmyzsh/ohmyzsh](https://github.com/ohmyzsh/ohmyzsh) |
| `$XDG_DATA_HOME/zsh/custom/plugins/fzf-tab` | [Aloxaf/fzf-tab](https://github.com/Aloxaf/fzf-tab) |
| `$XDG_DATA_HOME/zsh/custom/plugins/fast-syntax-highlighting` | [zdharma-continuum/fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting) |
| `$XDG_DATA_HOME/zsh/custom/plugins/zsh-completions` | [zsh-users/zsh-completions](https://github.com/zsh-users/zsh-completions) |

Oh My Zsh includes the `zsh-autosuggestions` plugin, so it is not cloned separately.

## Updating vendored code

These directories are part of this repository's tracked tree. Updating one is therefore a normal file change, not a `git submodule update`. Before updating, check the upstream project's license and compatibility with the shell setup. Avoid editing third-party files directly unless the change is intentionally maintained as a local patch.

## Design references (not vendored)

- [kianblakley/niri-land](https://github.com/kianblakley/niri-land) — reference for an overview-first Waybar, Rofi app/power/wallpaper menus, and compact Mako volume notifications. The upstream README describes the project as being in maintenance mode. The Niri profile here is an independent implementation in `config/ui/` and `bin/niri-*`; no upstream source files, wallpapers, or screenshot assets are copied. The upstream repository currently has no `LICENSE` file, so its code and bundled assets are not redistributed.

## Runtime-managed Zsh plugin ownership

Oh My Zsh supplies the built-in git, z, and zsh-autosuggestions plugins. The standalone runtime checkouts are fzf-tab, fast-syntax-highlighting, and zsh-completions. The installer validates the expected entrypoint for each checkout and reports clone failures instead of treating them as success.

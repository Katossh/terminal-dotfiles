# Vendored upstream sources

The current `master` tree contains the following third-party projects as regular tracked files/directories. They were historically listed in `.gitmodules`, but no Git submodule entries are present in the current tree. These links are kept here for attribution, license review, and future updates.

| Local path | Upstream project |
|---|---|
| `config/terminal/bat/themes/oceanic-next-color-scheme` | [voronianski/oceanic-next-color-scheme](https://github.com/voronianski/oceanic-next-color-scheme) |
| `config/terminal/bat/themes/material-theme` | [equinusocio/material-theme](https://github.com/equinusocio/material-theme) |
| `config/terminal/kitty/kitty_grab` | [yurikhan/kitty_grab](https://github.com/yurikhan/kitty_grab) |
| `config/terminal/zsh/.packages/zsh-z` | [agkozak/zsh-z](https://github.com/agkozak/zsh-z) |
| `config/terminal/zsh/.packages/fast-syntax-highlighting` | [zdharma-continuum/fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting) |
| `config/terminal/zsh/.packages/zsh-autosuggestions` | [zsh-users/zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) |
| `config/terminal/zsh/.packages/fzf-tab` | [Aloxaf/fzf-tab](https://github.com/Aloxaf/fzf-tab) |
| `config/terminal/zsh/.packages/ohmyzsh` | [ohmyzsh/ohmyzsh](https://github.com/ohmyzsh/ohmyzsh) |
| `config/terminal/zsh/.packages/zsh-completions` | [zsh-users/zsh-completions](https://github.com/zsh-users/zsh-completions) |
| `config/terminal/zsh/.packages/gitstatus` | [romkatv/gitstatus](https://github.com/romkatv/gitstatus) |
| `config/terminal/zsh/.packages/zsh-manydots-magic` | [knu/zsh-manydots-magic](https://github.com/knu/zsh-manydots-magic) |

## Updating vendored code

These directories are part of this repository's tracked tree. Updating one is therefore a normal file change, not a `git submodule update`. Before updating, check the upstream project's license and compatibility with the shell setup. Avoid editing third-party files directly unless the change is intentionally maintained as a local patch.

## Design references (not vendored)

- [kianblakley/niri-land](https://github.com/kianblakley/niri-land) — reference for an overview-first Waybar, Rofi app/power/wallpaper menus, and compact Mako volume notifications. The upstream README describes the project as being in maintenance mode. The Niri profile here is an independent implementation in `config/ui/` and `bin/niri-*`; no upstream source files, wallpapers, or screenshot assets are copied. The upstream repository currently has no `LICENSE` file, so its code and bundled assets are not redistributed.

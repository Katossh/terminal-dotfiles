# Vendored upstream sources

The current `master` tree contains the following third-party projects as regular tracked files/directories. They were historically listed in `.gitmodules`, but no Git submodule entries are present in the current tree. These links are kept here for attribution, license review, and future updates.

| Local path | Upstream project |
|---|---|
| `config/bat/themes/oceanic-next-color-scheme` | [voronianski/oceanic-next-color-scheme](https://github.com/voronianski/oceanic-next-color-scheme) |
| `config/bat/themes/material-theme` | [equinusocio/material-theme](https://github.com/equinusocio/material-theme) |
| `config/kitty/kitty_grab` | [yurikhan/kitty_grab](https://github.com/yurikhan/kitty_grab) |
| `config/zsh/.packages/zsh-z` | [agkozak/zsh-z](https://github.com/agkozak/zsh-z) |
| `config/zsh/.packages/fast-syntax-highlighting` | [zdharma-continuum/fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting) |
| `config/zsh/.packages/zsh-autosuggestions` | [zsh-users/zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) |
| `config/zsh/.packages/fzf-tab` | [Aloxaf/fzf-tab](https://github.com/Aloxaf/fzf-tab) |
| `config/zsh/.packages/ohmyzsh` | [ohmyzsh/ohmyzsh](https://github.com/ohmyzsh/ohmyzsh) |
| `config/zsh/.packages/zsh-completions` | [zsh-users/zsh-completions](https://github.com/zsh-users/zsh-completions) |
| `config/zsh/.packages/gitstatus` | [romkatv/gitstatus](https://github.com/romkatv/gitstatus) |
| `config/zsh/.packages/zsh-manydots-magic` | [knu/zsh-manydots-magic](https://github.com/knu/zsh-manydots-magic) |

## Updating vendored code

These directories are part of this repository's tracked tree. Updating one is therefore a normal file change, not a `git submodule update`. Before updating, check the upstream project's license and compatibility with the shell setup. Avoid editing third-party files directly unless the change is intentionally maintained as a local patch.

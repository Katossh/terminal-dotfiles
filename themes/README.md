# Shared terminal palette

`palettes/catppuccin-mocha.env` is the canonical palette. It uses a deliberately data-only `NAME=#RRGGBB` format rather than executable shell code, so another repository can parse it without evaluating this repository's scripts.

Terminal adapters translate palette tokens into native application formats:

- `adapters/fzf.zsh` exports FZF's color options for Zsh.
- `dots install` generates `kitty/themes/dots-palette.conf` and `~/.tmux/dots-theme.conf` from the same tokens.

Local token overrides belong in `~/.config/dots/theme.local.env`. Use the same `DOTS_THEME_*` names. Only six-digit hex colors are accepted by the manager.

The UI configurations are outside this repository's active scope. A future independent UI repository can consume the same data format, but the terminal manager must not import or execute anything from that repository.
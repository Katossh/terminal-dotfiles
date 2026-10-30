# Kitty terminal configuration

`kitty.conf` configures JetBrains Mono, a large scrollback, Catppuccin Mocha colors, window splits, tabs, font resizing, and keyboard shortcuts.

## Dependencies and assumptions
- Font family: JetBrains Mono; the referenced symbol font may need to be installed separately.
- Theme files live under `themes/`.
- The scrollback mappings refer to Neovim's `kitty-scrollback.nvim` plugin path; remove or adjust them if that plugin is not installed.
- `kitty_grab/` is a vendored upstream project; prefer updating it from its source rather than editing upstream code locally.

This is a Kitty emulator configuration, not a Windows Terminal settings file. Under WSL, it is relevant only if Kitty itself is running as a Linux GUI application. A Windows-hosted terminal usually needs its own host-side configuration.

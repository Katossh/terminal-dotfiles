# Kitty terminal configuration

`kitty.conf` configures JetBrainsMono Nerd Font, a large scrollback, Catppuccin Mocha colors, window splits, tabs, font resizing, and keyboard shortcuts.

## Dependencies and assumptions

- Font family: JetBrainsMono Nerd Font, provided by the required `nerd-fonts.jetbrains-mono` entry in `manifest/packages.tsv`.
- Theme files live under `themes/`.
- The scrollback mappings refer to Neovim's `kitty-scrollback.nvim` plugin path; remove or adjust them if that plugin is not installed.
- `kitty_grab/` is a vendored upstream project; prefer updating it from its source rather than editing upstream code locally.

## Clipboard shortcuts

- `Ctrl+C` copies selected text; when there is no selection, it sends SIGINT to the foreground process.
- `Ctrl+V` pastes from the system clipboard.
- `Ctrl+Shift+C` and `Ctrl+Shift+V` remain available as explicit copy/paste alternatives.
- The mappings allow fallback for non-Latin keyboard layouts.

This is a Kitty emulator configuration, not a Windows Terminal settings file. Under WSL, it is relevant only if Kitty itself is running as a Linux GUI application. A Windows-hosted terminal usually needs its own host-side configuration.

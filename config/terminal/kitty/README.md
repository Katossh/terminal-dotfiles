# Kitty terminal configuration

`kitty.conf` configures JetBrainsMono Nerd Font, a large scrollback, Catppuccin Mocha colors, window splits, tabs, font resizing, and keyboard shortcuts.

## Dependencies and assumptions

- Font family: JetBrainsMono Nerd Font, provided by the required `nerd-fonts.jetbrains-mono` entry in `manifest/packages.tsv`.
- Theme files live under `themes/`.
- The scrollback mappings refer to Neovim's `kitty-scrollback.nvim` plugin path; remove or adjust them if that plugin is not installed.
- `kitty_grab/` is a vendored upstream project; prefer updating it from its source rather than editing upstream code locally.

## Mouse behavior

- Middle-click paste from the PRIMARY selection is disabled in Kitty.
- Other middle-button behavior outside Kitty is left to the application and desktop configuration.
- The standard `Ctrl+Shift+C` and `Ctrl+Shift+V` clipboard shortcuts are unchanged.

This is a Kitty emulator configuration, not a Windows Terminal settings file. Under WSL, it is relevant only if Kitty itself is running as a Linux GUI application. A Windows-hosted terminal usually needs its own host-side configuration.

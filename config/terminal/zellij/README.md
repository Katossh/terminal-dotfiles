# Zellij

Zellij is included as an optional terminal multiplexer while tmux remains the
current default.

## Current status

- Launch manually with `zellij`.
- The shared configuration sets Zsh as the default shell and Neovim as the
  scrollback editor.
- Session serialization is enabled and the scrollback limit is 10,000 lines.
- Zsh does not automatically launch Zellij.
- The existing tmux package, configuration, plugins, and automatic startup
  remain unchanged during the evaluation period.

A future migration should explicitly review session persistence, copy/clipboard
behavior, mouse selection, keybindings, layouts, plugin equivalents, SSH use,
and the current automatic-start behavior before tmux is removed.

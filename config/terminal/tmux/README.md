# tmux

This directory contains a configuration based on [gpakosz/.tmux](https://github.com/gpakosz/.tmux).

- `.tmux.conf` — main configuration; avoid editing this generated/upstream-style file when an override will do.
- `.tmux.conf.local` — local colors, status line, pane behavior, and plugin options.

The installer links these files to the conventional targets `~/.tmux.conf` and `~/.tmux.conf.local`. This tracked source directory is separate from tmux's runtime plugin directory under `~/.tmux/`.

The local configuration uses **Catppuccin Mocha** colors. The installer also installs the official [Catppuccin tmux plugin](https://github.com/catppuccin/tmux) at the pinned `v2.3.2` tag under `~/.tmux/plugins/catppuccin/tmux` when tmux 3.2+ and Git are available. A built-in Mocha style remains active if the plugin cannot be installed. The plugin is installed manually rather than through TPM, following Catppuccin's recommendation.

## Runtime notes
- Install tmux from your Linux distribution.
- The config keeps the existing TPM-managed `tmux-copycat`, `tmux-resurrect`, and `tmux-continuum` plugins. Catppuccin is installed separately and is not managed by TPM.
- After linking the configs, the installer aligns a running tmux server's `default-shell` with the account login shell and reloads the configuration. Existing panes keep their current process; run `exec zsh` once in an old Bash pane.
- Clipboard integration is currently disabled in the local config. On WSL, configure tmux's copy command separately if copying should reach the Windows clipboard.
- Test the config with `tmux -f ~/.tmux.conf` before relying on it for persistent sessions.

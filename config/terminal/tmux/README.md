# tmux

This directory contains a configuration based on [gpakosz/.tmux](https://github.com/gpakosz/.tmux).

- `.tmux.conf` — main configuration; avoid editing this generated/upstream-style file when an override will do.
- `.tmux.conf.local` — local colors, status line, pane behavior, key bindings, and plugin options.

The installer links these files to the conventional targets `~/.tmux.conf` and `~/.tmux.conf.local`. This tracked source directory is separate from tmux's runtime plugin directory under `~/.tmux/`.

The local configuration uses **Catppuccin Mocha** colors. The installer also installs the official [Catppuccin tmux plugin](https://github.com/catppuccin/tmux) at the pinned `v2.3.2` tag under `~/.tmux/plugins/catppuccin/tmux` when tmux 3.2+ and Git are available. A built-in Mocha style remains active if the plugin cannot be installed. The plugin is installed manually rather than through TPM, following Catppuccin's recommendation.

## Runtime notes
- Install tmux from your Linux distribution.
- The config keeps the existing TPM-managed `tmux-copycat`, `tmux-resurrect`, and `tmux-continuum` plugins. Catppuccin is installed separately and is not managed by TPM.
- The local config resolves the installed Zsh executable and sets the tmux server's global `default-shell` to it, so all new windows and panes use Zsh regardless of the account's login-shell setting. Existing panes keep their current process; run `exec zsh` in an old Bash pane or recreate it.
- tmux mouse handling is enabled. Scrolling up with the wheel enters copy mode and browses the pane's scrollback; scrolling down returns to live output. The upstream `prefix + m` toggle remains available.
- Mouse selection and wheel input inside tmux panes are handled by tmux rather than Kitty. Keyboard-driven tmux copy mode also remains available. Copying a selection from copy mode uses the detected OS clipboard utility (`wl-copy` on Wayland, `xclip`/`xsel` on X11, or the platform equivalent). `set-clipboard external` permits tmux to set the terminal clipboard while ignoring application-originated OSC 52 attempts to populate tmux paste buffers.
- Applications inside panes can still request mouse tracking themselves; tmux's `mouse` option does not override an application's own mouse mode.
- The standard `Prefix + x` and `Prefix + &` shortcuts close the current pane or window without a confirmation prompt.
- Test the config with `tmux -f ~/.tmux.conf` before relying on it for persistent sessions.

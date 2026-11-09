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
- Mouse selection and wheel input inside tmux panes are handled by tmux rather than Kitty. Keyboard-driven tmux copy mode uses Vim-style keys: press `v` to start a selection, move to its end, then press `Ctrl+Shift+C` to copy and leave copy mode. The existing `y` binding remains available. Kitty maps this shortcut to `copy_or_noop`: it copies a Kitty text selection when one exists, but passes the key through when it does not, allowing tmux to handle its own selection.
- `Ctrl+Shift+V` remains Kitty's `paste_from_clipboard` action and pastes the system clipboard into the active pane. tmux sends copied selections to Kitty through OSC 52 using `set-clipboard external`; applications inside tmux cannot use OSC 52 to write tmux paste buffers.
- The distinct Ctrl+Shift+C key requires Kitty's `xterm-kitty` terminal type and tmux 3.5+ with extended keys enabled. The NixOS workstation's pinned Nixpkgs provides tmux 3.8. The config enables CSI-u reporting and advertises the Kitty `extkeys` feature to tmux. Ordinary `Ctrl+C` remains untouched and continues to interrupt foreground commands.
- Applications inside panes can still request mouse tracking themselves; tmux's `mouse` option does not override an application's own mouse mode.
- The standard `Prefix + x` and `Prefix + &` shortcuts close the current pane or window without a confirmation prompt.
- Test the config with `tmux -f ~/.tmux.conf` before relying on it for persistent sessions.

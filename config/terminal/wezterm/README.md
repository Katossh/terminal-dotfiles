# WezTerm configuration

`wezterm.lua` defines Kanagawa and Palenightfall color schemes, Victor Mono typography, pane navigation, tab management, search, copy mode, font sizing, and shortcuts for terminal navigation and launching a new Zsh session.

## Before using on Windows/WSL
- Review the `CMD` key bindings. They were written with a macOS keyboard model in mind and may not match the desired Windows shortcuts.
- The new-tab shortcut launches `zsh -i`; make sure WezTerm is configured to start the intended WSL distribution and that Zsh is installed there.
- The config integrates pane navigation with Neovim through the `IS_NVIM` user variable.
- The theme and font choices are independent of WSL, but installed fonts must be visible to the WezTerm host.

Keep host-terminal settings here and Linux-shell settings in `config/zsh/`. They solve different layers of the problem.

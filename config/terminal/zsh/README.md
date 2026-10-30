# Zsh configuration

The entry point is `dots/zshenv`. It sets XDG paths and `ZDOTDIR=$XDG_CONFIG_HOME/zsh`, so Zsh loads its startup files from this directory rather than directly from `~`.

## Files
- `.zshrc` — interactive shell setup, history, options, plugin loading, Starship, and optional automatic tmux startup.
- `aliases.zsh` — command aliases and the FZF/Neovim file preview helper.
- `completion.zsh` — completion initialization, matching rules, and cache settings.
- `prompt.zsh` — initializes Starship; the appearance is configured in `config/starship.toml`.
- `handlers.zsh` — custom message for unknown commands.
- `.packages/` — plugin sources vendored as regular tracked files, so a normal clone contains them without initializing Git submodules.

## Dependencies
The setup requires `zsh`, Starship, `git`, `fzf`, `bat`, `nvim`, and `tmux`. Starship is initialized by `prompt.zsh` and reads the linked `config/starship.toml`. The `project` helper is loaded only when `OPEN_PROJECT=1`.

The plugin sources are vendored as ordinary tracked files in the current tree. Upstream project links are listed in [`resources/upstream-sources.md`](../../resources/upstream-sources.md). If a plugin path is missing, check that the repository contents are intact before changing the shell startup files.

## Portability and local settings
- `dots/zshenv` contains shared defaults only. Keep passwords, API tokens, private keys, and machine-specific credentials out of tracked files.
- `BROWSER`, `TERMINAL`, `EDITOR`, personal directories, and optional tool paths may need local overrides.
- Starship configuration is tracked in `config/starship.toml` and linked into the XDG config directory by the installer.
- For WSL, disable automatic tmux startup in `.zshrc` if each new Windows Terminal tab should not enter tmux automatically.

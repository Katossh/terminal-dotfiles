# Zsh configuration

The entry point is `dots/zshenv`. It sets XDG paths and `ZDOTDIR=$XDG_CONFIG_HOME/zsh`, so Zsh loads its startup files from this directory rather than directly from `~`. The interactive setup initializes the vendored [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh) framework and keeps Starship as the prompt.

## Files
- `.zshrc` — interactive shell setup, history, options, Oh My Zsh plugins, standalone plugins, Starship, and optional automatic tmux startup.
- `aliases.zsh` — command aliases and the FZF/Neovim file preview helper.
- `completion.zsh` — completion matching rules and cache settings; Oh My Zsh runs `compinit` once using an XDG cache file.
- `prompt.zsh` — initializes Starship; the appearance is configured in `config/starship.toml`.
- `handlers.zsh` — custom message for unknown commands.
- `.packages/` — the vendored Oh My Zsh framework, extra completion definitions, and standalone plugins. They are regular tracked files, so a normal clone contains them without initializing Git submodules.

## Dependencies
The setup requires `zsh`, Starship, `git`, `fzf`, `bat`, `nvim`, and `tmux`. Starship is initialized by `prompt.zsh` and reads the linked `config/starship.toml`. The `project` helper is loaded only when `OPEN_PROJECT=1`.

Oh My Zsh's built-in `z` plugin replaces the separate `zsh-z` package. Fast syntax highlighting, autosuggestions, fzf-tab completion, and multi-dot path expansion remain separate plugins because Oh My Zsh does not bundle equivalent implementations. The extra `zsh-completions` definitions are added to `fpath` before `compinit`. Upstream project links are listed in [`resources/upstream-sources.md`](../../resources/upstream-sources.md).

## Portability and local settings
- `dots/zshenv` contains shared defaults only. Keep passwords, API tokens, private keys, and machine-specific credentials out of tracked files.
- `BROWSER`, `TERMINAL`, `EDITOR`, personal directories, and optional tool paths may need local overrides.
- Starship configuration is tracked in `config/starship.toml` and linked into the XDG config directory by the installer.
- For WSL, disable automatic tmux startup in `.zshrc` if each new Windows Terminal tab should not enter tmux automatically.

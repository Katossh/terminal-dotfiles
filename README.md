# Dotfiles

Personal configuration for the command line, terminal tools, and a Linux desktop. The repository is a collection of settings rather than a universal installer: some files are portable, while others were written for a specific desktop or operating system.

## Repository map

### Shell and terminal workflow
- `dots/zshenv` — shared environment variables and XDG paths; loaded before Zsh reads its interactive configuration.
- `config/zsh/` — Zsh startup, aliases, completion, prompt, and command-not-found handler.
- `config/starship.toml` — Starship prompt configuration.
- `config/.tmux/` — tmux configuration based on [gpakosz/.tmux](https://github.com/gpakosz/.tmux) and local overrides.
- `config/kitty/` — Kitty terminal settings, key bindings, and color themes.
- `config/wezterm/wezterm.lua` — WezTerm settings, themes, pane navigation, and keyboard shortcuts.

### Command-line tools
- `config/git/` — Git colors, aliases, diff tools, and global ignore rules.
- `config/bat/` — bat output styling and themes.
- `config/fd/` and `config/ripgrep/` — ignore rules for file discovery and text search.
- `bin/` — documented helper scripts for clipboard/branch copying, extraction, FZF previews, project selection, process selection, and Docker containers (`bin/README.md`).
- `resources/packages_list.md` — an old package checklist; currently it describes Homebrew on macOS.

### Desktop configuration
The remaining folders under `config/` include Linux desktop applications and Hyprland-related configuration, such as `hypr/`, `waybar/`, `rofi/`, `swaync/`, `wallust/`, and `wlogout/`. These belong to a graphical Linux desktop and are not required for a headless WSL shell.

## Platform notes

| Component | Status |
|---|---|
| Zsh, Starship, Git, bat, fd, ripgrep, helper scripts | Mostly portable; check optional tools and local paths |
| tmux | Linux-friendly; requires tmux and its configured plugins |
| Kitty | Configuration for the Kitty emulator; not a Windows Terminal profile |
| WezTerm | Cross-platform emulator, but current key bindings and some options were written with macOS in mind |
| Hyprland, Waybar, rofi, swaync | Linux desktop configuration; not a WSL shell setup |
| Package list | Historical macOS/Homebrew notes, not a Fedora installation script |

The shell configuration expects several tools (for example, `fzf`, `rg`, `bat`, `nvim`, `starship`, `git`, and optionally `tmux`). Install the tools you actually use with your distribution's package manager.

## Install

Clone the repository, including its submodules:

```sh
git clone --recurse-submodules https://github.com/Katossh/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
bash bin/makesymlinks
```

The installer creates symlinks from `dots/` into the home directory and from most of `config/` into `~/.config/`. The tmux files are placed at `~/.tmux.conf` and `~/.tmux.conf.local`, which are the locations expected by the upstream-style configuration. Before replacing an existing configuration, the installer backs it up under `~/.dotfiles_old/`. Review the script before running it on a machine with valuable local configuration.

After installing, open a new shell and check for missing commands. The plugin sources under `config/zsh/.packages/` are currently vendored as ordinary tracked files, not Git submodules. Their upstream URLs are documented in [`resources/upstream-sources.md`](./resources/upstream-sources.md); a normal clone is sufficient.

## Local overrides

Use local, untracked files for machine-specific settings. For example, `config/zsh/zprofile.local` is ignored by Git and can hold local environment customizations. Do not commit API tokens, passwords, private keys, or other credentials. Authenticate with tools such as `gh auth login`, or provide secrets through a local secret manager or an untracked file with restrictive permissions.

## Security

- Never put credentials in tracked shell startup files.
- If a token has ever been committed, revoke/rotate it; deleting the current line does not remove it from Git history.
- Check the repository history before publishing it or making it public.

## Layout direction

Terminal and shell configuration and the Hyprland desktop configuration are different concerns. For reuse across machines, keep the command-line setup minimal and portable, and keep desktop-specific settings separate. The current repository still contains both groups. The folder-level READMEs now document the intended boundaries, but the files have not yet been moved into separate repositories.

# Zsh configuration

## Startup layout

The zshenv file is linked to ~/.zshenv. It defines XDG paths, sets ZDOTDIR=$XDG_CONFIG_HOME/zsh, and discovers the dotfiles checkout. Interactive startup then reads:

1. .zshrc — PATH, history, options, Oh My Zsh and plugin initialization, custom modules, Starship, and optional tmux startup.
2. aliases.zsh — aliases and small interactive helpers.
3. completion.zsh — completion matching and cache styles.
4. command-state.zsh, failure-classifier.zsh, failure-messages.zsh, command-suggestions.zsh, and diagnostics.zsh — interactive command tracking, conservative diagnosis, failure messages, safe corrections, and `why`.
5. handlers.zsh — the shared failure hook and command-not-found integration.
5. prompt.zsh — Starship initialization (or a simple fallback prompt when Starship is unavailable).

The framework, plugins, history and completion caches stay outside the Git checkout.

## Runtime framework and plugins

The installer manages these upstream checkouts under XDG_DATA_HOME:

| Component | Runtime path | Purpose |
|---|---|---|
| Oh My Zsh | oh-my-zsh/ | Plugin loader and built-in plugins |
| git | oh-my-zsh/plugins/git/ | Git aliases and completions |
| z | oh-my-zsh/plugins/z/ | Directory-jump history |
| zsh-autosuggestions | oh-my-zsh/plugins/zsh-autosuggestions/ | Fish-like command suggestions |
| fzf-tab | zsh/custom/plugins/fzf-tab/ | Fuzzy completion menus |
| fast-syntax-highlighting | zsh/custom/plugins/fast-syntax-highlighting/ | Syntax highlighting while typing |
| zsh-completions | zsh/custom/plugins/zsh-completions/ | Additional completion definitions |

git, z, and zsh-autosuggestions are shipped within the Oh My Zsh repository. The other three repositories are cloned separately into its custom plugin area.

## Loading order

The order in .zshrc is intentional:

- zsh-completions/src is prepended to fpath before Oh My Zsh initializes completion.
- Oh My Zsh runs compinit and loads git and z.
- fzf-tab is loaded before ZLE widget wrappers.
- zsh-autosuggestions is enabled when present.
- fast-syntax-highlighting is loaded last so it can wrap widgets installed by earlier plugins.

The disabled zsh-manydots-magic experiment is not part of the active setup.

## Interactive failure diagnostics

The shell records the latest completed interactive command, its expanded form,
exit status, starting directory, completion time, and a monotonically
increasing record sequence. The record stays in shell memory; it is not written
to history or exported to child processes.

Non-zero command statuses are classified conservatively. The classifier
recognises common command-not-found and permission statuses, literal missing
paths passed to `cd`, Git and Nix commands, and a narrow set of documented
curl/wget network statuses. Ambiguous failures remain generic. The message
renderer uses `DOTS_FAILURE_MESSAGE_CHANCE`,
`DOTS_FAILURE_RARE_CHANCE`, and
`DOTS_FAILURE_MESSAGE_ESCALATION`; `NO_COLOR` disables colour.

Run `why` to inspect the most recently completed command, or
`why --verbose` to include its working directory, expanded command, and age.
It does not re-run the command, evaluate its text, or reconstruct stderr.

For a command-name typo, Zsh may offer close matches. A selected correction
requires a separate explicit confirmation before it runs. Aliases are omitted
because they cannot be invoked safely through a dynamically selected command
name. Non-interactive shells only print candidates and never prompt or execute
a correction.

## Installing or repairing

~~~sh
dots install --no-packages
dots health
~~~

This works even if the zsh executable is not currently installed or is absent from PATH. Git and GitHub connectivity are required. A failed required clone is reported as an error; the installer does not print a successful completion status in that case.

If the framework is missing when a shell starts, .zshrc uses native compinit as a fallback and prints the exact runtime path plus the repair command. It does not try to download code every time a shell opens.

## Updating

Automatic Oh My Zsh updates are disabled at shell startup to keep terminal startup deterministic. Update each runtime checkout explicitly:

~~~sh
git -C "$XDG_DATA_HOME/oh-my-zsh" pull --ff-only
git -C "$XDG_DATA_HOME/zsh/custom/plugins/fzf-tab" pull --ff-only
git -C "$XDG_DATA_HOME/zsh/custom/plugins/fast-syntax-highlighting" pull --ff-only
git -C "$XDG_DATA_HOME/zsh/custom/plugins/zsh-completions" pull --ff-only
~~~

zsh-autosuggestions is updated with the Oh My Zsh checkout because it is included there.

## Local customization

Do not modify runtime-managed upstream directories to customize the prompt or aliases. Put local configuration in ~/.config/zsh/zprofile.local or use the repository's personal override mechanism:

~~~text
~/.config/dots/overrides/zsh/aliases.zsh
~~~

Keep private credentials and machine-specific values out of tracked files.

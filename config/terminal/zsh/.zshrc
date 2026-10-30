# Load optional, untracked machine-local settings first.
[[ -f "$ZDOTDIR/zprofile.local" ]] && source "$ZDOTDIR/zprofile.local"

# Put user-installed helpers first (for Debian's batcat/fdfind compatibility
# links) and make helper commands available regardless of clone location.
typeset -U path
path=(
    "$HOME/.local/bin"
    "$DOTFILES_DIR/bin"
    /usr/local/bin
    /usr/local/sbin
    $path
)

# Emacs mode in ZLE
bindkey -e

# Keep generated history and completion files outside the Git checkout.
mkdir -p "$XDG_DATA_HOME/zsh" "$XDG_CACHE_HOME/zsh"
export HISTFILE="$XDG_DATA_HOME/zsh/history"
export HISTSIZE=10000
export SAVEHIST=10000
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_SAVE_NO_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS

# Directory stack and convenience options
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT
setopt AUTO_CD
setopt EXTENDED_GLOB

# Terminal tab/window title
tab_title_precmd() {
    print -Pn "\e]0;$(basename "$PWD")\a"
}
typeset -a precmd_functions
precmd_functions+=(tab_title_precmd)

# Modular configuration
source "$ZDOTDIR/aliases.zsh"
source "$ZDOTDIR/completion.zsh"
source "$ZDOTDIR/handlers.zsh"

# Optional plugins vendored under config/zsh/.packages.
# Load only files that exist so partial installs remain usable.
for plugin in \
    "$ZDOTDIR/.packages/zsh-z/zsh-z.plugin.zsh" \
    "$ZDOTDIR/.packages/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" \
    "$ZDOTDIR/.packages/zsh-autosuggestions/zsh-autosuggestions.zsh" \
    "$ZDOTDIR/.packages/fzf-tab/fzf-tab.plugin.zsh" \
    "$ZDOTDIR/.packages/zsh-manydots-magic/manydots-magic"; do
    [[ -f "$plugin" ]] && source "$plugin"
done

bindkey "^O" clear-screen

# Ctrl+W removes a shell-style word, respecting path separators.
autoload -U select-word-style
select-word-style bash

# Load the project picker only for terminals explicitly opened for that purpose.
if [[ "${OPEN_PROJECT:-0}" == 1 ]]; then
    source "$DOTFILES_DIR/bin/project"
fi

# Initialize the prompt after aliases, completions, plugins, and local helpers.
source "$ZDOTDIR/prompt.zsh"

# Start tmux automatically for interactive shells, but never nest tmux sessions.
if command -v tmux >/dev/null 2>&1 && [[ -n "$PS1" ]] &&
    [[ "$TERM" != screen* && "$TERM" != tmux* ]] && [[ -z "${TMUX:-}" ]]; then
    exec tmux
fi

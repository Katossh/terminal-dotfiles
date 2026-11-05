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

# Oh My Zsh and custom plugins are installed by dots outside the repository.
# This keeps third-party code out of the configuration tree.
export ZSH="$XDG_DATA_HOME/oh-my-zsh"
export ZSH_CUSTOM="$XDG_DATA_HOME/zsh/custom"
export ZSH_CACHE_DIR="$XDG_CACHE_HOME/oh-my-zsh"
export ZSH_COMPDUMP="$XDG_CACHE_HOME/zsh/.zcompdump"
export DISABLE_AUTO_UPDATE=true
mkdir -p "$ZSH_CACHE_DIR" "$XDG_CACHE_HOME/zsh"

# Extra completion definitions must be on fpath before Oh My Zsh runs compinit.
typeset -U fpath
if [[ -d "$ZSH_CUSTOM/plugins/zsh-completions/src" ]]; then
    fpath=("$ZSH_CUSTOM/plugins/zsh-completions/src" $fpath)
fi

ZSH_THEME=""
plugins=(git z)

# fzf-tab must load before plugins that wrap ZLE widgets. Keep syntax
# highlighting last so it can observe widgets installed by earlier plugins.
[[ -r "$ZSH_CUSTOM/plugins/fzf-tab/fzf-tab.plugin.zsh" ]] && plugins+=(fzf-tab)
[[ -r "$ZSH/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh" ]] && plugins+=(zsh-autosuggestions)
[[ -r "$ZSH_CUSTOM/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh" ]] && plugins+=(fast-syntax-highlighting)

if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
    source "$ZSH/oh-my-zsh.sh"
else
    # A config-only install remains usable when upstream downloads were skipped.
    autoload -Uz compinit
    compinit -d "$ZSH_COMPDUMP"
    print -u2 -- "dots: Oh My Zsh is missing at '$ZSH'. Run: dots install --no-packages"
fi

# Modular configuration
source "$ZDOTDIR/aliases.zsh"
source "$ZDOTDIR/completion.zsh"
source "$ZDOTDIR/handlers.zsh"

bindkey "^O" clear-screen

# Alt+Right accepts the next word of a zsh-autosuggestions suggestion.
# The plugin wraps forward-word with its partial-accept widget.
bindkey '^[[1;3C' forward-word

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

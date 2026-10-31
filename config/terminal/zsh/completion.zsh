# Oh My Zsh initializes compinit with the XDG cache path configured in .zshrc.
_comp_options+=(globdots)

# Menu-driven completion and case-insensitive matching.
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' expand prefix suffix

zstyle ':completion:*:*:*:*:descriptions' format '-- %d --'
zstyle ':completion:*:messages' format ' %F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format ' %F{red}-- no matches found --%f'

zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/.zcompcache"

# Non-blocking terminal animations for interactive Zsh.
#
# The persistent motif is inserted after Starship's first prompt line (the
# current directory/modules) and before its line_break module. The input
# symbol therefore remains on the following line. Animation frames arrive
# asynchronously through zle -F; the last frame stays in the prompt after the
# stream ends or the current input line is submitted.

typeset -gi _DOTS_FAILURE_ANIMATION_PENDING=${_DOTS_FAILURE_ANIMATION_PENDING:-0}
typeset -gi _DOTS_FAILURE_ANIMATION_FD=-1
typeset -gi _DOTS_FAILURE_ANIMATION_STEP=0
typeset -gi _DOTS_FAILURE_ANIMATION_ACTIVE=0
typeset -gi _DOTS_FAILURE_ANIMATION_STARTUP_PENDING=1
typeset -gi _DOTS_FAILURE_ANIMATION_FRAMES=0
typeset -gi _DOTS_FAILURE_ANIMATION_LAST_FRAMES=0
typeset -g _DOTS_FAILURE_ANIMATION_STATE='loaded'
typeset -g _DOTS_FAILURE_ANIMATION_LAST_STATE=''
typeset -g _DOTS_FAILURE_ANIMATION_FRAME='✨'
typeset -g _DOTS_FAILURE_ANIMATION_BASE_PROMPT=''
typeset -g _DOTS_FAILURE_ANIMATION_DECORATED_PROMPT=''
typeset -g _DOTS_FAILURE_ANIMATION_LAST_FRAME_PROMPT=''
# Internal test seam; production cadence remains 140 ms per frame.
typeset -g _DOTS_FAILURE_ANIMATION_INTERVAL='0.14'

_dots_failure_animation_stream() {
    emulate -L zsh

    local variant="${1:-1}"
    local frame
    local -a frames

    case "$variant" in
        2)
            frames=(
                '🌙' '✨' '💫' '✧' '🌙' '⋆' '✨' '💫' '🌙' '✧' '✨' '⋆' '💫' '🌙' '✨' '✧' '💫' '⋆' '🌙' '✨' '✧' '💫' '🌙' '✨' '⋆' '🌙' '💫' '✧' '✨' '🌙' '⋆' '💫' '✨' '✧' '🌙' '✨'
            )
            ;;
        3)
            frames=(
                '♡' '♥' '♡' '💗' '💖' '💞' '♡' '♥' '💗' '♡' '💘' '💞' '♥' '♡' '💖' '💗' '♡' '💞' '♥' '💘' '♡' '💗' '💖' '♡' '💞' '💗' '♥' '♡' '💘' '💖' '♡' '💗' '💞' '♥' '♡' '💖'
            )
            ;;
        4)
            frames=(
                '🦋' '✦' '🐈‍⬛' '✨' '🦋' '⋆' '💫' '🐈‍⬛' '✧' '🦋' '✨' '⋆' '🐈‍⬛' '💫' '✦' '🦋' '✧' '🐈‍⬛' '✨' '🦋' '⋆' '💫' '✦' '🐈‍⬛' '🦋' '✨' '✧' '⋆' '🐈‍⬛' '💫' '🦋' '✦' '✨' '🐈‍⬛' '⋆' '🦋'
            )
            ;;
        *)
            frames=(
                '✦' '✧' '⋆' '✧' '✨' '✦' '✧' '⋆' '✦' '✨' '✧' '✦' '⋆' '✧' '✨' '✦' '✧' '⋆' '✦' '✨' '✧' '⋆' '✦' '✧' '✨' '⋆' '✧' '✦' '✨' '⋆' '✧' '✦' '💫' '✧' '⋆' '✨'
            )
            ;;
    esac

    for frame in "${frames[@]}"; do
        print -r -- "$frame" || return 0
        command sleep "$_DOTS_FAILURE_ANIMATION_INTERVAL" 2>/dev/null || return 0
    done
}

_dots_failure_animation_apply_prompt() {
    emulate -L zsh

    local base="$_DOTS_FAILURE_ANIMATION_BASE_PROMPT"
    if [[ -z "$base" || "${DOTS_FAILURE_ANIMATION:-1}" == 0 ]]; then
        PROMPT="$base"
        _DOTS_FAILURE_ANIMATION_DECORATED_PROMPT="$PROMPT"
        return 0
    fi

    local -a colors
    colors=(
        $'\e[38;2;255;105;180m'
        $'\e[38;2;255;127;80m'
        $'\e[38;2;250;204;21m'
        $'\e[38;2;163;230;53m'
        $'\e[38;2;45;212;191m'
        $'\e[38;2;56;189;248m'
        $'\e[38;2;129;140;248m'
        $'\e[38;2;192;132;252m'
        $'\e[38;2;244;114;182m'
        $'\e[38;2;251;113;133m'
        $'\e[38;2;251;146;60m'
        $'\e[38;2;196;181;253m'
    )
    local color='' reset=''
    local -i color_index=1
    if (( _DOTS_FAILURE_ANIMATION_STEP > 0 )); then
        color_index=$(( ((_DOTS_FAILURE_ANIMATION_STEP - 1) % ${#colors[@]}) + 1 ))
    fi
    if [[ -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]]; then
        color="${colors[color_index]}"
        reset=="%B%{${color}%}✧━━  ✦ ${_DOTS_FAILURE_ANIMATION_FRAME} ✦  ━━✧%{${reset}%}%b"
    local first_line="$base"
    local remaining=''
    if [[ "$base" == *$'\n'* ]]; then
        first_line="${base%%$'\n'*}"
        remaining="${base#*$'\n'}"
        PROMPT="${first_line}  ${motif}"$'\n'"${remaining}"
    else
        PROMPT="${first_line}  ${motif}"
    fi

    _DOTS_FAILURE_ANIMATION_DECORATED_PROMPT="$PROMPT"
    _DOTS_FAILURE_ANIMATION_LAST_FRAME_PROMPT="$PROMPT"
}

_dots_failure_animation_refresh_prompt() {
    emulate -L zsh

    # Starship rebuilds PROMPT during precmd. In a fallback prompt without a
    # prompt hook, however, PROMPT may still contain our previous decoration.
    # Strip only that exact decoration; otherwise accept the newly generated
    # prompt as the clean base.
    if [[ -n "$_DOTS_FAILURE_ANIMATION_DECORATED_PROMPT" &&
        "$PROMPT" == "$_DOTS_FAILURE_ANIMATION_DECORATED_PROMPT" ]]; then
        PROMPT="$_DOTS_FAILURE_ANIMATION_BASE_PROMPT"
    else
        _DOTS_FAILURE_ANIMATION_BASE_PROMPT="${PROMPT-}"
    fi

    _dots_failure_animation_apply_prompt
}

_dots_failure_animation_cleanup() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    local redraw="${1:-0}"
    if (( _DOTS_FAILURE_ANIMATION_ACTIVE )); then
        _DOTS_FAILURE_ANIMATION_LAST_STATE="$_DOTS_FAILURE_ANIMATION_STATE"
        _DOTS_FAILURE_ANIMATION_LAST_FRAMES=$_DOTS_FAILURE_ANIMATION_FRAMES

        local fd="$_DOTS_FAILURE_ANIMATION_FD"
        zle -F "$fd" 2>/dev/null || true
        { exec {fd}<&- } 2>/dev/null || true

        _DOTS_FAILURE_ANIMATION_FD=-1
        _DOTS_FAILURE_ANIMATION_ACTIVE=0
        _DOTS_FAILURE_ANIMATION_STATE='finished'
    fi

    # Never clear the final frame. It is the static prompt decoration until a
    # later animation replaces it.
    [[ -n "$_DOTS_FAILURE_ANIMATION_BASE_PROMPT" ]] &&
        _dots_failure_animation_apply_prompt

    if (( redraw )) && zle; then
        zle .reset-prompt
    fi
}

_dots_failure_animation_fd_handler() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    local fd="${1:-}"
    local frame
    if [[ -z "$fd" ]] || ! IFS= builtin read -r -u "$fd" frame; then
        _DOTS_FAILURE_ANIMATION_STATE='stream-complete'
        _dots_failure_animation_cleanup 1
        return 0
    fi

    (( _DOTS_FAILURE_ANIMATION_STEP += 1 ))
    _DOTS_FAILURE_ANIMATION_FRAME="$frame"
    (( _DOTS_FAILURE_ANIMATION_FRAMES += 1 ))
    _DOTS_FAILURE_ANIMATION_STATE='frame-rendered'

    _dots_failure_animation_apply_prompt

    # This is a regular zle -F callback, not a widget handler. Resetting the
    # prompt uses the standard shell-level ZLE widget invocation.
    zle && zle .reset-prompt
}

# The message renderer calls this from an earlier precmd hook. Queue the work
# and let our final precmd hook start it after Starship has rebuilt PROMPT.
_dots_failure_animation_start() {
    emulate -L zsh

    [[ -o interactive && -t 0 && -t 1 &&
        "${TERM:-dumb}" != dumb &&
        "${DOTS_FAILURE_ANIMATION:-1}" != 0 ]] || return 0

    _DOTS_FAILURE_ANIMATION_PENDING=1
}

_dots_failure_animation_begin() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    (( _DOTS_FAILURE_ANIMATION_ACTIVE )) && return 0
    [[ -o interactive && -t 0 && -t 1 &&
        "${TERM:-dumb}" != dumb &&
        "${DOTS_FAILURE_ANIMATION:-1}" != 0 ]] || return 0

    _DOTS_FAILURE_ANIMATION_STEP=0
    _DOTS_FAILURE_ANIMATION_FRAMES=0
    _DOTS_FAILURE_ANIMATION_STATE='starting'

    local variant=$(( (RANDOM % 4) + 1 ))
    exec {_DOTS_FAILURE_ANIMATION_FD}< <(_dots_failure_animation_stream "$variant")
    _DOTS_FAILURE_ANIMATION_ACTIVE=1

    # Register from precmd, before ZLE starts reading the next command line.
    if zle -F "$_DOTS_FAILURE_ANIMATION_FD" _dots_failure_animation_fd_handler; then
        _DOTS_FAILURE_ANIMATION_STATE='registered'
    else
        _DOTS_FAILURE_ANIMATION_STATE='registration-failed'
        _dots_failure_animation_cleanup
    fi
}

_dots_failure_animation_precmd() {
    emulate -L zsh

    [[ -o interactive && -t 0 && -t 1 ]] || return 0

    _dots_failure_animation_refresh_prompt

    # The first interactive prompt gets one animation even though no command
    # has failed yet. It is independent of the failure-animation probability.
    if (( _DOTS_FAILURE_ANIMATION_STARTUP_PENDING )); then
        _DOTS_FAILURE_ANIMATION_STARTUP_PENDING=0
        _DOTS_FAILURE_ANIMATION_PENDING=1
    fi

    if (( _DOTS_FAILURE_ANIMATION_PENDING )); then
        _DOTS_FAILURE_ANIMATION_PENDING=0
        _dots_failure_animation_begin
    fi
}

_dots_failure_animation_line_finish() {
    _dots_failure_animation_cleanup
}

if [[ -o interactive ]]; then
    autoload -Uz add-zsh-hook add-zle-hook-widget
    add-zsh-hook precmd _dots_failure_animation_precmd
    add-zle-hook-widget zle-line-finish _dots_failure_animation_line_finish
fi
\e[0m'
    fi

    local motif="%B%{${color}%}✧━━  ✦ ${_DOTS_FAILURE_ANIMATION_FRAME} ✦  ━━✧%{${reset}%}%b"
    local first_line="$base"
    local remaining=''
    if [[ "$base" == *$'\n'* ]]; then
        first_line="${base%%$'\n'*}"
        remaining="${base#*$'\n'}"
        PROMPT="${first_line}  ${motif}"$'\n'"${remaining}"
    else
        PROMPT="${first_line}  ${motif}"
    fi

    _DOTS_FAILURE_ANIMATION_DECORATED_PROMPT="$PROMPT"
    _DOTS_FAILURE_ANIMATION_LAST_FRAME_PROMPT="$PROMPT"
}

_dots_failure_animation_refresh_prompt() {
    emulate -L zsh

    # Starship rebuilds PROMPT during precmd. In a fallback prompt without a
    # prompt hook, however, PROMPT may still contain our previous decoration.
    # Strip only that exact decoration; otherwise accept the newly generated
    # prompt as the clean base.
    if [[ -n "$_DOTS_FAILURE_ANIMATION_DECORATED_PROMPT" &&
        "$PROMPT" == "$_DOTS_FAILURE_ANIMATION_DECORATED_PROMPT" ]]; then
        PROMPT="$_DOTS_FAILURE_ANIMATION_BASE_PROMPT"
    else
        _DOTS_FAILURE_ANIMATION_BASE_PROMPT="${PROMPT-}"
    fi

    _dots_failure_animation_apply_prompt
}

_dots_failure_animation_cleanup() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    local redraw="${1:-0}"
    if (( _DOTS_FAILURE_ANIMATION_ACTIVE )); then
        _DOTS_FAILURE_ANIMATION_LAST_STATE="$_DOTS_FAILURE_ANIMATION_STATE"
        _DOTS_FAILURE_ANIMATION_LAST_FRAMES=$_DOTS_FAILURE_ANIMATION_FRAMES

        local fd="$_DOTS_FAILURE_ANIMATION_FD"
        zle -F "$fd" 2>/dev/null || true
        { exec {fd}<&- } 2>/dev/null || true

        _DOTS_FAILURE_ANIMATION_FD=-1
        _DOTS_FAILURE_ANIMATION_STEP=0
        _DOTS_FAILURE_ANIMATION_ACTIVE=0
        _DOTS_FAILURE_ANIMATION_STATE='finished'
    fi

    # Never clear the final frame. It is the static prompt decoration until a
    # later animation replaces it.
    [[ -n "$_DOTS_FAILURE_ANIMATION_BASE_PROMPT" ]] &&
        _dots_failure_animation_apply_prompt

    if (( redraw )) && zle; then
        zle .reset-prompt
    fi
}

_dots_failure_animation_fd_handler() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    local fd="${1:-}"
    local frame
    if [[ -z "$fd" ]] || ! IFS= builtin read -r -u "$fd" frame; then
        _DOTS_FAILURE_ANIMATION_STATE='stream-complete'
        _dots_failure_animation_cleanup 1
        return 0
    fi

    (( _DOTS_FAILURE_ANIMATION_STEP += 1 ))
    _DOTS_FAILURE_ANIMATION_FRAME="$frame"
    (( _DOTS_FAILURE_ANIMATION_FRAMES += 1 ))
    _DOTS_FAILURE_ANIMATION_STATE='frame-rendered'

    _dots_failure_animation_apply_prompt

    # This is a regular zle -F callback, not a widget handler. Resetting the
    # prompt uses the standard shell-level ZLE widget invocation.
    zle && zle .reset-prompt
}

# The message renderer calls this from an earlier precmd hook. Queue the work
# and let our final precmd hook start it after Starship has rebuilt PROMPT.
_dots_failure_animation_start() {
    emulate -L zsh

    [[ -o interactive && -t 0 && -t 1 &&
        "${TERM:-dumb}" != dumb &&
        "${DOTS_FAILURE_ANIMATION:-1}" != 0 ]] || return 0

    _DOTS_FAILURE_ANIMATION_PENDING=1
}

_dots_failure_animation_begin() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    (( _DOTS_FAILURE_ANIMATION_ACTIVE )) && return 0
    [[ -o interactive && -t 0 && -t 1 &&
        "${TERM:-dumb}" != dumb &&
        "${DOTS_FAILURE_ANIMATION:-1}" != 0 ]] || return 0

    _DOTS_FAILURE_ANIMATION_STEP=0
    _DOTS_FAILURE_ANIMATION_FRAMES=0
    _DOTS_FAILURE_ANIMATION_STATE='starting'

    local variant=$(( (RANDOM % 4) + 1 ))
    exec {_DOTS_FAILURE_ANIMATION_FD}< <(_dots_failure_animation_stream "$variant")
    _DOTS_FAILURE_ANIMATION_ACTIVE=1

    # Register from precmd, before ZLE starts reading the next command line.
    if zle -F "$_DOTS_FAILURE_ANIMATION_FD" _dots_failure_animation_fd_handler; then
        _DOTS_FAILURE_ANIMATION_STATE='registered'
    else
        _DOTS_FAILURE_ANIMATION_STATE='registration-failed'
        _dots_failure_animation_cleanup
    fi
}

_dots_failure_animation_precmd() {
    emulate -L zsh

    [[ -o interactive && -t 0 && -t 1 ]] || return 0

    _dots_failure_animation_refresh_prompt

    # The first interactive prompt gets one animation even though no command
    # has failed yet. It is independent of the failure-animation probability.
    if (( _DOTS_FAILURE_ANIMATION_STARTUP_PENDING )); then
        _DOTS_FAILURE_ANIMATION_STARTUP_PENDING=0
        _DOTS_FAILURE_ANIMATION_PENDING=1
    fi

    if (( _DOTS_FAILURE_ANIMATION_PENDING )); then
        _DOTS_FAILURE_ANIMATION_PENDING=0
        _dots_failure_animation_begin
    fi
}

_dots_failure_animation_line_finish() {
    _dots_failure_animation_cleanup
}

if [[ -o interactive ]]; then
    autoload -Uz add-zsh-hook add-zle-hook-widget
    add-zsh-hook precmd _dots_failure_animation_precmd
    add-zle-hook-widget zle-line-finish _dots_failure_animation_line_finish
fi
\e[0m'
    fi

    local motif="%B%{${color}%}✧━━  ✦ ${_DOTS_FAILURE_ANIMATION_FRAME} ✦  ━━✧%{${reset}%}%b"
    local first_line="$base"
    local remaining=''
    if [[ "$base" == *$'\n'* ]]; then
        first_line="${base%%$'\n'*}"
        remaining="${base#*$'\n'}"
        PROMPT="${first_line}  ${motif}"$'\n'"${remaining}"
    else
        PROMPT="${first_line}  ${motif}"
    fi

    _DOTS_FAILURE_ANIMATION_DECORATED_PROMPT="$PROMPT"
    _DOTS_FAILURE_ANIMATION_LAST_FRAME_PROMPT="$PROMPT"
}

_dots_failure_animation_refresh_prompt() {
    emulate -L zsh

    # Starship rebuilds PROMPT during precmd. In a fallback prompt without a
    # prompt hook, however, PROMPT may still contain our previous decoration.
    # Strip only that exact decoration; otherwise accept the newly generated
    # prompt as the clean base.
    if [[ -n "$_DOTS_FAILURE_ANIMATION_DECORATED_PROMPT" &&
        "$PROMPT" == "$_DOTS_FAILURE_ANIMATION_DECORATED_PROMPT" ]]; then
        PROMPT="$_DOTS_FAILURE_ANIMATION_BASE_PROMPT"
    else
        _DOTS_FAILURE_ANIMATION_BASE_PROMPT="${PROMPT-}"
    fi

    _dots_failure_animation_apply_prompt
}

_dots_failure_animation_cleanup() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    local redraw="${1:-0}"
    if (( _DOTS_FAILURE_ANIMATION_ACTIVE )); then
        _DOTS_FAILURE_ANIMATION_LAST_STATE="$_DOTS_FAILURE_ANIMATION_STATE"
        _DOTS_FAILURE_ANIMATION_LAST_FRAMES=$_DOTS_FAILURE_ANIMATION_FRAMES

        local fd="$_DOTS_FAILURE_ANIMATION_FD"
        zle -F "$fd" 2>/dev/null || true
        { exec {fd}<&- } 2>/dev/null || true

        _DOTS_FAILURE_ANIMATION_FD=-1
        _DOTS_FAILURE_ANIMATION_ACTIVE=0
        _DOTS_FAILURE_ANIMATION_STATE='finished'
    fi

    # Never clear the final frame. It is the static prompt decoration until a
    # later animation replaces it.
    [[ -n "$_DOTS_FAILURE_ANIMATION_BASE_PROMPT" ]] &&
        _dots_failure_animation_apply_prompt

    if (( redraw )) && zle; then
        zle .reset-prompt
    fi
}

_dots_failure_animation_fd_handler() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    local fd="${1:-}"
    local frame
    if [[ -z "$fd" ]] || ! IFS= builtin read -r -u "$fd" frame; then
        _DOTS_FAILURE_ANIMATION_STATE='stream-complete'
        _dots_failure_animation_cleanup 1
        return 0
    fi

    (( _DOTS_FAILURE_ANIMATION_STEP += 1 ))
    _DOTS_FAILURE_ANIMATION_FRAME="$frame"
    (( _DOTS_FAILURE_ANIMATION_FRAMES += 1 ))
    _DOTS_FAILURE_ANIMATION_STATE='frame-rendered'

    _dots_failure_animation_apply_prompt

    # This is a regular zle -F callback, not a widget handler. Resetting the
    # prompt uses the standard shell-level ZLE widget invocation.
    zle && zle .reset-prompt
}

# The message renderer calls this from an earlier precmd hook. Queue the work
# and let our final precmd hook start it after Starship has rebuilt PROMPT.
_dots_failure_animation_start() {
    emulate -L zsh

    [[ -o interactive && -t 0 && -t 1 &&
        "${TERM:-dumb}" != dumb &&
        "${DOTS_FAILURE_ANIMATION:-1}" != 0 ]] || return 0

    _DOTS_FAILURE_ANIMATION_PENDING=1
}

_dots_failure_animation_begin() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    (( _DOTS_FAILURE_ANIMATION_ACTIVE )) && return 0
    [[ -o interactive && -t 0 && -t 1 &&
        "${TERM:-dumb}" != dumb &&
        "${DOTS_FAILURE_ANIMATION:-1}" != 0 ]] || return 0

    _DOTS_FAILURE_ANIMATION_STEP=0
    _DOTS_FAILURE_ANIMATION_FRAMES=0
    _DOTS_FAILURE_ANIMATION_STATE='starting'

    local variant=$(( (RANDOM % 4) + 1 ))
    exec {_DOTS_FAILURE_ANIMATION_FD}< <(_dots_failure_animation_stream "$variant")
    _DOTS_FAILURE_ANIMATION_ACTIVE=1

    # Register from precmd, before ZLE starts reading the next command line.
    if zle -F "$_DOTS_FAILURE_ANIMATION_FD" _dots_failure_animation_fd_handler; then
        _DOTS_FAILURE_ANIMATION_STATE='registered'
    else
        _DOTS_FAILURE_ANIMATION_STATE='registration-failed'
        _dots_failure_animation_cleanup
    fi
}

_dots_failure_animation_precmd() {
    emulate -L zsh

    [[ -o interactive && -t 0 && -t 1 ]] || return 0

    _dots_failure_animation_refresh_prompt

    # The first interactive prompt gets one animation even though no command
    # has failed yet. It is independent of the failure-animation probability.
    if (( _DOTS_FAILURE_ANIMATION_STARTUP_PENDING )); then
        _DOTS_FAILURE_ANIMATION_STARTUP_PENDING=0
        _DOTS_FAILURE_ANIMATION_PENDING=1
    fi

    if (( _DOTS_FAILURE_ANIMATION_PENDING )); then
        _DOTS_FAILURE_ANIMATION_PENDING=0
        _dots_failure_animation_begin
    fi
}

_dots_failure_animation_line_finish() {
    _dots_failure_animation_cleanup
}

if [[ -o interactive ]]; then
    autoload -Uz add-zsh-hook add-zle-hook-widget
    add-zsh-hook precmd _dots_failure_animation_precmd
    add-zle-hook-widget zle-line-finish _dots_failure_animation_line_finish
fi
\e[0m'
    fi

    local motif="%B%{${color}%}✧━━  ✦ ${_DOTS_FAILURE_ANIMATION_FRAME} ✦  ━━✧%{${reset}%}%b"
    local first_line="$base"
    local remaining=''
    if [[ "$base" == *$'\n'* ]]; then
        first_line="${base%%$'\n'*}"
        remaining="${base#*$'\n'}"
        PROMPT="${first_line}  ${motif}"$'\n'"${remaining}"
    else
        PROMPT="${first_line}  ${motif}"
    fi

    _DOTS_FAILURE_ANIMATION_DECORATED_PROMPT="$PROMPT"
    _DOTS_FAILURE_ANIMATION_LAST_FRAME_PROMPT="$PROMPT"
}

_dots_failure_animation_refresh_prompt() {
    emulate -L zsh

    # Starship rebuilds PROMPT during precmd. In a fallback prompt without a
    # prompt hook, however, PROMPT may still contain our previous decoration.
    # Strip only that exact decoration; otherwise accept the newly generated
    # prompt as the clean base.
    if [[ -n "$_DOTS_FAILURE_ANIMATION_DECORATED_PROMPT" &&
        "$PROMPT" == "$_DOTS_FAILURE_ANIMATION_DECORATED_PROMPT" ]]; then
        PROMPT="$_DOTS_FAILURE_ANIMATION_BASE_PROMPT"
    else
        _DOTS_FAILURE_ANIMATION_BASE_PROMPT="${PROMPT-}"
    fi

    _dots_failure_animation_apply_prompt
}

_dots_failure_animation_cleanup() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    local redraw="${1:-0}"
    if (( _DOTS_FAILURE_ANIMATION_ACTIVE )); then
        _DOTS_FAILURE_ANIMATION_LAST_STATE="$_DOTS_FAILURE_ANIMATION_STATE"
        _DOTS_FAILURE_ANIMATION_LAST_FRAMES=$_DOTS_FAILURE_ANIMATION_FRAMES

        local fd="$_DOTS_FAILURE_ANIMATION_FD"
        zle -F "$fd" 2>/dev/null || true
        { exec {fd}<&- } 2>/dev/null || true

        _DOTS_FAILURE_ANIMATION_FD=-1
        _DOTS_FAILURE_ANIMATION_STEP=0
        _DOTS_FAILURE_ANIMATION_ACTIVE=0
        _DOTS_FAILURE_ANIMATION_STATE='finished'
    fi

    # Never clear the final frame. It is the static prompt decoration until a
    # later animation replaces it.
    [[ -n "$_DOTS_FAILURE_ANIMATION_BASE_PROMPT" ]] &&
        _dots_failure_animation_apply_prompt

    if (( redraw )) && zle; then
        zle .reset-prompt
    fi
}

_dots_failure_animation_fd_handler() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    local fd="${1:-}"
    local frame
    if [[ -z "$fd" ]] || ! IFS= builtin read -r -u "$fd" frame; then
        _DOTS_FAILURE_ANIMATION_STATE='stream-complete'
        _dots_failure_animation_cleanup 1
        return 0
    fi

    (( _DOTS_FAILURE_ANIMATION_STEP += 1 ))
    _DOTS_FAILURE_ANIMATION_FRAME="$frame"
    (( _DOTS_FAILURE_ANIMATION_FRAMES += 1 ))
    _DOTS_FAILURE_ANIMATION_STATE='frame-rendered'

    _dots_failure_animation_apply_prompt

    # This is a regular zle -F callback, not a widget handler. Resetting the
    # prompt uses the standard shell-level ZLE widget invocation.
    zle && zle .reset-prompt
}

# The message renderer calls this from an earlier precmd hook. Queue the work
# and let our final precmd hook start it after Starship has rebuilt PROMPT.
_dots_failure_animation_start() {
    emulate -L zsh

    [[ -o interactive && -t 0 && -t 1 &&
        "${TERM:-dumb}" != dumb &&
        "${DOTS_FAILURE_ANIMATION:-1}" != 0 ]] || return 0

    _DOTS_FAILURE_ANIMATION_PENDING=1
}

_dots_failure_animation_begin() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    (( _DOTS_FAILURE_ANIMATION_ACTIVE )) && return 0
    [[ -o interactive && -t 0 && -t 1 &&
        "${TERM:-dumb}" != dumb &&
        "${DOTS_FAILURE_ANIMATION:-1}" != 0 ]] || return 0

    _DOTS_FAILURE_ANIMATION_STEP=0
    _DOTS_FAILURE_ANIMATION_FRAMES=0
    _DOTS_FAILURE_ANIMATION_STATE='starting'

    local variant=$(( (RANDOM % 4) + 1 ))
    exec {_DOTS_FAILURE_ANIMATION_FD}< <(_dots_failure_animation_stream "$variant")
    _DOTS_FAILURE_ANIMATION_ACTIVE=1

    # Register from precmd, before ZLE starts reading the next command line.
    if zle -F "$_DOTS_FAILURE_ANIMATION_FD" _dots_failure_animation_fd_handler; then
        _DOTS_FAILURE_ANIMATION_STATE='registered'
    else
        _DOTS_FAILURE_ANIMATION_STATE='registration-failed'
        _dots_failure_animation_cleanup
    fi
}

_dots_failure_animation_precmd() {
    emulate -L zsh

    [[ -o interactive && -t 0 && -t 1 ]] || return 0

    _dots_failure_animation_refresh_prompt

    # The first interactive prompt gets one animation even though no command
    # has failed yet. It is independent of the failure-animation probability.
    if (( _DOTS_FAILURE_ANIMATION_STARTUP_PENDING )); then
        _DOTS_FAILURE_ANIMATION_STARTUP_PENDING=0
        _DOTS_FAILURE_ANIMATION_PENDING=1
    fi

    if (( _DOTS_FAILURE_ANIMATION_PENDING )); then
        _DOTS_FAILURE_ANIMATION_PENDING=0
        _dots_failure_animation_begin
    fi
}

_dots_failure_animation_line_finish() {
    _dots_failure_animation_cleanup
}

if [[ -o interactive ]]; then
    autoload -Uz add-zsh-hook add-zle-hook-widget
    add-zsh-hook precmd _dots_failure_animation_precmd
    add-zle-hook-widget zle-line-finish _dots_failure_animation_line_finish
fi

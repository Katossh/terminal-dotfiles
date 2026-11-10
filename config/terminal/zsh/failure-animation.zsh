# Non-blocking terminal animations for interactive Zsh.
#
# Failure notifications only set _DOTS_FAILURE_ANIMATION_PENDING. This module
# starts the visual effect from ZLE and receives frames through zle -F, so
# ordinary key presses continue to be processed while the animation runs.

typeset -gi _DOTS_FAILURE_ANIMATION_PENDING=${_DOTS_FAILURE_ANIMATION_PENDING:-0}
typeset -gi _DOTS_FAILURE_ANIMATION_FD=-1
typeset -gi _DOTS_FAILURE_ANIMATION_STEP=0
typeset -gi _DOTS_FAILURE_ANIMATION_ACTIVE=0
typeset -g _DOTS_FAILURE_ANIMATION_ORIGINAL_RPROMPT=''
typeset -g _DOTS_FAILURE_ANIMATION_STATE='loaded'
typeset -gi _DOTS_FAILURE_ANIMATION_FRAMES=0
typeset -g _DOTS_FAILURE_ANIMATION_LAST_STATE=''
typeset -gi _DOTS_FAILURE_ANIMATION_LAST_FRAMES=0

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
        command sleep 0.14 2>/dev/null || return 0
    done
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

        RPROMPT="$_DOTS_FAILURE_ANIMATION_ORIGINAL_RPROMPT"
        _DOTS_FAILURE_ANIMATION_FD=-1
        _DOTS_FAILURE_ANIMATION_STEP=0
        _DOTS_FAILURE_ANIMATION_ACTIVE=0
        _DOTS_FAILURE_ANIMATION_ORIGINAL_RPROMPT=''
        _DOTS_FAILURE_ANIMATION_STATE='finished'

        if (( redraw )) && zle; then
            zle .reset-prompt
        fi
    fi
}

_dots_failure_animation_fd_handler() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    local fd="${1:-}"
    local frame
    if [[ -z "$fd" ]] || ! IFS= builtin read -r -u "$fd" frame; then
        _DOTS_FAILURE_ANIMATION_STATE='stream-closed'
        _dots_failure_animation_cleanup 1
        return 0
    fi

    local -a colors=(
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
    if [[ -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]]; then
        (( _DOTS_FAILURE_ANIMATION_STEP += 1 ))
        color="${colors[(( (_DOTS_FAILURE_ANIMATION_STEP - 1) % ${#colors[@]}) + 1)]}"
        reset=$'\e[0m'
    fi

    local right_prompt="$_DOTS_FAILURE_ANIMATION_ORIGINAL_RPROMPT"
    [[ -n "$right_prompt" ]] && right_prompt+=" "
    RPROMPT="${right_prompt}%{${color}%}${frame}%{${reset}%}"
    (( _DOTS_FAILURE_ANIMATION_FRAMES += 1 ))
    _DOTS_FAILURE_ANIMATION_STATE='frame-rendered'

    # This is a regular zle -F callback, not a widget handler. Resetting the
    # prompt uses the standard shell-level ZLE widget invocation.
    zle && zle .reset-prompt
}

_dots_failure_animation_start() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    (( _DOTS_FAILURE_ANIMATION_ACTIVE )) && return 0
    [[ -o interactive && -t 0 && -t 1 &&
        "${TERM:-dumb}" != dumb &&
        "${DOTS_FAILURE_ANIMATION:-1}" != 0 ]] || return 0

    _dots_failure_animation_cleanup
    _DOTS_FAILURE_ANIMATION_PENDING=1
    _DOTS_FAILURE_ANIMATION_ORIGINAL_RPROMPT="${RPROMPT-}"
    _DOTS_FAILURE_ANIMATION_STEP=0
    _DOTS_FAILURE_ANIMATION_FRAMES=0
    _DOTS_FAILURE_ANIMATION_STATE='starting'

    local variant=$(( (RANDOM % 4) + 1 ))
    exec {_DOTS_FAILURE_ANIMATION_FD}< <(_dots_failure_animation_stream "$variant")
    _DOTS_FAILURE_ANIMATION_ACTIVE=1

    # Register from precmd, before ZLE starts reading the next command line.
    # This follows the same lifecycle used by established asynchronous Zsh prompts.
    if zle -F "$_DOTS_FAILURE_ANIMATION_FD" _dots_failure_animation_fd_handler; then
        _DOTS_FAILURE_ANIMATION_STATE='registered'
    else
        _DOTS_FAILURE_ANIMATION_STATE='registration-failed'
        _dots_failure_animation_cleanup
    fi
}

_dots_failure_animation_line_finish() {
    _dots_failure_animation_cleanup
}

if [[ -o interactive ]]; then
    autoload -Uz add-zle-hook-widget
    add-zle-hook-widget zle-line-finish _dots_failure_animation_line_finish
fi

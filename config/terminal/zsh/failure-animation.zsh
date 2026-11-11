# Non-blocking terminal animations for interactive Zsh.
#
# Starship's PROMPT is a command substitution, not the rendered prompt text.
# Preserve that command and wrap its output, inserting the motif before its
# first real newline (the line_break module). Frames are delivered to ZLE
# asynchronously, and the final frame remains visible until the next animation.

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
typeset -g _DOTS_FAILURE_ANIMATION_ORIGINAL_PROMPT="${PROMPT-}"
typeset -g _DOTS_FAILURE_ANIMATION_PROMPT_MODE='static'
typeset -g _DOTS_FAILURE_ANIMATION_LAST_RENDERED_PROMPT=''
typeset -g _DOTS_FAILURE_ANIMATION_INTERVAL='0.14'

if [[ "$_DOTS_FAILURE_ANIMATION_ORIGINAL_PROMPT" == *'$('* ]]; then
    _DOTS_FAILURE_ANIMATION_PROMPT_MODE='command'
fi

# Starship enables promptsubst itself; keep it enabled when wrapping a static
# fallback prompt as well.
setopt promptsubst
PROMPT='$(_dots_failure_animation_render_prompt)'

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

_dots_failure_animation_render_prompt() {
    emulate -L zsh

    local rendered=''
    if [[ "$_DOTS_FAILURE_ANIMATION_PROMPT_MODE" == command ]]; then
        # This is the exact command-substitution string installed by Starship.
        # It is generated from our local shell configuration, not user input.
        rendered="$(eval "$_DOTS_FAILURE_ANIMATION_ORIGINAL_PROMPT")"
    else
        rendered="$_DOTS_FAILURE_ANIMATION_ORIGINAL_PROMPT"
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
        reset=$'\e[0m'
    fi

    local motif="%B%{${color}%}✧━━  ✦ ${_DOTS_FAILURE_ANIMATION_FRAME} ✦  ━━✧%{${reset}%}%b"
    local first_line="$rendered"
    local remaining=''
    if [[ "$rendered" == *$'\n'* ]]; then
        first_line="${rendered%%$'\n'*}"
        remaining="${rendered#*$'\n'}"
        rendered="${first_line}  ${motif}"$'\n'"${remaining}"
    else
        rendered="${first_line}  ${motif}"
    fi

    _DOTS_FAILURE_ANIMATION_LAST_RENDERED_PROMPT="$rendered"
    print -rn -- "$rendered"
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

    # Do not reset the frame or colour index. The prompt wrapper renders the
    # same final state until another animation begins.
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

    # Redraw expands PROMPT, whose wrapper re-renders Starship and inserts the
    # current frame at the correct location.
    zle && zle .reset-prompt
}

# Failure-message hooks queue work here. The actual process starts from the
# last precmd hook, before ZLE begins reading the next line.
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

    # One animation on the first interactive prompt of every Zsh session,
    # regardless of whether a command has failed.
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

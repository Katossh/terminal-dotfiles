# Non-blocking, emoji-only prompt animation for interactive Zsh.
#
# Starship's PROMPT is a command substitution, not the rendered prompt text.
# Preserve that command and wrap its output, appending one animated emoji to
# its first line. Frames are delivered to ZLE asynchronously.
# DOTS_FAILURE_ANIMATION_CONTINUOUS=1 loops while the prompt is idle.

typeset -gi _DOTS_FAILURE_ANIMATION_PENDING=${_DOTS_FAILURE_ANIMATION_PENDING:-0}
typeset -gi _DOTS_FAILURE_ANIMATION_FD=-1
typeset -gi _DOTS_FAILURE_ANIMATION_STEP=0
typeset -gi _DOTS_FAILURE_ANIMATION_ACTIVE=0
typeset -gi _DOTS_FAILURE_ANIMATION_STARTUP_PENDING=1
typeset -gi _DOTS_FAILURE_ANIMATION_FRAMES=0
typeset -gi _DOTS_FAILURE_ANIMATION_LAST_FRAMES=0
typeset -g _DOTS_FAILURE_ANIMATION_STATE='loaded'
typeset -g _DOTS_FAILURE_ANIMATION_LAST_STATE=''
typeset -g _DOTS_FAILURE_ANIMATION_FRAME='🦊'
typeset -g _DOTS_FAILURE_ANIMATION_ORIGINAL_PROMPT="${PROMPT-}"
typeset -g _DOTS_FAILURE_ANIMATION_PROMPT_MODE='static'
typeset -g _DOTS_FAILURE_ANIMATION_LAST_RENDERED_PROMPT=''
typeset -g _DOTS_FAILURE_ANIMATION_INTERVAL='0.14'

if [[ "$_DOTS_FAILURE_ANIMATION_ORIGINAL_PROMPT" == '$('*')' ]]; then
    _DOTS_FAILURE_ANIMATION_PROMPT_MODE='command'
fi

# Starship enables promptsubst itself; keep it enabled for a static fallback.
setopt promptsubst
PROMPT='$(_dots_failure_animation_render_prompt)'

_dots_failure_animation_continuous_enabled() {
    emulate -L zsh

    local setting="${DOTS_FAILURE_ANIMATION_CONTINUOUS:-0}"
    setting="${setting:l}"
    case "$setting" in
        1|true|yes|on) return 0 ;;
        *) return 1 ;;
    esac
}

_dots_failure_animation_stream() {
    emulate -L zsh

    local variant="${1:-1}"
    local continuous="${2:-0}"
    local frame
    local -a frames

    # Each variant is a 24-frame emoji sequence. The animation contains no
    # decorative text glyphs, borders, stars, or side bars.
    case "$variant" in
        2)
            frames=(
                '🌱' '🌿' '🍀' '🌵' '🌴' '🌳' '🌲' '🌷'
                '🌹' '🌺' '🌻' '🌼' '🪷' '🪻' '🍄' '🪴'
                '🌾' '🍁' '🍂' '🍃' '🌊' '💧' '🌧️' '☀️'
            )
            ;;
        3)
            frames=(
                '🍓' '🍒' '🍑' '🍉' '🍋' '🍊' '🍍' '🥭'
                '🍇' '🫐' '🍈' '🍏' '🍎' '🍐' '🍌' '🥝'
                '🥑' '🍅' '🥕' '🌽' '🥨' '🧀' '🍰' '🍩'
            )
            ;;
        4)
            frames=(
                '🌙' '🌍' '🌎' '🌏' '🪐' '☄️' '🚀' '🛰️'
                '🛸' '👽' '🤖' '🧬' '🔭' '🧪' '⚗️' '🧫'
                '🦠' '⚛️' '🔬' '🧠' '🪄' '🔮' '💎' '🧿'
            )
            ;;
        5)
            frames=(
                '💻' '🖥️' '⌨️' '🖱️' '📱' '📟' '📡' '🔋'
                '🔌' '💡' '🔦' '🕹️' '🎮' '🧩' '🎧' '🎹'
                '🎸' '📷' '📹' '🛠️' '⚙️' '🧰' '🪛' '🧲'
            )
            ;;
        6)
            frames=(
                '🔥' '💧' '🌊' '⚡' '🌪️' '🌈' '🌫️' '🌬️'
                '🌋' '🪨' '🪵' '🧊' '❄️' '☃️' '🌡️' '🌤️'
                '⛈️' '🌦️' '☔' '🌀' '🪸' '🐚' '🪺' '🪹'
            )
            ;;
        *)
            frames=(
                '🦊' '🐈' '🐈‍⬛' '🐕' '🐺' '🦝' '🐼' '🐻'
                '🐨' '🐯' '🦁' '🐸' '🐵' '🐧' '🦉' '🦋'
                '🐬' '🐳' '🐙' '🦀' '🐢' '🦎' '🐍' '🦖'
            )
            ;;
    esac

    while true; do
        for frame in "${frames[@]}"; do
            print -r -- "$frame" || return 0
            command sleep "$_DOTS_FAILURE_ANIMATION_INTERVAL" 2>/dev/null || return 0
        done

        [[ "$continuous" == 1 ]] || break
    done
}

_dots_failure_animation_render_prompt() {
    emulate -L zsh

    local rendered=''
    if [[ "$_DOTS_FAILURE_ANIMATION_PROMPT_MODE" == command ]]; then
        # Execute Starship's original command, not its rendered output.
        local prompt_command="${_DOTS_FAILURE_ANIMATION_ORIGINAL_PROMPT[3,-2]}"
        rendered="$(eval "$prompt_command")"
    else
        rendered="$_DOTS_FAILURE_ANIMATION_ORIGINAL_PROMPT"
    fi

    # The emoji is the only addition to the existing prompt.
    local first_line="$rendered"
    local remaining=''
    if [[ "$rendered" == *$'\n'* ]]; then
        first_line="${rendered%%$'\n'*}"
        remaining="${rendered#*$'\n'}"
        rendered="${first_line}  ${_DOTS_FAILURE_ANIMATION_FRAME}"$'\n'"${remaining}"
    else
        rendered="${first_line}  ${_DOTS_FAILURE_ANIMATION_FRAME}"
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

    # Keep the last emoji visible after the stream stops.
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

    # Redraw expands PROMPT and renders the latest emoji.
    zle && zle .reset-prompt
}

# Failure-message hooks queue work here; the stream starts from precmd.
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

    local variant=$(( (RANDOM % 6) + 1 ))
    local continuous=0
    _dots_failure_animation_continuous_enabled && continuous=1

    exec {_DOTS_FAILURE_ANIMATION_FD}< <(_dots_failure_animation_stream "$variant" "$continuous")
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

    if _dots_failure_animation_continuous_enabled; then
        # Restart at every new prompt. zle-line-finish stops the old stream
        # before the command runs, so it never animates during command execution.
        _DOTS_FAILURE_ANIMATION_STARTUP_PENDING=0
        _DOTS_FAILURE_ANIMATION_PENDING=1
    elif (( _DOTS_FAILURE_ANIMATION_STARTUP_PENDING ));
        # Preserve the one-shot startup animation when continuous mode is off.
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

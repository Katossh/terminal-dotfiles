# Non-blocking, style-aware emoji animation immediately before the Zsh prompt character.
#
# Starship's PROMPT is a command substitution, not the rendered prompt text.
# Preserve its output and insert the current frame before the final prompt
# marker (❯ by default), leaving the path line and RPROMPT untouched.
# Frames are delivered to ZLE asynchronously.
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
typeset -g _DOTS_FAILURE_ANIMATION_FRAME='💀'
typeset -g _DOTS_FAILURE_ANIMATION_STYLE='normal'
typeset -ga _DOTS_FAILURE_ANIMATION_POOL=()
typeset -g _DOTS_FAILURE_ANIMATION_ORIGINAL_PROMPT="${PROMPT-}"
typeset -g _DOTS_FAILURE_ANIMATION_PROMPT_MODE='static'
typeset -g _DOTS_FAILURE_ANIMATION_LAST_RENDERED_PROMPT=''
typeset -g _DOTS_FAILURE_ANIMATION_INTERVAL='0.06'
typeset -g _DOTS_FAILURE_ANIMATION_BANNER=''
typeset -g _DOTS_FAILURE_ANIMATION_GRADIENT_STYLE=''
typeset -gi _DOTS_FAILURE_ANIMATION_GRADIENT_OFFSET=0

if [[ "$_DOTS_FAILURE_ANIMATION_ORIGINAL_PROMPT" == '$('*')' ]]; then
    _DOTS_FAILURE_ANIMATION_PROMPT_MODE='command'
fi

# Starship enables promptsubst itself; keep it enabled for a static fallback.
setopt promptsubst
PROMPT='$(_dots_failure_animation_render_prompt)'

_dots_failure_animation_continuous_enabled() {
    emulate -L zsh

    local setting="${DOTS_FAILURE_EMOJI_ANIMATION_INFINITE:-${DOTS_FAILURE_ANIMATION_CONTINUOUS:-0}}"
    setting="${setting:l}"
    case "$setting" in
        1|true|yes|on) return 0 ;;
        *) return 1 ;;
    esac
}

# The ordinary styles deliberately share one pool. Anime, Ecchi and Rainbow
# each have a distinct pool so the animation matches the selected message voice.
_dots_failure_animation_pool_for_style() {
    emulate -L zsh

    local style="${1:-normal}"
    case "$style" in
        legendary|mythic)
            _DOTS_FAILURE_ANIMATION_POOL=()
            ;;
        anime)
            _DOTS_FAILURE_ANIMATION_POOL=(
                '😭' '🥰' '🥺' '💖' '💗' '💓' '💕'
            )
            ;;
        ecchi)
            _DOTS_FAILURE_ANIMATION_POOL=(
                '😏' '❤️' '🩷' '💘'
            )
            ;;
        rainbow)
            _DOTS_FAILURE_ANIMATION_POOL=(
                '🧡' '💛' '💚' '💙' '🤍'
            )
            ;;
        normal|sarcastic|dramatic|*)
            _DOTS_FAILURE_ANIMATION_POOL=(
                '👀' '😳' '🫠' '✨'
                '💀' '😂' '🤡' '🪿'
                '🔥' '💔' '🖤' '🤎' '💜'
            )
            ;;
    esac
}

_dots_failure_animation_stream() {
    emulate -L zsh

    local style="${1:-normal}"
    local continuous="${2:-0}"
    local frame
    local -i pool_size=0
    local -i previous_index=0
    local -i frame_number=0
    local -i index=0

    if [[ "$style" == legendary || "$style" == mythic ]]; then
        while true; do
            print -r -- "G:$frame_number" || return 0
            (( frame_number = (frame_number + 1) % 12 ))
            command sleep "$_DOTS_FAILURE_ANIMATION_INTERVAL" 2>/dev/null || return 0
        done
    fi

    _dots_failure_animation_pool_for_style "$style"
    pool_size="${#_DOTS_FAILURE_ANIMATION_POOL}"
    (( pool_size > 0 )) || return 0

    # Keep the familiar 24-frame duration, but sample randomly from the
    # selected style's pool and avoid identical adjacent frames.
    while true; do
        previous_index=0
        for (( frame_number = 0; frame_number < 24; frame_number++ )); do
            index=$(( (RANDOM % pool_size) + 1 ))
            if (( pool_size > 1 && index == previous_index )); then
                index=$(( (index % pool_size) + 1 ))
            fi

            frame="${_DOTS_FAILURE_ANIMATION_POOL[index]}"
            print -r -- "$frame" || return 0
            command sleep "$_DOTS_FAILURE_ANIMATION_INTERVAL" 2>/dev/null || return 0
            previous_index="$index"
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
        rendered="${_DOTS_FAILURE_ANIMATION_ORIGINAL_PROMPT}"
    fi

    # Insert only before the final input marker. This avoids decorating the
    # directory/path line and keeps prompts without the marker unchanged.
    local marker="${DOTS_FAILURE_ANIMATION_PROMPT_MARKER:-❯}"
    if [[ -n "$marker" && "$rendered" == *"$marker"* ]]; then
        local suffix="${rendered##*${(b)marker}}"
        local marker_and_suffix="${marker}${suffix}"
        local prefix="${rendered%${(b)marker_and_suffix}}"
        rendered="${prefix}${_DOTS_FAILURE_ANIMATION_FRAME} ${marker_and_suffix}"
    fi

    if [[ -n "$_DOTS_FAILURE_ANIMATION_BANNER" ]]; then
        local banner="${_DOTS_FAILURE_ANIMATION_BANNER//\%/%%}"
        local -a banner_colors banner_chars
        local color character
        local reset= [[ "$_DOTS_FAILURE_ANIMATION_GRADIENT_STYLE" == mythic ]]; then
            banner_colors=(
                $'\e[38;2;245;245;247m' $'\e[38;2;205;207;212m'
                $'\e[38;2;157;160;168m' $'\e[38;2;105;109;119m'
                $'\e[38;2;55;58;67m' $'\e[38;2;18;19;24m'
            )
        else
            banner_colors=(
                $'\e[38;2;255;91;132m' $'\e[38;2;255;169;91m'
                $'\e[38;2;255;224;112m' $'\e[38;2;117;220;160m'
                $'\e[38;2;90;193;255m' $'\e[38;2;161;130;255m'
                $'\e[38;2;255;130;215m'
            )
        fi
        banner_chars=( "${(@s::)banner}" )
        banner_size=${#banner_colors[@]}
        local gradient_banner=''
        for character in "${banner_chars[@]}"; do
            color_index=$(( (_DOTS_FAILURE_ANIMATION_GRADIENT_OFFSET + character_index) % banner_size + 1 ))
            color="${banner_colors[color_index]}"
            gradient_banner+="%{${color}%}${character}%{${reset}%}"
            (( character_index += 1 ))
        done
        rendered="${gradient_banner}"$'\n'"${rendered}"
    fi

    _DOTS_FAILURE_ANIMATION_LAST_RENDERED_PROMPT="$rendered"
    print -rn -- "$rendered"
}

_dots_failure_animation_cleanup() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    local redraw="${1:-0}"
    if (( _DOTS_FAILURE_ANIMATION_ACTIVE )); then
        _DOTS_FAILURE_ANIMATION_LAST_STATE="${_DOTS_FAILURE_ANIMATION_STATE}"
        _DOTS_FAILURE_ANIMATION_LAST_FRAMES=${_DOTS_FAILURE_ANIMATION_FRAMES}

        local fd="${_DOTS_FAILURE_ANIMATION_FD}"
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
    if [[ "$frame" == G:<-> ]]; then
        _DOTS_FAILURE_ANIMATION_GRADIENT_OFFSET="${frame#G:}"
    else
        _DOTS_FAILURE_ANIMATION_FRAME="$frame"
    fi
    (( _DOTS_FAILURE_ANIMATION_FRAMES += 1 ))
    _DOTS_FAILURE_ANIMATION_STATE='frame-rendered'

    # Redraw expands PROMPT and renders the latest emoji before the prompt marker.
    zle && zle .reset-prompt
}

# Failure-message hooks queue work here. The selected style follows the message.
_dots_failure_animation_start() {
    emulate -L zsh

    [[ -o interactive && -t 0 && -t 1 &&
        "${TERM:-dumb}" != dumb &&
        "${DOTS_FAILURE_ANIMATION:-1}" != 0 ]] || return 0

    local style="${1:-normal}"
    case "$style" in
        anime|ecchi|rainbow|normal|sarcastic|dramatic|legendary|mythic) ;;
        *) style=normal ;;
    esac

    _DOTS_FAILURE_ANIMATION_STYLE="$style"
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

    local style="${_DOTS_FAILURE_ANIMATION_STYLE:-normal}"
    local continuous=0
    _dots_failure_animation_continuous_enabled && continuous=1

    exec {_DOTS_FAILURE_ANIMATION_FD}< <(_dots_failure_animation_stream "$style" "$continuous")
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
        # when a command is submitted, so it never animates during execution.
        _DOTS_FAILURE_ANIMATION_STARTUP_PENDING=0
        _DOTS_FAILURE_ANIMATION_PENDING=1
    elif (( _DOTS_FAILURE_ANIMATION_STARTUP_PENDING )); then
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
    _DOTS_FAILURE_ANIMATION_BANNER=''
    _DOTS_FAILURE_ANIMATION_GRADIENT_STYLE=''
    _dots_failure_animation_cleanup
}

if [[ -o interactive ]]; then
    autoload -Uz add-zsh-hook add-zle-hook-widget
    add-zsh-hook precmd _dots_failure_animation_precmd
    add-zle-hook-widget zle-line-finish _dots_failure_animation_line_finish
fi
\\e[0m'
        local -i color_index=0 character_index=0 banner_size=0
        if [[ "$_DOTS_FAILURE_ANIMATION_GRADIENT_STYLE" == mythic ]]; then
            banner_colors=(
                $'\e[38;2;245;245;247m' $'\e[38;2;205;207;212m'
                $'\e[38;2;157;160;168m' $'\e[38;2;105;109;119m'
                $'\e[38;2;55;58;67m' $'\e[38;2;18;19;24m'
            )
        else
            banner_colors=(
                $'\e[38;2;255;91;132m' $'\e[38;2;255;169;91m'
                $'\e[38;2;255;224;112m' $'\e[38;2;117;220;160m'
                $'\e[38;2;90;193;255m' $'\e[38;2;161;130;255m'
                $'\e[38;2;255;130;215m'
            )
        fi
        banner_chars=( "${(@s::)banner}" )
        banner_size=${#banner_colors[@]}
        local gradient_banner=''
        for character in "${banner_chars[@]}"; do
            color_index=$(( (_DOTS_FAILURE_ANIMATION_GRADIENT_OFFSET + color_index) % banner_size + 1 ))
            color="${banner_colors[color_index]}"
            gradient_banner+="%{${color}%}${character}%{$'\e[0m'%}"
        done
        rendered="${gradient_banner}"$'\n'"${rendered}"
    fi

    _DOTS_FAILURE_ANIMATION_LAST_RENDERED_PROMPT="$rendered"
    print -rn -- "$rendered"
}

_dots_failure_animation_cleanup() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    local redraw="${1:-0}"
    if (( _DOTS_FAILURE_ANIMATION_ACTIVE )); then
        _DOTS_FAILURE_ANIMATION_LAST_STATE="${_DOTS_FAILURE_ANIMATION_STATE}"
        _DOTS_FAILURE_ANIMATION_LAST_FRAMES=${_DOTS_FAILURE_ANIMATION_FRAMES}

        local fd="${_DOTS_FAILURE_ANIMATION_FD}"
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
    if [[ "$frame" == G:<-> ]]; then
        _DOTS_FAILURE_ANIMATION_GRADIENT_OFFSET="${frame#G:}"
    else
        _DOTS_FAILURE_ANIMATION_FRAME="$frame"
    fi
    (( _DOTS_FAILURE_ANIMATION_FRAMES += 1 ))
    _DOTS_FAILURE_ANIMATION_STATE='frame-rendered'

    # Redraw expands PROMPT and renders the latest emoji before the prompt marker.
    zle && zle .reset-prompt
}

# Failure-message hooks queue work here. The selected style follows the message.
_dots_failure_animation_start() {
    emulate -L zsh

    [[ -o interactive && -t 0 && -t 1 &&
        "${TERM:-dumb}" != dumb &&
        "${DOTS_FAILURE_ANIMATION:-1}" != 0 ]] || return 0

    local style="${1:-normal}"
    case "$style" in
        anime|ecchi|rainbow|normal|sarcastic|dramatic|legendary|mythic) ;;
        *) style=normal ;;
    esac

    _DOTS_FAILURE_ANIMATION_STYLE="$style"
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

    local style="${_DOTS_FAILURE_ANIMATION_STYLE:-normal}"
    local continuous=0
    _dots_failure_animation_continuous_enabled && continuous=1

    exec {_DOTS_FAILURE_ANIMATION_FD}< <(_dots_failure_animation_stream "$style" "$continuous")
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
        # when a command is submitted, so it never animates during execution.
        _DOTS_FAILURE_ANIMATION_STARTUP_PENDING=0
        _DOTS_FAILURE_ANIMATION_PENDING=1
    elif (( _DOTS_FAILURE_ANIMATION_STARTUP_PENDING )); then
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
    _DOTS_FAILURE_ANIMATION_BANNER=''
    _DOTS_FAILURE_ANIMATION_GRADIENT_STYLE=''
    _dots_failure_animation_cleanup
}

if [[ -o interactive ]]; then
    autoload -Uz add-zsh-hook add-zle-hook-widget
    add-zsh-hook precmd _dots_failure_animation_precmd
    add-zle-hook-widget zle-line-finish _dots_failure_animation_line_finish
fi
\\e[0m'
        local -i color_index=0 character_index=0 banner_size=0
        if [[ "$_DOTS_FAILURE_ANIMATION_GRADIENT_STYLE" == mythic ]]; then
            banner_colors=(
                $'\e[38;2;245;245;247m' $'\e[38;2;205;207;212m'
                $'\e[38;2;157;160;168m' $'\e[38;2;105;109;119m'
                $'\e[38;2;55;58;67m' $'\e[38;2;18;19;24m'
            )
        else
            banner_colors=(
                $'\e[38;2;255;91;132m' $'\e[38;2;255;169;91m'
                $'\e[38;2;255;224;112m' $'\e[38;2;117;220;160m'
                $'\e[38;2;90;193;255m' $'\e[38;2;161;130;255m'
                $'\e[38;2;255;130;215m'
            )
        fi
        banner_chars=( "${(@s::)banner}" )
        banner_size=${#banner_colors[@]}
        local gradient_banner=''
        for character in "${banner_chars[@]}"; do
            color_index=$(( (_DOTS_FAILURE_ANIMATION_GRADIENT_OFFSET + character_index) % banner_size + 1 ))
            color="${banner_colors[color_index]}"
            gradient_banner+="%{${color}%}${character}%{$'\e[0m'%}"
        done
        rendered="${gradient_banner}"$'\n'"${rendered}"
    fi

    _DOTS_FAILURE_ANIMATION_LAST_RENDERED_PROMPT="$rendered"
    print -rn -- "$rendered"
}

_dots_failure_animation_cleanup() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    local redraw="${1:-0}"
    if (( _DOTS_FAILURE_ANIMATION_ACTIVE )); then
        _DOTS_FAILURE_ANIMATION_LAST_STATE="${_DOTS_FAILURE_ANIMATION_STATE}"
        _DOTS_FAILURE_ANIMATION_LAST_FRAMES=${_DOTS_FAILURE_ANIMATION_FRAMES}

        local fd="${_DOTS_FAILURE_ANIMATION_FD}"
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
    if [[ "$frame" == G:<-> ]]; then
        _DOTS_FAILURE_ANIMATION_GRADIENT_OFFSET="${frame#G:}"
    else
        _DOTS_FAILURE_ANIMATION_FRAME="$frame"
    fi
    (( _DOTS_FAILURE_ANIMATION_FRAMES += 1 ))
    _DOTS_FAILURE_ANIMATION_STATE='frame-rendered'

    # Redraw expands PROMPT and renders the latest emoji before the prompt marker.
    zle && zle .reset-prompt
}

# Failure-message hooks queue work here. The selected style follows the message.
_dots_failure_animation_start() {
    emulate -L zsh

    [[ -o interactive && -t 0 && -t 1 &&
        "${TERM:-dumb}" != dumb &&
        "${DOTS_FAILURE_ANIMATION:-1}" != 0 ]] || return 0

    local style="${1:-normal}"
    case "$style" in
        anime|ecchi|rainbow|normal|sarcastic|dramatic|legendary|mythic) ;;
        *) style=normal ;;
    esac

    _DOTS_FAILURE_ANIMATION_STYLE="$style"
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

    local style="${_DOTS_FAILURE_ANIMATION_STYLE:-normal}"
    local continuous=0
    _dots_failure_animation_continuous_enabled && continuous=1

    exec {_DOTS_FAILURE_ANIMATION_FD}< <(_dots_failure_animation_stream "$style" "$continuous")
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
        # when a command is submitted, so it never animates during execution.
        _DOTS_FAILURE_ANIMATION_STARTUP_PENDING=0
        _DOTS_FAILURE_ANIMATION_PENDING=1
    elif (( _DOTS_FAILURE_ANIMATION_STARTUP_PENDING )); then
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
    _DOTS_FAILURE_ANIMATION_BANNER=''
    _DOTS_FAILURE_ANIMATION_GRADIENT_STYLE=''
    _dots_failure_animation_cleanup
}

if [[ -o interactive ]]; then
    autoload -Uz add-zsh-hook add-zle-hook-widget
    add-zsh-hook precmd _dots_failure_animation_precmd
    add-zle-hook-widget zle-line-finish _dots_failure_animation_line_finish
fi
\\e[0m'
        local -i color_index=0 character_index=0 banner_size=0
        if [[ "$_DOTS_FAILURE_ANIMATION_GRADIENT_STYLE" == mythic ]]; then
            banner_colors=(
                $'\e[38;2;245;245;247m' $'\e[38;2;205;207;212m'
                $'\e[38;2;157;160;168m' $'\e[38;2;105;109;119m'
                $'\e[38;2;55;58;67m' $'\e[38;2;18;19;24m'
            )
        else
            banner_colors=(
                $'\e[38;2;255;91;132m' $'\e[38;2;255;169;91m'
                $'\e[38;2;255;224;112m' $'\e[38;2;117;220;160m'
                $'\e[38;2;90;193;255m' $'\e[38;2;161;130;255m'
                $'\e[38;2;255;130;215m'
            )
        fi
        banner_chars=( "${(@s::)banner}" )
        banner_size=${#banner_colors[@]}
        local gradient_banner=''
        for character in "${banner_chars[@]}"; do
            color_index=$(( (_DOTS_FAILURE_ANIMATION_GRADIENT_OFFSET + color_index) % banner_size + 1 ))
            color="${banner_colors[color_index]}"
            gradient_banner+="%{${color}%}${character}%{$'\e[0m'%}"
        done
        rendered="${gradient_banner}"$'\n'"${rendered}"
    fi

    _DOTS_FAILURE_ANIMATION_LAST_RENDERED_PROMPT="$rendered"
    print -rn -- "$rendered"
}

_dots_failure_animation_cleanup() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    local redraw="${1:-0}"
    if (( _DOTS_FAILURE_ANIMATION_ACTIVE )); then
        _DOTS_FAILURE_ANIMATION_LAST_STATE="${_DOTS_FAILURE_ANIMATION_STATE}"
        _DOTS_FAILURE_ANIMATION_LAST_FRAMES=${_DOTS_FAILURE_ANIMATION_FRAMES}

        local fd="${_DOTS_FAILURE_ANIMATION_FD}"
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
    if [[ "$frame" == G:<-> ]]; then
        _DOTS_FAILURE_ANIMATION_GRADIENT_OFFSET="${frame#G:}"
    else
        _DOTS_FAILURE_ANIMATION_FRAME="$frame"
    fi
    (( _DOTS_FAILURE_ANIMATION_FRAMES += 1 ))
    _DOTS_FAILURE_ANIMATION_STATE='frame-rendered'

    # Redraw expands PROMPT and renders the latest emoji before the prompt marker.
    zle && zle .reset-prompt
}

# Failure-message hooks queue work here. The selected style follows the message.
_dots_failure_animation_start() {
    emulate -L zsh

    [[ -o interactive && -t 0 && -t 1 &&
        "${TERM:-dumb}" != dumb &&
        "${DOTS_FAILURE_ANIMATION:-1}" != 0 ]] || return 0

    local style="${1:-normal}"
    case "$style" in
        anime|ecchi|rainbow|normal|sarcastic|dramatic|legendary|mythic) ;;
        *) style=normal ;;
    esac

    _DOTS_FAILURE_ANIMATION_STYLE="$style"
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

    local style="${_DOTS_FAILURE_ANIMATION_STYLE:-normal}"
    local continuous=0
    _dots_failure_animation_continuous_enabled && continuous=1

    exec {_DOTS_FAILURE_ANIMATION_FD}< <(_dots_failure_animation_stream "$style" "$continuous")
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
        # when a command is submitted, so it never animates during execution.
        _DOTS_FAILURE_ANIMATION_STARTUP_PENDING=0
        _DOTS_FAILURE_ANIMATION_PENDING=1
    elif (( _DOTS_FAILURE_ANIMATION_STARTUP_PENDING )); then
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
    _DOTS_FAILURE_ANIMATION_BANNER=''
    _DOTS_FAILURE_ANIMATION_GRADIENT_STYLE=''
    _dots_failure_animation_cleanup
}

if [[ -o interactive ]]; then
    autoload -Uz add-zsh-hook add-zle-hook-widget
    add-zsh-hook precmd _dots_failure_animation_precmd
    add-zle-hook-widget zle-line-finish _dots_failure_animation_line_finish
fi
\e[0m'
        local -i color_index=0 character_index=0 banner_size=0
        if [[ "$_DOTS_FAILURE_ANIMATION_GRADIENT_STYLE" == mythic ]]; then
            banner_colors=(
                $'\e[38;2;245;245;247m' $'\e[38;2;205;207;212m'
                $'\e[38;2;157;160;168m' $'\e[38;2;105;109;119m'
                $'\e[38;2;55;58;67m' $'\e[38;2;18;19;24m'
            )
        else
            banner_colors=(
                $'\e[38;2;255;91;132m' $'\e[38;2;255;169;91m'
                $'\e[38;2;255;224;112m' $'\e[38;2;117;220;160m'
                $'\e[38;2;90;193;255m' $'\e[38;2;161;130;255m'
                $'\e[38;2;255;130;215m'
            )
        fi
        banner_chars=( "${(@s::)banner}" )
        banner_size=${#banner_colors[@]}
        local gradient_banner=''
        for character in "${banner_chars[@]}"; do
            color_index=$(( (_DOTS_FAILURE_ANIMATION_GRADIENT_OFFSET + character_index) % banner_size + 1 ))
            color="${banner_colors[color_index]}"
            gradient_banner+="%{${color}%}${character}%{$'\e[0m'%}"
        done
        rendered="${gradient_banner}"$'\n'"${rendered}"
    fi

    _DOTS_FAILURE_ANIMATION_LAST_RENDERED_PROMPT="$rendered"
    print -rn -- "$rendered"
}

_dots_failure_animation_cleanup() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    local redraw="${1:-0}"
    if (( _DOTS_FAILURE_ANIMATION_ACTIVE )); then
        _DOTS_FAILURE_ANIMATION_LAST_STATE="${_DOTS_FAILURE_ANIMATION_STATE}"
        _DOTS_FAILURE_ANIMATION_LAST_FRAMES=${_DOTS_FAILURE_ANIMATION_FRAMES}

        local fd="${_DOTS_FAILURE_ANIMATION_FD}"
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
    if [[ "$frame" == G:<-> ]]; then
        _DOTS_FAILURE_ANIMATION_GRADIENT_OFFSET="${frame#G:}"
    else
        _DOTS_FAILURE_ANIMATION_FRAME="$frame"
    fi
    (( _DOTS_FAILURE_ANIMATION_FRAMES += 1 ))
    _DOTS_FAILURE_ANIMATION_STATE='frame-rendered'

    # Redraw expands PROMPT and renders the latest emoji before the prompt marker.
    zle && zle .reset-prompt
}

# Failure-message hooks queue work here. The selected style follows the message.
_dots_failure_animation_start() {
    emulate -L zsh

    [[ -o interactive && -t 0 && -t 1 &&
        "${TERM:-dumb}" != dumb &&
        "${DOTS_FAILURE_ANIMATION:-1}" != 0 ]] || return 0

    local style="${1:-normal}"
    case "$style" in
        anime|ecchi|rainbow|normal|sarcastic|dramatic|legendary|mythic) ;;
        *) style=normal ;;
    esac

    _DOTS_FAILURE_ANIMATION_STYLE="$style"
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

    local style="${_DOTS_FAILURE_ANIMATION_STYLE:-normal}"
    local continuous=0
    _dots_failure_animation_continuous_enabled && continuous=1

    exec {_DOTS_FAILURE_ANIMATION_FD}< <(_dots_failure_animation_stream "$style" "$continuous")
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
        # when a command is submitted, so it never animates during execution.
        _DOTS_FAILURE_ANIMATION_STARTUP_PENDING=0
        _DOTS_FAILURE_ANIMATION_PENDING=1
    elif (( _DOTS_FAILURE_ANIMATION_STARTUP_PENDING )); then
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
    _DOTS_FAILURE_ANIMATION_BANNER=''
    _DOTS_FAILURE_ANIMATION_GRADIENT_STYLE=''
    _dots_failure_animation_cleanup
}

if [[ -o interactive ]]; then
    autoload -Uz add-zsh-hook add-zle-hook-widget
    add-zsh-hook precmd _dots_failure_animation_precmd
    add-zle-hook-widget zle-line-finish _dots_failure_animation_line_finish
fi
\\e[0m'
        local -i color_index=0 character_index=0 banner_size=0
        if [[ "$_DOTS_FAILURE_ANIMATION_GRADIENT_STYLE" == mythic ]]; then
            banner_colors=(
                $'\e[38;2;245;245;247m' $'\e[38;2;205;207;212m'
                $'\e[38;2;157;160;168m' $'\e[38;2;105;109;119m'
                $'\e[38;2;55;58;67m' $'\e[38;2;18;19;24m'
            )
        else
            banner_colors=(
                $'\e[38;2;255;91;132m' $'\e[38;2;255;169;91m'
                $'\e[38;2;255;224;112m' $'\e[38;2;117;220;160m'
                $'\e[38;2;90;193;255m' $'\e[38;2;161;130;255m'
                $'\e[38;2;255;130;215m'
            )
        fi
        banner_chars=( "${(@s::)banner}" )
        banner_size=${#banner_colors[@]}
        local gradient_banner=''
        for character in "${banner_chars[@]}"; do
            color_index=$(( (_DOTS_FAILURE_ANIMATION_GRADIENT_OFFSET + color_index) % banner_size + 1 ))
            color="${banner_colors[color_index]}"
            gradient_banner+="%{${color}%}${character}%{$'\e[0m'%}"
        done
        rendered="${gradient_banner}"$'\n'"${rendered}"
    fi

    _DOTS_FAILURE_ANIMATION_LAST_RENDERED_PROMPT="$rendered"
    print -rn -- "$rendered"
}

_dots_failure_animation_cleanup() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    local redraw="${1:-0}"
    if (( _DOTS_FAILURE_ANIMATION_ACTIVE )); then
        _DOTS_FAILURE_ANIMATION_LAST_STATE="${_DOTS_FAILURE_ANIMATION_STATE}"
        _DOTS_FAILURE_ANIMATION_LAST_FRAMES=${_DOTS_FAILURE_ANIMATION_FRAMES}

        local fd="${_DOTS_FAILURE_ANIMATION_FD}"
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
    if [[ "$frame" == G:<-> ]]; then
        _DOTS_FAILURE_ANIMATION_GRADIENT_OFFSET="${frame#G:}"
    else
        _DOTS_FAILURE_ANIMATION_FRAME="$frame"
    fi
    (( _DOTS_FAILURE_ANIMATION_FRAMES += 1 ))
    _DOTS_FAILURE_ANIMATION_STATE='frame-rendered'

    # Redraw expands PROMPT and renders the latest emoji before the prompt marker.
    zle && zle .reset-prompt
}

# Failure-message hooks queue work here. The selected style follows the message.
_dots_failure_animation_start() {
    emulate -L zsh

    [[ -o interactive && -t 0 && -t 1 &&
        "${TERM:-dumb}" != dumb &&
        "${DOTS_FAILURE_ANIMATION:-1}" != 0 ]] || return 0

    local style="${1:-normal}"
    case "$style" in
        anime|ecchi|rainbow|normal|sarcastic|dramatic|legendary|mythic) ;;
        *) style=normal ;;
    esac

    _DOTS_FAILURE_ANIMATION_STYLE="$style"
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

    local style="${_DOTS_FAILURE_ANIMATION_STYLE:-normal}"
    local continuous=0
    _dots_failure_animation_continuous_enabled && continuous=1

    exec {_DOTS_FAILURE_ANIMATION_FD}< <(_dots_failure_animation_stream "$style" "$continuous")
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
        # when a command is submitted, so it never animates during execution.
        _DOTS_FAILURE_ANIMATION_STARTUP_PENDING=0
        _DOTS_FAILURE_ANIMATION_PENDING=1
    elif (( _DOTS_FAILURE_ANIMATION_STARTUP_PENDING )); then
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
    _DOTS_FAILURE_ANIMATION_BANNER=''
    _DOTS_FAILURE_ANIMATION_GRADIENT_STYLE=''
    _dots_failure_animation_cleanup
}

if [[ -o interactive ]]; then
    autoload -Uz add-zsh-hook add-zle-hook-widget
    add-zsh-hook precmd _dots_failure_animation_precmd
    add-zle-hook-widget zle-line-finish _dots_failure_animation_line_finish
fi
\\e[0m'
        local -i color_index=0 character_index=0 banner_size=0
        if [[ "$_DOTS_FAILURE_ANIMATION_GRADIENT_STYLE" == mythic ]]; then
            banner_colors=(
                $'\e[38;2;245;245;247m' $'\e[38;2;205;207;212m'
                $'\e[38;2;157;160;168m' $'\e[38;2;105;109;119m'
                $'\e[38;2;55;58;67m' $'\e[38;2;18;19;24m'
            )
        else
            banner_colors=(
                $'\e[38;2;255;91;132m' $'\e[38;2;255;169;91m'
                $'\e[38;2;255;224;112m' $'\e[38;2;117;220;160m'
                $'\e[38;2;90;193;255m' $'\e[38;2;161;130;255m'
                $'\e[38;2;255;130;215m'
            )
        fi
        banner_chars=( "${(@s::)banner}" )
        banner_size=${#banner_colors[@]}
        local gradient_banner=''
        for character in "${banner_chars[@]}"; do
            color_index=$(( (_DOTS_FAILURE_ANIMATION_GRADIENT_OFFSET + character_index) % banner_size + 1 ))
            color="${banner_colors[color_index]}"
            gradient_banner+="%{${color}%}${character}%{$'\e[0m'%}"
        done
        rendered="${gradient_banner}"$'\n'"${rendered}"
    fi

    _DOTS_FAILURE_ANIMATION_LAST_RENDERED_PROMPT="$rendered"
    print -rn -- "$rendered"
}

_dots_failure_animation_cleanup() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    local redraw="${1:-0}"
    if (( _DOTS_FAILURE_ANIMATION_ACTIVE )); then
        _DOTS_FAILURE_ANIMATION_LAST_STATE="${_DOTS_FAILURE_ANIMATION_STATE}"
        _DOTS_FAILURE_ANIMATION_LAST_FRAMES=${_DOTS_FAILURE_ANIMATION_FRAMES}

        local fd="${_DOTS_FAILURE_ANIMATION_FD}"
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
    if [[ "$frame" == G:<-> ]]; then
        _DOTS_FAILURE_ANIMATION_GRADIENT_OFFSET="${frame#G:}"
    else
        _DOTS_FAILURE_ANIMATION_FRAME="$frame"
    fi
    (( _DOTS_FAILURE_ANIMATION_FRAMES += 1 ))
    _DOTS_FAILURE_ANIMATION_STATE='frame-rendered'

    # Redraw expands PROMPT and renders the latest emoji before the prompt marker.
    zle && zle .reset-prompt
}

# Failure-message hooks queue work here. The selected style follows the message.
_dots_failure_animation_start() {
    emulate -L zsh

    [[ -o interactive && -t 0 && -t 1 &&
        "${TERM:-dumb}" != dumb &&
        "${DOTS_FAILURE_ANIMATION:-1}" != 0 ]] || return 0

    local style="${1:-normal}"
    case "$style" in
        anime|ecchi|rainbow|normal|sarcastic|dramatic|legendary|mythic) ;;
        *) style=normal ;;
    esac

    _DOTS_FAILURE_ANIMATION_STYLE="$style"
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

    local style="${_DOTS_FAILURE_ANIMATION_STYLE:-normal}"
    local continuous=0
    _dots_failure_animation_continuous_enabled && continuous=1

    exec {_DOTS_FAILURE_ANIMATION_FD}< <(_dots_failure_animation_stream "$style" "$continuous")
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
        # when a command is submitted, so it never animates during execution.
        _DOTS_FAILURE_ANIMATION_STARTUP_PENDING=0
        _DOTS_FAILURE_ANIMATION_PENDING=1
    elif (( _DOTS_FAILURE_ANIMATION_STARTUP_PENDING )); then
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
    _DOTS_FAILURE_ANIMATION_BANNER=''
    _DOTS_FAILURE_ANIMATION_GRADIENT_STYLE=''
    _dots_failure_animation_cleanup
}

if [[ -o interactive ]]; then
    autoload -Uz add-zsh-hook add-zle-hook-widget
    add-zsh-hook precmd _dots_failure_animation_precmd
    add-zle-hook-widget zle-line-finish _dots_failure_animation_line_finish
fi
\\e[0m'
        local -i color_index=0 character_index=0 banner_size=0
        if [[ "$_DOTS_FAILURE_ANIMATION_GRADIENT_STYLE" == mythic ]]; then
            banner_colors=(
                $'\e[38;2;245;245;247m' $'\e[38;2;205;207;212m'
                $'\e[38;2;157;160;168m' $'\e[38;2;105;109;119m'
                $'\e[38;2;55;58;67m' $'\e[38;2;18;19;24m'
            )
        else
            banner_colors=(
                $'\e[38;2;255;91;132m' $'\e[38;2;255;169;91m'
                $'\e[38;2;255;224;112m' $'\e[38;2;117;220;160m'
                $'\e[38;2;90;193;255m' $'\e[38;2;161;130;255m'
                $'\e[38;2;255;130;215m'
            )
        fi
        banner_chars=( "${(@s::)banner}" )
        banner_size=${#banner_colors[@]}
        local gradient_banner=''
        for character in "${banner_chars[@]}"; do
            color_index=$(( (_DOTS_FAILURE_ANIMATION_GRADIENT_OFFSET + color_index) % banner_size + 1 ))
            color="${banner_colors[color_index]}"
            gradient_banner+="%{${color}%}${character}%{$'\e[0m'%}"
        done
        rendered="${gradient_banner}"$'\n'"${rendered}"
    fi

    _DOTS_FAILURE_ANIMATION_LAST_RENDERED_PROMPT="$rendered"
    print -rn -- "$rendered"
}

_dots_failure_animation_cleanup() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    local redraw="${1:-0}"
    if (( _DOTS_FAILURE_ANIMATION_ACTIVE )); then
        _DOTS_FAILURE_ANIMATION_LAST_STATE="${_DOTS_FAILURE_ANIMATION_STATE}"
        _DOTS_FAILURE_ANIMATION_LAST_FRAMES=${_DOTS_FAILURE_ANIMATION_FRAMES}

        local fd="${_DOTS_FAILURE_ANIMATION_FD}"
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
    if [[ "$frame" == G:<-> ]]; then
        _DOTS_FAILURE_ANIMATION_GRADIENT_OFFSET="${frame#G:}"
    else
        _DOTS_FAILURE_ANIMATION_FRAME="$frame"
    fi
    (( _DOTS_FAILURE_ANIMATION_FRAMES += 1 ))
    _DOTS_FAILURE_ANIMATION_STATE='frame-rendered'

    # Redraw expands PROMPT and renders the latest emoji before the prompt marker.
    zle && zle .reset-prompt
}

# Failure-message hooks queue work here. The selected style follows the message.
_dots_failure_animation_start() {
    emulate -L zsh

    [[ -o interactive && -t 0 && -t 1 &&
        "${TERM:-dumb}" != dumb &&
        "${DOTS_FAILURE_ANIMATION:-1}" != 0 ]] || return 0

    local style="${1:-normal}"
    case "$style" in
        anime|ecchi|rainbow|normal|sarcastic|dramatic|legendary|mythic) ;;
        *) style=normal ;;
    esac

    _DOTS_FAILURE_ANIMATION_STYLE="$style"
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

    local style="${_DOTS_FAILURE_ANIMATION_STYLE:-normal}"
    local continuous=0
    _dots_failure_animation_continuous_enabled && continuous=1

    exec {_DOTS_FAILURE_ANIMATION_FD}< <(_dots_failure_animation_stream "$style" "$continuous")
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
        # when a command is submitted, so it never animates during execution.
        _DOTS_FAILURE_ANIMATION_STARTUP_PENDING=0
        _DOTS_FAILURE_ANIMATION_PENDING=1
    elif (( _DOTS_FAILURE_ANIMATION_STARTUP_PENDING )); then
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
    _DOTS_FAILURE_ANIMATION_BANNER=''
    _DOTS_FAILURE_ANIMATION_GRADIENT_STYLE=''
    _dots_failure_animation_cleanup
}

if [[ -o interactive ]]; then
    autoload -Uz add-zsh-hook add-zle-hook-widget
    add-zsh-hook precmd _dots_failure_animation_precmd
    add-zle-hook-widget zle-line-finish _dots_failure_animation_line_finish
fi

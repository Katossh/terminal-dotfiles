# Non-blocking, style-aware prompt animation for interactive Zsh.
#
# Ordinary failures animate one emoji immediately before the input marker.
# Legendary and Mythic notices become animated prompt banners with a moving
# left-to-right gradient. ZLE receives frames asynchronously.
# DOTS_FAILURE_ANIMATION_INFINITE=1 loops ordinary emoji until Enter is pressed.

typeset -gi _DOTS_FAILURE_ANIMATION_PENDING=${_DOTS_FAILURE_ANIMATION_PENDING:-0}
typeset -gi _DOTS_FAILURE_ANIMATION_FD=-1
typeset -gi _DOTS_FAILURE_ANIMATION_STEP=0
typeset -gi _DOTS_FAILURE_ANIMATION_ACTIVE=0
typeset -gi _DOTS_FAILURE_ANIMATION_STARTUP_PENDING=1
typeset -gi _DOTS_FAILURE_ANIMATION_FRAMES=0
typeset -gi _DOTS_FAILURE_ANIMATION_LAST_FRAMES=0
typeset -gi _DOTS_FAILURE_ANIMATION_PHASE=0
typeset -g _DOTS_FAILURE_ANIMATION_STATE='loaded'
typeset -g _DOTS_FAILURE_ANIMATION_LAST_STATE=''
typeset -g _DOTS_FAILURE_ANIMATION_FRAME='💀'
typeset -g _DOTS_FAILURE_ANIMATION_STYLE='normal'
typeset -g _DOTS_FAILURE_ANIMATION_MODE='emoji'
typeset -g _DOTS_FAILURE_ANIMATION_BANNER=''
typeset -g _DOTS_FAILURE_ANIMATION_GRADIENT_LINE=''
typeset -ga _DOTS_FAILURE_ANIMATION_POOL=()
typeset -g _DOTS_FAILURE_ANIMATION_ORIGINAL_PROMPT="${PROMPT-}"
typeset -g _DOTS_FAILURE_ANIMATION_PROMPT_MODE='static'
typeset -g _DOTS_FAILURE_ANIMATION_LAST_RENDERED_PROMPT=''
typeset -g _DOTS_FAILURE_ANIMATION_INTERVAL='0.08'

if [[ "$_DOTS_FAILURE_ANIMATION_ORIGINAL_PROMPT" == '$('*')' ]]; then
    _DOTS_FAILURE_ANIMATION_PROMPT_MODE='command'
fi

# Starship enables promptsubst itself; keep it enabled for a static fallback.
setopt promptsubst
PROMPT='$(_dots_failure_animation_render_prompt)'

_dots_failure_animation_infinite_enabled() {
    emulate -L zsh

    # CONTINUOUS remains a backwards-compatible alias. The new INFINITE
    # variable takes precedence when both are set.
    local setting="${DOTS_FAILURE_ANIMATION_INFINITE-${DOTS_FAILURE_ANIMATION_CONTINUOUS:-0}}"
    setting="${setting:l}"
    case "$setting" in
        1|true|yes|on) return 0 ;;
        *) return 1 ;;
    esac
}

# Normal, Sarcastic and Dramatic share the general reaction pool. Anime,
# Ecchi and Rainbow keep separate identities.
_dots_failure_animation_pool_for_style() {
    emulate -L zsh

    local style="${1:-normal}"
    case "$style" in
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
                '👀' '😳' '✨' '💀' '😂' '🤡' '🪿'
                '🔥' '💔' '🖤' '🤎' '💜' '🫠'
            )
            ;;
    esac
}

_dots_failure_animation_stream() {
    emulate -L zsh

    local style="${1:-normal}"
    local mode="${2:-emoji}"
    local infinite="${3:-0}"
    local frame
    local -i pool_size=0
    local -i previous_index=0
    local -i frame_number=0
    local -i index=0
    local -i phase=0

    # Gradient animations are intentionally endless while the prompt is
    # waiting for input. A four-point step gives a ~2-second sweep; Enter
    # closes the pipe through zle-line-finish.
    if [[ "$mode" == legendary || "$mode" == mythic ]]; then
        while true; do
            print -r -- "$phase" || return 0
            (( phase = (phase + 4) % 100 ))
            command sleep "$_DOTS_FAILURE_ANIMATION_INTERVAL" 2>/dev/null || return 0
        done
    fi

    _dots_failure_animation_pool_for_style "$style"
    pool_size="${#_DOTS_FAILURE_ANIMATION_POOL}"
    (( pool_size > 0 )) || return 0

    # A shorter 12-frame cycle makes ordinary reactions feel snappier.
    while true; do
        previous_index=0
        for (( frame_number = 0; frame_number < 12; frame_number++ )); do
            index=$(( (RANDOM % pool_size) + 1 ))
            if (( pool_size > 1 && index == previous_index )); then
                index=$(( (index % pool_size) + 1 ))
            fi

            frame="${_DOTS_FAILURE_ANIMATION_POOL[index]}"
            print -r -- "$frame" || return 0
            previous_index="$index"
            command sleep "$_DOTS_FAILURE_ANIMATION_INTERVAL" 2>/dev/null || return 0
        done

        [[ "$infinite" == 1 ]] || break
    done
}

_dots_failure_animation_gradient_line() {
    emulate -L zsh

    local message="${1-}"
    local style="${2:-legendary}"
    local phase="${3:-0}"
    local character output='' reset_color=$'\e[0m'
    local -a characters colors
    local -i length=0 denominator=1 position=0 color_index=1 index=0 color_count=0

    # Colour individual characters so the moving sweep remains visible even
    # on short banners. Zsh keeps each Unicode code point intact.
    characters=( "${(@s::)message}" )
    length="${#characters[@]}"
    if (( length == 0 )); then
        characters=("$message")
        length=1
    fi

    case "$style" in
        mythic)
            # Monochrome charcoal-to-silver gradient; deliberately not rainbow.
            colors=(
                $'\e[38;2;15;17;21m'
                $'\e[38;2;27;30;36m'
                $'\e[38;2;43;47;55m'
                $'\e[38;2;62;68;78m'
                $'\e[38;2;85;93;105m'
                $'\e[38;2;115;124;137m'
                $'\e[38;2;151;160;171m'
                $'\e[38;2;190;197;205m'
                $'\e[38;2;220;224;229m'
                $'\e[38;2;167;175;185m'
                $'\e[38;2;105;113;124m'
                $'\e[38;2;48;53;62m'
            )
            ;;
        *)
            # Legendary uses a moving metallic gold gradient.
            colors=(
                $'\e[38;2;74;50;12m'
                $'\e[38;2;105;74;17m'
                $'\e[38;2;139;101;26m'
                $'\e[38;2;174;132;39m'
                $'\e[38;2;207;166;62m'
                $'\e[38;2;237;202;105m'
                $'\e[38;2;255;231;159m'
                $'\e[38;2;255;245;207m'
                $'\e[38;2;235;203;119m'
                $'\e[38;2;190;145;55m'
                $'\e[38;2;137;96;27m'
                $'\e[38;2;91;61;16m'
            )
            ;;
    esac

    color_count="${#colors}"
    denominator=$(( length > 1 ? length - 1 : 1 ))
    for (( index = 1; index <= length; index++ )); do
        position=$(( (((index - 1) * 100 / denominator) + phase) % 100 ))
        color_index=$(( (position * color_count / 100) + 1 ))
        (( color_index > color_count )) && color_index="$color_count"
        character="${characters[index]}"
        # A literal percent must remain an adjacent %% pair for promptsubst.
        [[ "$character" == '%' ]] && character='%%'
        output+="%{${colors[color_index]}%}${character}%{${reset_color}%}"
        # Whitespace already exists as a character in the input string.
    done

    _DOTS_FAILURE_ANIMATION_GRADIENT_LINE="$output"
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

    if [[ ( "$_DOTS_FAILURE_ANIMATION_MODE" == legendary ||
            "$_DOTS_FAILURE_ANIMATION_MODE" == mythic ) &&
          -n "$_DOTS_FAILURE_ANIMATION_BANNER" ]]; then
        local -a banner_lines
        local banner_rendered='' line
        banner_lines=( "${(@f)_DOTS_FAILURE_ANIMATION_BANNER}" )
        for line in "${banner_lines[@]}"; do
            _dots_failure_animation_gradient_line "$line" "$_DOTS_FAILURE_ANIMATION_MODE" "$_DOTS_FAILURE_ANIMATION_PHASE"
            banner_rendered+="${_DOTS_FAILURE_ANIMATION_GRADIENT_LINE}"$'\n'
        done
        rendered="${banner_rendered}${rendered}"
    else
        # Insert ordinary emoji immediately before the final input marker.
        local marker="${DOTS_FAILURE_ANIMATION_PROMPT_MARKER:-❯}"
        if [[ -n "$marker" && "$rendered" == *"$marker"* ]]; then
            local suffix="${rendered##*${(b)marker}}"
            local marker_and_suffix="${marker}${suffix}"
            local prefix="${rendered%${(b)marker_and_suffix}}"
            rendered="${prefix}${_DOTS_FAILURE_ANIMATION_FRAME} ${marker_and_suffix}"
        fi
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
        _DOTS_FAILURE_ANIMATION_LAST_FRAMES=$_DOTS_FAILURE_ANIMATION_FRAMES

        local fd="${_DOTS_FAILURE_ANIMATION_FD}"
        zle -F "$fd" 2>/dev/null || true
        { exec {fd}<&- } 2>/dev/null || true

        _DOTS_FAILURE_ANIMATION_FD=-1
        _DOTS_FAILURE_ANIMATION_ACTIVE=0
        _DOTS_FAILURE_ANIMATION_STATE='finished'
    fi

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
    if [[ "$_DOTS_FAILURE_ANIMATION_MODE" == legendary ||
          "$_DOTS_FAILURE_ANIMATION_MODE" == mythic ]]; then
        _DOTS_FAILURE_ANIMATION_PHASE="$frame"
    else
        _DOTS_FAILURE_ANIMATION_FRAME="$frame"
    fi
    (( _DOTS_FAILURE_ANIMATION_FRAMES += 1 ))
    _DOTS_FAILURE_ANIMATION_STATE='frame-rendered'

    # Redraw expands PROMPT and renders the current emoji or gradient phase.
    zle && zle .reset-prompt
}

# Failure-message hooks queue the matching style and, for rare events, the banner.
_dots_failure_animation_start() {
    emulate -L zsh

    [[ -o interactive && -t 0 && -t 1 &&
        "${TERM:-dumb}" != dumb &&
        "${DOTS_FAILURE_ANIMATION:-1}" != 0 ]] || return 1

    local style="${1:-normal}"
    local banner="${2:-}"
    local detail="${3:-}"
    case "$style" in
        anime|ecchi|rainbow|normal|sarcastic|dramatic|legendary|mythic) ;;
        *) style=normal ;;
    esac

    _DOTS_FAILURE_ANIMATION_STYLE="$style"
    _DOTS_FAILURE_ANIMATION_MODE='emoji'
    _DOTS_FAILURE_ANIMATION_BANNER=''
    if [[ "$style" == legendary || "$style" == mythic ]]; then
        _DOTS_FAILURE_ANIMATION_MODE="$style"
        _DOTS_FAILURE_ANIMATION_BANNER="$banner"
        [[ -n "$detail" ]] && _DOTS_FAILURE_ANIMATION_BANNER+=$'\n'"↳ ${detail}"
        _DOTS_FAILURE_ANIMATION_PHASE=0
    fi

    _DOTS_FAILURE_ANIMATION_PENDING=1
    return 0
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
    local mode="${_DOTS_FAILURE_ANIMATION_MODE:-emoji}"
    local infinite=0
    local interval="${DOTS_FAILURE_ANIMATION_INTERVAL:-0.08}"
    if [[ "$interval" != <-> && "$interval" != <->.<-> ]]; then
        interval=0.08
    elif (( interval < 0.01 || interval > 2.0 )); then
        interval=0.08
    fi
    _DOTS_FAILURE_ANIMATION_INTERVAL="$interval"

    if [[ "$mode" == legendary || "$mode" == mythic ]]; then
        infinite=1
    else
        _dots_failure_animation_infinite_enabled && infinite=1
    fi

    exec {_DOTS_FAILURE_ANIMATION_FD}< <(_dots_failure_animation_stream "$style" "$mode" "$infinite")
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

    if _dots_failure_animation_infinite_enabled; then
        # Restart ordinary emoji animation at each idle prompt.
        _DOTS_FAILURE_ANIMATION_STARTUP_PENDING=0
        if [[ "$_DOTS_FAILURE_ANIMATION_MODE" != legendary &&
              "$_DOTS_FAILURE_ANIMATION_MODE" != mythic ]]; then
            _DOTS_FAILURE_ANIMATION_PENDING=1
        fi
    elif (( _DOTS_FAILURE_ANIMATION_STARTUP_PENDING )); then
        # Preserve the one-shot startup animation when infinite mode is off.
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
    _DOTS_FAILURE_ANIMATION_PENDING=0
    _DOTS_FAILURE_ANIMATION_BANNER=''
    _DOTS_FAILURE_ANIMATION_MODE='emoji'
    _DOTS_FAILURE_ANIMATION_STYLE='normal'
    _DOTS_FAILURE_ANIMATION_PHASE=0
}

if [[ -o interactive ]]; then
    autoload -Uz add-zsh-hook add-zle-hook-widget
    add-zsh-hook precmd _dots_failure_animation_precmd
    add-zle-hook-widget zle-line-finish _dots_failure_animation_line_finish
fi

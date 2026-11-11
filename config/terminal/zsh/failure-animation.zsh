# Non-blocking, style-aware emoji animation immediately before the Zsh prompt character.
#
# Starship's PROMPT is a command substitution, not the rendered prompt text.
# Preserve its output and insert the current frame before the final prompt
# marker (❯ by default), leaving the path line and RPROMPT untouched.
# Frames are delivered to ZLE asynchronously.
# DOTS_FAILURE_EMOJI_ANIMATION_INFINITE=1 loops while the prompt is idle.

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
typeset -g _DOTS_FAILURE_ANIMATION_INTERVAL='0.075'
typeset -gi _DOTS_FAILURE_ANIMATION_GRADIENT_PID=0
typeset -gi _DOTS_FAILURE_ANIMATION_GRADIENT_ACTIVE=0
typeset -g _DOTS_FAILURE_ANIMATION_PALETTE_TRANSPORT=''

typeset -ga _DOTS_FAILURE_ANIMATION_LEGENDARY_COLORS=(
    'rgb:ff/5b/84' 'rgb:ff/77/6c' 'rgb:ff/96/5c' 'rgb:ff/b4/5d'
    'rgb:ff/d0/65' 'rgb:ec/e0/69' 'rgb:c9/e2/6c' 'rgb:a3/de/7a'
    'rgb:7d/d9/9a' 'rgb:5c/d4/b9' 'rgb:54/c6/df' 'rgb:5c/a8/f5'
    'rgb:78/8b/ff' 'rgb:a0/7b/ff' 'rgb:c9/79/f0' 'rgb:ed/78/bd'
)
typeset -ga _DOTS_FAILURE_ANIMATION_MYTHIC_COLORS=(
    'rgb:f5/f5/f7' 'rgb:e5/e6/ea' 'rgb:d4/d6/db' 'rgb:c2/c5/cc'
    'rgb:b0/b3/bd' 'rgb:9e/a2/ad' 'rgb:8c/91/9e' 'rgb:7a/80/8e'
    'rgb:68/6e/7c' 'rgb:57/5d/6c' 'rgb:46/4c/5b' 'rgb:36/3c/4b'
    'rgb:29/2f/3e' 'rgb:20/26/34' 'rgb:18/1d/2a' 'rgb:10/14/1f'
)

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

# Legendary and Mythic messages use indexed foreground colours. Kitty stores
# those indices in terminal cells, including scrollback. Updating the palette
# therefore animates already-printed messages. Kitty's color stack restores
# the exact prior palette on shell exit. Slots 208-223 are Legendary and
# 224-239 are Mythic; Kitty reserves 248-255 for special colors.
_dots_failure_animation_palette_sequence() {
    emulate -L zsh
    local -i phase=$(( ${1:-0} % 16 )) offset=0 color_index=0 palette_index=0
    local sequence=$'\e]21'
    for (( offset = 0; offset < 16; offset++ )); do
        color_index=$(( (offset + phase) % 16 + 1 ))
        palette_index=$(( 208 + offset ))
        sequence+=";${palette_index}=${_DOTS_FAILURE_ANIMATION_LEGENDARY_COLORS[color_index]}"
        palette_index=$(( 224 + offset ))
        sequence+=";${palette_index}=${_DOTS_FAILURE_ANIMATION_MYTHIC_COLORS[color_index]}"
    done
    sequence+=$'\e\\'
    print -rn -- "$sequence"
}

_dots_failure_animation_palette_restore_sequence() {
    emulate -L zsh
    print -rn -- $'\e]30101\e\\'
}

_dots_failure_animation_palette_write() {
    emulate -L zsh
    local sequence="${1-}"
    [[ -n "$sequence" ]] || return 1
    if [[ "$_DOTS_FAILURE_ANIMATION_PALETTE_TRANSPORT" == tmux ]]; then
        local escape=$'\e'
        local passthrough="${sequence//${escape}/${escape}${escape}}"
        print -rn -- $'\ePtmux;'"${passthrough}"$'\e\\' > /dev/tty
    else
        print -rn -- "$sequence" > /dev/tty
    fi
}

_dots_failure_animation_palette_worker() {
    emulate -L zsh
    local interval="${DOTS_FAILURE_GRADIENT_INTERVAL:-0.10}"
    local -F interval_seconds=0.10
    if [[ "$interval" == <-> || "$interval" == <->.<-> ]]; then interval_seconds="$interval"; fi
    (( interval_seconds < 0.05 )) && interval_seconds=0.05
    (( interval_seconds > 0.50 )) && interval_seconds=0.50
    local -i phase=0
    local sequence=''
    while true; do
        sequence="$( _dots_failure_animation_palette_sequence "$phase" )"
        _dots_failure_animation_palette_write "$sequence" || return 0
        (( phase = (phase + 1) % 16 ))
        command sleep "$interval_seconds" 2>/dev/null || return 0
    done
}

_dots_failure_animation_gradient_start() {
    emulate -L zsh
    [[ -o interactive && -t 0 && -t 1 && -n "${KITTY_WINDOW_ID:-}" && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]] || return 1
    if [[ -n "${TMUX:-}" ]]; then
        local passthrough_setting="$(command tmux show-options -gv allow-passthrough 2>/dev/null)"
        [[ "$passthrough_setting" == on ]] || return 1
        _DOTS_FAILURE_ANIMATION_PALETTE_TRANSPORT='tmux'
    else
        _DOTS_FAILURE_ANIMATION_PALETTE_TRANSPORT='direct'
    fi
    if (( _DOTS_FAILURE_ANIMATION_GRADIENT_ACTIVE )) && kill -0 "$_DOTS_FAILURE_ANIMATION_GRADIENT_PID" 2>/dev/null; then return 0; fi
    # Save the actual Kitty theme, then animate only ordinary indexed colors.
    local push_sequence=$'\e]30001\e\\'
    _dots_failure_animation_palette_write "$push_sequence" || return 1
    ( _dots_failure_animation_palette_worker ) </dev/null >/dev/null 2>&1 &
    _DOTS_FAILURE_ANIMATION_GRADIENT_PID=$!
    _DOTS_FAILURE_ANIMATION_GRADIENT_ACTIVE=1
    return 0
}

_dots_failure_animation_gradient_stop() {
    emulate -L zsh
    if (( _DOTS_FAILURE_ANIMATION_GRADIENT_ACTIVE )); then
        local pid="$_DOTS_FAILURE_ANIMATION_GRADIENT_PID"
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
        _DOTS_FAILURE_ANIMATION_GRADIENT_PID=0
        _DOTS_FAILURE_ANIMATION_GRADIENT_ACTIVE=0
        local restore_sequence="$( _dots_failure_animation_palette_restore_sequence )"
        _dots_failure_animation_palette_write "$restore_sequence" 2>/dev/null || true
    fi
    _DOTS_FAILURE_ANIMATION_PALETTE_TRANSPORT=''
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

    _dots_failure_animation_pool_for_style "$style"
    pool_size="${#_DOTS_FAILURE_ANIMATION_POOL}"
    (( pool_size > 0 )) || return 0

    # 24 frames at 75 ms each gives a ~1.8-second sequence. Sample randomly
    # from the selected style's pool and avoid identical adjacent frames.
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
    _DOTS_FAILURE_ANIMATION_FRAME="$frame"
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
        anime|ecchi|rainbow|normal|sarcastic|dramatic) ;;
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
    _dots_failure_animation_cleanup
}

if [[ -o interactive ]]; then
    autoload -Uz add-zsh-hook add-zle-hook-widget
    add-zsh-hook precmd _dots_failure_animation_precmd
    add-zle-hook-widget zle-line-finish _dots_failure_animation_line_finish
    add-zsh-hook zshexit _dots_failure_animation_gradient_stop
fi

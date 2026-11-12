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
typeset -gi _DOTS_FAILURE_ANIMATION_STREAM_START_PHASE=0
typeset -gi _DOTS_FAILURE_ANIMATION_LAST_PAUSED_PHASE=0
typeset -gi _DOTS_FAILURE_ANIMATION_RESUME_FROM_PHASE=0
typeset -gi _DOTS_FAILURE_ANIMATION_TTY_FD=-1
typeset -gi _DOTS_FAILURE_ANIMATION_ANCHOR_LINES=0
typeset -gi _DOTS_FAILURE_ANIMATION_ANCHOR_ROW=0
typeset -gi _DOTS_FAILURE_ANIMATION_ANCHOR_COL=1
typeset -g _DOTS_FAILURE_ANIMATION_STATE='loaded'
typeset -g _DOTS_FAILURE_ANIMATION_LAST_STATE=''
typeset -g _DOTS_FAILURE_ANIMATION_FRAME='💀'
typeset -g _DOTS_FAILURE_ANIMATION_STYLE='normal'
typeset -g _DOTS_FAILURE_ANIMATION_MODE='emoji'
typeset -g _DOTS_FAILURE_ANIMATION_BANNER=''
typeset -g _DOTS_FAILURE_ANIMATION_GRADIENT_LINE=''
typeset -g _DOTS_FAILURE_ANIMATION_GRADIENT_LINE_RAW=''
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
    # Preserve both historic names: the Emoji-specific setting from main and
    # the earlier Continuous alias. The PR32 name takes precedence.
    local setting="${DOTS_FAILURE_ANIMATION_INFINITE-${DOTS_FAILURE_EMOJI_ANIMATION_INFINITE-${DOTS_FAILURE_ANIMATION_CONTINUOUS:-0}}}"
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
    local -i phase="${4:-0}"

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
    local character output='' raw_output='' reset_color=$'\e[0m'
    local -a characters colors
    local -i length=0 denominator=1 position=0 color_index=1 index=0 color_count=0

    # Colour individual characters so the moving sweep remains visible even
    # on short banners. Subtracting the phase moves the highlight left-to-right.
    # Zsh keeps each Unicode code point intact.
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
        position=$(( (((index - 1) * 100 / denominator) - phase + 100) % 100 ))
        color_index=$(( (position * color_count / 100) + 1 ))
        (( color_index > color_count )) && color_index="$color_count"
        character="${characters[index]}"
        raw_output+="${colors[color_index]}${character}${reset_color}"
        # A literal percent must remain an adjacent %% pair for promptsubst.
        [[ "$character" == '%' ]] && character='%%'
        output+="%{${colors[color_index]}%}${character}%{${reset_color}%}"
        # Whitespace already exists as a character in the input string.
    done

    _DOTS_FAILURE_ANIMATION_GRADIENT_LINE="$output"
    _DOTS_FAILURE_ANIMATION_GRADIENT_LINE_RAW="$raw_output"
}

_dots_failure_animation_query_cursor() {
    emulate -L zsh

    local tty_state response
    local -i read_status=0
    tty_state="$(command stty -g < /dev/tty 2>/dev/null)" || return 1
    command stty -echo -icanon min 0 time 5 < /dev/tty 2>/dev/null || return 1
    print -rn -u "$_DOTS_FAILURE_ANIMATION_TTY_FD" -- $'\e[6n'
    IFS= builtin read -r -d R -t 0.5 response < /dev/tty
    read_status=$?
    command stty "$tty_state" < /dev/tty 2>/dev/null || return 1
    (( read_status == 0 )) || return 1
    response="${response#$'\e['}"
    response="${response%R}"
    [[ "$response" == <->\;<-> ]] || return 1
    _DOTS_FAILURE_ANIMATION_ANCHOR_ROW="${response%%;*}"
    _DOTS_FAILURE_ANIMATION_ANCHOR_COL="${response#*;}"
    (( _DOTS_FAILURE_ANIMATION_ANCHOR_ROW > 0 && _DOTS_FAILURE_ANIMATION_ANCHOR_COL > 0 ))
}

# Print the banner once at the current cursor position. Its absolute screen
# coordinates were captured immediately beforehand with the terminal DSR.
_dots_failure_animation_print_anchor() {
    emulate -L zsh
    local fd="${_DOTS_FAILURE_ANIMATION_TTY_FD}"
    local line
    local -a banner_lines
    local -i index=0
    (( fd >= 0 )) || return 1
    banner_lines=( "${(@f)_DOTS_FAILURE_ANIMATION_BANNER}" )
    (( ${#banner_lines} > 0 )) || return 1
    print -rn -u "$fd" -- $'\e[?7l'
    for (( index = 1; index <= ${#banner_lines}; index++ )); do
        line="${banner_lines[index]}"
        _dots_failure_animation_gradient_line "$line" "$_DOTS_FAILURE_ANIMATION_MODE" 0
        print -rn -u "$fd" -- "$_DOTS_FAILURE_ANIMATION_GRADIENT_LINE_RAW"
        print -rn -u "$fd" -- $'\r\n'
    done
    print -rn -u "$fd" -- $'\e[?7h'
    _DOTS_FAILURE_ANIMATION_ANCHOR_LINES="${#banner_lines}"
}

# Repaint with absolute cursor coordinates. Never use DECSC/DECRC or CSI s/u:
# ZLE shares those single save-cursor slots and can overwrite them while editing.
_dots_failure_animation_render_anchor() {
    emulate -L zsh
    local fd="${_DOTS_FAILURE_ANIMATION_TTY_FD}"
    local line
    local -a banner_lines
    local -i index=0 row=0
    (( fd >= 0 && _DOTS_FAILURE_ANIMATION_ANCHOR_ROW > 0 )) || return 1
    banner_lines=( "${(@f)_DOTS_FAILURE_ANIMATION_BANNER}" )
    (( ${#banner_lines} > 0 )) || return 1

    # ZLE invokes this handler synchronously between key-processing cycles.
    # Save and restore the live terminal cursor around the absolute repaint;
    # never invalidate or redraw ZLE's input line for an animation frame.
    # This keeps typed text and the insertion cursor untouched.
    print -rn -u "$fd" -- $'\e7'
    for (( index = 1; index <= ${#banner_lines}; index++ )); do
        line="${banner_lines[index]}"
        _dots_failure_animation_gradient_line "$line" "$_DOTS_FAILURE_ANIMATION_MODE" "$_DOTS_FAILURE_ANIMATION_PHASE"
        row=$(( _DOTS_FAILURE_ANIMATION_ANCHOR_ROW + index - 1 ))
        if (( index == 1 )); then
            print -rn -u "$fd" -- "$(builtin printf $'\e[%d;%dH' "$row" "$_DOTS_FAILURE_ANIMATION_ANCHOR_COL")"
        else
            print -rn -u "$fd" -- "$(builtin printf $'\e[%d;1H' "$row")"
        fi
        print -rn -u "$fd" -- "$_DOTS_FAILURE_ANIMATION_GRADIENT_LINE_RAW"
    done
    print -rn -u "$fd" -- $'\e8'
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

    if [[ "$_DOTS_FAILURE_ANIMATION_MODE" != legendary &&
          "$_DOTS_FAILURE_ANIMATION_MODE" != mythic ]]; then
        # Ordinary emoji remains prompt decoration. Rare banners are printed
        # and repainted at their original terminal output position instead.
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
    local keep_tty="${2:-0}"
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

    if (( _DOTS_FAILURE_ANIMATION_TTY_FD >= 0 && keep_tty != 1 )); then
        local tty_fd="${_DOTS_FAILURE_ANIMATION_TTY_FD}"
        { exec {tty_fd}>&- } 2>/dev/null || true
        _DOTS_FAILURE_ANIMATION_TTY_FD=-1
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

    if [[ "$_DOTS_FAILURE_ANIMATION_MODE" == legendary ||
          "$_DOTS_FAILURE_ANIMATION_MODE" == mythic ]]; then
        # Paint over the exact failure-output rows, not the live prompt.
        _dots_failure_animation_render_anchor
    else
        # Ordinary emoji animation remains prompt decoration.
        zle && zle .reset-prompt
    fi
}

# Failure-message hooks queue the matching style and, for rare events, the banner.
_dots_failure_animation_start() {
    emulate -L zsh

    [[ -o interactive && -t 0 && -t 1 &&
        "${TERM:-dumb}" != dumb &&
        "${DOTS_FAILURE_ANIMATION:-1}" != 0 &&
        -z "${NO_COLOR:-}" ]] || return 1

    local style="${1:-normal}"
    local banner="${2:-}"
    local detail="${3:-}"
    case "$style" in
        anime|ecchi|rainbow|normal|sarcastic|dramatic|legendary|mythic) ;;
        *) style=normal ;;
    esac

    # A rare banner remains the active terminal notice until the user clears
    # the screen. Ordinary failures must not silently dismiss it.
    if [[ "$style" != legendary && "$style" != mythic &&
          ( "$_DOTS_FAILURE_ANIMATION_MODE" == legendary ||
            "$_DOTS_FAILURE_ANIMATION_MODE" == mythic ) &&
          -n "$_DOTS_FAILURE_ANIMATION_BANNER" ]]; then
        return 0
    fi

    _DOTS_FAILURE_ANIMATION_STYLE="$style"
    _DOTS_FAILURE_ANIMATION_MODE='emoji'
    _DOTS_FAILURE_ANIMATION_BANNER=''
    if [[ "$style" == legendary || "$style" == mythic ]]; then
        if (( _DOTS_FAILURE_ANIMATION_TTY_FD >= 0 )); then
            _dots_failure_animation_cleanup
        fi
        _DOTS_FAILURE_ANIMATION_MODE="$style"
        _DOTS_FAILURE_ANIMATION_BANNER="$banner"
        [[ -n "$detail" ]] && _DOTS_FAILURE_ANIMATION_BANNER+=$'\n'"↳ ${detail}"
        _DOTS_FAILURE_ANIMATION_PHASE=0
        exec {_DOTS_FAILURE_ANIMATION_TTY_FD}>/dev/tty || {
            _DOTS_FAILURE_ANIMATION_TTY_FD=-1
            return 1
        }
        if ! _dots_failure_animation_query_cursor; then
            # Cursor-position reporting may be unavailable. Print a static
            # notice at this exact point rather than animate an unsafe row.
            _dots_failure_animation_print_anchor || return 1
            local tty_fd="${_DOTS_FAILURE_ANIMATION_TTY_FD}"
            { exec {tty_fd}>&- } 2>/dev/null || true
            _DOTS_FAILURE_ANIMATION_TTY_FD=-1
            return 0
        fi
        _dots_failure_animation_print_anchor || return 1
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

    _DOTS_FAILURE_ANIMATION_STREAM_START_PHASE="$_DOTS_FAILURE_ANIMATION_PHASE"
    exec {_DOTS_FAILURE_ANIMATION_FD}< <(_dots_failure_animation_stream "$style" "$mode" "$infinite" "$_DOTS_FAILURE_ANIMATION_STREAM_START_PHASE")
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

    if [[ "$_DOTS_FAILURE_ANIMATION_MODE" == legendary ||
          "$_DOTS_FAILURE_ANIMATION_MODE" == mythic ]]; then
        # Pause the worker while a foreground command owns the terminal. Keep
        # the original output position and resume from the current phase when
        # the next prompt is ready; never print the banner a second time.
        _DOTS_FAILURE_ANIMATION_STARTUP_PENDING=0
        if (( _DOTS_FAILURE_ANIMATION_TTY_FD >= 0 && _DOTS_FAILURE_ANIMATION_ANCHOR_ROW > 0 )); then
            _DOTS_FAILURE_ANIMATION_RESUME_FROM_PHASE="$_DOTS_FAILURE_ANIMATION_LAST_PAUSED_PHASE"
            _DOTS_FAILURE_ANIMATION_PENDING=1
        fi
    elif _dots_failure_animation_infinite_enabled; then
        # Restart ordinary emoji animation at each idle prompt.
        _DOTS_FAILURE_ANIMATION_STARTUP_PENDING=0
        _DOTS_FAILURE_ANIMATION_PENDING=1
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

_dots_failure_animation_reset() {
    emulate -L zsh

    _dots_failure_animation_cleanup
    _DOTS_FAILURE_ANIMATION_PENDING=0
    _DOTS_FAILURE_ANIMATION_BANNER=''
    _DOTS_FAILURE_ANIMATION_MODE='emoji'
    _DOTS_FAILURE_ANIMATION_STYLE='normal'
    _DOTS_FAILURE_ANIMATION_PHASE=0
}

_dots_failure_animation_preexec() {
    emulate -L zsh

    local -a command_words
    command_words=( "${(@z)1}" )
    case "${command_words[1]:-}" in
        clear)
            _dots_failure_animation_reset
            ;;
        command|builtin)
            [[ "${command_words[2]:-}" == clear ]] && _dots_failure_animation_reset
            ;;
    esac
}

_dots_failure_animation_clear_screen_widget() {
    _dots_failure_animation_reset
    zle .clear-screen
}

_dots_failure_animation_line_finish() {
    _DOTS_FAILURE_ANIMATION_PENDING=0

    # ZLE stops receiving file-descriptor callbacks when Enter hands the
    # terminal to a foreground command. Stop the worker but retain the TTY
    # descriptor, banner text, phase, and absolute output coordinates.
    if [[ ( "$_DOTS_FAILURE_ANIMATION_MODE" == legendary ||
            "$_DOTS_FAILURE_ANIMATION_MODE" == mythic ) &&
          -n "$_DOTS_FAILURE_ANIMATION_BANNER" ]]; then
        _DOTS_FAILURE_ANIMATION_LAST_PAUSED_PHASE="$_DOTS_FAILURE_ANIMATION_PHASE"
        _dots_failure_animation_cleanup 0 1
        return 0
    fi

    _dots_failure_animation_cleanup
    _DOTS_FAILURE_ANIMATION_BANNER=''
    _DOTS_FAILURE_ANIMATION_MODE='emoji'
    _DOTS_FAILURE_ANIMATION_STYLE='normal'
    _DOTS_FAILURE_ANIMATION_PHASE=0
}

if [[ -o interactive ]]; then
    autoload -Uz add-zsh-hook add-zle-hook-widget
    add-zsh-hook precmd _dots_failure_animation_precmd
    add-zsh-hook preexec _dots_failure_animation_preexec
    add-zle-hook-widget zle-line-finish _dots_failure_animation_line_finish
    # Wrap the built-in widget so Ctrl+L clears the persistent banner too.
    zle -N clear-screen _dots_failure_animation_clear_screen_widget
fi

# Non-blocking, style-aware prompt animation for interactive Zsh.
#
# Ordinary failures animate one emoji before the input marker through ZLE.
# Legendary and Mythic use a transparent Kitty graphics overlay attached to
# their original output cells; Kitty owns playback and scrollback positioning.
# Other terminals keep one static gradient. INFINITE loops ordinary emoji.

typeset -g _DOTS_FAILURE_ANIMATION_SOURCE_FILE="${${(%):-%x}:A}"
typeset -gi _DOTS_FAILURE_ANIMATION_PENDING=${_DOTS_FAILURE_ANIMATION_PENDING:-0}
typeset -gi _DOTS_FAILURE_ANIMATION_FD=-1
typeset -gi _DOTS_FAILURE_ANIMATION_STEP=0
typeset -gi _DOTS_FAILURE_ANIMATION_ACTIVE=0
typeset -gi _DOTS_FAILURE_ANIMATION_STARTUP_PENDING=1
typeset -gi _DOTS_FAILURE_ANIMATION_FRAMES=0
typeset -gi _DOTS_FAILURE_ANIMATION_LAST_FRAMES=0
typeset -gi _DOTS_FAILURE_ANIMATION_TTY_FD=-1
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
    local infinite="${2:-0}"
    local frame
    local -i pool_size=0 previous_index=0 frame_number=0 index=0

    _dots_failure_animation_pool_for_style "$style"
    pool_size="${#_DOTS_FAILURE_ANIMATION_POOL}"
    (( pool_size > 0 )) || return 0

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
        if (( color_index > color_count )); then
            color_index="$color_count"
        fi
        character="${characters[index]}"
        raw_output+="${colors[color_index]}${character}${reset_color}"
        # A literal percent must remain an adjacent %% pair for promptsubst.
        if [[ "$character" == '%' ]]; then
            character='%%'
        fi
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

# Kitty receives one transparent animated overlay at the failure cursor
# position, then the real text is printed once beneath it. Graphics placements
# scroll with the underlying terminal cells into scrollback.
_dots_failure_animation_kitty_scrollback() {
    emulate -L zsh

    local style="${1:-legendary}"
    local banner="${2-}"
    local detail="${3-}"
    [[ -o interactive && -t 0 && -t 1 &&
        "${TERM:-dumb}" == xterm-kitty &&
        -n "${KITTY_WINDOW_ID:-}" &&
        -z "${TMUX:-}" &&
        -z "${NO_COLOR:-}" &&
        "${DOTS_FAILURE_ANIMATION:-1}" != 0 ]] || return 1

    command -v kitty >/dev/null 2>&1 || return 1
    command -v python3 >/dev/null 2>&1 || return 1

    local renderer="${_DOTS_FAILURE_ANIMATION_SOURCE_FILE:h:h:h:h}/scripts/render-failure-animation.py"
    [[ -r "$renderer" ]] || return 1

    local window_pixels pixel_width pixel_height font_family dimensions
    local -i terminal_columns="${COLUMNS:-0}" terminal_lines="${LINES:-0}"
    (( terminal_columns > 0 && terminal_lines > 0 )) || return 1
    window_pixels="$(command kitty +kitten icat --print-window-size 2>/dev/null)" || return 1
    [[ "$window_pixels" == <->x<-> ]] || return 1
    pixel_width="${window_pixels%%x*}"
    pixel_height="${window_pixels#*x}"
    (( pixel_width > 0 && pixel_height > 0 )) || return 1

    local -i cell_width=$(( pixel_width / terminal_columns ))
    local -i cell_height=$(( pixel_height / terminal_lines ))
    (( cell_width > 0 && cell_height > 0 )) || return 1
    font_family=monospace
    if command -v fc-match >/dev/null 2>&1; then
        font_family="$(command fc-match -f '%{family[0]}' 'JetBrainsMono Nerd Font' 2>/dev/null)"
        [[ -n "$font_family" ]] || font_family=monospace
    fi

    local -a banner_lines image_dimensions
    banner_lines=( "$banner" )
    [[ -n "$detail" ]] && banner_lines+=( "↳ $detail" )

    local temp_dir image_file
    temp_dir="$(command mktemp -d "${TMPDIR:-/tmp}/dots-failure-animation.XXXXXX" 2>/dev/null)" || return 1
    image_file="$temp_dir/banner.gif"
    dimensions="$(
        {
            print -r -- "$banner"
            [[ -n "$detail" ]] && print -r -- "↳ $detail"
        } | command python3 "$renderer" \
            --style "$style" \
            --cell-width "$cell_width" \
            --cell-height "$cell_height" \
            --font-family "$font_family" \
            --output "$image_file" 2>/dev/null
    )" || {
        command rm -rf -- "$temp_dir"
        return 1
    }

    image_dimensions=( ${(z)dimensions} )
    if (( ${#image_dimensions} != 2 )); then
        command rm -rf -- "$temp_dir"
        return 1
    fi

    local -i image_columns="${image_dimensions[1]}"
    local -i image_rows="${image_dimensions[2]}"
    if (( image_columns <= 0 || image_columns + 1 >= terminal_columns ||
          image_rows != ${#banner_lines} || image_rows >= terminal_lines )); then
        command rm -rf -- "$temp_dir"
        return 1
    fi

    exec {_DOTS_FAILURE_ANIMATION_TTY_FD}>/dev/tty || {
        _DOTS_FAILURE_ANIMATION_TTY_FD=-1
        command rm -rf -- "$temp_dir"
        return 1
    }
    if ! _dots_failure_animation_query_cursor ||
        (( _DOTS_FAILURE_ANIMATION_ANCHOR_ROW <= 0 ||
           _DOTS_FAILURE_ANIMATION_ANCHOR_COL != 1 ||
           _DOTS_FAILURE_ANIMATION_ANCHOR_ROW + image_rows - 1 > terminal_lines ||
           _DOTS_FAILURE_ANIMATION_ANCHOR_COL + image_columns - 1 >= terminal_columns )); then
        local tty_fd="$_DOTS_FAILURE_ANIMATION_TTY_FD"
        { exec {tty_fd}>&- } 2>/dev/null || true
        _DOTS_FAILURE_ANIMATION_TTY_FD=-1
        command rm -rf -- "$temp_dir"
        return 1
    fi

    local placement="${image_columns}x${image_rows}@$(( _DOTS_FAILURE_ANIMATION_ANCHOR_COL - 1 ))x$(( _DOTS_FAILURE_ANIMATION_ANCHOR_ROW - 1 ))"
    # All options that would otherwise make icat read the TTY are explicit.
    if ! command kitty +kitten icat \
        --stdin=no \
        --use-window-size "$terminal_columns,$terminal_lines,$pixel_width,$pixel_height" \
        --transfer-mode=stream \
        --engine=builtin \
        --place "$placement" \
        --z-index 1 \
        --loop -1 \
        "$image_file" >/dev/tty 2>/dev/null; then
        local tty_fd="$_DOTS_FAILURE_ANIMATION_TTY_FD"
        { exec {tty_fd}>&- } 2>/dev/null || true
        _DOTS_FAILURE_ANIMATION_TTY_FD=-1
        command rm -rf -- "$temp_dir"
        return 1
    fi

    print -rn -u "$_DOTS_FAILURE_ANIMATION_TTY_FD" -- \
        "$(builtin printf $'\e[%d;%dH' "$_DOTS_FAILURE_ANIMATION_ANCHOR_ROW" "$_DOTS_FAILURE_ANIMATION_ANCHOR_COL")"

    local line
    for line in "${banner_lines[@]}"; do
        # The transparent image is the gradient. Keep real, selectable text
        # underneath it; do not invoke the shell ANSI renderer a second time.
        print -r -u "$_DOTS_FAILURE_ANIMATION_TTY_FD" -- "$line"
    done

    local tty_fd="$_DOTS_FAILURE_ANIMATION_TTY_FD"
    { exec {tty_fd}>&- } 2>/dev/null || true
    _DOTS_FAILURE_ANIMATION_TTY_FD=-1
    command rm -rf -- "$temp_dir"
    return 0
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
    _DOTS_FAILURE_ANIMATION_FRAME="$frame"
    (( _DOTS_FAILURE_ANIMATION_FRAMES += 1 ))
    _DOTS_FAILURE_ANIMATION_STATE='frame-rendered'
    zle && zle .reset-prompt
}

# Failure-message hooks queue the matching style and, for rare events, the banner.
_dots_failure_animation_start() {
    emulate -L zsh

    [[ -o interactive && -t 0 && -t 1 &&
        "${TERM:-dumb}" != dumb &&
        "${DOTS_FAILURE_ANIMATION:-1}" != 0 &&
        -z "${NO_COLOR:-}" ]] || return 1

    local style="${1:-normal}"
    local banner="${2-}"
    local detail="${3-}"
    case "$style" in
        anime|ecchi|rainbow|normal|sarcastic|dramatic|legendary|mythic) ;;
        *) style=normal ;;
    esac

    _DOTS_FAILURE_ANIMATION_STYLE="$style"
    if [[ "$style" == legendary || "$style" == mythic ]]; then
        _dots_failure_animation_kitty_scrollback "$style" "$banner" "$detail"
        return $?
    fi

    _DOTS_FAILURE_ANIMATION_MODE='emoji'
    _DOTS_FAILURE_ANIMATION_BANNER=''
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
    local infinite=0
    local interval="${DOTS_FAILURE_ANIMATION_INTERVAL:-0.08}"
    if [[ "$interval" != <-> && "$interval" != <->.<-> ]]; then
        interval=0.08
    elif (( interval < 0.01 || interval > 2.0 )); then
        interval=0.08
    fi
    _DOTS_FAILURE_ANIMATION_INTERVAL="$interval"

    _dots_failure_animation_infinite_enabled && infinite=1
    exec {_DOTS_FAILURE_ANIMATION_FD}< <(_dots_failure_animation_stream "$style" "$infinite")
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
        _DOTS_FAILURE_ANIMATION_STARTUP_PENDING=0
        _DOTS_FAILURE_ANIMATION_PENDING=1
    elif (( _DOTS_FAILURE_ANIMATION_STARTUP_PENDING )); then
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

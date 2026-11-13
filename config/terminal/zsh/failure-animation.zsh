# Style-aware prompt and failure-message animations for interactive Zsh.
#
# Failure gradients are rendered as prompt-safe rows above the input line.
# A background timer sends phase numbers only; ZLE renders each frame without
# reading input or modifying the editable command buffer.
# Prompt emoji and failure-gradient frames share one ZLE file-descriptor watcher.

typeset -gi _DOTS_FAILURE_ANIMATION_PENDING=${_DOTS_FAILURE_ANIMATION_PENDING:-0}
typeset -gi _DOTS_FAILURE_ANIMATION_FD=-1
typeset -gi _DOTS_FAILURE_ANIMATION_STEP=0
typeset -gi _DOTS_FAILURE_ANIMATION_ACTIVE=0
typeset -gi _DOTS_FAILURE_ANIMATION_STARTUP_PENDING=1
typeset -gi _DOTS_FAILURE_ANIMATION_FRAMES=0
typeset -gi _DOTS_FAILURE_ANIMATION_LAST_FRAMES=0
typeset -gi _DOTS_FAILURE_ANIMATION_LAST_BANNER_FRAMES=0
typeset -gi _DOTS_FAILURE_GRADIENT_ACTIVE=0
typeset -gi _DOTS_FAILURE_GRADIENT_ACCEPT_PENDING=0
typeset -gi _DOTS_FAILURE_GRADIENT_PENDING=0
typeset -gi _DOTS_FAILURE_GRADIENT_PHASE=0
typeset -g _DOTS_FAILURE_GRADIENT_INTERVAL='0.08'
typeset -ga _DOTS_FAILURE_GRADIENT_LINES=()
typeset -g _DOTS_FAILURE_ANIMATION_GRADIENT_MESSAGE=''
typeset -g _DOTS_FAILURE_ANIMATION_GRADIENT_PROMPT=''
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
        legendary)
            # Metallic gold sweep.
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
        rainbow)
            colors=(
                $'\e[38;2;255;82;82m'
                $'\e[38;2;255;145;64m'
                $'\e[38;2;255;207;75m'
                $'\e[38;2;165;220;80m'
                $'\e[38;2;70;210;130m'
                $'\e[38;2;60;190;210m'
                $'\e[38;2;80;140;245m'
                $'\e[38;2;130;110;255m'
                $'\e[38;2;185;100;245m'
                $'\e[38;2;230;105;195m'
                $'\e[38;2;255;115;150m'
                $'\e[38;2;255;82;82m'
            )
            ;;
        anime)
            colors=(
                $'\e[38;2;255;190;220m'
                $'\e[38;2;249;166;216m'
                $'\e[38;2;239;150;220m'
                $'\e[38;2;220;145;226m'
                $'\e[38;2;198;150;235m'
                $'\e[38;2;176;162;243m'
                $'\e[38;2;160;178;250m'
                $'\e[38;2;190;173;250m'
                $'\e[38;2;220;163;239m'
                $'\e[38;2;245;157;221m'
                $'\e[38;2;255;178;220m'
                $'\e[38;2;255;190;220m'
            )
            ;;
        ecchi)
            colors=(
                $'\e[38;2;120;24;70m'
                $'\e[38;2;155;34;83m'
                $'\e[38;2;190;45;98m'
                $'\e[38;2;225;65;120m'
                $'\e[38;2;255;92;145m'
                $'\e[38;2;255;130;170m'
                $'\e[38;2;255;165;190m'
                $'\e[38;2;255;130;170m'
                $'\e[38;2;225;65;120m'
                $'\e[38;2;190;45;98m'
                $'\e[38;2;155;34;83m'
                $'\e[38;2;120;24;70m'
            )
            ;;
        *)
            # Everyday styles use a restrained Catppuccin-inspired sweep.
            colors=(
                $'\e[38;2;36;123;160m'
                $'\e[38;2;69;130;160m'
                $'\e[38;2;89;145;164m'
                $'\e[38;2;120;154;177m'
                $'\e[38;2;148;163;184m'
                $'\e[38;2;166;173;200m'
                $'\e[38;2;177;157;210m'
                $'\e[38;2;202;158;230m'
                $'\e[38;2;210;145;188m'
                $'\e[38;2;219;143;170m'
                $'\e[38;2;202;153;169m'
                $'\e[38;2;166;173;200m'
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

# Animate the message in its final output position. Each frame replaces the
# same terminal rows; after the last frame the message remains plain selectable
# text with its final gradient. No graphics placement survives to scrollback.
# Prepare message lines once; frame callbacks only recolour and display them.
_dots_failure_animation_prepare_banner() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    local style="${1:-normal}"
    local banner="${2-}"
    local detail="${3-}"
    [[ -n "$banner" && -o interactive && -t 0 && -t 1 ]] || return 1

    local -i columns="${COLUMNS:-0}" line_width=0
    (( columns > 2 )) || return 1
    line_width=$(( columns - 2 ))

    local folded
    local -a lines=()
    folded="$(print -rn -- "$banner" | command fold -s -w "$line_width" 2>/dev/null)" || return 1
    lines=( "${(@f)folded}" )
    (( ${#lines} > 0 )) || return 1
    if [[ -n "$detail" ]]; then
        folded="$(print -rn -- "↳ $detail" | command fold -s -w "$line_width" 2>/dev/null)" || return 1
        lines+=( "${(@f)folded}" )
    fi

    local interval="${DOTS_FAILURE_GRADIENT_INTERVAL:-0.08}"
    if [[ "$interval" != <-> && "$interval" != <->.<-> ]]; then
        interval=0.08
    elif (( interval < 0.01 || interval > 1.0 )); then
        interval=0.08
    fi

    _DOTS_FAILURE_ANIMATION_STYLE="$style"
    _DOTS_FAILURE_ANIMATION_BANNER="$banner"
    _DOTS_FAILURE_GRADIENT_LINES=( "${lines[@]}" )
    _DOTS_FAILURE_GRADIENT_PHASE=0
    _DOTS_FAILURE_GRADIENT_INTERVAL="$interval"
    _DOTS_FAILURE_ANIMATION_LAST_BANNER_FRAMES=0
    _DOTS_FAILURE_ANIMATION_GRADIENT_MESSAGE=''
    return 0
}

# The worker emits phase numbers only. It has no terminal descriptor and
# cannot read or consume keyboard input.
_dots_failure_animation_gradient_stream() {
    emulate -L zsh
    local interval="${1:-0.08}"
    local -i frame=1

    # Phase zero is rendered by zle-line-init so the message is visible
    # immediately; the worker supplies the remaining 24 animated phases.
    for (( frame = 1; frame < 25; frame++ )); do
        command sleep "$interval" 2>/dev/null || return 0
        print -r -- "$(( frame * 4 ))" || return 0
    done

    # An explicit terminator is more reliable than waiting for pipe EOF:
    # ZLE can react to this final readable record even when EOF is delayed.
    print -r -- DONE
}

_dots_failure_animation_gradient_cleanup() {
    emulate -L zsh
    (( _DOTS_FAILURE_GRADIENT_ACTIVE )) || return 0
    _dots_failure_animation_cleanup
}

_dots_failure_animation_render_gradient_message() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    local message=''
    local -i line=1 line_count="${#_DOTS_FAILURE_GRADIENT_LINES}"
    (( line_count > 0 )) || return 1

    for (( line = 1; line <= line_count; line++ )); do
        _dots_failure_animation_gradient_line \
            "${_DOTS_FAILURE_GRADIENT_LINES[line]}" \
            "$_DOTS_FAILURE_ANIMATION_STYLE" \
            "$_DOTS_FAILURE_GRADIENT_PHASE"
        message+="${_DOTS_FAILURE_ANIMATION_GRADIENT_LINE}"
        (( line < line_count )) && message+=$'\n'
    done

    _DOTS_FAILURE_ANIMATION_GRADIENT_MESSAGE="$message"
    _DOTS_FAILURE_ANIMATION_GRADIENT_PROMPT="$message"
}

# The shared FD callback delegates gradient display to a ZLE widget, keeping
# updates isolated from the shell's command buffer and cursor.
_dots_failure_animation_gradient_render_widget() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    if _dots_failure_animation_render_gradient_message; then
        # zle -M prints ANSI bytes as text. Prompt-safe %{...%} spans are
        # interpreted by ZLE and take zero columns in cursor calculations.
        zle .reset-prompt
        zle -R
    fi
}

# Start the timer and register its reader before ZLE starts. This mirrors
# the working prompt emoji watcher and keeps process/FD setup out of widgets.
_dots_failure_animation_start_gradient() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    # Share the exact FD lifecycle and callback used by the working prompt
    # animation. Only the stream payload and renderer differ.
    _dots_failure_animation_cleanup
    _DOTS_FAILURE_ANIMATION_STEP=0
    _DOTS_FAILURE_ANIMATION_FRAMES=0

    exec {_DOTS_FAILURE_ANIMATION_FD}< <(_dots_failure_animation_gradient_stream "$_DOTS_FAILURE_GRADIENT_INTERVAL") || {
        _DOTS_FAILURE_ANIMATION_STATE='gradient-fallback-pipe-open'
        return 1
    }

    _DOTS_FAILURE_ANIMATION_ACTIVE=1
    _DOTS_FAILURE_GRADIENT_ACTIVE=1
    if zle -F "$_DOTS_FAILURE_ANIMATION_FD" _dots_failure_animation_fd_handler; then
        _DOTS_FAILURE_ANIMATION_STATE='gradient-registered'
        return 0
    fi

    _DOTS_FAILURE_ANIMATION_STATE='gradient-registration-failed'
    _dots_failure_animation_cleanup
    return 1
}

# Paint phase zero after the next prompt enters ZLE. The timer and FD watcher
# have already been created by the precmd path, outside the editor widget.
_dots_failure_animation_gradient_line_init() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    (( _DOTS_FAILURE_GRADIENT_PENDING )) || return 0
    _DOTS_FAILURE_GRADIENT_PENDING=0
    _DOTS_FAILURE_GRADIENT_PHASE=0

    if _dots_failure_animation_render_gradient_message; then
        _DOTS_FAILURE_ANIMATION_LAST_BANNER_FRAMES=1
        zle .reset-prompt
        zle -R
    fi
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

    # The single failure banner occupies a prompt row above the input line.
    # ZLE interprets its %{...%} spans as zero-width colour controls.
    if [[ -n "$_DOTS_FAILURE_ANIMATION_GRADIENT_PROMPT" ]]; then
        rendered="${_DOTS_FAILURE_ANIMATION_GRADIENT_PROMPT}"$'\n'"${rendered}"
    fi

    # Ordinary prompt emoji remains immediately before the final input marker.
    local marker="${DOTS_FAILURE_ANIMATION_PROMPT_MARKER:-❯}"
    if [[ -n "$marker" ]]; then
        local marker_pattern="${(b)marker}"
        if [[ "$rendered" == *"$marker"* ]]; then
            local suffix="${rendered##*${marker_pattern}}"
            local prefix="${rendered%${marker_pattern}*}"
            prefix="${prefix//${marker_pattern}/}"
            while [[ "$prefix" == *' ' ]]; do
                prefix="${prefix% }"
            done
            rendered="${prefix} ${_DOTS_FAILURE_ANIMATION_FRAME} ${marker}${suffix}"
        else
            rendered="${rendered% }"
            rendered="${rendered} ${_DOTS_FAILURE_ANIMATION_FRAME} ${marker}"
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

    _DOTS_FAILURE_GRADIENT_ACTIVE=0
    _DOTS_FAILURE_GRADIENT_FD=-1

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
        if (( _DOTS_FAILURE_GRADIENT_ACTIVE )); then
            _DOTS_FAILURE_ANIMATION_STATE='gradient-finished'
            _dots_failure_animation_cleanup

            # Enter is deferred while the gradient is active. Replay it only
            # after the stream reaches EOF so every phase gets rendered.
            if (( _DOTS_FAILURE_GRADIENT_ACCEPT_PENDING )); then
                _DOTS_FAILURE_GRADIENT_ACCEPT_PENDING=0
                zle _dots_failure_animation_replay_accept_widget
            fi
            return 0
        fi
        _DOTS_FAILURE_ANIMATION_STATE='stream-complete'
        _dots_failure_animation_cleanup 1
        return 0
    fi

    if [[ "$frame" == DONE ]] && (( _DOTS_FAILURE_GRADIENT_ACTIVE )); then
        _DOTS_FAILURE_ANIMATION_STATE='gradient-finished'
        _dots_failure_animation_cleanup
        if (( _DOTS_FAILURE_GRADIENT_ACCEPT_PENDING )); then
            _DOTS_FAILURE_GRADIENT_ACCEPT_PENDING=0
            zle _dots_failure_animation_replay_accept_widget
        fi
        return 0
    fi

    (( _DOTS_FAILURE_ANIMATION_STEP += 1 ))
    (( _DOTS_FAILURE_ANIMATION_FRAMES += 1 ))

    if (( _DOTS_FAILURE_GRADIENT_ACTIVE )); then
        [[ "$frame" == <-> ]] || return 0
        _DOTS_FAILURE_GRADIENT_PHASE=$(( frame % 100 ))
        (( _DOTS_FAILURE_ANIMATION_LAST_BANNER_FRAMES += 1 ))
        _DOTS_FAILURE_ANIMATION_STATE='gradient-frame-rendered'
        zle _dots_failure_animation_gradient_render_widget
        return 0
    fi

    _DOTS_FAILURE_ANIMATION_FRAME="$frame"
    _DOTS_FAILURE_ANIMATION_STATE='frame-rendered'
    zle && zle .reset-prompt
}

# Failure-message hooks render complete messages before the next prompt.
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
    if [[ -n "$banner" ]]; then
        _DOTS_FAILURE_ANIMATION_MODE='gradient'
        if _dots_failure_animation_prepare_banner "$style" "$banner" "$detail"; then
            # This function runs before ZLE: start and register the timer now,
            # then let zle-line-init paint the first frame. This also works when
            # the failure notice is queued by a later precmd hook.
            _DOTS_FAILURE_GRADIENT_PENDING=1
            if _dots_failure_animation_start_gradient; then
                _DOTS_FAILURE_ANIMATION_STATE='gradient-pending'
            else
                local fallback_reason="$_DOTS_FAILURE_ANIMATION_STATE"
                _DOTS_FAILURE_ANIMATION_STATE="gradient-static-fallback-${fallback_reason}"
                return 1
            fi
            return 0
        fi
        _DOTS_FAILURE_ANIMATION_MODE='emoji'
        _DOTS_FAILURE_ANIMATION_BANNER=''
        _DOTS_FAILURE_GRADIENT_LINES=()
        return 1
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

_dots_failure_animation_replay_accept_widget() {
    zle -U $'\n'
}

_dots_failure_animation_accept_line_widget() {
    emulate -L zsh

    # Keep ZLE responsive and preserve the current buffer. A submitted line
    # is replayed after the gradient worker has delivered its final frame.
    if (( _DOTS_FAILURE_GRADIENT_ACTIVE )); then
        _DOTS_FAILURE_GRADIENT_ACCEPT_PENDING=1
        return 0
    fi

    _DOTS_FAILURE_GRADIENT_ACCEPT_PENDING=0
    zle .accept-line
}

_dots_failure_animation_reset() {
    emulate -L zsh

    _dots_failure_animation_cleanup
    _dots_failure_animation_gradient_cleanup
    _DOTS_FAILURE_GRADIENT_PENDING=0
    _DOTS_FAILURE_GRADIENT_ACCEPT_PENDING=0
    _DOTS_FAILURE_ANIMATION_PENDING=0
    _DOTS_FAILURE_ANIMATION_BANNER=''
    _DOTS_FAILURE_GRADIENT_LINES=()
    _DOTS_FAILURE_ANIMATION_GRADIENT_MESSAGE=''
    _DOTS_FAILURE_ANIMATION_GRADIENT_PROMPT=''
    _DOTS_FAILURE_ANIMATION_MODE='emoji'
    _DOTS_FAILURE_ANIMATION_STYLE='normal'
}

_dots_failure_animation_preexec() {
    emulate -L zsh

    # zle-line-finish can run during editor transitions while the buffer is
    # still editable. Keep the gradient alive there; stop it only once Zsh
    # enters preexec, which means the user actually submitted a command.
    if (( _DOTS_FAILURE_GRADIENT_ACTIVE )) || [[ -n "$_DOTS_FAILURE_ANIMATION_GRADIENT_PROMPT" ]]; then
        _dots_failure_animation_cleanup
        _DOTS_FAILURE_GRADIENT_PENDING=0
        _DOTS_FAILURE_GRADIENT_LINES=()
        _DOTS_FAILURE_ANIMATION_GRADIENT_MESSAGE=''
        _DOTS_FAILURE_ANIMATION_GRADIENT_PROMPT=''
        _DOTS_FAILURE_ANIMATION_MODE='emoji'
        _DOTS_FAILURE_ANIMATION_STYLE='normal'
    fi

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

    # Ordinary prompt emoji animation is still tied to line submission. A
    # failure gradient has its own lifecycle and is cancelled in preexec.
    if (( !_DOTS_FAILURE_GRADIENT_ACTIVE )) && [[ -z "$_DOTS_FAILURE_ANIMATION_GRADIENT_PROMPT" ]]; then
        _dots_failure_animation_cleanup
        _DOTS_FAILURE_GRADIENT_PENDING=0
        _DOTS_FAILURE_ANIMATION_BANNER=''
        _DOTS_FAILURE_GRADIENT_LINES=()
        _DOTS_FAILURE_ANIMATION_GRADIENT_MESSAGE=''
        _DOTS_FAILURE_ANIMATION_GRADIENT_PROMPT=''
        _DOTS_FAILURE_ANIMATION_MODE='emoji'
        _DOTS_FAILURE_ANIMATION_STYLE='normal'
        _DOTS_FAILURE_ANIMATION_PHASE=0
    fi
}

if [[ -o interactive ]]; then
    autoload -Uz add-zsh-hook add-zle-hook-widget
    add-zsh-hook precmd _dots_failure_animation_precmd
    add-zsh-hook preexec _dots_failure_animation_preexec
    add-zle-hook-widget zle-line-init _dots_failure_animation_gradient_line_init
    add-zle-hook-widget zle-line-finish _dots_failure_animation_line_finish
    # FD frame updates use a ZLE widget; the banner uses prompt-safe colour
    # spans, never a raw ANSI message or terminal graphics overlay.
    zle -N _dots_failure_animation_gradient_render_widget
    zle -N _dots_failure_animation_replay_accept_widget
    # Enter waits for the last gradient frame instead of interrupting it.
    zle -N accept-line _dots_failure_animation_accept_line_widget
    # Wrap the built-in widget so Ctrl+L clears the banner too.
    zle -N clear-screen _dots_failure_animation_clear_screen_widget
fi

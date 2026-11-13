# Style-aware prompt and failure-message animations for interactive Zsh.
#
# One background producer drives both animations. On every tick it writes two
# integers through a private pipe: an emoji pool index and a gradient phase.
# A ZLE file-descriptor widget reads that pipe, updates the prompt emoji, and
# refreshes a dedicated gradient block immediately above the editable line.
# The producer never reads stdin, never writes to the terminal, and never moves
# the cursor; ZLE remains the only owner of input, BUFFER, CURSOR, PROMPT, and
# RPROMPT.
#
# ZLE's message area (zle -M / zle -R) deliberately renders control characters
# as caret notation, so it cannot display ANSI colour. The gradient therefore
# lives in the prompt as a separate block. The original prompt is preserved and
# re-expanded by the wrapper; the block is removed before the next prompt after
# the line has been accepted.

# Sourcing this file again must not wrap the wrapper or install duplicate
# hooks. Keep the first prompt capture and the existing widget aliases.
if (( ${+_DOTS_FAILURE_ANIMATION_LOADED} )); then
    return 0
fi
typeset -gi _DOTS_FAILURE_ANIMATION_LOADED=1

typeset -gi _DOTS_FAILURE_ANIMATION_PENDING=${_DOTS_FAILURE_ANIMATION_PENDING:-0}
typeset -gi _DOTS_FAILURE_ANIMATION_FD=-1
typeset -gi _DOTS_FAILURE_ANIMATION_PRODUCER_PID=0
typeset -gi _DOTS_FAILURE_ANIMATION_ACTIVE=0
typeset -gi _DOTS_FAILURE_ANIMATION_STEP=0
typeset -gi _DOTS_FAILURE_ANIMATION_STARTUP_PENDING=1
typeset -gi _DOTS_FAILURE_ANIMATION_FRAMES=0
typeset -gi _DOTS_FAILURE_ANIMATION_LAST_FRAMES=0
typeset -gi _DOTS_FAILURE_ANIMATION_GRADIENT_FRAMES=0
typeset -gi _DOTS_FAILURE_ANIMATION_LAST_BANNER_FRAMES=0
typeset -gi _DOTS_FAILURE_ANIMATION_GRADIENT_PHASE=0
typeset -g _DOTS_FAILURE_ANIMATION_STATE='loaded'
typeset -g _DOTS_FAILURE_ANIMATION_LAST_STATE=''
typeset -g _DOTS_FAILURE_ANIMATION_FRAME='💀'
typeset -g _DOTS_FAILURE_ANIMATION_STYLE='normal'
typeset -g _DOTS_FAILURE_ANIMATION_MODE='emoji'
typeset -g _DOTS_FAILURE_ANIMATION_BANNER=''
typeset -g _DOTS_FAILURE_ANIMATION_GRADIENT_MESSAGE=''
typeset -g _DOTS_FAILURE_ANIMATION_GRADIENT_LINE=''
typeset -g _DOTS_FAILURE_ANIMATION_GRADIENT_LINE_RAW=''
typeset -ga _DOTS_FAILURE_ANIMATION_POOL=()
typeset -ga _DOTS_FAILURE_GRADIENT_LINES=()
typeset -g _DOTS_FAILURE_ANIMATION_ORIGINAL_PROMPT="${PROMPT-}"
typeset -g _DOTS_FAILURE_ANIMATION_PROMPT_MODE='static'
typeset -g _DOTS_FAILURE_ANIMATION_LAST_RENDERED_PROMPT=''
typeset -g _DOTS_FAILURE_ANIMATION_INTERVAL='0.08'
typeset -g _DOTS_FAILURE_ANIMATION_GRADIENT_INTERVAL='0.08'
typeset -gi _DOTS_FAILURE_ANIMATION_HAS_ZSELECT=0

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

# Message templates carry ANSI SGR codes for their static form. Strip those
# before folding and per-character colouring; otherwise the escape bytes are
# counted as visible characters and the original colour codes are mangled.
_dots_failure_animation_plain_text() {
    emulate -L zsh
    setopt localoptions extendedglob

    local text="${1-}"
    text="${text//$'\e['[0-9;]##[[:alpha:]]/}"
    REPLY="$text"
}

_dots_failure_animation_valid_interval() {
    emulate -L zsh

    local value="${1-}"
    local fallback="${2:-0.08}"
    local minimum="${3:-0.01}"
    local maximum="${4:-1.0}"

    if [[ "$value" != <-> && "$value" != <->.<-> ]]; then
        REPLY="$fallback"
    elif (( value < minimum || value > maximum )); then
        REPLY="$fallback"
    else
        REPLY="$value"
    fi
}

# The worker emits "emoji_index phase" lines and nothing else. It sleeps with
# zselect, which is a builtin, so no external timer process can be orphaned.
# stdin and stderr are detached: the producer cannot consume typed input or
# write diagnostics over the user's screen.
_dots_failure_animation_producer() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    exec </dev/null 2>/dev/null
    trap 'exit 0' INT TERM HUP

    local style="${1:-normal}"
    local interval="${2:-0.08}"
    local -i emoji_ticks="${3:-12}"
    local -i gradient_ticks="${4:-0}"
    local -i infinite="${5:-0}"
    local -i delay=$(( interval * 100 + 0.5 ))

    _dots_failure_animation_pool_for_style "$style"
    local -i pool_size="${#_DOTS_FAILURE_ANIMATION_POOL}"
    local -i total=$(( emoji_ticks > gradient_ticks ? emoji_ticks : gradient_ticks ))
    (( total > 0 )) || return 0

    # The parent needs the real pid to terminate the worker on cleanup. In a
    # subshell $$ is the original shell, so use zsh/system's sysparams.
    print -r -- "pid ${sysparams[pid]:-0}" || return 0

    local -i tick=0 cycle=0 index=0 previous=0 phase=0
    while true; do
        for (( tick = 0; tick < total; tick++ )); do
            if (( _DOTS_FAILURE_ANIMATION_HAS_ZSELECT )); then
                zselect -t "$delay" 2>/dev/null || true
            else
                command sleep "$interval" 2>/dev/null || true
            fi

            index=0
            phase=0
            if (( tick < emoji_ticks && pool_size > 0 )); then
                index=$(( (RANDOM % pool_size) + 1 ))
                if (( pool_size > 1 && index == previous )); then
                    index=$(( (index % pool_size) + 1 ))
                fi
                previous=$index
            fi
            if (( cycle == 0 && tick < gradient_ticks )); then
                phase=$(( ((tick + 1) * 4) % 100 ))
            fi
            [[ -n "${DOTS_TEST_DIAG_LOG:-}" ]] &&
                print -r -- "P ${EPOCHREALTIME:-} ${tick}" >> "$DOTS_TEST_DIAG_LOG"
            print -r -- "$index $phase" || return 0
        done

        (( infinite )) || return 0
        (( cycle += 1 ))
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
    done

    _DOTS_FAILURE_ANIMATION_GRADIENT_LINE="$output"
    _DOTS_FAILURE_ANIMATION_GRADIENT_LINE_RAW="$raw_output"
}

# Fold plain text once, before animation starts. Frame updates only recolour
# these fixed lines, so the message never reflows between frames.
_dots_failure_animation_prepare_banner() {
    emulate -L zsh
    setopt localoptions no_ignore_braces extendedglob

    local style="${1:-normal}"
    local banner="${2-}"
    local detail="${3-}"
    [[ -n "$banner" && -o interactive && -t 0 && -t 1 ]] || return 1

    local -i columns="${COLUMNS:-0}" line_width=0
    (( columns > 2 )) || return 1
    line_width=$(( columns - 2 ))

    _dots_failure_animation_plain_text "$banner"
    local plain_banner="$REPLY"
    local folded
    local -a lines
    folded="$(print -rn -- "$plain_banner" | command fold -s -w "$line_width" 2>/dev/null)" || return 1
    lines=( "${(@f)folded}" )
    (( ${#lines} > 0 )) || return 1

    if [[ -n "$detail" ]]; then
        _dots_failure_animation_plain_text "↳ $detail"
        folded="$(print -rn -- "$REPLY" | command fold -s -w "$line_width" 2>/dev/null)" || return 1
        lines+=( "${(@f)folded}" )
    fi

    _dots_failure_animation_valid_interval "${DOTS_FAILURE_GRADIENT_INTERVAL:-0.08}" 0.08 0.01 1.0
    local interval="$REPLY"

    _DOTS_FAILURE_ANIMATION_STYLE="$style"
    _DOTS_FAILURE_ANIMATION_BANNER="$plain_banner"
    _DOTS_FAILURE_GRADIENT_LINES=( "${lines[@]}" )
    _DOTS_FAILURE_ANIMATION_GRADIENT_PHASE=0
    _DOTS_FAILURE_ANIMATION_GRADIENT_MESSAGE=''
    _DOTS_FAILURE_ANIMATION_GRADIENT_FRAMES=0
    _DOTS_FAILURE_ANIMATION_LAST_BANNER_FRAMES=0
    _DOTS_FAILURE_ANIMATION_GRADIENT_INTERVAL="$interval"
    return 0
}

_dots_failure_animation_render_gradient_message() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    local -i line=1 line_count="${#_DOTS_FAILURE_GRADIENT_LINES}"
    (( line_count > 0 )) || return 1

    local message=''
    for (( line = 1; line <= line_count; line++ )); do
        _dots_failure_animation_gradient_line \
            "${_DOTS_FAILURE_GRADIENT_LINES[line]}" \
            "$_DOTS_FAILURE_ANIMATION_STYLE" \
            "$_DOTS_FAILURE_ANIMATION_GRADIENT_PHASE"
        message+="${_DOTS_FAILURE_ANIMATION_GRADIENT_LINE}"
        (( line < line_count )) && message+=$'\n'
    done

    _DOTS_FAILURE_ANIMATION_GRADIENT_MESSAGE="$message"
}

_dots_failure_animation_cleanup() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    if (( _DOTS_FAILURE_ANIMATION_ACTIVE )); then
        _DOTS_FAILURE_ANIMATION_LAST_STATE="${_DOTS_FAILURE_ANIMATION_STATE}"
        _DOTS_FAILURE_ANIMATION_LAST_FRAMES=$_DOTS_FAILURE_ANIMATION_FRAMES
        _DOTS_FAILURE_ANIMATION_LAST_BANNER_FRAMES=$_DOTS_FAILURE_ANIMATION_GRADIENT_FRAMES

        local fd="$_DOTS_FAILURE_ANIMATION_FD"
        local -i producer_pid="$_DOTS_FAILURE_ANIMATION_PRODUCER_PID"

        if (( fd >= 0 )); then
            zle -F "$fd" 2>/dev/null || true
            { exec {fd}<&- } 2>/dev/null || true
        fi
        if (( producer_pid > 0 )); then
            kill -TERM "$producer_pid" 2>/dev/null || true
        fi

        _DOTS_FAILURE_ANIMATION_FD=-1
        _DOTS_FAILURE_ANIMATION_PRODUCER_PID=0
        _DOTS_FAILURE_ANIMATION_ACTIVE=0
        _DOTS_FAILURE_ANIMATION_STATE='finished'
    fi
}

# Widget handler installed with "zle -F -w". It owns both counters and is the
# only place that refreshes the wrapped prompt.
_dots_failure_animation_fd_handler() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    local fd="${1:-}"
    local line emoji phase
    [[ -n "${DOTS_TEST_DIAG_LOG:-}" ]] &&
        print -r -- "H ${EPOCHREALTIME:-} ${_DOTS_FAILURE_ANIMATION_FRAMES}" >> "$DOTS_TEST_DIAG_LOG"
    if [[ -z "$fd" ]] || ! IFS= builtin read -r -u "$fd" line; then
        _DOTS_FAILURE_ANIMATION_STATE='stream-complete'
        _dots_failure_animation_cleanup
        return 0
    fi

    if [[ "$line" == 'pid '* && "${line#pid }" == <-> ]]; then
        _DOTS_FAILURE_ANIMATION_PRODUCER_PID="${line#pid }"
        return 0
    fi

    emoji="${line%% *}"
    phase=0
    if [[ "$line" == *' '* ]]; then
        phase="${line##* }"
    fi
    [[ "$emoji" == <-> ]] || emoji=0
    [[ "$phase" == <-> ]] || phase=0

    local -i emoji_changed=0 gradient_changed=0
    if (( emoji > 0 && emoji <= ${#_DOTS_FAILURE_ANIMATION_POOL} )); then
        _DOTS_FAILURE_ANIMATION_FRAME="${_DOTS_FAILURE_ANIMATION_POOL[emoji]}"
        (( _DOTS_FAILURE_ANIMATION_STEP += 1 ))
        (( _DOTS_FAILURE_ANIMATION_FRAMES += 1 ))
        emoji_changed=1
    fi

    if [[ "$_DOTS_FAILURE_ANIMATION_MODE" == gradient ]] &&
        (( phase > 0 && phase < 100 )); then
        _DOTS_FAILURE_ANIMATION_GRADIENT_PHASE="$phase"
        if _dots_failure_animation_render_gradient_message; then
            (( _DOTS_FAILURE_ANIMATION_GRADIENT_FRAMES += 1 ))
            (( _DOTS_FAILURE_ANIMATION_LAST_BANNER_FRAMES = _DOTS_FAILURE_ANIMATION_GRADIENT_FRAMES ))
            gradient_changed=1
        fi
    fi

    if (( emoji_changed || gradient_changed )); then
        _DOTS_FAILURE_ANIMATION_STATE='frame-rendered'
        # Re-expanding the wrapped prompt is the only display operation. ZLE
        # keeps the edit buffer, cursor, and completion state; the producer
        # never touches the terminal itself.
        zle .reset-prompt
    fi
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

    # Prompt emoji animation stays on the input line and never becomes part of
    # the gradient block or its counters.
    local marker="${DOTS_FAILURE_ANIMATION_PROMPT_MARKER:-❯}"
    if [[ -n "$marker" ]]; then
        local marker_pattern="${(b)marker}"
        if [[ "$rendered" == *"$marker"* ]]; then
            # Strip earlier copies as well: Starship modules can leave a marker
            # before the final input marker (for example after the exit code).
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

    # Keep the gradient immediately above the editable input line. When the
    # original prompt has several lines, insert the block after the last
    # newline so status/path lines stay above it; otherwise place it above the
    # single-line prompt.
    if [[ "$_DOTS_FAILURE_ANIMATION_MODE" == gradient &&
        -n "$_DOTS_FAILURE_ANIMATION_GRADIENT_MESSAGE" ]]; then
        if [[ "$rendered" == *$'\n'* ]]; then
            local prompt_prefix="${rendered%$'\n'*}"
            local input_line="${rendered##*$'\n'}"
            rendered="${prompt_prefix}"$'\n'"${_DOTS_FAILURE_ANIMATION_GRADIENT_MESSAGE}"$'\n'"${input_line}"
        else
            rendered="${_DOTS_FAILURE_ANIMATION_GRADIENT_MESSAGE}"$'\n'"${rendered}"
        fi
    fi

    _DOTS_FAILURE_ANIMATION_LAST_RENDERED_PROMPT="$rendered"
    print -rn -- "$rendered"
}

# Start one producer session for the current edit line. The producer is
# registered from precmd, before ZLE starts. The initial phase-0 block is
# already part of the prompt; the remaining 24 phases arrive from the pipe.
_dots_failure_animation_begin() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    (( _DOTS_FAILURE_ANIMATION_ACTIVE )) && return 0
    [[ -o interactive && -o zle && -t 0 && -t 1 &&
        "${TERM:-dumb}" != dumb &&
        "${DOTS_FAILURE_ANIMATION:-1}" != 0 ]] || return 0

    local style="${_DOTS_FAILURE_ANIMATION_STYLE:-normal}"
    _dots_failure_animation_pool_for_style "$style"

    local -i emoji_ticks=12 gradient_ticks=0 infinite=0
    _dots_failure_animation_valid_interval "${DOTS_FAILURE_ANIMATION_INTERVAL:-0.08}" 0.08 0.01 2.0
    local interval="$REPLY"
    _DOTS_FAILURE_ANIMATION_INTERVAL="$interval"

    if [[ "$_DOTS_FAILURE_ANIMATION_MODE" == gradient ]]; then
        # 24 pipe phases plus the phase-0 block already in the prompt.
        gradient_ticks=24
        emoji_ticks=24
        interval="$_DOTS_FAILURE_ANIMATION_GRADIENT_INTERVAL"
    fi

    _dots_failure_animation_infinite_enabled && infinite=1

    _DOTS_FAILURE_ANIMATION_STEP=0
    _DOTS_FAILURE_ANIMATION_FRAMES=0
    _DOTS_FAILURE_ANIMATION_PRODUCER_PID=0
    _DOTS_FAILURE_ANIMATION_STATE='starting'

    exec {_DOTS_FAILURE_ANIMATION_FD}< <(
        _dots_failure_animation_producer "$style" "$interval" "$emoji_ticks" "$gradient_ticks" "$infinite"
    ) || {
        _DOTS_FAILURE_ANIMATION_FD=-1
        _DOTS_FAILURE_ANIMATION_STATE='start-failed'
        return 1
    }

    _DOTS_FAILURE_ANIMATION_ACTIVE=1
    if zle -F -w "$_DOTS_FAILURE_ANIMATION_FD" _dots_failure_animation_fd_handler; then
        _DOTS_FAILURE_ANIMATION_STATE='registered'
    else
        _DOTS_FAILURE_ANIMATION_STATE='registration-failed'
        _dots_failure_animation_cleanup
        return 1
    fi
}

# Queue a failure message. The template may still contain the static colour
# codes used by the non-animated renderer; prepare_banner strips them.
_dots_failure_animation_start() {
    emulate -L zsh
    setopt localoptions no_ignore_braces

    [[ -o interactive && -o zle && -t 0 && -t 1 &&
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
    _DOTS_FAILURE_ANIMATION_MODE='emoji'
    _DOTS_FAILURE_ANIMATION_BANNER=''
    _DOTS_FAILURE_GRADIENT_LINES=()
    _DOTS_FAILURE_ANIMATION_GRADIENT_MESSAGE=''
    _DOTS_FAILURE_ANIMATION_GRADIENT_FRAMES=0
    _DOTS_FAILURE_ANIMATION_LAST_BANNER_FRAMES=0

    if [[ -n "$banner" ]]; then
        if _dots_failure_animation_prepare_banner "$style" "$banner" "$detail"; then
            _DOTS_FAILURE_ANIMATION_GRADIENT_PHASE=0
            if _dots_failure_animation_render_gradient_message; then
                _DOTS_FAILURE_ANIMATION_MODE='gradient'
                # The phase-0 block is the first visible frame.
                _DOTS_FAILURE_ANIMATION_GRADIENT_FRAMES=1
                _DOTS_FAILURE_ANIMATION_LAST_BANNER_FRAMES=1
                _DOTS_FAILURE_ANIMATION_PENDING=1
                _DOTS_FAILURE_ANIMATION_STATE='gradient-pending'
                return 0
            fi
        fi
        return 1
    fi

    _DOTS_FAILURE_ANIMATION_PENDING=1
    return 0
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

_dots_failure_animation_precmd() {
    emulate -L zsh

    [[ -o interactive && -t 0 && -t 1 ]] || return 0

    # The previous prompt (including its final gradient frame) is already
    # ordinary scrollback by the time precmd runs. Drop the block before the
    # next prompt unless a failure hook has queued a new one in this precmd.
    # Ctrl+C bypasses zle-line-finish, so stop any worker that is still active
    # before clearing the block; otherwise it would keep firing frames for a
    # prompt that no longer shows a gradient.
    if (( ! _DOTS_FAILURE_ANIMATION_PENDING )) &&
        [[ "$_DOTS_FAILURE_ANIMATION_MODE" == gradient ]]; then
        _dots_failure_animation_cleanup
        _DOTS_FAILURE_ANIMATION_MODE='emoji'
        _DOTS_FAILURE_ANIMATION_BANNER=''
        _DOTS_FAILURE_GRADIENT_LINES=()
        _DOTS_FAILURE_ANIMATION_GRADIENT_MESSAGE=''
        _DOTS_FAILURE_ANIMATION_GRADIENT_PHASE=0
        _DOTS_FAILURE_ANIMATION_GRADIENT_FRAMES=0
    fi

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
    _DOTS_FAILURE_GRADIENT_LINES=()
    _DOTS_FAILURE_ANIMATION_GRADIENT_MESSAGE=''
    _DOTS_FAILURE_ANIMATION_MODE='emoji'
    _DOTS_FAILURE_ANIMATION_STYLE='normal'
    _DOTS_FAILURE_ANIMATION_GRADIENT_PHASE=0
    _DOTS_FAILURE_ANIMATION_GRADIENT_FRAMES=0
}

# Accepting the line must leave the last painted block on screen: ZLE commits
# the current prompt to scrollback and prints command output below it. The next
# precmd clears the block before drawing the following prompt, so the message
# is preserved exactly once as ordinary terminal text.
_dots_failure_animation_line_finish() {
    emulate -L zsh

    _dots_failure_animation_cleanup
    _DOTS_FAILURE_ANIMATION_PENDING=0
}

# Ctrl+C invokes send-break without running zle-line-finish. Stop the producer
# before the built-in widget resets the line. The last visible frame remains in
# scrollback, just like ordinary failure output.
_dots_failure_animation_send_break() {
    emulate -L zsh

    _dots_failure_animation_reset
    zle _dots_failure_animation_previous_send_break 2>/dev/null || zle .send-break
}

_dots_failure_animation_clear_screen_widget() {
    emulate -L zsh

    _dots_failure_animation_reset
    zle _dots_failure_animation_previous_clear_screen 2>/dev/null || zle .clear-screen
}

if [[ -o interactive ]] && (( ! ${+_DOTS_FAILURE_ANIMATION_INSTALLED} )); then
    typeset -gi _DOTS_FAILURE_ANIMATION_INSTALLED=1
    autoload -Uz add-zsh-hook add-zle-hook-widget
    if zmodload zsh/zselect 2>/dev/null; then
        _DOTS_FAILURE_ANIMATION_HAS_ZSELECT=1
    fi
    zmodload zsh/system 2>/dev/null || true

    add-zsh-hook precmd _dots_failure_animation_precmd
    add-zsh-hook preexec _dots_failure_animation_preexec
    add-zle-hook-widget zle-line-finish _dots_failure_animation_line_finish

    zle -N _dots_failure_animation_fd_handler
    zle -N _dots_failure_animation_send_break
    zle -N _dots_failure_animation_clear_screen_widget

    # Preserve any plugin wrapper that was installed before this module.
    zle -A send-break _dots_failure_animation_previous_send_break 2>/dev/null || true
    zle -A clear-screen _dots_failure_animation_previous_clear_screen 2>/dev/null || true
    zle -N send-break _dots_failure_animation_send_break
    zle -N clear-screen _dots_failure_animation_clear_screen_widget
fi

# Autonomous, style-aware prompt and failure-message animations for interactive Zsh.
#
# Failure gradients are rendered directly in terminal output as autonomous
# scrollback messages. Dedicated 256-color palette slots are updated via OSC 4
# in a background worker, so gradients animate in their original scrollback
# position independently of user typing, Enter, command execution, or prompt redraws.
#
# Prompt emoji frames continue to animate before the input marker via ZLE.

typeset -gi _DOTS_FAILURE_ANIMATION_PENDING=${_DOTS_FAILURE_ANIMATION_PENDING:-0}
typeset -gi _DOTS_FAILURE_ANIMATION_FD=-1
typeset -gi _DOTS_FAILURE_ANIMATION_STEP=0
typeset -gi _DOTS_FAILURE_ANIMATION_ACTIVE=0
typeset -gi _DOTS_FAILURE_ANIMATION_STARTUP_PENDING=1
typeset -gi _DOTS_FAILURE_ANIMATION_FRAMES=0
typeset -gi _DOTS_FAILURE_ANIMATION_LAST_FRAMES=0
typeset -gi _DOTS_FAILURE_ANIMATION_LAST_BANNER_FRAMES=0
typeset -gi _DOTS_FAILURE_GRADIENT_ACTIVE=0
typeset -gi _DOTS_FAILURE_GRADIENT_SUBMITTED=0
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

# Palette allocation pool: 5 concurrent blocks of 12 slots each (slots 180-239)
typeset -gi _DOTS_FAILURE_GRADIENT_NUM_BLOCKS=5
typeset -gi _DOTS_FAILURE_GRADIENT_BLOCK_SIZE=12
typeset -gi _DOTS_FAILURE_GRADIENT_BASE_SLOT=180
typeset -ga _DOTS_FAILURE_GRADIENT_PIDS=(0 0 0 0 0)
typeset -ga _DOTS_FAILURE_GRADIENT_TIMES=(0 0 0 0 0)
typeset -gi _DOTS_FAILURE_GRADIENT_LAST_PID=0

if [[ "$_DOTS_FAILURE_ANIMATION_ORIGINAL_PROMPT" == '$('*')' ]]; then
    _DOTS_FAILURE_ANIMATION_PROMPT_MODE='command'
fi

# Starship enables promptsubst itself; keep it enabled for a static fallback.
setopt promptsubst
PROMPT='$(_dots_failure_animation_render_prompt)'

_dots_failure_animation_infinite_enabled() {
    emulate -L zsh

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

_dots_failure_animation_get_palette() {
    emulate -L zsh
    local style="${1:-normal}"
    case "$style" in
        mythic)
            reply=(
                '0f/11/15' '1b/1e/24' '2b/2f/37' '3e/44/4e'
                '55/5d/69' '73/7c/89' '97/a0/ab' 'be/c5/cd'
                'dc/e0/e5' 'a7/af/b9' '69/71/7c' '30/35/3e'
            )
            ;;
        legendary)
            reply=(
                '4a/32/0c' '69/4a/11' '8b/65/1a' 'ae/84/27'
                'cf/a6/3e' 'ed/ca/69' 'ff/e7/9f' 'ff/f5/cf'
                'eb/cb/77' 'be/91/37' '89/60/1b' '5b/3d/10'
            )
            ;;
        rainbow)
            reply=(
                'ff/52/52' 'ff/91/40' 'ff/cf/4b' 'a5/dc/50'
                '46/d2/82' '3c/be/d2' '50/8c/f5' '82/6e/ff'
                'b9/64/f5' 'e6/69/c3' 'ff/73/96' 'ff/52/52'
            )
            ;;
        anime)
            reply=(
                'ff/be/dc' 'f9/a6/d8' 'ef/96/dc' 'dc/91/e2'
                'c6/96/eb' 'b0/a2/f3' 'a0/b2/fa' 'be/ad/fa'
                'dc/a3/ef' 'f5/9d/dd' 'ff/b2/dc' 'ff/be/dc'
            )
            ;;
        ecchi)
            reply=(
                '78/18/46' '9b/22/53' 'be/2d/62' 'e1/41/78'
                'ff/5c/91' 'ff/82/aa' 'ff/a5/be' 'ff/82/aa'
                'e1/41/78' 'be/2d/62' '9b/22/53' '78/18/46'
            )
            ;;
        *)
            reply=(
                '24/7b/a0' '45/82/a0' '59/91/a4' '78/9a/b1'
                '94/a3/b8' 'a6/ad/c8' 'b1/9d/d2' 'ca/9e/e6'
                'd2/91/bc' 'db/8f/aa' 'ca/99/a9' 'a6/ad/c8'
            )
            ;;
    esac
}

_dots_failure_palette_write() {
    emulate -L zsh
    local sequence="${1-}"
    local -i tty_fd="${2:--1}"
    [[ -n "$sequence" ]] || return 1

    if [[ -n "${TMUX:-}" ]]; then
        local escape=$'\e'
        local passthrough="${sequence//${escape}/${escape}${escape}}"
        sequence=$'\ePtmux;'"${passthrough}"$'\e\\'
    fi

    if (( tty_fd >= 0 )); then
        print -rn -u "$tty_fd" -- "$sequence" 2>/dev/null || true
    else
        print -rn -- "$sequence" > /dev/tty 2>/dev/null ||
            print -rn -- "$sequence" 2>/dev/null || true
    fi
}

_dots_failure_gradient_active_count() {
    emulate -L zsh
    local -i i count=0 pid=0
    for (( i = 1; i <= ${#_DOTS_FAILURE_GRADIENT_PIDS}; i++ )); do
        pid=${_DOTS_FAILURE_GRADIENT_PIDS[i]}
        if (( pid > 0 )) && kill -0 "$pid" 2>/dev/null; then
            (( count += 1 ))
        else
            _DOTS_FAILURE_GRADIENT_PIDS[i]=0
        fi
    done
    REPLY=$count
}

_dots_failure_gradient_kill_all() {
    emulate -L zsh
    local -i i=0 pid=0
    for (( i = 1; i <= ${#_DOTS_FAILURE_GRADIENT_PIDS}; i++ )); do
        pid=${_DOTS_FAILURE_GRADIENT_PIDS[i]}
        if (( pid > 0 )) && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
        _DOTS_FAILURE_GRADIENT_PIDS[i]=0
        _DOTS_FAILURE_GRADIENT_TIMES[i]=0
    done
    _DOTS_FAILURE_GRADIENT_ACTIVE=0
}

_dots_failure_gradient_allocate_block() {
    emulate -L zsh
    local -i i=0 pid=0
    for (( i = 1; i <= _DOTS_FAILURE_GRADIENT_NUM_BLOCKS; i++ )); do
        pid=${_DOTS_FAILURE_GRADIENT_PIDS[i]}
        if (( pid == 0 )) || ! kill -0 "$pid" 2>/dev/null; then
            _DOTS_FAILURE_GRADIENT_PIDS[i]=0
            REPLY=$(( i - 1 ))
            return 0
        fi
    done

    # All blocks busy: reclaim the oldest running worker
    local -i oldest_block=0 oldest_time=0 cur_time=0
    oldest_time=${_DOTS_FAILURE_GRADIENT_TIMES[1]}
    for (( i = 2; i <= _DOTS_FAILURE_GRADIENT_NUM_BLOCKS; i++ )); do
        cur_time=${_DOTS_FAILURE_GRADIENT_TIMES[i]}
        if (( cur_time < oldest_time )); then
            oldest_time=$cur_time
            oldest_block=$(( i - 1 ))
        fi
    done

    pid=${_DOTS_FAILURE_GRADIENT_PIDS[oldest_block + 1]}
    if (( pid > 0 )) && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
    fi
    REPLY=$oldest_block
    return 0
}

_dots_failure_gradient_worker() {
    emulate -L zsh
    local -i block_id=$1
    local -i base_slot=$2
    local style="${3:-normal}"
    local interval="${4:-0.08}"
    local -i tty_fd="${5:--1}"
    local -i total_frames="${6:-25}"
    local -i frame=0 offset=0 phase=0 color_index=0 position=0 slot=0
    local sequence=""
    local -a colors

    _dots_failure_animation_get_palette "$style"
    colors=( "${reply[@]}" )
    local -i color_count="${#colors}"
    (( color_count > 0 )) || return 0

    for (( frame = 1; frame < total_frames; frame++ )); do
        command sleep "$interval" 2>/dev/null || break
        phase=$(( (frame * 4) % 100 ))
        sequence=""
        for (( offset = 0; offset < 12; offset++ )); do
            slot=$(( base_slot + offset ))
            position=$(( (((offset * 100 / 11) - phase + 100) % 100) ))
            color_index=$(( (position * color_count / 100) + 1 ))
            (( color_index > color_count )) && color_index=$color_count
            sequence+=";${slot};rgb:${colors[color_index]}"
        done
        _dots_failure_palette_write $'\e]4'"${sequence}"$'\e\\' "$tty_fd"
    done
    if (( tty_fd >= 0 )); then
        exec {tty_fd}>&- 2>/dev/null || true
    fi
}

_dots_failure_animation_format_gradient_line() {
    emulate -L zsh
    local text="${1-}"
    local -i base_slot=$2
    local -a characters
    characters=( "${(@s::)text}" )
    local -i length=${#characters[@]}
    if (( length == 0 )); then
        REPLY=""
        return 0
    fi
    local -i denominator=$(( length > 1 ? length - 1 : 1 ))
    local -i index=0 slot=0
    local out="" reset_color=$'\e[0m'
    for (( index = 1; index <= length; index++ )); do
        slot=$(( base_slot + ((index - 1) * 11 / denominator) ))
        out+=$'\e[38;5;'"${slot}m${characters[index]}${reset_color}"
    done
    REPLY="$out"
}

_dots_failure_animation_gradient_line() {
    emulate -L zsh

    local message="${1-}"
    local style="${2:-legendary}"
    local phase="${3:-0}"
    local character output='' raw_output='' reset_color=$'\e[0m'
    local -a characters colors
    local -i length=0 denominator=1 position=0 color_index=1 index=0 color_count=0

    characters=( "${(@s::)message}" )
    length="${#characters[@]}"
    if (( length == 0 )); then
        characters=("$message")
        length=1
    fi

    case "$style" in
        mythic)
            colors=(
                $'\e[38;2;15;17;21m' $'\e[38;2;27;30;36m' $'\e[38;2;43;47;55m'
                $'\e[38;2;62;68;78m' $'\e[38;2;85;93;105m' $'\e[38;2;115;124;137m'
                $'\e[38;2;151;160;171m' $'\e[38;2;190;197;205m' $'\e[38;2;220;224;229m'
                $'\e[38;2;167;175;185m' $'\e[38;2;105;113;124m' $'\e[38;2;48;53;62m'
            )
            ;;
        legendary)
            colors=(
                $'\e[38;2;74;50;12m' $'\e[38;2;105;74;17m' $'\e[38;2;139;101;26m'
                $'\e[38;2;174;132;39m' $'\e[38;2;207;166;62m' $'\e[38;2;237;202;105m'
                $'\e[38;2;255;231;159m' $'\e[38;2;255;245;207m' $'\e[38;2;235;203;119m'
                $'\e[38;2;190;145;55m' $'\e[38;2;137;96;27m' $'\e[38;2;91;61;16m'
            )
            ;;
        rainbow)
            colors=(
                $'\e[38;2;255;82;82m' $'\e[38;2;255;145;64m' $'\e[38;2;255;207;75m'
                $'\e[38;2;165;220;80m' $'\e[38;2;70;210;130m' $'\e[38;2;60;190;210m'
                $'\e[38;2;80;140;245m' $'\e[38;2;130;110;255m' $'\e[38;2;185;100;245m'
                $'\e[38;2;230;105;195m' $'\e[38;2;255;115;150m' $'\e[38;2;255;82;82m'
            )
            ;;
        anime)
            colors=(
                $'\e[38;2;255;190;220m' $'\e[38;2;249;166;216m' $'\e[38;2;239;150;220m'
                $'\e[38;2;220;145;226m' $'\e[38;2;198;150;235m' $'\e[38;2;176;162;243m'
                $'\e[38;2;160;178;250m' $'\e[38;2;190;173;250m' $'\e[38;2;220;163;239m'
                $'\e[38;2;245;157;221m' $'\e[38;2;255;178;220m' $'\e[38;2;255;190;220m'
            )
            ;;
        ecchi)
            colors=(
                $'\e[38;2;120;24;70m' $'\e[38;2;155;34;83m' $'\e[38;2;190;45;98m'
                $'\e[38;2;225;65;120m' $'\e[38;2;255;92;145m' $'\e[38;2;255;130;170m'
                $'\e[38;2;255;165;190m' $'\e[38;2;255;130;170m' $'\e[38;2;225;65;120m'
                $'\e[38;2;190;45;98m' $'\e[38;2;155;34;83m' $'\e[38;2;120;24;70m'
            )
            ;;
        *)
            colors=(
                $'\e[38;2;36;123;160m' $'\e[38;2;69;130;160m' $'\e[38;2;89;145;164m'
                $'\e[38;2;120;154;177m' $'\e[38;2;148;163;184m' $'\e[38;2;166;173;200m'
                $'\e[38;2;177;157;210m' $'\e[38;2;202;158;230m' $'\e[38;2;210;145;188m'
                $'\e[38;2;219;143;170m' $'\e[38;2;202;153;169m' $'\e[38;2;166;173;200m'
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
        if [[ "$character" == '%' ]]; then
            character='%%'
        fi
        output+="%{${colors[color_index]}%}${character}%{${reset_color}%}"
    done

    _DOTS_FAILURE_ANIMATION_GRADIENT_LINE="$output"
    _DOTS_FAILURE_ANIMATION_GRADIENT_LINE_RAW="$raw_output"
}

_dots_failure_animation_render_prompt() {
    emulate -L zsh

    local rendered=''
    if [[ "$_DOTS_FAILURE_ANIMATION_PROMPT_MODE" == command ]]; then
        local prompt_command="${_DOTS_FAILURE_ANIMATION_ORIGINAL_PROMPT[3,-2]}"
        rendered="$(eval "$prompt_command")"
    else
        rendered="${_DOTS_FAILURE_ANIMATION_ORIGINAL_PROMPT}"
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
    (( _DOTS_FAILURE_ANIMATION_FRAMES += 1 ))
    _DOTS_FAILURE_ANIMATION_FRAME="$frame"
    _DOTS_FAILURE_ANIMATION_STATE='frame-rendered'
    zle && zle .reset-prompt
}

_dots_failure_animation_start() {
    emulate -L zsh

    [[ -o interactive && -t 1 &&
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

    # If there is no banner, just trigger prompt emoji animation
    if [[ -z "$banner" ]]; then
        _DOTS_FAILURE_ANIMATION_STYLE="$style"
        _DOTS_FAILURE_ANIMATION_MODE='emoji'
        _DOTS_FAILURE_ANIMATION_PENDING=1
        return 0
    fi

    local -i columns="${COLUMNS:-80}" line_width=0
    (( columns > 2 )) || columns=80
    line_width=$(( columns - 2 ))

    local -a lines=()
    local folded
    folded="$(print -rn -- "$banner" | command fold -s -w "$line_width" 2>/dev/null)" || folded="$banner"
    lines=( "${(@f)folded}" )
    if [[ -n "$detail" ]]; then
        local detail_folded
        detail_folded="$(print -rn -- "  ↳ $detail" | command fold -s -w "$line_width" 2>/dev/null)" || detail_folded="  ↳ $detail"
        lines+=( "${(@f)detail_folded}" )
    fi

    local -i block_id
    _dots_failure_gradient_allocate_block
    block_id=$REPLY
    local -i base_slot=$(( _DOTS_FAILURE_GRADIENT_BASE_SLOT + block_id * _DOTS_FAILURE_GRADIENT_BLOCK_SIZE ))

    local interval="${DOTS_FAILURE_GRADIENT_INTERVAL:-0.08}"
    if [[ "$interval" != <-> && "$interval" != <->.<-> ]]; then
        interval=0.08
    elif (( interval < 0.01 || interval > 1.0 )); then
        interval=0.08
    fi

    # Prepare initial palette colors (phase 0)
    local -a colors
    _dots_failure_animation_get_palette "$style"
    colors=( "${reply[@]}" )
    local -i color_count="${#colors}"
    local initial_seq=""
    local -i offset=0 slot=0
    for (( offset = 0; offset < 12; offset++ )); do
        slot=$(( base_slot + offset ))
        initial_seq+=";${slot};rgb:${colors[offset + 1]}"
    done

    # Open TTY descriptor for worker
    local tty_fd=-1
    exec {tty_fd}>/dev/tty 2>/dev/null || exec {tty_fd}>&1

    # Send initial palette definitions
    _dots_failure_palette_write $'\e]4'"${initial_seq}"$'\e\\' "$tty_fd"

    # Print formatted lines to terminal stdout
    local line
    for line in "${lines[@]}"; do
        _dots_failure_animation_format_gradient_line "$line" "$base_slot"
        print -r -- "$REPLY"
    done

    # Spawn autonomous background worker
    local worker_pid
    ( _dots_failure_gradient_worker "$block_id" "$base_slot" "$style" "$interval" "$tty_fd" 25 ) </dev/null >/dev/null 2>&1 &!
    worker_pid=$!
    _DOTS_FAILURE_GRADIENT_PIDS[block_id + 1]=$worker_pid
    _DOTS_FAILURE_GRADIENT_TIMES[block_id + 1]=${EPOCHSECONDS:-$(( $(date +%s 2>/dev/null || echo 0) ))}
    _DOTS_FAILURE_GRADIENT_LAST_PID=$worker_pid
    _DOTS_FAILURE_GRADIENT_ACTIVE=1
    _DOTS_FAILURE_ANIMATION_LAST_BANNER_FRAMES=1
    _DOTS_FAILURE_ANIMATION_STATE='gradient-running'

    # Trigger emoji animation for prompt marker
    _DOTS_FAILURE_ANIMATION_STYLE="$style"
    _DOTS_FAILURE_ANIMATION_MODE='emoji'
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

    _dots_failure_gradient_active_count
    if (( REPLY > 0 )); then
        _DOTS_FAILURE_GRADIENT_ACTIVE=1
    else
        _DOTS_FAILURE_GRADIENT_ACTIVE=0
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
    _dots_failure_gradient_kill_all
    _DOTS_FAILURE_GRADIENT_PENDING=0
    _DOTS_FAILURE_GRADIENT_SUBMITTED=0
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

    # Ordinary prompt emoji animation is tied to line submission unless infinite.
    if ! _dots_failure_animation_infinite_enabled; then
        _dots_failure_animation_cleanup
    fi
}

if [[ -o interactive ]]; then
    autoload -Uz add-zsh-hook add-zle-hook-widget
    add-zsh-hook precmd _dots_failure_animation_precmd
    add-zsh-hook preexec _dots_failure_animation_preexec
    add-zsh-hook zshexit _dots_failure_gradient_kill_all
    add-zle-hook-widget zle-line-finish _dots_failure_animation_line_finish
    zle -N clear-screen _dots_failure_animation_clear_screen_widget
fi

# Shared message rendering for interactive Zsh command failures.
#
# This module deliberately does not detect failures or install shell hooks.
# Source it from .zshrc when the failure handler is ready to call
# dots_failure_message CATEGORY COMMAND [DETAIL].
#
# Optional user configuration:
#   DOTS_FAILURE_MESSAGE_CHANCE=100       # 0..100; percentage of failures shown
#   DOTS_FAILURE_STYLE=auto              # normal|anime|ecchi|sarcastic|dramatic|rainbow|legendary|mythic
#   DOTS_FAILURE_LEGENDARY_CHANCE=2      # 0..100; rainbow/rare names remain aliases
#   DOTS_FAILURE_MYTHIC_CHANCE=1          # 0..1000 per mille; default 1 = 0.1%
#   DOTS_FAILURE_GRADIENT_INTERVAL=0.08   # seconds between message gradient frames
#   DOTS_FAILURE_ANIMATION_CHANCE=100     # 0..100; message gradient animation chance
#   DOTS_FAILURE_ANIMATION=0              # disable animation independently
#   DOTS_FAILURE_MESSAGE_ESCALATION=1     # set to 0 to disable repeat escalation
#   NO_COLOR=1                            # disable ANSI colours

typeset -g _DOTS_FAILURE_MESSAGE_LAST_KEY=''
typeset -g _DOTS_FAILURE_MESSAGE_LAST_TEMPLATE=''
typeset -gi _DOTS_FAILURE_MESSAGE_STREAK=0

_dots_failure_message_sanitize() {
    emulate -L zsh

    local value="${1-}"
    REPLY="${value//[[:cntrl:]]/ }"
}


_dots_failure_message_rainbow() {
    emulate -L zsh

    local message="${1-}"
    # Rainbow ANSI output is useful only on a colour-capable interactive
    # terminal. Redirected output and NO_COLOR stay plain and copyable.
    if [[ ! -t 1 || -n "${NO_COLOR:-}" || "${TERM:-dumb}" == dumb ]]; then
        print -r -- "$message"
        return 0
    fi

    # Twelve RGB stops add pink, teal, indigo, and warm sunset tones.
    local -a characters colors
    characters=( "${(@s::)message}" )
    colors=(
        $'\e[38;2;255;92;124m'
        $'\e[38;2;255;146;93m'
        $'\e[38;2;255;207;102m'
        $'\e[38;2;190;230;105m'
        $'\e[38;2;91;218;151m'
        $'\e[38;2;68;211;205m'
        $'\e[38;2;92;190;255m'
        $'\e[38;2;112;145;255m'
        $'\e[38;2;157;125;255m'
        $'\e[38;2;206;124;255m'
        $'\e[38;2;255;122;211m'
        $'\e[38;2;255;165;190m'
    )

    local character
    local -i index=$(( (RANDOM % ${#colors[@]}) + 1 ))
    for character in "${characters[@]}"; do
        print -rn -- "${colors[index]}${character}"
        (( index = index % ${#colors[@]} + 1 ))
    done
    print -r -- $'\e[0m'
}

_dots_failure_message_gradient() {
    emulate -L zsh

    local style="${1:-legendary}"
    local message="${2-}"
    local palette_active="${3:-0}"
    if [[ ! -t 1 || -n "${NO_COLOR:-}" || "${TERM:-dumb}" == dumb ]]; then
        print -r -- "$message"
        return 0
    fi

    local -a characters legendary_colors mythic_colors colors
    characters=( "${(@s::)message}" )
    legendary_colors=(
        '255;91;132' '255;119;108' '255;150;92' '255;180;93'
        '255;208;101' '236;224;105' '201;226;108' '163;222;122'
        '125;217;154' '92;212;185' '84;198;223' '92;168;245'
        '120;139;255' '160;123;255' '201;121;240' '237;120;189'
    )
    mythic_colors=(
        '245;245;247' '229;230;234' '212;214;219' '194;197;204'
        '176;179;189' '158;162;173' '140;145;158' '122;128;142'
        '104;110;124' '87;93;108' '70;76;91' '54;60;75'
        '41;47;62' '32;38;52' '24;29;42' '16;20;31'
    )
    if [[ "$style" == mythic ]]; then colors=( "${mythic_colors[@]}" ); else colors=( "${legendary_colors[@]}" ); fi

    local -i character_index=0 character_count=${#characters[@]} color_index=1 palette_base=208
    [[ "$style" == mythic ]] && palette_base=224
    local character color
    for character in "${characters[@]}"; do
        if (( character_count > 1 )); then
            color_index=$(( (character_index * 15 / (character_count - 1)) + 1 ))
        fi
        if [[ "$palette_active" == 1 ]]; then
            printf '\e[38;5;%dm%s' "$((palette_base + color_index - 1))" "$character"
        else
            printf '\e[38;2;%sm%s' "${colors[color_index]}" "$character"
        fi
        (( character_index += 1 ))
    done
    printf '\e[0m\n'
}

_dots_failure_message_animate() {
    emulate -L zsh

    # Pass the final style and, for rare events, the complete banner plus detail.
    # Return failure when no interactive animator is available so the caller
    # can preserve the static fallback message.
    (( ${+functions[_dots_failure_animation_start]} )) || return 1
    _dots_failure_animation_start "${1:-normal}" "${2-}" "${3-}"
}

# Resolve the data engine relative to this module, not the shell's current directory.
typeset -g _DOTS_FAILURE_MESSAGE_SOURCE_FILE="${${(%):-%x}:A}"
typeset -g _DOTS_FAILURE_MESSAGE_ENGINE="${_DOTS_FAILURE_MESSAGE_SOURCE_FILE:h}/failure-message-engine.py"

dots_failure_message() {
    emulate -L zsh
    setopt localoptions no_aliases

    local category="${1:-generic}"
    category="${category:l}"
    local command_text="${2:-unknown}"
    local detail="${3:-}"
    local username="${USER:-${LOGNAME:-user}}"

    _dots_failure_message_sanitize "$command_text"
    command_text="$REPLY"
    _dots_failure_message_sanitize "$detail"
    detail="$REPLY"
    _dots_failure_message_sanitize "$username"
    username="$REPLY"

    case "$category" in
        not_found|permission|missing_path|git|nix|network|generic) ;;
        *) category=generic ;;
    esac

    local chance="${DOTS_FAILURE_MESSAGE_CHANCE:-100}"
    case "$chance" in
        (''|*[!0-9]*) chance=100 ;;
    esac
    while [[ "$chance" == 0* && "$chance" != 0 ]]; do chance="${chance#0}"; done
    (( chance > 100 )) && chance=100
    (( chance == 0 || RANDOM % 100 >= chance )) && return 0

    local failure_key="${category}:${command_text}"
    if [[ "$_DOTS_FAILURE_MESSAGE_LAST_KEY" == "$failure_key" ]]; then
        _DOTS_FAILURE_MESSAGE_STREAK=$((_DOTS_FAILURE_MESSAGE_STREAK + 1))
    else
        _DOTS_FAILURE_MESSAGE_LAST_KEY="$failure_key"
        _DOTS_FAILURE_MESSAGE_STREAK=1
    fi

    local escalation_setting="${DOTS_FAILURE_MESSAGE_ESCALATION:-1}"
    escalation_setting="${escalation_setting:l}"
    case "$escalation_setting" in
        0|false|no|off) _DOTS_FAILURE_MESSAGE_STREAK=1 ;;
    esac

    local -a selected_fields
    selected_fields=()
    if command -v python3 >/dev/null 2>&1 && [[ -r "$_DOTS_FAILURE_MESSAGE_ENGINE" ]]; then
        selected_fields=( "${(@f)$(command python3 "$_DOTS_FAILURE_MESSAGE_ENGINE" select \
            --category "$category" --command "$command_text" --username "$username" \
            --streak "$_DOTS_FAILURE_MESSAGE_STREAK" \
            --avoid-text "$_DOTS_FAILURE_MESSAGE_LAST_TEMPLATE" 2>/dev/null)}" )
    fi

    local selected_style='normal'
    local selected_rarity='common'
    local selected_character='terminal'
    local selected_id='fallback'
    local selected_template="Command \"$command_text\" failed. Inspect the error output above."
    if (( ${#selected_fields[@]} == 5 )); then
        selected_style="${selected_fields[1]}"
        selected_rarity="${selected_fields[2]}"
        selected_character="${selected_fields[3]}"
        selected_id="${selected_fields[4]}"
        selected_template="${selected_fields[5]}"
    elif [[ "${DOTS_FAILURE_DEBUG:-0}" == 1 ]]; then
        print -u2 -- "dots: message engine unavailable; using the emergency fallback"
    fi
    _DOTS_FAILURE_MESSAGE_LAST_TEMPLATE="$selected_template"

    local red='' green='' yellow='' blue='' magenta='' cyan='' purple='' dim=''
    local pink='' reset=''
    if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]]; then
        red=$'\e[38;2;248;113;113m'
        green=$'\e[38;2;134;239;172m'
        yellow=$'\e[38;2;253;224;71m'
        blue=$'\e[38;2;147;197;253m'
        magenta=$'\e[38;2;240;171;252m'
        cyan=$'\e[38;2;103;232;249m'
        purple=$'\e[38;2;196;181;253m'
        dim=$'\e[38;2;161;161;170m'
        pink=$'\e[38;2;249;168;212m'
        reset=$'\e[0m'
    fi

    local message_color="$yellow"
    case "$selected_style" in
        anime) message_color="$magenta" ;;
        ecchi) message_color="$pink" ;;
        sarcastic) message_color="$yellow" ;;
        dramatic) message_color="$red" ;;
        normal)
            case "$category" in
                not_found|permission) message_color="$red" ;;
                missing_path) message_color="$yellow" ;;
                git) message_color="$green" ;;
                nix) message_color="$blue" ;;
                network) message_color="$cyan" ;;
                *) message_color="$yellow" ;;
            esac
            ;;
    esac

    local -i special_banner_queued=0
    if [[ "$selected_rarity" == legendary || "$selected_rarity" == mythic ]]; then
        if _dots_failure_message_animate "$selected_style" "$selected_template" "$detail"; then
            special_banner_queued=1
        fi
    else
        local animation_chance="${DOTS_FAILURE_ANIMATION_CHANCE:-50}"
        case "$animation_chance" in
            (''|*[!0-9]*) animation_chance=50 ;;
        esac
        while [[ "$animation_chance" == 0* && "$animation_chance" != 0 ]]; do animation_chance="${animation_chance#0}"; done
        (( animation_chance > 100 )) && animation_chance=100
        if (( RANDOM % 100 < animation_chance )); then
            _dots_failure_message_animate "$selected_style"
        fi
    fi

    if (( ! special_banner_queued )); then
        if [[ "$selected_style" == rainbow ]]; then
            _dots_failure_message_rainbow "$selected_template"
        elif [[ "$selected_rarity" == legendary || "$selected_rarity" == mythic ]]; then
            _dots_failure_message_gradient "$selected_rarity" "$selected_template" 0
        else
            printf '%s%s%s\n' "$message_color" "$selected_template" "$reset"
        fi
        if [[ -n "$detail" ]]; then
            printf '  %s↳ %s%s\n' "$dim" "$detail" "$reset"
        fi
    fi

    # Message rendering must never replace the failed command's status.
    return 0
}

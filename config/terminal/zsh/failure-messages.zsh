# Shared failure notices and optional rarity events for interactive Zsh.
#
# Public API: dots_failure_message CATEGORY COMMAND [DETAIL]
# CATEGORY remains available to diagnostics, but does not change the ordinary
# message template. Rarity is selected independently from the failure category.

_dots_failure_message_sanitize() {
    emulate -L zsh

    local value="${1-}"
    REPLY="${value//[[:cntrl:]]/ }"
}

_dots_failure_message_animate() {
    emulate -L zsh

    (( ${+functions[_dots_failure_animation_start]} )) || return 1
    _dots_failure_animation_start "${1:-normal}" "${2-}" "${3-}"
}

# Parse a probability in basis points (100 = 1%). Clamp safely before
# arithmetic so oversized environment values cannot overflow shell integers.
_dots_failure_message_basis_points() {
    emulate -L zsh

    local value="${1-}" fallback="${2:-0}"
    case "$value" in
        (''|*[!0-9]*) value="$fallback" ;;
    esac
    while [[ "$value" == 0* && "$value" != 0 ]]; do
        value="${value#0}"
    done
    if (( ${#value} > 5 )); then
        value=10000
    elif (( value > 10000 )); then
        value=10000
    fi
    REPLY="$value"
}

dots_failure_message() {
    emulate -L zsh
    setopt localoptions no_aliases

    local command="${2:-unknown}"
    local detail="${3-}"
    local chance="${DOTS_FAILURE_MESSAGE_CHANCE:-100}"
    local requested_style="${DOTS_FAILURE_STYLE:-auto}"
    local selected_style=normal
    local message

    # Sanitise untrusted command output before it reaches prompt expansion.
    _dots_failure_message_sanitize "$command"
    command="$REPLY"
    _dots_failure_message_sanitize "$detail"
    detail="$REPLY"

    # Keep the existing opt-out while defaulting to one notice for every failure.
    case "$chance" in
        (''|*[!0-9]*) chance=100 ;;
    esac
    while [[ "$chance" == 0* && "$chance" != 0 ]]; do
        chance="${chance#0}"
    done
    (( chance > 100 )) && chance=100
    (( chance == 0 )) && return 0

    requested_style="${requested_style:l}"
    case "$requested_style" in
        legendary|mythic)
            # Explicit rarity values are convenient for previewing the banners.
            selected_style="$requested_style"
            ;;
        normal)
            selected_style=normal
            ;;
        auto|'')
            local legendary_chance mythic_chance
            _dots_failure_message_basis_points "${DOTS_FAILURE_LEGENDARY_CHANCE:-100}" 100
            legendary_chance="$REPLY"
            _dots_failure_message_basis_points "${DOTS_FAILURE_MYTHIC_CHANCE:-10}" 10
            mythic_chance="$REPLY"

            # Mythic is rolled first. If the configured ranges overlap, Mythic
            # retains priority and Legendary is reduced to the remaining range.
            (( mythic_chance + legendary_chance > 10000 )) &&
                legendary_chance=$(( 10000 - mythic_chance ))
            local -i rarity_roll=$(( RANDOM % 10000 ))
            if (( rarity_roll < mythic_chance )); then
                selected_style=mythic
            elif (( rarity_roll < mythic_chance + legendary_chance )); then
                selected_style=legendary
            fi
            ;;
        *)
            # Removed themed message styles fall back to the single ordinary
            # template; the prompt emoji pool is shared independently.
            selected_style=normal
            ;;
    esac

    case "$selected_style" in
        legendary)
            message="🏆 LEGENDARY FAILURE — \"$command\" failed in spectacular fashion."
            ;;
        mythic)
            message="🌠 MYTHIC FAILURE — \"$command\" failed in defiance of probability itself."
            ;;
        *)
            message="✖ Command \"$command\" failed."
            ;;
    esac

    # Ordinary and rare banners use the same asynchronous ZLE lifecycle.
    # Legendary and Mythic select their dedicated gradients in failure-animation.zsh.
    if _dots_failure_message_animate "$selected_style" "$message" "$detail"; then
        return 0
    fi

    # Non-interactive, NO_COLOR, and animation-disabled fallback.
    print -r -- "$message"
    [[ -z "$detail" ]] || print -r -- "  ↳ $detail"
    return 0
}

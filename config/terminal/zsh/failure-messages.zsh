# One consistent failure notice for interactive Zsh.
#
# Public API: dots_failure_message CATEGORY COMMAND [DETAIL]
# CATEGORY is retained for compatibility with the classifier and handlers.
# Every category uses the same message; the command and optional detail vary.

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

dots_failure_message() {
    emulate -L zsh
    setopt localoptions no_aliases

    local category="${1:-generic}"
    local command="${2:-unknown}"
    local detail="${3-}"
    local chance="${DOTS_FAILURE_MESSAGE_CHANCE:-100}"
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

    message="✖ Command \"$command\" failed."

    # There is one message template and one gradient palette. If animation is
    # unavailable (non-interactive shell, NO_COLOR, or explicit opt-out),
    # print the same message plainly instead of selecting another variant.
    if _dots_failure_message_animate normal "$message" "$detail"; then
        return 0
    fi

    print -r -- "$message"
    [[ -z "$detail" ]] || print -r -- "  ↳ $detail"
    return 0
}

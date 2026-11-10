# Interactive command failure handling.
#
# Source after command-state, failure-classifier, failure-messages,
# command-suggestions, and diagnostics. The state hook runs first and publishes
# one completed command record; this hook consumes each sequence exactly once.

typeset -gi _DOTS_FAILURE_NOTICE_LAST_SEQUENCE=${DOTS_LAST_SEQUENCE:-0}

_dots_failure_notice_precmd() {
    emulate -L zsh

    local -i sequence=${DOTS_LAST_SEQUENCE:-0}
    (( sequence > _DOTS_FAILURE_NOTICE_LAST_SEQUENCE )) || return 0
    typeset -gi _DOTS_FAILURE_NOTICE_LAST_SEQUENCE=$sequence

    local -i status_code=${DOTS_LAST_STATUS:-0}
    (( status_code != 0 )) || return 0

    # Interrupts and external termination are useful to inspect with "why",
    # but do not need an unsolicited failure banner.
    case "$status_code" in
        130|137|143) return 0 ;;
    esac

    (( ${+functions[dots_classify_failure]} )) || return 0
    (( ${+functions[dots_failure_message]} )) || return 0

    local command_text="${DOTS_LAST_EXECUTED_COMMAND:-${DOTS_LAST_COMMAND:-}}"
    local category
    dots_classify_failure "$command_text" "$status_code" || return 0
    category="$REPLY"

    case "$category" in
        not_found|permission|missing_path|git|nix|network|generic) ;;
        *) category=generic ;;
    esac

    dots_failure_message "$category" "${DOTS_LAST_COMMAND:-$command_text}" "exit status $status_code"
    return 0
}

command_not_found_handler() {
    emulate -L zsh
    setopt localoptions no_aliases

    local command_name="${1-}"
    (( $# > 0 )) || return 127
    shift
    local -a command_arguments
    command_arguments=( "$@" )

    # Suggestions never execute by themselves. The user must both select a
    # candidate and explicitly approve running it with the original arguments.
    if [[ -o interactive ]] &&
        [[ -r /dev/tty ]] &&
        (( ${+functions[dots_suggest_command]} )); then
        if dots_suggest_command "$command_name"; then
            local selected_command="$REPLY"
            local confirmation=''

            print -u2 -n -- "Run '$selected_command' with the original arguments? [y/N] "
            if IFS= read -r confirmation </dev/tty; then
                confirmation="${confirmation:l}"
                case "$confirmation" in
                    y|yes)
                        if (( ${+functions[dots_command_state_note_executed_command]} )); then
                            dots_command_state_note_executed_command "$selected_command" "${command_arguments[@]}" || true
                        fi
                        "$selected_command" "${command_arguments[@]}"
                        return $?
                        ;;
                esac
            fi
            print -u2
        fi
    elif (( ${+functions[dots_suggest_command]} )); then
        # Non-interactive shells may print candidates, but are never prompted.
        dots_suggest_command "$command_name" || true
    fi

    return 127
}

# The command-state hook is prepended by command-state.zsh. Append this hook
# after it, and remove any previous registration to keep sourcing idempotent.
typeset -ga precmd_functions
precmd_functions=(
    ${precmd_functions:#_dots_failure_notice_precmd}
    _dots_failure_notice_precmd
)

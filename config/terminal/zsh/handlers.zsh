# Interactive command failure handling.
#
# The completion tracker is sourced before this file. Its first precmd hook
# captures the exit status and marks one completed command; this hook consumes
# that marker once, so prompt redraws never repeat a failure message.

command_not_found_handler() {
    emulate -L zsh
    setopt localoptions no_aliases

    local command_name="${1-}"
    (( $# > 0 )) || return 127
    shift
    local -a command_arguments
    command_arguments=("$@")

    # In scripts, suggestions are printed without blocking or execution. In an
    # interactive TTY, the user must select a candidate and confirm it below.
    if dots_suggest_command "$command_name"; then
        local suggestion="$REPLY"
        local confirmed=''

        print -u2 -n -- "Run '$suggestion' with the original arguments? [y/N] "
        if read -q confirmed </dev/tty; then
            print -u2
            "$suggestion" "${command_arguments[@]}"
            return $?
        fi
        print -u2
    fi

    return 127
}

dots_failure_notice_precmd() {
    emulate -L zsh

    # Consume completion exactly once, including successful commands.
    (( ${_DOTS_COMMAND_STATE_COMPLETED:-0} )) || return 0
    typeset -gi _DOTS_COMMAND_STATE_COMPLETED=0

    local -i status_code=${DOTS_LAST_STATUS:-0}
    # Ctrl+C and external termination are intentional control flow, not a
    # failed operation that needs a random message.
    (( status_code == 0 || status_code == 130 || status_code == 137 || status_code == 143 )) && return 0

    local command_text="${DOTS_LAST_EXECUTED_COMMAND:-${DOTS_LAST_COMMAND:-}}"
    dots_classify_failure "$command_text" "$status_code" "${DOTS_LAST_CWD:-$PWD}" || return 0
    local category="$REPLY"

    dots_failure_message "$category" "${DOTS_LAST_COMMAND:-$command_text}"
    return 0
}

# Make repeated sourcing safe; the state hook remains earlier in the array.
typeset -ga precmd_functions
precmd_functions=(
    ${precmd_functions:#dots_failure_notice_precmd}
    dots_failure_notice_precmd
)

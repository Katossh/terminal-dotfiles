# Unified interactive failure reporting and typo correction.
#
# The state hook runs first and publishes the just-finished command. This hook
# then classifies and renders one message per completed command record.
typeset -gi _DOTS_FAILURE_HANDLER_LAST_SEQUENCE=-1

_dots_failure_handler_precmd() {
    emulate -L zsh

    local -i sequence="\${DOTS_LAST_SEQUENCE:-0}"
    (( sequence > 0 )) || return 0
    (( sequence != _DOTS_FAILURE_HANDLER_LAST_SEQUENCE )) || return 0
    typeset -gi _DOTS_FAILURE_HANDLER_LAST_SEQUENCE=$sequence

    local -i failure_status="\${DOTS_LAST_STATUS:-0}"
    (( failure_status != 0 )) || return 0

    (( \${+functions[dots_classify_failure]} )) || return 0
    (( \${+functions[dots_failure_message]} )) || return 0

    local command_text="\${DOTS_LAST_EXECUTED_COMMAND:-\${DOTS_LAST_COMMAND:-}}"
    local category
    if dots_classify_failure "$command_text" "$failure_status"; then
        category="$REPLY"
    else
        category=generic
    fi

    case "$category" in
        not_found|permission|missing_path|git|nix|network|generic) ;;
        *) category=generic ;;
    esac

    dots_failure_message "$category" "\${DOTS_LAST_COMMAND:-unknown}" "exit status $failure_status"
    return 0
}

# Zsh invokes this when an interactive command name cannot be resolved.
# A correction is never run silently: the user must select it and then
# explicitly confirm the second prompt.
command_not_found_handler() {
    emulate -L zsh
    setopt localoptions no_aliases

    local missing_command="\${1-}"
    (( $# > 0 )) || return 127
    shift

    if [[ -o interactive ]] && (( \${+functions[dots_suggest_command]} )); then
        if dots_suggest_command "$missing_command"; then
            local selected_command="$REPLY"
            local confirmation=''

            print -u2 -n -- "Run '\${selected_command}' instead? [y/N] "
            if [[ -r /dev/tty ]] && IFS= read -r confirmation </dev/tty; then
                confirmation="\${confirmation:l}"
                if [[ "$confirmation" == y || "$confirmation" == yes ]]; then
                    "$selected_command" "$@"
                    local -i command_status=$?

                    if (( \${+functions[dots_command_state_note_executed_command]} )); then
                        dots_command_state_note_executed_command "$selected_command" "$@"
                    fi
                    return "$command_status"
                fi
            fi
        fi
    fi

    return 127
}

# Preserve other prompt hooks and register this integration hook exactly once.
# It is appended so command-state's first-position hook publishes status first.
typeset -ga precmd_functions
precmd_functions=(
    \${precmd_functions:#_dots_failure_handler_precmd}
    _dots_failure_handler_precmd
)

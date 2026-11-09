# Track the most recently completed interactive Zsh command.
#
# Source this module from .zshrc after framework/plugin initialization and
# before command diagnostics. State is kept in shell parameters only: nothing
# is written to disk or exported to child processes.
#
# Public interface:
#   DOTS_LAST_COMMAND          Text entered by the user (pre-expansion).
#   DOTS_LAST_EXECUTED_COMMAND Full command text after Zsh expansion.
#   DOTS_LAST_STATUS           Exit status of that command.
#   DOTS_LAST_CWD              Working directory when it started.
#   DOTS_LAST_TIMESTAMP        Unix timestamp (seconds) when it finished.
#
# The public values are updated in precmd, not preexec. While a command such
# as a future "why" function is running, the values therefore still describe
# the command that ran immediately before it.

# EPOCHSECONDS is supplied by zsh/datetime. Keep the tracker usable if that
# optional module is unavailable; in that case the timestamp is an empty
# string rather than invoking an external date command on every prompt.
zmodload zsh/datetime 2>/dev/null || true

typeset -g DOTS_LAST_COMMAND="${DOTS_LAST_COMMAND-}"
typeset -g DOTS_LAST_EXECUTED_COMMAND="${DOTS_LAST_EXECUTED_COMMAND-}"
typeset -gi DOTS_LAST_STATUS=${DOTS_LAST_STATUS:-0}
typeset -g DOTS_LAST_CWD="${DOTS_LAST_CWD-}"
typeset -g DOTS_LAST_TIMESTAMP="${DOTS_LAST_TIMESTAMP-}"

# These pending values are intentionally separate from the public state.
typeset -g _DOTS_COMMAND_STATE_PENDING_COMMAND=""
typeset -g _DOTS_COMMAND_STATE_PENDING_EXECUTED_COMMAND=""
typeset -g _DOTS_COMMAND_STATE_PENDING_CWD=""
typeset -gi _DOTS_COMMAND_STATE_PENDING=0

_dots_command_state_preexec() {
    emulate -L zsh

    # Zsh passes the typed command as $1, a shortened expanded command as $2,
    # and the full expanded command as $3. History may be disabled, so retain
    # a useful fallback when $1 is empty.
    local typed_command="${1-}"
    local executed_command="${3:-${2:-$typed_command}}"

    [[ -n "$typed_command" ]] || typed_command="$executed_command"

    typeset -g _DOTS_COMMAND_STATE_PENDING_COMMAND="$typed_command"
    typeset -g _DOTS_COMMAND_STATE_PENDING_EXECUTED_COMMAND="$executed_command"
    typeset -g _DOTS_COMMAND_STATE_PENDING_CWD="$PWD"
    typeset -gi _DOTS_COMMAND_STATE_PENDING=1
    return 0
}

_dots_command_state_precmd() {
    # This must be the first command in the hook: entering the function after
    # the command finishes is the only reliable point to read its exit status.
    local -i command_status=$?
    emulate -L zsh

    # precmd also runs for the initial prompt, before any interactive command.
    (( _DOTS_COMMAND_STATE_PENDING )) || return 0

    typeset -g DOTS_LAST_COMMAND="$_DOTS_COMMAND_STATE_PENDING_COMMAND"
    typeset -g DOTS_LAST_EXECUTED_COMMAND="$_DOTS_COMMAND_STATE_PENDING_EXECUTED_COMMAND"
    typeset -gi DOTS_LAST_STATUS=$command_status
    typeset -g DOTS_LAST_CWD="$_DOTS_COMMAND_STATE_PENDING_CWD"

    if (( ${+EPOCHSECONDS} )); then
        typeset -g DOTS_LAST_TIMESTAMP="$EPOCHSECONDS"
    else
        typeset -g DOTS_LAST_TIMESTAMP=""
    fi

    _DOTS_COMMAND_STATE_PENDING=0
    _DOTS_COMMAND_STATE_PENDING_COMMAND=""
    _DOTS_COMMAND_STATE_PENDING_EXECUTED_COMMAND=""
    _DOTS_COMMAND_STATE_PENDING_CWD=""
    return 0
}

# Install each hook exactly once. Prepending the precmd hook captures the
# original command status before another prompt hook can fail or change state.
typeset -ga preexec_functions precmd_functions
preexec_functions=(
    _dots_command_state_preexec
    ${preexec_functions:#_dots_command_state_preexec}
)
precmd_functions=(
    _dots_command_state_precmd
    ${precmd_functions:#_dots_command_state_precmd}
)

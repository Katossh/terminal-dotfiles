#!/usr/bin/env zsh
emulate -LR zsh
setopt err_return no_unset

REPO_DIR="${0:A:h:h}"
ZSH_DIR="$REPO_DIR/config/terminal/zsh"

source "$ZSH_DIR/command-state.zsh"
source "$ZSH_DIR/failure-classifier.zsh"
source "$ZSH_DIR/failure-messages.zsh"
source "$ZSH_DIR/command-suggestions.zsh"
source "$ZSH_DIR/diagnostics.zsh"
source "$ZSH_DIR/handlers.zsh"

fail() {
    print -u2 -r -- "FAIL: $*"
    exit 1
}

assert_eq() {
    local label="$1"
    local expected="$2"
    local actual="$3"
    [[ "$actual" == "$expected" ]] || fail "$label (expected '$expected', got '$actual')"
    print -- "ok - $label"
}

assert_contains() {
    local label="$1"
    local needle="$2"
    local haystack="$3"
    [[ "$haystack" == *"$needle"* ]] || fail "$label (missing '$needle'; output: $haystack)"
    print -- "ok - $label"
}

export NO_COLOR=1
export DOTS_FAILURE_MESSAGE_CHANCE=100
export DOTS_FAILURE_RARE_CHANCE=0
export DOTS_FAILURE_MESSAGE_ESCALATION=0

# The integration hook must be registered once and must follow the state hook.
typeset -i notice_count=0
for hook in "${precmd_functions[@]}"; do
    if [[ "$hook" == dots_failure_notice_precmd ]]; then
        (( notice_count += 1 ))
    fi
done
assert_eq "failure notice hook is registered once" "1" "$notice_count"
assert_eq "state tracker remains the first precmd hook" "_dots_command_state_precmd" "${precmd_functions[1]}"

# Simulate an ordinary failed command and verify state -> classifier -> message
# integration, including one-shot consumption of the completion marker.
_dots_command_state_preexec "grep needle missing.txt" "grep needle missing.txt" "grep needle missing.txt"
setopt no_errexit
false
_dots_command_state_precmd
setopt errexit
assert_eq "failed command status is captured" "1" "$DOTS_LAST_STATUS"
assert_eq "completed-command marker is set" "1" "$_DOTS_COMMAND_STATE_COMPLETED"

capture_file="$(mktemp "${TMPDIR:-/tmp}/dots-failure-integration.XXXXXX")"
dots_failure_notice_precmd >"$capture_file"
output="$(<"$capture_file")"
rm -f "$capture_file"
assert_contains "failure notice includes the original command" "grep needle missing.txt" "$output"
assert_eq "failure notice consumes completion marker" "0" "$_DOTS_COMMAND_STATE_COMPLETED"

capture_file="$(mktemp "${TMPDIR:-/tmp}/dots-failure-integration.XXXXXX")"
dots_failure_notice_precmd >"$capture_file"
second_output="$(<"$capture_file")"
rm -f "$capture_file"
assert_eq "prompt redraw does not repeat failure notice" "" "$second_output"

# A command-not-found handler must not execute or auto-accept anything in a
# non-interactive shell. The normal completion hook receives status 127.
_dots_command_state_preexec "dots-command-that-does-not-exist-7f3c" "dots-command-that-does-not-exist-7f3c" "dots-command-that-does-not-exist-7f3c"
setopt no_errexit
command_not_found_handler "dots-command-that-does-not-exist-7f3c"
_dots_command_state_precmd
setopt errexit
assert_eq "unresolved command remains a 127 failure" "127" "$DOTS_LAST_STATUS"

# why explains the captured failure without replacing its record.
why_output="$(why)"
assert_contains "why diagnoses the last failed command" "could not resolve the command name" "$why_output"
assert_eq "why preserves the last command" "dots-command-that-does-not-exist-7f3c" "$DOTS_LAST_COMMAND"

print -r -- "failure integration tests passed"

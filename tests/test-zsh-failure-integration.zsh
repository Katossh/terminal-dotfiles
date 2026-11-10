#!/usr/bin/env zsh
setopt errexit nounset

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
    [[ "$haystack" == *"$needle"* ]] || fail "$label (missing '$needle' in: $haystack)"
    print -- "ok - $label"
}

export NO_COLOR=1
export DOTS_FAILURE_MESSAGE_CHANCE=100
export DOTS_FAILURE_RARE_CHANCE=0
export DOTS_FAILURE_MESSAGE_ESCALATION=0

# The failure hook must see the state published by the state hook.
_dots_command_state_preexec "git status" "git status" "git status"
setopt no_errexit
false
_dots_command_state_precmd
setopt errexit

first_output="$(mktemp "${TMPDIR:-/tmp}/dots-zsh-integration.XXXXXX")"
second_output="$(mktemp "${TMPDIR:-/tmp}/dots-zsh-integration.XXXXXX")"
trap 'rm -f "$first_output" "$second_output"' EXIT

_dots_failure_handler_precmd > "$first_output"
message="$(cat "$first_output")"
assert_contains "failure message hook renders Git failure" "git status" "$message"
_dots_failure_handler_precmd > "$second_output"
assert_eq "failure record is reported once" "" "$(cat "$second_output")"

# A second identical failure is a new command record and must be reported.
_dots_command_state_preexec "git status" "git status" "git status"
setopt no_errexit
false
_dots_command_state_precmd
setopt errexit
_dots_failure_handler_precmd > "$second_output"
message="$(cat "$second_output")"
assert_contains "repeated failure receives a new message" "git status" "$message"

# Re-running the prompt hook without a new command must not emit a duplicate.
: > "$first_output"
_dots_failure_handler_precmd > "$first_output"
assert_eq "prompt redraw does not repeat a failure message" "" "$(cat "$first_output")"

# Success records advance state but never emit a failure message.
_dots_command_state_preexec "true" "true" "true"
true
_dots_command_state_precmd
: > "$first_output"
_dots_failure_handler_precmd > "$first_output"
assert_eq "successful commands do not emit failure messages" "" "$(cat "$first_output")"

# A corrected command remains distinguishable from the typo the user typed.
_dots_command_state_preexec "gti status" "gti status" "gti status"
dots_command_state_note_executed_command git status
setopt no_errexit
false
_dots_command_state_precmd
setopt errexit
assert_eq "typed command is preserved" "gti status" "$DOTS_LAST_COMMAND"
assert_eq "executed correction is recorded" "git status" "$DOTS_LAST_EXECUTED_COMMAND"
dots_classify_failure "$DOTS_LAST_EXECUTED_COMMAND" "$DOTS_LAST_STATUS"
assert_eq "corrected command is classified as Git" "git" "$REPLY"

# why consumes the same state and does not run or alter the previous command.
diagnostic_output="$(why --verbose)"
assert_contains "why uses the integrated command state" "Last command: gti status" "$diagnostic_output"
assert_contains "why diagnoses corrected command text" "Diagnosis (git)" "$diagnostic_output"

# Non-interactive command-not-found handling must return 127 without blocking.
if command_not_found_handler dots-integration-command-that-does-not-exist; then
    fail "command-not-found handler unexpectedly succeeded"
else
    assert_eq "non-interactive missing command returns 127" "127" "$?"
fi

print -- "Zsh failure integration tests passed."

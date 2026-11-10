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
    local expected="$2"
    local actual="$3"
    [[ "$actual" == *"$expected"* ]] || fail "$label (missing '$expected' in: $actual)"
    print -- "ok - $label"
}

capture_output() {
    local capture_file
    capture_file="$(mktemp "${TMPDIR:-/tmp}/dots-failure-integration.XXXXXX")" || return 1
    "$@" > "$capture_file"
    DOTS_TEST_CAPTURE="$(<"$capture_file")"
    rm -f "$capture_file"
}

export NO_COLOR=1
export DOTS_FAILURE_MESSAGE_CHANCE=100
export DOTS_FAILURE_RARE_CHANCE=0
export DOTS_FAILURE_MESSAGE_ESCALATION=0

# The state hook must precede the failure reporter in every interactive shell.
assert_eq "state hook is first" "_dots_command_state_precmd" "${precmd_functions[1]}"
assert_eq "failure reporter is registered after state" "_dots_failure_notice_precmd" "${precmd_functions[-1]}"

# The test drives hooks manually with synthetic completed commands. Prevent
# the shell from treating test-runner commands as additional interactive input.
preexec_functions=()
precmd_functions=()
# Discard the setup command captured before the hook arrays were cleared.
_DOTS_COMMAND_STATE_PENDING=0
_DOTS_COMMAND_STATE_PENDING_COMMAND=''
_DOTS_COMMAND_STATE_PENDING_EXECUTED_COMMAND=''
_DOTS_COMMAND_STATE_PENDING_CWD=''

# A failed command is published, classified, and reported once.
_dots_command_state_preexec "git status" "git status" "git status"
setopt no_errexit
( exit 1 )
_dots_command_state_precmd
setopt errexit
assert_eq "first command receives sequence one" "1" "$DOTS_LAST_SEQUENCE"
assert_eq "failed status is retained" "1" "$DOTS_LAST_STATUS"

typeset -g DOTS_TEST_CAPTURE=''
capture_output _dots_failure_notice_precmd
assert_contains "Git failure is rendered" "git status" "$DOTS_TEST_CAPTURE"
capture_output _dots_failure_notice_precmd
assert_eq "the same failure is not rendered twice" "" "$DOTS_TEST_CAPTURE"

# why reports the saved record and preserves it through the following prompt.
_dots_command_state_preexec "why --verbose" "why --verbose" "why --verbose"
capture_output why --verbose
assert_contains "why reports the previous command" "Last command: git status" "$DOTS_TEST_CAPTURE"
assert_contains "why classifies the previous command" "Diagnosis (git)" "$DOTS_TEST_CAPTURE"
true
_dots_command_state_precmd
assert_eq "why does not replace the previous command" "git status" "$DOTS_LAST_COMMAND"
assert_eq "why does not advance the sequence" "1" "$DOTS_LAST_SEQUENCE"
capture_output _dots_failure_notice_precmd
assert_eq "why does not repeat the failure banner" "" "$DOTS_TEST_CAPTURE"

# A selected correction keeps the typo for display but records the command
# that actually ran for classification and subsequent diagnostics.
_dots_command_state_preexec "gti status" "gti status" "gti status"
dots_command_state_note_executed_command git status
setopt no_errexit
( exit 1 )
_dots_command_state_precmd
setopt errexit
assert_eq "typed typo remains visible" "gti status" "$DOTS_LAST_COMMAND"
assert_eq "executed command is corrected" "git status" "$DOTS_LAST_EXECUTED_COMMAND"
capture_output _dots_failure_notice_precmd
assert_contains "corrected command is classified as Git" "git status" "$DOTS_TEST_CAPTURE"
_dots_command_state_preexec "why" "why" "why"
capture_output why
assert_contains "why explains the corrected command" "Diagnosis (git)" "$DOTS_TEST_CAPTURE"
true
_dots_command_state_precmd
assert_eq "why preserves the corrected record" "gti status" "$DOTS_LAST_COMMAND"

# A successful command advances the sequence but does not produce a banner.
_dots_command_state_preexec "true" "true" "true"
true
_dots_command_state_precmd
capture_output _dots_failure_notice_precmd
assert_eq "successful commands produce no failure banner" "" "$DOTS_TEST_CAPTURE"

# Interruptions remain available to why without an unsolicited failure banner.
_dots_command_state_preexec "sleep 2" "sleep 2" "sleep 2"
setopt no_errexit
( exit 130 )
_dots_command_state_precmd
setopt errexit
capture_output _dots_failure_notice_precmd
assert_eq "interrupt status does not produce a failure banner" "" "$DOTS_TEST_CAPTURE"

# A non-interactive command-not-found call never prompts or executes a guess.
setopt no_errexit
command_not_found_handler dots-command-that-does-not-exist-7f3c
command_status=$?
setopt errexit
assert_eq "missing command returns conventional status 127" "127" "$command_status"

print -- "Zsh failure integration tests passed."

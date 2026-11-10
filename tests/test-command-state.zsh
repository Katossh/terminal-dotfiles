#!/usr/bin/env zsh
setopt errexit nounset

REPO_DIR="${0:A:h:h}"
source "$REPO_DIR/config/terminal/zsh/command-state.zsh"

fail() {
    print -u2 -- "not ok - $1"
    exit 1
}

assert_eq() {
    local label="$1"
    local expected="$2"
    local actual="$3"

    [[ "$actual" == "$expected" ]] || {
        print -u2 -- "not ok - $label (expected '$expected', got '$actual')"
        exit 1
    }
    print -- "ok - $label"
}

# The initial prompt must not invent a previous command.
_dots_command_state_precmd
assert_eq "initial command is empty" "" "$DOTS_LAST_COMMAND"
assert_eq "initial status is zero" "0" "$DOTS_LAST_STATUS"
assert_eq "initial sequence is zero" "0" "$DOTS_LAST_SEQUENCE"

# Simulate a failed interactive command. preexec records pending data, while
# the public state remains unchanged until precmd runs after command completion.
original_cwd="$PWD"
_dots_command_state_preexec "false" "false" "false"
assert_eq "preexec does not publish an unfinished command" "" "$DOTS_LAST_COMMAND"

setopt no_errexit
false
_dots_command_state_precmd
setopt errexit

assert_eq "typed command is retained" "false" "$DOTS_LAST_COMMAND"
assert_eq "executed command is retained" "false" "$DOTS_LAST_EXECUTED_COMMAND"
assert_eq "non-zero status is captured" "1" "$DOTS_LAST_STATUS"
assert_eq "first completed command advances sequence" "1" "$DOTS_LAST_SEQUENCE"
assert_eq "starting directory is captured" "$original_cwd" "$DOTS_LAST_CWD"
[[ "$DOTS_LAST_TIMESTAMP" == <-> ]] || fail "completion timestamp is not an epoch integer"
print -- "ok - completion timestamp is an epoch integer"

# The full expanded command is available separately from what the user typed.
_dots_command_state_preexec "gco" "git checkout" "git checkout main"
assert_eq "previous result remains readable while the next command runs" "false" "$DOTS_LAST_COMMAND"
true
_dots_command_state_precmd
assert_eq "typed alias is retained" "gco" "$DOTS_LAST_COMMAND"
assert_eq "full expanded command is retained" "git checkout main" "$DOTS_LAST_EXECUTED_COMMAND"
assert_eq "successful status is captured" "0" "$DOTS_LAST_STATUS"
assert_eq "second completed command advances sequence" "2" "$DOTS_LAST_SEQUENCE"

# A confirmed typo correction can record the command that actually ran without
# changing what the user originally typed.
_dots_command_state_preexec "gti status" "gti status" "gti status"
dots_command_state_note_executed_command git status --porcelain=v1
assert_eq "replacement is pending until command completion" "git status --porcelain=v1" "$_DOTS_COMMAND_STATE_PENDING_EXECUTED_COMMAND"
true
_dots_command_state_precmd
assert_eq "typed typo remains available for diagnostics" "gti status" "$DOTS_LAST_COMMAND"
assert_eq "executed correction is recorded" "git status --porcelain=v1" "$DOTS_LAST_EXECUTED_COMMAND"
assert_eq "third completed command advances sequence" "3" "$DOTS_LAST_SEQUENCE"

# Interrupt-style statuses are captured just like ordinary exit codes.
_dots_command_state_preexec "sleep 99" "sleep 99" "sleep 99"
setopt no_errexit
( exit 130 )
_dots_command_state_precmd
setopt errexit
assert_eq "interrupted command status is captured" "130" "$DOTS_LAST_STATUS"
assert_eq "fourth completed command advances sequence" "4" "$DOTS_LAST_SEQUENCE"

# A diagnostic function can preserve the failure it is inspecting, even when
# the user invokes it repeatedly.
_dots_command_state_preexec "why" "why" "why"
dots_command_state_preserve_previous
true
_dots_command_state_precmd
assert_eq "diagnostic command does not replace previous command" "sleep 99" "$DOTS_LAST_COMMAND"
assert_eq "diagnostic command preserves previous status" "130" "$DOTS_LAST_STATUS"
assert_eq "diagnostic command does not advance sequence" "4" "$DOTS_LAST_SEQUENCE"

# A prompt redraw without a preceding command must leave the previous record
# untouched.
last_command="$DOTS_LAST_COMMAND"
last_status="$DOTS_LAST_STATUS"
_dots_command_state_precmd
assert_eq "empty precmd leaves command untouched" "$last_command" "$DOTS_LAST_COMMAND"
assert_eq "empty precmd leaves status untouched" "$last_status" "$DOTS_LAST_STATUS"

# Re-sourcing in this non-interactive test process must not register
# interactive hooks. The interactive .zshrc path is covered by startup wiring.
source "$REPO_DIR/config/terminal/zsh/command-state.zsh"
typeset -i preexec_count=0
typeset -i precmd_count=0
for hook in "${preexec_functions[@]}"; do
    if [[ "$hook" == _dots_command_state_preexec ]]; then
        (( preexec_count += 1 ))
    fi
done
for hook in "${precmd_functions[@]}"; do
    if [[ "$hook" == _dots_command_state_precmd ]]; then
        (( precmd_count += 1 ))
    fi
done
assert_eq "preexec hook is not registered in non-interactive shell" "0" "$preexec_count"
assert_eq "precmd hook is not registered in non-interactive shell" "0" "$precmd_count"

print -- "command state tests passed"

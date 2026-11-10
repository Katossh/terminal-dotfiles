#!/usr/bin/env zsh
setopt errexit nounset

REPO_DIR="${0:A:h:h}"
source "$REPO_DIR/config/terminal/zsh/command-state.zsh"

# These tests call the hook functions directly with synthetic command records.
# Disable automatic hook dispatch in the non-interactive test shell; otherwise
# the test runner's own function calls become records between the simulations.
typeset -ga preexec_functions precmd_functions
preexec_functions=()
precmd_functions=()
# The command that disables preexec was itself seen by the previous hook.
_DOTS_COMMAND_STATE_PENDING=0
_DOTS_COMMAND_STATE_PENDING_COMMAND=''
_DOTS_COMMAND_STATE_PENDING_EXECUTED_COMMAND=''
_DOTS_COMMAND_STATE_PENDING_CWD=''
_DOTS_COMMAND_STATE_PRESERVE_PREVIOUS=0
# The assignment above can itself be observed by the still-active preexec
# hook. Discard that setup command before beginning synthetic test cases.
_DOTS_COMMAND_STATE_PENDING=0
_DOTS_COMMAND_STATE_PENDING_COMMAND=''
_DOTS_COMMAND_STATE_PENDING_EXECUTED_COMMAND=''
_DOTS_COMMAND_STATE_PENDING_CWD=''

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
assert_eq "starting directory is captured" "$original_cwd" "$DOTS_LAST_CWD"
assert_eq "first completed command advances sequence" "1" "$DOTS_LAST_SEQUENCE"
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

# Interrupt-style statuses are captured just like ordinary exit codes.
_dots_command_state_preexec "sleep 99" "sleep 99" "sleep 99"
setopt no_errexit
( exit 130 )
_dots_command_state_precmd
setopt errexit
assert_eq "interrupted command status is captured" "130" "$DOTS_LAST_STATUS"
assert_eq "third completed command advances sequence" "3" "$DOTS_LAST_SEQUENCE"

# A diagnostic function can preserve the failure it is inspecting, even when
# the user invokes it repeatedly.
_dots_command_state_preexec "why" "why" "why"
dots_command_state_preserve_previous
true
_dots_command_state_precmd
assert_eq "diagnostic command does not replace previous command" "sleep 99" "$DOTS_LAST_COMMAND"
assert_eq "diagnostic command preserves previous status" "130" "$DOTS_LAST_STATUS"
assert_eq "diagnostic command does not advance sequence" "3" "$DOTS_LAST_SEQUENCE"

# A prompt redraw without a preceding command must leave the previous record
# untouched.
last_command="$DOTS_LAST_COMMAND"
last_status="$DOTS_LAST_STATUS"
_dots_command_state_precmd
assert_eq "empty precmd leaves command untouched" "$last_command" "$DOTS_LAST_COMMAND"
assert_eq "empty precmd leaves status untouched" "$last_status" "$DOTS_LAST_STATUS"

# A confirmed command correction replaces only the expanded command record.
_dots_command_state_preexec "gti status --message 'hello world'" "gti status" "gti status"
assert_eq "correction starts with the typed command preserved" "gti status --message 'hello world'" "$_DOTS_COMMAND_STATE_PENDING_COMMAND"
dots_command_state_note_executed_command git status --message "hello world"
setopt no_errexit
( exit 1 )
_dots_command_state_precmd
setopt errexit
assert_eq "the original typo remains available" "gti status --message 'hello world'" "$DOTS_LAST_COMMAND"
assert_eq "corrected command and arguments are safely quoted" "git status --message hello\\ world" "$DOTS_LAST_EXECUTED_COMMAND"
assert_eq "confirmed correction advances sequence" "4" "$DOTS_LAST_SEQUENCE"

# Re-sourcing the module must not register duplicate hook functions.
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
assert_eq "preexec hook is registered once" "1" "$preexec_count"
assert_eq "precmd hook is registered once" "1" "$precmd_count"
assert_eq "preexec hook runs first" "_dots_command_state_preexec" "${preexec_functions[1]}"
assert_eq "precmd hook runs first" "_dots_command_state_precmd" "${precmd_functions[1]}"

print -- "command state tests passed"

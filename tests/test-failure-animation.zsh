#!/usr/bin/env zsh
setopt errexit nounset

REPO_DIR="${0:A:h:h}"
ZSH_DIR="$REPO_DIR/config/terminal/zsh"
INIT_FILE="$(mktemp)"
PTY_NAME="dots_single_gradient_test"

fail() {
    print -u2 -r -- "not ok - $*"
    exit 1
}

assert_contains() {
    local label="$1" needle="$2" haystack="$3"
    [[ "$haystack" == *"$needle"* ]] || fail "$label (missing: $needle; captured: $haystack)"
    print -- "ok - $label"
}

assert_absent() {
    local label="$1" needle="$2" haystack="$3"
    [[ "$haystack" != *"$needle"* ]] || fail "$label (unexpected: $needle; captured: $haystack)"
    print -- "ok - $label"
}

zmodload zsh/zpty 2>/dev/null || {
    print -- "skip - zsh/zpty is unavailable"
    exit 0
}

cat > "$INIT_FILE" <<'ZSH_INIT'
setopt promptsubst
unset NO_COLOR
STARSHIP_TEST_PROMPT=$'BASE_PATH\nBASE_OUTPUT ❯ '
PROMPT='$(print -rn -- "$STARSHIP_TEST_PROMPT")'
source "$ZSH_DIR/failure-messages.zsh"
source "$ZSH_DIR/failure-animation.zsh"
_DOTS_FAILURE_ANIMATION_STARTUP_PENDING=0
_DOTS_FAILURE_GRADIENT_INTERVAL=0.2

_dots_test_buffer_snapshot() {
    zle -M "BUFFER_SNAPSHOT_BEGIN:${BUFFER}:CURSOR_${CURSOR}:FRAMES_${_DOTS_FAILURE_ANIMATION_LAST_BANNER_FRAMES}:ACTIVE_${_DOTS_FAILURE_GRADIENT_ACTIVE}:WORKER_${_DOTS_FAILURE_ANIMATION_ACTIVE}:ACCEPT_PENDING_${_DOTS_FAILURE_GRADIENT_ACCEPT_PENDING}:STEP_${_DOTS_FAILURE_ANIMATION_STEP}:FRAME_COUNT_${_DOTS_FAILURE_ANIMATION_FRAMES}:STATE_${_DOTS_FAILURE_ANIMATION_STATE}:LAST_STATE_${_DOTS_FAILURE_ANIMATION_LAST_STATE}:FD_${_DOTS_FAILURE_ANIMATION_FD}"
}
zle -N _dots_test_buffer_snapshot
bindkey '^T' _dots_test_buffer_snapshot

_dots_test_queue_failure() {
    typeset -gi _DOTS_TEST_FAILURE_PENDING=1
    print -r -- FAILURE_QUEUED
}
_dots_test_start_failure() {
    (( ${_DOTS_TEST_FAILURE_PENDING:-0} )) || return 0
    typeset -gi _DOTS_TEST_FAILURE_PENDING=0
    dots_failure_message not_found 'missing-command' 'command not found'
}
precmd_functions=( _dots_test_start_failure ${precmd_functions:#_dots_test_start_failure} )

_dots_test_report_preexec() {
    print -r -- "SUBMIT_AFTER_FRAMES_${_DOTS_FAILURE_ANIMATION_LAST_BANNER_FRAMES}_ACTIVE_${_DOTS_FAILURE_GRADIENT_ACTIVE}_PENDING_${_DOTS_FAILURE_GRADIENT_ACCEPT_PENDING}"
}
preexec_functions=( ${preexec_functions:#_dots_test_report_preexec} _dots_test_report_preexec )
ZSH_INIT

trap 'zpty -d "$PTY_NAME" 2>/dev/null || true; rm -f "$INIT_FILE"' EXIT

zpty -b "$PTY_NAME" env TERM=xterm-256color COLUMNS=120 LINES=30 \
    "ZSH_DIR=$ZSH_DIR" DOTS_FAILURE_MESSAGE_CHANCE=100 \
    DOTS_FAILURE_ANIMATION=1 DOTS_FAILURE_GRADIENT_INTERVAL=0.2 \
    zsh -f -i

read_until() {
    local needle="$1"
    local -i tries=0
    local output='' data=''
    while (( tries < 120 )); do
        if zpty -r -t "$PTY_NAME" data; then output+="$data"; fi
        [[ "$output" == *"$needle"* ]] && break
        command sleep 0.05
        (( tries += 1 ))
    done
    REPLY="$output"
}

read_until_visible() {
    local needle="$1"
    local -i tries=0
    local output='' data='' visible=''
    while (( tries < 120 )); do
        if zpty -r -t "$PTY_NAME" data; then output+="$data"; fi
        visible="$(print -rn -- "$output" | command python3 -c 'import re, sys; sys.stdout.write(re.sub(r"(?:\x1b|\^\[)\[[0-9;]*m", "", sys.stdin.read()))')"
        [[ "$visible" == *"$needle"* ]] && break
        command sleep 0.05
        (( tries += 1 ))
    done
    _DOTS_TEST_LAST_RAW_OUTPUT="$output"
    REPLY="$visible"
}

drain_for() {
    local -i rounds="$1"
    local output='' data=''
    while (( rounds > 0 )); do
        if zpty -r -t "$PTY_NAME" data; then output+="$data"; fi
        command sleep 0.02
        rounds=$(( rounds - 1 ))
    done
    REPLY="$output"
}

# Wait for the interactive shell's initial prompt before loading the modules.
local startup='' chunk=''
local -i attempt=0
while (( attempt < 40 )); do
    if zpty -r -t "$PTY_NAME" chunk; then startup+="$chunk"; fi
    [[ -n "$startup" ]] && break
    command sleep 0.05
    (( attempt += 1 ))
done
[[ -n "$startup" ]] || fail "interactive child shell did not start"
print -- "ok - interactive child shell started"

zpty -w "$PTY_NAME" "source '$INIT_FILE'"
read_until "BASE_OUTPUT"
assert_contains "normal prompt renders after sourcing the modules" "BASE_PATH" "$REPLY"

# The real public failure-message function is called from precmd.
zpty -w "$PTY_NAME" '_dots_test_queue_failure'$'\n'
read_until FAILURE_QUEUED
read_until_visible 'command not found'
assert_contains "one deterministic error message appears" '✖ Command "missing-command" failed.' "$REPLY"
assert_contains "diagnostic detail appears below the same message" 'command not found' "$REPLY"
assert_contains "failure banner remains above the input prompt" "BASE_OUTPUT" "$REPLY"
assert_contains "path line remains intact" "BASE_PATH" "$REPLY"

# The PTY must receive real ANSI bytes, never printable caret notation.
[[ "$_DOTS_TEST_LAST_RAW_OUTPUT" == *$'\e[38;2;'* ]] || fail "gradient did not emit actual 24-bit ANSI control bytes"
assert_absent "gradient does not emit printable caret escape notation" '^[[38;2;' "$_DOTS_TEST_LAST_RAW_OUTPUT"

# Type and submit a command while the gradient is still active.
zpty -w -n "$PTY_NAME" 'print -r -- GRADIENT_COMMAND_EXECUTED'
read_until_visible 'GRADIENT_COMMAND_EXECUTED'
assert_contains "input is accepted while the gradient animates" "GRADIENT_COMMAND_EXECUTED" "$REPLY"

# Enter is queued by the ZLE widget instead of cancelling the active worker.
zpty -w -n "$PTY_NAME" $'\\r'
zpty -w -n "$PTY_NAME" $'\\x14'
read_until_visible "BUFFER_SNAPSHOT_BEGIN:"
assert_contains "the complete command remains editable while Enter is queued" \
    "BUFFER_SNAPSHOT_BEGIN:print -r -- GRADIENT_COMMAND_EXECUTED:CURSOR_37" "$REPLY"
assert_contains "the gradient remains active after Enter" "ACTIVE_1" "$REPLY"
assert_contains "the pending Enter is recorded" "ACCEPT_PENDING_1" "$REPLY"
assert_absent "the command has not started before the gradient finishes" "SUBMIT_AFTER_FRAMES_" "$REPLY"

# The FD watcher completes every phase, then replays Enter automatically.
read_until "SUBMIT_AFTER_FRAMES_25_ACTIVE_0_PENDING_0"
submitted_output="$REPLY"
if [[ "$submitted_output" != *"SUBMIT_AFTER_FRAMES_25_ACTIVE_0_PENDING_0"* ]]; then
    zpty -w -n "$PTY_NAME" $'\\x14'
    read_until_visible "BUFFER_SNAPSHOT_BEGIN:"
    fail "gradient completion hand-off did not run; final ZLE snapshot: $REPLY"
fi
assert_contains "command submission waits for all 25 gradient frames" \
    "SUBMIT_AFTER_FRAMES_25_ACTIVE_0_PENDING_0" "$submitted_output"
if [[ "$submitted_output" != *"GRADIENT_COMMAND_EXECUTED"* ]]; then
    read_until "GRADIENT_COMMAND_EXECUTED"
    submitted_output+="${REPLY}"
fi
assert_contains "the queued command executes unchanged" "GRADIENT_COMMAND_EXECUTED" "$submitted_output"
print -- "All single-gradient failure animation integration tests passed."

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
_DOTS_FAILURE_GRADIENT_INTERVAL=0.08

_dots_test_buffer_snapshot() {
    zle -M "BUFFER_SNAPSHOT_BEGIN:${BUFFER}:CURSOR_${CURSOR}:FRAMES_${_DOTS_FAILURE_ANIMATION_LAST_BANNER_FRAMES}:ACTIVE_${_DOTS_FAILURE_GRADIENT_ACTIVE}:WORKER_${_DOTS_FAILURE_ANIMATION_ACTIVE}:STATE_${_DOTS_FAILURE_ANIMATION_STATE}:BANNER_${#_DOTS_FAILURE_ANIMATION_GRADIENT_PROMPT}:SUBMITTED_${_DOTS_FAILURE_GRADIENT_SUBMITTED}"
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
    print -r -- "SUBMITTED_ACTIVE_${_DOTS_FAILURE_GRADIENT_ACTIVE}_WORKER_${_DOTS_FAILURE_ANIMATION_ACTIVE}_FRAMES_${_DOTS_FAILURE_ANIMATION_LAST_BANNER_FRAMES}"
}
preexec_functions=( ${preexec_functions:#_dots_test_report_preexec} _dots_test_report_preexec )
ZSH_INIT

trap 'zpty -d "$PTY_NAME" 2>/dev/null || true; rm -f "$INIT_FILE"' EXIT

zpty -b "$PTY_NAME" env TERM=xterm-256color COLUMNS=120 LINES=30 \
    "ZSH_DIR=$ZSH_DIR" DOTS_FAILURE_MESSAGE_CHANCE=100 \
    DOTS_FAILURE_ANIMATION=1 DOTS_FAILURE_GRADIENT_INTERVAL=0.02 \
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

# Type a command while the gradient is active, then submit it immediately.
zpty -w -n "$PTY_NAME" "sleep 0.1; print -r -- EX'ECUTED_OK'"
read_until_visible "EX'ECUTED_OK'"
assert_contains "input is accepted while the gradient animates" "EX'ECUTED_OK'" "$REPLY"

zpty -w -n "$PTY_NAME" $'\r'
read_until "SUBMITTED_ACTIVE_1_WORKER_1"
assert_contains "command submission does not cancel the active gradient" \
    "SUBMITTED_ACTIVE_1_WORKER_1" "$REPLY"
submitted_output="$REPLY"
if [[ "$submitted_output" != *"EXECUTED_OK"* ]]; then
    read_until "EXECUTED_OK"
    submitted_output+="${REPLY}"
fi
assert_contains "the submitted command executes unchanged" "EXECUTED_OK" "$submitted_output"

# Once the command exits and ZLE is active again, buffered frames are rendered.
read_until "BASE_OUTPUT"
local snapshot=''
local -i frame_attempt=0
while (( frame_attempt < 120 )); do
    zpty -w -n "$PTY_NAME" $'\x14'
    read_until_visible "BUFFER_SNAPSHOT_BEGIN:"
    snapshot="$REPLY"
    [[ "$snapshot" == *"FRAMES_25"* && "$snapshot" == *"WORKER_0"* ]] && break
    command sleep 0.05
    (( frame_attempt += 1 ))
done
assert_contains "all 25 gradient frames finish after command submission" "FRAMES_25" "$snapshot"
assert_contains "the gradient worker terminates after the final prompt redraw" "WORKER_0" "$snapshot"
assert_contains "the submitted command leaves a clean editable prompt" "BUFFER_SNAPSHOT_BEGIN::CURSOR_0" "$snapshot"

print -- "All single-gradient failure animation integration tests passed."

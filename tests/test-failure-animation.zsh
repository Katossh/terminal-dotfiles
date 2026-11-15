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
    zle -M "BUFFER_SNAPSHOT_BEGIN:${BUFFER}:CURSOR_${CURSOR}:FRAMES_${_DOTS_FAILURE_ANIMATION_LAST_BANNER_FRAMES}:ACTIVE_${_DOTS_FAILURE_GRADIENT_ACTIVE}:WORKER_${_DOTS_FAILURE_ANIMATION_ACTIVE}:BANNERS_${#_DOTS_FAILURE_GRADIENT_BANNERS}:PHASE_SLOTS_${#_DOTS_FAILURE_GRADIENT_PHASES}:STATE_${_DOTS_FAILURE_ANIMATION_STATE}:BANNER_${#_DOTS_FAILURE_ANIMATION_GRADIENT_PROMPT}"
}
zle -N _dots_test_buffer_snapshot
bindkey '^T' _dots_test_buffer_snapshot

_dots_test_queue_failure() {
    typeset -gi _DOTS_TEST_FAILURE_PENDING=1
    typeset -g _DOTS_TEST_FAILURE_COMMAND="${1:-missing-command}"
    typeset -g _DOTS_TEST_FAILURE_DETAIL="${2:-command not found}"
    print -r -- FAILURE_QUEUED
}
_dots_test_start_failure() {
    (( ${_DOTS_TEST_FAILURE_PENDING:-0} )) || return 0
    typeset -gi _DOTS_TEST_FAILURE_PENDING=0
    dots_failure_message not_found "$_DOTS_TEST_FAILURE_COMMAND" "$_DOTS_TEST_FAILURE_DETAIL"
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

# Leave the prompt idle beyond the old 25-frame cutoff. The gradient must
# still be active and the banner must remain available for live redraws.
local persistent_snapshot='' frame_count=''
local -i animation_attempt=0
while (( animation_attempt < 120 )); do
    zpty -w -n "$PTY_NAME" $'\C-T'
    read_until_visible "BUFFER_SNAPSHOT_BEGIN:"
    persistent_snapshot="$REPLY"
    frame_count="${persistent_snapshot##*FRAMES_}"
    frame_count="${frame_count%%:*}"
    if (( frame_count > 30 )); then
        break
    fi
    command sleep 0.03
    (( animation_attempt += 1 ))
done
(( frame_count > 30 )) || fail "gradient stopped before exceeding 30 frames"
assert_contains "gradient remains active beyond the former 25-frame limit" "ACTIVE_1" "$persistent_snapshot"
assert_contains "gradient worker keeps running while the prompt is idle" "WORKER_1" "$persistent_snapshot"
print -- "ok - gradient phase stream loops indefinitely while the banner is active"

# Typing and submitting a successful command must not cancel the first failure.
zpty -w -n "$PTY_NAME" "sleep 0.1; print -r -- EX'ECUTED_OK'"
read_until_visible "EX'ECUTED_OK'"
assert_contains "input is accepted while the gradient animates" "EX'ECUTED_OK'" "$REPLY"
zpty -w -n "$PTY_NAME" $'\C-M'
read_until "SUBMITTED_ACTIVE_1_WORKER_1"
assert_contains "command submission leaves the first gradient worker active" "SUBMITTED_ACTIVE_1_WORKER_1" "$REPLY"
submitted_output="$REPLY"
if [[ "$submitted_output" != *"EXECUTED_OK"* ]]; then
    read_until "EXECUTED_OK"
    submitted_output+="$REPLY"
fi
assert_contains "the submitted command executes unchanged" "EXECUTED_OK" "$submitted_output"

read_until "BASE_OUTPUT"
local snapshot=''
zpty -w -n "$PTY_NAME" $'\C-T'
read_until_visible "BUFFER_SNAPSHOT_BEGIN:"
snapshot="$REPLY"
assert_contains "the first failure remains registered after command submission" "BANNERS_1" "$snapshot"
assert_contains "the first failure remains animated on the next prompt" "WORKER_1" "$snapshot"
assert_contains "the first failure text remains visible" 'missing-command' "$snapshot"

# A second failed command must append a separate animation, not replace the first.
zpty -w -n "$PTY_NAME" "_dots_test_queue_failure second-missing 'second command not found'"
zpty -w -n "$PTY_NAME" $'\C-M'
read_until "SUBMITTED_ACTIVE_1_WORKER_1"
read_until FAILURE_QUEUED
read_until_visible 'second command not found'
assert_contains "the second failure is rendered" 'second command not found' "$REPLY"

zpty -w -n "$PTY_NAME" $'\C-T'
read_until_visible "BUFFER_SNAPSHOT_BEGIN:"
snapshot="$REPLY"
assert_contains "both failure banners are retained independently" "BANNERS_2" "$snapshot"
assert_contains "both failure animations share a live scheduler" "WORKER_1" "$snapshot"
assert_contains "the first failure survives the second failure" 'missing-command' "$snapshot"
assert_contains "the second failure has its own retained message" 'second-missing' "$snapshot"
assert_contains "each failure retains a separate phase slot" "PHASE_SLOTS_2" "$snapshot"

# A further successful command also leaves both animations running.
zpty -w -n "$PTY_NAME" "print -r -- FINAL_EXECUTED"
read_until_visible "FINAL_EXECUTED"
zpty -w -n "$PTY_NAME" $'\C-M'
read_until "SUBMITTED_ACTIVE_1_WORKER_1"
assert_contains "later command submission does not stop either animation" "SUBMITTED_ACTIVE_1_WORKER_1" "$REPLY"
read_until "FINAL_EXECUTED"
read_until "BASE_OUTPUT"

zpty -w -n "$PTY_NAME" $'\C-T'
read_until_visible "BUFFER_SNAPSHOT_BEGIN:"
snapshot="$REPLY"
assert_contains "both failures remain after another command" "BANNERS_2" "$snapshot"
assert_contains "both failure records remain available" 'missing-command' "$snapshot"
assert_contains "the newer failure remains available" 'second-missing' "$snapshot"
assert_contains "the scheduler remains active after repeated submissions" "WORKER_1" "$snapshot"

# Explicitly clearing the prompt is still allowed to remove every animation.
zpty -w -n "$PTY_NAME" $'\C-L'
zpty -w -n "$PTY_NAME" $'\C-T'
read_until_visible "BUFFER_SNAPSHOT_BEGIN:"
snapshot="$REPLY"
assert_contains "Ctrl+L explicitly clears all failure records" "BANNERS_0" "$snapshot"
assert_contains "Ctrl+L stops the shared gradient worker" "WORKER_0" "$snapshot"

print -- "All independent failure-gradient integration tests passed."

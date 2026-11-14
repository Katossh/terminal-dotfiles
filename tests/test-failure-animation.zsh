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

# Autonomous scrollback gradient: the failure message is printed directly into
# terminal output (not embedded in PROMPT) before the prompt appears.  OSC 4
# palette slots 180-191 are used for block 0.  Each character is coloured with
# \e[38;5;180m ... \e[38;5;191m.  A background worker updates those slots for
# 25 frames via OSC 4 sequences (\e]4;180;rgb:...\e\\).

cat > "$INIT_FILE" <<'ZSH_INIT'
setopt promptsubst
unset NO_COLOR
# Unset TMUX so OSC 4 sequences are not wrapped in tmux passthrough.
unset TMUX
STARSHIP_TEST_PROMPT=$'BASE_PATH\nBASE_OUTPUT ❯ '
PROMPT='$(print -rn -- "$STARSHIP_TEST_PROMPT")'
source "$ZSH_DIR/failure-messages.zsh"
source "$ZSH_DIR/failure-animation.zsh"
_DOTS_FAILURE_ANIMATION_STARTUP_PENDING=0

# Buffer snapshot written to ZLE message line.  Includes live worker count
# (not the stale precmd-updated flag) so we can verify self-termination.
_dots_test_buffer_snapshot() {
    _dots_failure_gradient_active_count
    local live=$REPLY
    zle -M "BUFFER_SNAPSHOT_BEGIN:${BUFFER}:CURSOR_${CURSOR}:WORKER_ALIVE_${live}:STATE_${_DOTS_FAILURE_ANIMATION_STATE}"
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

# Report gradient state at command submission (runs in preexec, before execution).
_dots_test_report_preexec() {
    _dots_failure_gradient_active_count
    print -r -- "PREEXEC_ACTIVE_${_DOTS_FAILURE_GRADIENT_ACTIVE}_WORKERS_${REPLY}"
}
preexec_functions=( ${preexec_functions:#_dots_test_report_preexec} _dots_test_report_preexec )

# Second failure queue for the multi-gradient coexistence test.
_dots_test_queue_failure2() {
    typeset -gi _DOTS_TEST_FAILURE2_PENDING=1
    print -r -- FAILURE2_QUEUED
}
_dots_test_start_failure2() {
    (( ${_DOTS_TEST_FAILURE2_PENDING:-0} )) || return 0
    typeset -gi _DOTS_TEST_FAILURE2_PENDING=0
    dots_failure_message permission_denied 'some-script' 'permission denied'
}
precmd_functions+=( _dots_test_start_failure2 )
ZSH_INIT

trap 'zpty -d "$PTY_NAME" 2>/dev/null || true; rm -f "$INIT_FILE"' EXIT

# Start PTY without inheriting TMUX so OSC 4 is not wrapped in passthrough.
zpty -b "$PTY_NAME" env -u TMUX TERM=xterm-256color COLUMNS=120 LINES=30 \
    "ZSH_DIR=$ZSH_DIR" DOTS_FAILURE_MESSAGE_CHANCE=100 \
    DOTS_FAILURE_ANIMATION=1 DOTS_FAILURE_GRADIENT_INTERVAL=0.12 \
    zsh -f -i

# Global accumulator: ALL raw PTY output since session start.
typeset -g _ALL_RAW=""

_pty_drain_all() {
    local data=''
    while zpty -r -t "$PTY_NAME" data 2>/dev/null; do
        _ALL_RAW+="$data"
    done
}

read_until() {
    local needle="$1"
    local -i tries=0
    local data=''
    while (( tries < 120 )); do
        if zpty -r -t "$PTY_NAME" data 2>/dev/null; then _ALL_RAW+="$data"; fi
        [[ "$_ALL_RAW" == *"$needle"* ]] && break
        command sleep 0.05
        (( tries += 1 ))
    done
    REPLY="$_ALL_RAW"
}

# Wait for output newer than the current accumulator, so a stale prompt or
# preexec marker from an earlier command cannot satisfy the assertion.
read_until_after() {
    local needle="$1"
    local before="$_ALL_RAW"
    local new_data=''
    local data=''
    local -i tries=0
    while (( tries < 120 )); do
        if zpty -r -t "$PTY_NAME" data 2>/dev/null; then _ALL_RAW+="$data"; fi
        new_data="${_ALL_RAW:${#before}}"
        [[ "$new_data" == *"$needle"* ]] && break
        command sleep 0.05
        (( tries += 1 ))
    done
    REPLY="$new_data"
}

_count_osc4_frames() {
    REPLY="$(print -rn -- "$1" | command python3 -c 'import sys; print(sys.stdin.buffer.read().count(bytes([27]) + b"]4;"))')"
}

# Strip ANSI CSI SGR and ED sequences for visible-text comparison.
_strip_sgr() {
    print -rn -- "$1" | command python3 -c \
        'import re, sys; sys.stdout.write(re.sub(r"(?:\x1b|\^\[)\[[0-9;]*[mJKH]", "", sys.stdin.read()))'
}

read_until_visible() {
    local needle="$1"
    local -i tries=0
    local data='' visible=''
    while (( tries < 120 )); do
        if zpty -r -t "$PTY_NAME" data 2>/dev/null; then _ALL_RAW+="$data"; fi
        visible="$(_strip_sgr "$_ALL_RAW")"
        [[ "$visible" == *"$needle"* ]] && break
        command sleep 0.05
        (( tries += 1 ))
    done
    REPLY="$visible"
}

drain_for() {
    local -i rounds="$1"
    local data=''
    while (( rounds > 0 )); do
        if zpty -r -t "$PTY_NAME" data 2>/dev/null; then _ALL_RAW+="$data"; fi
        command sleep 0.02
        rounds=$(( rounds - 1 ))
    done
}

# ── Startup ──────────────────────────────────────────────────────────────────

local chunk=''
local -i attempt=0
while (( attempt < 40 )); do
    if zpty -r -t "$PTY_NAME" chunk 2>/dev/null; then _ALL_RAW+="$chunk"; fi
    [[ -n "$_ALL_RAW" ]] && break
    command sleep 0.05
    (( attempt += 1 ))
done
[[ -n "$_ALL_RAW" ]] || fail "interactive child shell did not start"
print -- "ok - interactive child shell started"

zpty -w "$PTY_NAME" "source '$INIT_FILE'"
read_until "BASE_OUTPUT"
local visible_startup
visible_startup="$(_strip_sgr "$_ALL_RAW")"
assert_contains "normal prompt renders after sourcing the modules" "BASE_PATH" "$visible_startup"

# ── Single gradient: message layout ──────────────────────────────────────────

# Queue the failure and let precmd emit the banner before the next prompt.
zpty -w "$PTY_NAME" '_dots_test_queue_failure'$'\n'
read_until FAILURE_QUEUED
read_until_after "BASE_OUTPUT"

# No input is written to the PTY while the gradient is running.  The worker
# must continue emitting OSC 4 palette updates while ZLE is idle.
_count_osc4_frames "$_ALL_RAW"
local -i idle_frames_before=$REPLY
drain_for 20
_count_osc4_frames "$_ALL_RAW"
local -i idle_frames_after=$REPLY
(( idle_frames_after - idle_frames_before >= 2 )) ||
    fail "gradient advances without user input (before=$idle_frames_before after=$idle_frames_after)"
print -- "ok - gradient advances autonomously while the PTY receives no user input"

local full_visible
full_visible="$(_strip_sgr "$_ALL_RAW")"

assert_contains "one deterministic error message appears" '✖ Command "missing-command" failed.' "$full_visible"
assert_contains "diagnostic detail appears below the message" 'command not found' "$full_visible"
assert_contains "failure banner precedes the next prompt" "BASE_OUTPUT" "$full_visible"
assert_contains "path line remains intact" "BASE_PATH" "$full_visible"

# ── Raw escape-byte checks ────────────────────────────────────────────────────

# New architecture: message characters use 256-colour palette indices (\e[38;5;NNNm).
[[ "$_ALL_RAW" == *$'\e[38;5;'* ]] || fail "gradient did not emit 256-colour palette-index ANSI bytes (\e[38;5;)"
print -- "ok - 256-colour palette-index sequences present in PTY output"
assert_absent "gradient does not emit printable caret escape notation" '^[[38;5;' "$_ALL_RAW"

# OSC 4 sequences from the autonomous worker must appear in the PTY output.
[[ "$_ALL_RAW" == *$'\e]4;'* ]] || fail "autonomous gradient worker did not emit OSC 4 palette update sequences"
print -- "ok - autonomous OSC 4 palette frames received in PTY output"

# 24-bit TrueColor is NOT used for the message text (palette slots are used instead).
assert_absent "gradient message text does not embed raw 24-bit TrueColor codes" $'\e[38;2;' "$_ALL_RAW"

# ── Gradient independence: user can type while worker runs ───────────────────

# Type a command while the gradient worker is still running.
zpty -w -n "$PTY_NAME" 'sleep 0.24; print -r -- TYPED_DURING_GRADIENT'
read_until_visible "TYPED_DURING_GRADIENT"
assert_contains "input is accepted while the gradient animates" "TYPED_DURING_GRADIENT" "$REPLY"

# ── Command submission does not stop the gradient worker ─────────────────────

# Inspect the live child-shell PID count while the command is typed but before
# Enter.  This distinguishes a completed frame lifecycle from submit-triggered
# cancellation.
zpty -w -n "$PTY_NAME" # preexec fires before the command executes and prints PREEXEC_ACTIVE.
_count_osc4_frames "$_ALL_RAW"
local -i foreground_frames_before=$REPLY
read_until_after "PREEXEC_ACTIVE_"
assert_contains "gradient worker is still alive when Enter submits the command" \
    "PREEXEC_ACTIVE_1_WORKERS_1" "$REPLY"

# The foreground sleep temporarily removes ZLE from the terminal, but the
# detached animation worker must continue writing palette updates to the TTY.
read_until_after "BASE_OUTPUT"
local command_output="$REPLY"
_count_osc4_frames "$_ALL_RAW"
local -i foreground_frames_after=$REPLY
(( foreground_frames_after - foreground_frames_before >= 2 )) ||
    fail "gradient advances while a foreground command runs (before=$foreground_frames_before after=$foreground_frames_after)"
print -- "ok - gradient advances while the shell executes a foreground command"

local post_cmd_visible
post_cmd_visible="$(_strip_sgr "$command_output")"
assert_contains "foreground command output appears after submission" \
    "TYPED_DURING_GRADIENT" "$post_cmd_visible"
assert_contains "next prompt appears after command completes" "BASE_OUTPUT" "$command_output"

# ── PROMPT is clean: no banner embedded in PROMPT string ─────────────────────

local snapshot=''
local -i snap_attempt=0
while (( snap_attempt < 60 )); do
    zpty -w -n "$PTY_NAME" $'\x14'
    read_until_after "BUFFER_SNAPSHOT_BEGIN:"
    snapshot="$REPLY"
    [[ "$snapshot" == *"BUFFER_SNAPSHOT_BEGIN:"* ]] && break
    command sleep 0.05
    (( snap_attempt += 1 ))
done
assert_contains "buffer snapshot received" "BUFFER_SNAPSHOT_BEGIN:" "$snapshot"
assert_contains "prompt buffer is clean (no banner text in BUFFER)" "BUFFER_SNAPSHOT_BEGIN::CURSOR_0" "$snapshot"

# ── Second failure: messages coexist in scrollback ───────────────────────────

# Allow the first gradient worker to finish completely before the second failure.
# (24 palette updates * 0.12s = 2.88s; wait with scheduling headroom.)
command sleep 3.2

zpty -w "$PTY_NAME" '_dots_test_queue_failure2'$'\n'
read_until FAILURE2_QUEUED
read_until_after "BASE_OUTPUT"
drain_for 10

local second_visible
second_visible="$(_strip_sgr "$_ALL_RAW")"

assert_contains "second failure message appears" 'permission denied' "$second_visible"
# Both messages must coexist in the scrollback visible text.
assert_contains "first failure message still present after second failure" \
    '✖ Command "missing-command" failed.' "$second_visible"

# The second message uses 256-colour palette slots (may reuse block 0 since
# the first worker finished, or use block 1 if still running).
[[ "$_ALL_RAW" == *$'\e[38;5;'* ]] ||
    fail "second failure message did not use 256-colour palette-index sequences"
print -- "ok - second failure uses 256-colour palette-index sequences"

# ── Worker lifecycle: workers self-terminate after their frame cycle ───────────

# Allow time for the second worker's 24 palette updates (24 * 0.12s + headroom).
command sleep 3.2

# Ask the shell to report live worker count via the ZLE snapshot widget.
local final_snap=''
local -i fs_attempt=0
while (( fs_attempt < 60 )); do
    zpty -w -n "$PTY_NAME" $'\x14'
    read_until_after "BUFFER_SNAPSHOT_BEGIN:"
    final_snap="$REPLY"
    [[ "$final_snap" == *"WORKER_ALIVE_"* ]] && break
    command sleep 0.05
    (( fs_attempt += 1 ))
done
assert_contains "gradient workers self-terminate after their frame lifecycle" \
    "WORKER_ALIVE_0" "$final_snap"

print -- "All single-gradient failure animation integration tests passed."
\x14'
read_until_after "BUFFER_SNAPSHOT_BEGIN:"
local pre_submit_snapshot="$REPLY"
assert_contains "gradient worker remains alive while a command is being typed" \
    "WORKER_ALIVE_1" "$pre_submit_snapshot"

zpty -w -n "$PTY_NAME" # preexec fires before the command executes and prints PREEXEC_ACTIVE.
_count_osc4_frames "$_ALL_RAW"
local -i foreground_frames_before=$REPLY
read_until_after "PREEXEC_ACTIVE_"
assert_contains "gradient worker is still alive when Enter submits the command" \
    "PREEXEC_ACTIVE_1_WORKERS_1" "$REPLY"

# The foreground sleep temporarily removes ZLE from the terminal, but the
# detached animation worker must continue writing palette updates to the TTY.
read_until_after "BASE_OUTPUT"
local command_output="$REPLY"
_count_osc4_frames "$_ALL_RAW"
local -i foreground_frames_after=$REPLY
(( foreground_frames_after - foreground_frames_before >= 2 )) ||
    fail "gradient advances while a foreground command runs (before=$foreground_frames_before after=$foreground_frames_after)"
print -- "ok - gradient advances while the shell executes a foreground command"

local post_cmd_visible
post_cmd_visible="$(_strip_sgr "$command_output")"
assert_contains "foreground command output appears after submission" \
    "TYPED_DURING_GRADIENT" "$post_cmd_visible"
assert_contains "next prompt appears after command completes" "BASE_OUTPUT" "$command_output"

# ── PROMPT is clean: no banner embedded in PROMPT string ─────────────────────

local snapshot=''
local -i snap_attempt=0
while (( snap_attempt < 60 )); do
    zpty -w -n "$PTY_NAME" $'\x14'
    read_until_after "BUFFER_SNAPSHOT_BEGIN:"
    snapshot="$REPLY"
    [[ "$snapshot" == *"BUFFER_SNAPSHOT_BEGIN:"* ]] && break
    command sleep 0.05
    (( snap_attempt += 1 ))
done
assert_contains "buffer snapshot received" "BUFFER_SNAPSHOT_BEGIN:" "$snapshot"
assert_contains "prompt buffer is clean (no banner text in BUFFER)" "BUFFER_SNAPSHOT_BEGIN::CURSOR_0" "$snapshot"

# ── Second failure: messages coexist in scrollback ───────────────────────────

# Allow the first gradient worker to finish completely before the second failure.
# (24 palette updates * 0.12s = 2.88s; wait with scheduling headroom.)
command sleep 3.2

zpty -w "$PTY_NAME" '_dots_test_queue_failure2'$'\n'
read_until FAILURE2_QUEUED
read_until_after "BASE_OUTPUT"
drain_for 10

local second_visible
second_visible="$(_strip_sgr "$_ALL_RAW")"

assert_contains "second failure message appears" 'permission denied' "$second_visible"
# Both messages must coexist in the scrollback visible text.
assert_contains "first failure message still present after second failure" \
    '✖ Command "missing-command" failed.' "$second_visible"

# The second message uses 256-colour palette slots (may reuse block 0 since
# the first worker finished, or use block 1 if still running).
[[ "$_ALL_RAW" == *$'\e[38;5;'* ]] ||
    fail "second failure message did not use 256-colour palette-index sequences"
print -- "ok - second failure uses 256-colour palette-index sequences"

# ── Worker lifecycle: workers self-terminate after their frame cycle ───────────

# Allow time for the second worker's 24 palette updates (24 * 0.12s + headroom).
command sleep 3.2

# Ask the shell to report live worker count via the ZLE snapshot widget.
local final_snap=''
local -i fs_attempt=0
while (( fs_attempt < 60 )); do
    zpty -w -n "$PTY_NAME" $'\x14'
    read_until_after "BUFFER_SNAPSHOT_BEGIN:"
    final_snap="$REPLY"
    [[ "$final_snap" == *"WORKER_ALIVE_"* ]] && break
    command sleep 0.05
    (( fs_attempt += 1 ))
done
assert_contains "gradient workers self-terminate after their frame lifecycle" \
    "WORKER_ALIVE_0" "$final_snap"

print -- "All single-gradient failure animation integration tests passed."
\r'
# preexec fires before the command executes and prints PREEXEC_ACTIVE.
_count_osc4_frames "$_ALL_RAW"
local -i foreground_frames_before=$REPLY
read_until_after "PREEXEC_ACTIVE_"
assert_contains "gradient worker is still alive when Enter submits the command" \
    "PREEXEC_ACTIVE_1_WORKERS_1" "$REPLY"

# The foreground sleep temporarily removes ZLE from the terminal, but the
# detached animation worker must continue writing palette updates to the TTY.
read_until_after "BASE_OUTPUT"
local command_output="$REPLY"
_count_osc4_frames "$_ALL_RAW"
local -i foreground_frames_after=$REPLY
(( foreground_frames_after - foreground_frames_before >= 2 )) ||
    fail "gradient advances while a foreground command runs (before=$foreground_frames_before after=$foreground_frames_after)"
print -- "ok - gradient advances while the shell executes a foreground command"

local post_cmd_visible
post_cmd_visible="$(_strip_sgr "$command_output")"
assert_contains "foreground command output appears after submission" \
    "TYPED_DURING_GRADIENT" "$post_cmd_visible"
assert_contains "next prompt appears after command completes" "BASE_OUTPUT" "$command_output"

# ── PROMPT is clean: no banner embedded in PROMPT string ─────────────────────

local snapshot=''
local -i snap_attempt=0
while (( snap_attempt < 60 )); do
    zpty -w -n "$PTY_NAME" $'\x14'
    read_until_after "BUFFER_SNAPSHOT_BEGIN:"
    snapshot="$REPLY"
    [[ "$snapshot" == *"BUFFER_SNAPSHOT_BEGIN:"* ]] && break
    command sleep 0.05
    (( snap_attempt += 1 ))
done
assert_contains "buffer snapshot received" "BUFFER_SNAPSHOT_BEGIN:" "$snapshot"
assert_contains "prompt buffer is clean (no banner text in BUFFER)" "BUFFER_SNAPSHOT_BEGIN::CURSOR_0" "$snapshot"

# ── Second failure: messages coexist in scrollback ───────────────────────────

# Allow the first gradient worker to finish completely before the second failure.
# (24 palette updates * 0.12s = 2.88s; wait with scheduling headroom.)
command sleep 3.2

zpty -w "$PTY_NAME" '_dots_test_queue_failure2'$'\n'
read_until FAILURE2_QUEUED
read_until_after "BASE_OUTPUT"
drain_for 10

local second_visible
second_visible="$(_strip_sgr "$_ALL_RAW")"

assert_contains "second failure message appears" 'permission denied' "$second_visible"
# Both messages must coexist in the scrollback visible text.
assert_contains "first failure message still present after second failure" \
    '✖ Command "missing-command" failed.' "$second_visible"

# The second message uses 256-colour palette slots (may reuse block 0 since
# the first worker finished, or use block 1 if still running).
[[ "$_ALL_RAW" == *$'\e[38;5;'* ]] ||
    fail "second failure message did not use 256-colour palette-index sequences"
print -- "ok - second failure uses 256-colour palette-index sequences"

# ── Worker lifecycle: workers self-terminate after their frame cycle ───────────

# Allow time for the second worker's 24 palette updates (24 * 0.12s + headroom).
command sleep 3.2

# Ask the shell to report live worker count via the ZLE snapshot widget.
local final_snap=''
local -i fs_attempt=0
while (( fs_attempt < 60 )); do
    zpty -w -n "$PTY_NAME" $'\x14'
    read_until_after "BUFFER_SNAPSHOT_BEGIN:"
    final_snap="$REPLY"
    [[ "$final_snap" == *"WORKER_ALIVE_"* ]] && break
    command sleep 0.05
    (( fs_attempt += 1 ))
done
assert_contains "gradient workers self-terminate after their frame lifecycle" \
    "WORKER_ALIVE_0" "$final_snap"

print -- "All single-gradient failure animation integration tests passed."

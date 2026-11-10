#!/usr/bin/env zsh
setopt errexit nounset

REPO_DIR="${0:A:h:h}"
ZSH_DIR="$REPO_DIR/config/terminal/zsh"
INIT_FILE="$(mktemp)"
PTY_NAME="dots_failure_animation_test"

fail() { print -u2 -r -- "not ok - $*"; exit 1; }
assert_contains() {
    local label="$1" needle="$2" haystack="$3"
    [[ "$haystack" == *"$needle"* ]] || fail "$label (missing: $needle; captured: $haystack)"
    print -- "ok - $label"
}

zmodload zsh/zpty 2>/dev/null || {
    print -- "skip - zsh/zpty is unavailable"
    exit 0
}

cat > "$INIT_FILE" <<'ZSH_INIT'
PROMPT=$'BASE_PATH\nBASE_OUTPUT '
RPROMPT='BASE_RPROMPT'
source "$ZSH_DIR/failure-messages.zsh"
source "$ZSH_DIR/failure-animation.zsh"

# Keep the production code path while shortening the test animation.
_DOTS_FAILURE_ANIMATION_INTERVAL=0.001

_dots_test_prompt_report() {
    local -a prompt_lines
    prompt_lines=("${(@f)PROMPT}")
    local first="${prompt_lines[1]-}"
    local second="${prompt_lines[2]-}"
    local -i layout=0
    [[ "$first" == *BASE_PATH* && "$first" == *"✧━━"* &&
        "$second" == "BASE_OUTPUT " ]] && layout=1
    print -r -- "PROMPT_STATE ACTIVE_${_DOTS_FAILURE_ANIMATION_ACTIVE} STATE_${_DOTS_FAILURE_ANIMATION_STATE} LAYOUT_${layout}"
}
typeset -ga precmd_functions
precmd_functions+=(_dots_test_prompt_report)
print -r -- MODULES_READY
ZSH_INIT

zpty -b "$PTY_NAME" env TERM=xterm-256color COLUMNS=120 LINES=30 \
    DOTS_FAILURE_MESSAGE_CHANCE=100 DOTS_FAILURE_ANIMATION_CHANCE=100 \
    DOTS_FAILURE_STYLE=normal DOTS_FAILURE_MESSAGE_ESCALATION=0 DOTS_FAILURE_ANIMATION=1 \
    "ZSH_DIR=$ZSH_DIR" zsh -f -i
trap 'zpty -d "$PTY_NAME" 2>/dev/null || true; rm -f "$INIT_FILE"' EXIT

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

# Wait for the clean shell, then source the same modules as the real .zshrc.
# Its first precmd after module initialisation must launch the startup animation.
local_startup=''
typeset chunk=''
typeset -i attempt=0
while (( attempt < 40 )); do
    if zpty -r -t "$PTY_NAME" chunk; then local_startup+="$chunk"; fi
    [[ -n "$local_startup" ]] && break
    command sleep 0.05
    (( attempt += 1 ))
done
if [[ -z "$local_startup" ]]; then fail "interactive child shell did not reach its prompt"; fi
print -- "ok - clean interactive child shell reached its prompt"

zpty -w "$PTY_NAME" "source '$INIT_FILE'"
read_until "PROMPT_STATE ACTIVE_1"
assert_contains "first prompt after Zsh module initialisation starts animation" "PROMPT_STATE ACTIVE_1" "$REPLY"
assert_contains "animation sits between path and the second prompt line" "LAYOUT_1" "$REPLY"

# Drain terminal output while the asynchronous stream finishes.
drain_for 220
zpty -w "$PTY_NAME" 'print -r -- "STARTUP_FINISHED ACTIVE_${_DOTS_FAILURE_ANIMATION_ACTIVE} LAST_FRAMES_${_DOTS_FAILURE_ANIMATION_LAST_FRAMES} LAST_STATE_${_DOTS_FAILURE_ANIMATION_LAST_STATE} FRAME_${_DOTS_FAILURE_ANIMATION_FRAME}"; print -r -- STATE_INSPECTION_DONE'
assert_contains "startup animation completed all 36 frames" "STARTUP_FINISHED ACTIVE_0 LAST_FRAMES_36 LAST_STATE_stream-complete" "$REPLY"
read_until "PROMPT_STATE ACTIVE_0"
assert_contains "final startup frame remains in the prompt" "LAYOUT_1" "$REPLY"

# Trigger the real public renderer; the queued animation starts in precmd.
zpty -w "$PTY_NAME" 'dots_failure_message generic animation-integration-test; print -r -- FAILURE_MESSAGE_RETURNED; print -r -- FAILURE_COMMAND_DONE'
assert_contains "public failure-message renderer returned" "FAILURE_MESSAGE_RETURNED" "$REPLY"
read_until "PROMPT_STATE ACTIVE_1"
assert_contains "failure notification starts another animation" "PROMPT_STATE ACTIVE_1" "$REPLY"

# Enter cancels the remaining frames but must not clear the latest one.
command sleep 0.08
zpty -w "$PTY_NAME" 'print -r -- "INPUT_ACCEPTED ACTIVE_${_DOTS_FAILURE_ANIMATION_ACTIVE} FRAME_${_DOTS_FAILURE_ANIMATION_FRAME} RPROMPT_${RPROMPT}"; print -r -- INPUT_INSPECTION_DONE'
assert_contains "keyboard input remains responsive during animation" "INPUT_ACCEPTED ACTIVE_0" "$REPLY"
assert_contains "right prompt remains unchanged" "RPROMPT_BASE_RPROMPT" "$REPLY"
read_until "PROMPT_STATE ACTIVE_0"
assert_contains "latest frame persists after Enter" "LAYOUT_1" "$REPLY"

print -- "All persistent multiline animation integration tests passed."
\n'
read_until STATE_INSPECTION_DONE
assert_contains "startup animation completed all 36 frames" "STARTUP_FINISHED ACTIVE_0 LAST_FRAMES_36 LAST_STATE_stream-complete" "$REPLY"
read_until "PROMPT_STATE ACTIVE_0"
assert_contains "final startup frame remains in the prompt" "LAYOUT_1" "$REPLY"

# Trigger the real public renderer; the queued animation starts in precmd.
zpty -w "$PTY_NAME" 'dots_failure_message generic animation-integration-test; print -r -- FAILURE_MESSAGE_RETURNED'$'\n'
read_until FAILURE_MESSAGE_RETURNED
assert_contains "public failure-message renderer returned" "FAILURE_MESSAGE_RETURNED" "$REPLY"
read_until "PROMPT_STATE ACTIVE_1"
assert_contains "failure notification starts another animation" "PROMPT_STATE ACTIVE_1" "$REPLY"

# Enter cancels the remaining frames but must not clear the latest one.
command sleep 0.08
zpty -w "$PTY_NAME" 'print -r -- "INPUT_ACCEPTED ACTIVE_${_DOTS_FAILURE_ANIMATION_ACTIVE} FRAME_${_DOTS_FAILURE_ANIMATION_FRAME} RPROMPT_${RPROMPT}"'$'\n'
read_until INPUT_ACCEPTED
assert_contains "keyboard input remains responsive during animation" "INPUT_ACCEPTED ACTIVE_0" "$REPLY"
assert_contains "right prompt remains unchanged" "RPROMPT_BASE_RPROMPT" "$REPLY"
read_until "PROMPT_STATE ACTIVE_0"
assert_contains "latest frame persists after Enter" "LAYOUT_1" "$REPLY"

print -- "All persistent multiline animation integration tests passed."
\n'
read_until FAILURE_COMMAND_DONE
assert_contains "public failure-message renderer returned" "FAILURE_MESSAGE_RETURNED" "$REPLY"
read_until "PROMPT_STATE ACTIVE_1"
assert_contains "failure notification starts another animation" "PROMPT_STATE ACTIVE_1" "$REPLY"

# Enter cancels the remaining frames but must not clear the latest one.
command sleep 0.08
zpty -w "$PTY_NAME" 'print -r -- "INPUT_ACCEPTED ACTIVE_${_DOTS_FAILURE_ANIMATION_ACTIVE} FRAME_${_DOTS_FAILURE_ANIMATION_FRAME} RPROMPT_${RPROMPT}"'$'\n'
read_until INPUT_ACCEPTED
assert_contains "keyboard input remains responsive during animation" "INPUT_ACCEPTED ACTIVE_0" "$REPLY"
assert_contains "right prompt remains unchanged" "RPROMPT_BASE_RPROMPT" "$REPLY"
read_until "PROMPT_STATE ACTIVE_0"
assert_contains "latest frame persists after Enter" "LAYOUT_1" "$REPLY"

print -- "All persistent multiline animation integration tests passed."
\n'
read_until STATE_INSPECTION_DONE
assert_contains "startup animation completed all 36 frames" "STARTUP_FINISHED ACTIVE_0 LAST_FRAMES_36 LAST_STATE_stream-complete" "$REPLY"
read_until "PROMPT_STATE ACTIVE_0"
assert_contains "final startup frame remains in the prompt" "LAYOUT_1" "$REPLY"

# Trigger the real public renderer; the queued animation starts in precmd.
zpty -w "$PTY_NAME" 'dots_failure_message generic animation-integration-test; print -r -- FAILURE_MESSAGE_RETURNED'$'\n'
read_until FAILURE_MESSAGE_RETURNED
assert_contains "public failure-message renderer returned" "FAILURE_MESSAGE_RETURNED" "$REPLY"
read_until "PROMPT_STATE ACTIVE_1"
assert_contains "failure notification starts another animation" "PROMPT_STATE ACTIVE_1" "$REPLY"

# Enter cancels the remaining frames but must not clear the latest one.
command sleep 0.08
zpty -w "$PTY_NAME" 'print -r -- "INPUT_ACCEPTED ACTIVE_${_DOTS_FAILURE_ANIMATION_ACTIVE} FRAME_${_DOTS_FAILURE_ANIMATION_FRAME} RPROMPT_${RPROMPT}"'$'\n'
read_until INPUT_ACCEPTED
assert_contains "keyboard input remains responsive during animation" "INPUT_ACCEPTED ACTIVE_0" "$REPLY"
assert_contains "right prompt remains unchanged" "RPROMPT_BASE_RPROMPT" "$REPLY"
read_until "PROMPT_STATE ACTIVE_0"
assert_contains "latest frame persists after Enter" "LAYOUT_1" "$REPLY"

print -- "All persistent multiline animation integration tests passed."
\n'
read_until INPUT_INSPECTION_DONE
assert_contains "keyboard input remains responsive during animation" "INPUT_ACCEPTED ACTIVE_0" "$REPLY"
assert_contains "right prompt remains unchanged" "RPROMPT_BASE_RPROMPT" "$REPLY"
read_until "PROMPT_STATE ACTIVE_0"
assert_contains "latest frame persists after Enter" "LAYOUT_1" "$REPLY"

print -- "All persistent multiline animation integration tests passed."
\n'
read_until STATE_INSPECTION_DONE
assert_contains "startup animation completed all 36 frames" "STARTUP_FINISHED ACTIVE_0 LAST_FRAMES_36 LAST_STATE_stream-complete" "$REPLY"
read_until "PROMPT_STATE ACTIVE_0"
assert_contains "final startup frame remains in the prompt" "LAYOUT_1" "$REPLY"

# Trigger the real public renderer; the queued animation starts in precmd.
zpty -w "$PTY_NAME" 'dots_failure_message generic animation-integration-test; print -r -- FAILURE_MESSAGE_RETURNED'$'\n'
read_until FAILURE_MESSAGE_RETURNED
assert_contains "public failure-message renderer returned" "FAILURE_MESSAGE_RETURNED" "$REPLY"
read_until "PROMPT_STATE ACTIVE_1"
assert_contains "failure notification starts another animation" "PROMPT_STATE ACTIVE_1" "$REPLY"

# Enter cancels the remaining frames but must not clear the latest one.
command sleep 0.08
zpty -w "$PTY_NAME" 'print -r -- "INPUT_ACCEPTED ACTIVE_${_DOTS_FAILURE_ANIMATION_ACTIVE} FRAME_${_DOTS_FAILURE_ANIMATION_FRAME} RPROMPT_${RPROMPT}"'$'\n'
read_until INPUT_ACCEPTED
assert_contains "keyboard input remains responsive during animation" "INPUT_ACCEPTED ACTIVE_0" "$REPLY"
assert_contains "right prompt remains unchanged" "RPROMPT_BASE_RPROMPT" "$REPLY"
read_until "PROMPT_STATE ACTIVE_0"
assert_contains "latest frame persists after Enter" "LAYOUT_1" "$REPLY"

print -- "All persistent multiline animation integration tests passed."
\n'
read_until FAILURE_COMMAND_DONE
assert_contains "public failure-message renderer returned" "FAILURE_MESSAGE_RETURNED" "$REPLY"
read_until "PROMPT_STATE ACTIVE_1"
assert_contains "failure notification starts another animation" "PROMPT_STATE ACTIVE_1" "$REPLY"

# Enter cancels the remaining frames but must not clear the latest one.
command sleep 0.08
zpty -w "$PTY_NAME" 'print -r -- "INPUT_ACCEPTED ACTIVE_${_DOTS_FAILURE_ANIMATION_ACTIVE} FRAME_${_DOTS_FAILURE_ANIMATION_FRAME} RPROMPT_${RPROMPT}"'$'\n'
read_until INPUT_ACCEPTED
assert_contains "keyboard input remains responsive during animation" "INPUT_ACCEPTED ACTIVE_0" "$REPLY"
assert_contains "right prompt remains unchanged" "RPROMPT_BASE_RPROMPT" "$REPLY"
read_until "PROMPT_STATE ACTIVE_0"
assert_contains "latest frame persists after Enter" "LAYOUT_1" "$REPLY"

print -- "All persistent multiline animation integration tests passed."
\n'
read_until STATE_INSPECTION_DONE
assert_contains "startup animation completed all 36 frames" "STARTUP_FINISHED ACTIVE_0 LAST_FRAMES_36 LAST_STATE_stream-complete" "$REPLY"
read_until "PROMPT_STATE ACTIVE_0"
assert_contains "final startup frame remains in the prompt" "LAYOUT_1" "$REPLY"

# Trigger the real public renderer; the queued animation starts in precmd.
zpty -w "$PTY_NAME" 'dots_failure_message generic animation-integration-test; print -r -- FAILURE_MESSAGE_RETURNED'$'\n'
read_until FAILURE_MESSAGE_RETURNED
assert_contains "public failure-message renderer returned" "FAILURE_MESSAGE_RETURNED" "$REPLY"
read_until "PROMPT_STATE ACTIVE_1"
assert_contains "failure notification starts another animation" "PROMPT_STATE ACTIVE_1" "$REPLY"

# Enter cancels the remaining frames but must not clear the latest one.
command sleep 0.08
zpty -w "$PTY_NAME" 'print -r -- "INPUT_ACCEPTED ACTIVE_${_DOTS_FAILURE_ANIMATION_ACTIVE} FRAME_${_DOTS_FAILURE_ANIMATION_FRAME} RPROMPT_${RPROMPT}"'$'\n'
read_until INPUT_ACCEPTED
assert_contains "keyboard input remains responsive during animation" "INPUT_ACCEPTED ACTIVE_0" "$REPLY"
assert_contains "right prompt remains unchanged" "RPROMPT_BASE_RPROMPT" "$REPLY"
read_until "PROMPT_STATE ACTIVE_0"
assert_contains "latest frame persists after Enter" "LAYOUT_1" "$REPLY"

print -- "All persistent multiline animation integration tests passed."

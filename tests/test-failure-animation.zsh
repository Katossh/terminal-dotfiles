#!/usr/bin/env zsh
setopt errexit nounset

REPO_DIR="${0:A:h:h}"
ZSH_DIR="$REPO_DIR/config/terminal/zsh"
TEST_ZDOTDIR="$(mktemp -d)"
PTY_NAME="dots_failure_animation_test"

fail() { print -u2 -r -- "not ok - $*"; exit 1; }
assert_contains() {
    local label="$1" needle="$2" haystack="$3"
    [[ "$haystack" == *"$needle"* ]] || fail "$label (missing: $needle)"
    print -- "ok - $label"
}

zmodload zsh/zpty 2>/dev/null || {
    print -- "skip - zsh/zpty is unavailable"
    exit 0
}

cat > "$TEST_ZDOTDIR/.zshrc" <<'ZSHRC'
PROMPT='BASE_PATH'$'\n''BASE_OUTPUT '
RPROMPT='BASE_RPROMPT'
source "$ZSH_DIR/failure-messages.zsh"
source "$ZSH_DIR/failure-animation.zsh"

# Keep the production code path while making the integration test fast.
_DOTS_FAILURE_ANIMATION_INTERVAL=0.001

_dots_test_prompt_report() {
    local first="${PROMPT%%$'\n'*}"
    local second="${PROMPT#*$'\n'}"
    local -i layout=0
    [[ "$first" == *BASE_PATH* && "$first" == *"✧━━"* &&
        "$second" == "BASE_OUTPUT " ]] && layout=1
    print -r -- "PROMPT_STATE ACTIVE_${_DOTS_FAILURE_ANIMATION_ACTIVE} STATE_${_DOTS_FAILURE_ANIMATION_STATE} LAYOUT_${layout}"
}
typeset -ga precmd_functions
precmd_functions+=(_dots_test_prompt_report)
print -r -- DOTS_TEST_ZSHRC_LOADED
ZSHRC

zpty -b "$PTY_NAME" env TERM=xterm-256color COLUMNS=120 LINES=30 \
    DOTS_FAILURE_MESSAGE_CHANCE=100 DOTS_FAILURE_ANIMATION_CHANCE=100 \
    DOTS_FAILURE_STYLE=normal DOTS_FAILURE_MESSAGE_ESCALATION=0 DOTS_FAILURE_ANIMATION=1 \
    "ZSH_DIR=$ZSH_DIR" "HOME=$TEST_ZDOTDIR" "ZDOTDIR=$TEST_ZDOTDIR" zsh -i
trap 'zpty -d "$PTY_NAME" 2>/dev/null || true; rm -rf "$TEST_ZDOTDIR"' EXIT

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

# Startup animation must happen at the first prompt, without a failed command.
read_until "DOTS_TEST_ZSHRC_LOADED"
assert_contains "temporary startup file was loaded" "DOTS_TEST_ZSHRC_LOADED" "$REPLY"
read_until "PROMPT_STATE ACTIVE_1"
assert_contains "first interactive prompt starts the animation" "PROMPT_STATE ACTIVE_1" "$REPLY"
assert_contains "animation occupies the path line before line_break" "LAYOUT_1" "$REPLY"

# Let the 36-frame startup animation complete and inspect the persistent state.
drain_for 60
zpty -w "$PTY_NAME" 'print -r -- "STARTUP_FINISHED ACTIVE_${_DOTS_FAILURE_ANIMATION_ACTIVE} LAST_FRAMES_${_DOTS_FAILURE_ANIMATION_LAST_FRAMES} LAST_STATE_${_DOTS_FAILURE_ANIMATION_LAST_STATE} FRAME_${_DOTS_FAILURE_ANIMATION_FRAME}"'$'\n'
read_until STARTUP_FINISHED
assert_contains "startup animation completes all frames" "STARTUP_FINISHED ACTIVE_0 LAST_FRAMES_36 LAST_STATE_stream-complete" "$REPLY"
read_until "PROMPT_STATE ACTIVE_0"
assert_contains "final startup frame remains visible" "LAYOUT_1" "$REPLY"

# The public message renderer queues another animation for the next prompt.
zpty -w "$PTY_NAME" 'dots_failure_message generic animation-integration-test; print -r -- FAILURE_MESSAGE_RETURNED'$'\n'
read_until FAILURE_MESSAGE_RETURNED
assert_contains "public failure-message renderer returned" "FAILURE_MESSAGE_RETURNED" "$REPLY"
read_until "PROMPT_STATE ACTIVE_1"
assert_contains "failure notice starts a new animation" "PROMPT_STATE ACTIVE_1" "$REPLY"

# Enter must cancel the remaining frames but preserve the latest one.
command sleep 0.08
zpty -w "$PTY_NAME" 'print -r -- "INPUT_ACCEPTED ACTIVE_${_DOTS_FAILURE_ANIMATION_ACTIVE} FRAME_${_DOTS_FAILURE_ANIMATION_FRAME} RPROMPT_${RPROMPT}"'$'\n'
read_until INPUT_ACCEPTED
assert_contains "keyboard input remains responsive during animation" "INPUT_ACCEPTED ACTIVE_0" "$REPLY"
assert_contains "RPROMPT is untouched" "RPROMPT_BASE_RPROMPT" "$REPLY"
read_until "PROMPT_STATE ACTIVE_0"
assert_contains "latest frame persists after Enter" "LAYOUT_1" "$REPLY"

print -- "All persistent multiline animation integration tests passed."

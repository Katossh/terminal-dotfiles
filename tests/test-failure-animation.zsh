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
setopt promptsubst
STARSHIP_TEST_PROMPT=$'BASE_PATH\nBASE_OUTPUT '
PROMPT='$(print -rn -- "$STARSHIP_TEST_PROMPT")'
RPROMPT='BASE_RPROMPT'
source "$ZSH_DIR/failure-messages.zsh"
source "$ZSH_DIR/failure-animation.zsh"

_DOTS_FAILURE_ANIMATION_INTERVAL=0.05

_dots_test_enable_continuous() {
    export DOTS_FAILURE_ANIMATION_CONTINUOUS=1
    print -r -- CONTINUOUS_ENABLED
}

_dots_test_stop_continuous_widget() {
    export DOTS_FAILURE_ANIMATION_CONTINUOUS=0
    zle .accept-line
}
zle -N _dots_test_stop_continuous_widget
bindkey '^X' _dots_test_stop_continuous_widget

_dots_test_prompt_report() {
    local rendered
    local -a prompt_lines
    rendered="$(_dots_failure_animation_render_prompt)"
    prompt_lines=("${(@f)rendered}")
    local first="${prompt_lines[1]-}"
    local second="${prompt_lines[2]-}"
    local -i layout=0
    [[ "$first" == *BASE_PATH* &&
        "$first" == *"$_DOTS_FAILURE_ANIMATION_FRAME"* &&
        "$first" != *'━━'* && "$first" != *'✦'* && "$first" != *'✧'* &&
        "$second" == "BASE_OUTPUT " ]] && layout=1
    print -r -- "RENDER_CHECK first=${(qqq)first} second=${(qqq)second}"
    print -r -- "PROMPT_STATE ACTIVE_${_DOTS_FAILURE_ANIMATION_ACTIVE} LAST_FRAMES_${_DOTS_FAILURE_ANIMATION_LAST_FRAMES} LAYOUT_${layout} CONTINUOUS_${DOTS_FAILURE_ANIMATION_CONTINUOUS:-0}"
}
typeset -ga precmd_functions
precmd_functions+=(_dots_test_prompt_report)
print -r -- MODULES_READY
ZSH_INIT

trap 'zpty -d "$PTY_NAME" 2>/dev/null || true; rm -f "$INIT_FILE"' EXIT

zpty -b "$PTY_NAME" env TERM=xterm-256color COLUMNS=120 LINES=30 \
    DOTS_FAILURE_MESSAGE_CHANCE=100 DOTS_FAILURE_ANIMATION_CHANCE=100 \
    DOTS_FAILURE_STYLE=normal DOTS_FAILURE_MESSAGE_ESCALATION=0 DOTS_FAILURE_ANIMATION=1 \
    "ZSH_DIR=$ZSH_DIR" NO_COLOR=1 zsh -f -i

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

# Wait for the clean shell, then load the same modules as the real .zshrc.
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
assert_contains "prompt adds only the current emoji, with no side bars or star glyphs" "LAYOUT_1" "$REPLY"

# Drain terminal output while the default one-shot stream finishes.
drain_for 220
zpty -w "$PTY_NAME" 'print -r -- "STARTUP_FINISHED ACTIVE_${_DOTS_FAILURE_ANIMATION_ACTIVE} LAST_FRAMES_${_DOTS_FAILURE_ANIMATION_LAST_FRAMES} LAST_STATE_${_DOTS_FAILURE_ANIMATION_LAST_STATE}"; print -r -- STATE_INSPECTION_DONE'$'\n'
read_until STATE_INSPECTION_DONE
assert_contains "startup animation completes its 24 emoji frames" "STARTUP_FINISHED ACTIVE_0 LAST_FRAMES_24 LAST_STATE_stream-complete" "$REPLY"
read_until "PROMPT_STATE ACTIVE_0"
assert_contains "final startup emoji remains in the prompt" "LAYOUT_1" "$REPLY"

# Trigger the public renderer; the queued animation starts in precmd.
zpty -w "$PTY_NAME" 'dots_failure_message generic animation-integration-test; print -r -- FAILURE_MESSAGE_RETURNED; print -r -- FAILURE_COMMAND_DONE'$'\n'
read_until FAILURE_COMMAND_DONE
assert_contains "public failure-message renderer returned" "FAILURE_MESSAGE_RETURNED" "$REPLY"
read_until "PROMPT_STATE ACTIVE_1"
assert_contains "failure notification starts another animation" "PROMPT_STATE ACTIVE_1" "$REPLY"

# Enter cancels the remaining frames but must not clear the latest one.
command sleep 0.08
zpty -w "$PTY_NAME" 'print -r -- "INPUT_ACCEPTED"; print -r -- INPUT_INSPECTION_DONE'$'\n'
read_until INPUT_INSPECTION_DONE
assert_contains "keyboard input remains responsive during animation" "INPUT_ACCEPTED" "$REPLY"
read_until "PROMPT_STATE ACTIVE_0"
assert_contains "latest emoji persists after Enter" "LAYOUT_1" "$REPLY"

# Continuous mode should loop while the prompt is idle.
zpty -w "$PTY_NAME" '_dots_test_enable_continuous'$'\n'
read_until CONTINUOUS_ENABLED
read_until "PROMPT_STATE ACTIVE_1"
assert_contains "continuous mode starts on the next prompt" "PROMPT_STATE ACTIVE_1" "$REPLY"

# A single Ctrl-X invokes a test ZLE widget that disables the env flag and
# accepts an empty line. This avoids typing over the repeatedly redrawn prompt.
drain_for 220
zpty -w "$PTY_NAME" $'\x18'
read_until "PROMPT_STATE ACTIVE_0"
assert_contains "continuous mode stops when disabled at the prompt" "CONTINUOUS_0" "$REPLY"
typeset continuous_report="$REPLY"
typeset continuous_frames="${continuous_report##*LAST_FRAMES_}"
continuous_frames="${continuous_frames%%[^0-9]*}"
[[ "$continuous_frames" == <-> ]] || fail "continuous animation frame count was not reported"
(( continuous_frames > 36 )) || fail "continuous animation must run beyond one 24-frame cycle"
print -- "ok - continuous animation loops beyond one frame sequence"

# Re-enable, verify another prompt restarts, then disable it again.
zpty -w "$PTY_NAME" '_dots_test_enable_continuous'$'\n'
read_until CONTINUOUS_ENABLED
read_until "PROMPT_STATE ACTIVE_1"
assert_contains "continuous animation restarts on a later prompt" "PROMPT_STATE ACTIVE_1" "$REPLY"
zpty -w "$PTY_NAME" $'\x18'
read_until "PROMPT_STATE ACTIVE_0"
assert_contains "continuous mode can be disabled repeatedly" "CONTINUOUS_0" "$REPLY"

print -- "All emoji-only and continuous animation integration tests passed."

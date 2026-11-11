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

_dots_test_snapshot() {
    print -r -- "STATE_SNAPSHOT ACTIVE_${_DOTS_FAILURE_ANIMATION_ACTIVE} LAST_FRAMES_${_DOTS_FAILURE_ANIMATION_LAST_FRAMES} LAST_STATE_${_DOTS_FAILURE_ANIMATION_LAST_STATE} RPROMPT_${RPROMPT}"
}
_dots_test_enable_continuous() {
    export DOTS_FAILURE_ANIMATION_CONTINUOUS=1
    print -r -- CONTINUOUS_ENABLED
}
_dots_test_disable_continuous() {
    export DOTS_FAILURE_ANIMATION_CONTINUOUS=0
    print -r -- "CONTINUOUS_DISABLED ACTIVE_${_DOTS_FAILURE_ANIMATION_ACTIVE} LAST_FRAMES_${_DOTS_FAILURE_ANIMATION_LAST_FRAMES} LAST_STATE_${_DOTS_FAILURE_ANIMATION_LAST_STATE}"
}
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

# Wait for the clean shell, then load the modules as the real .zshrc does.
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
read_until "BASE_OUTPUT"
assert_contains "first interactive prompt renders the path line" "BASE_PATH" "$REPLY"
assert_contains "emoji-only animation preserves the second prompt line" "BASE_OUTPUT" "$REPLY"
[[ "$REPLY" != *'━━'* && "$REPLY" != *'✦'* && "$REPLY" != *'✧'* ]] || fail "animation still contains side bars or star glyphs"
print -- "ok - prompt contains no decorative bars or star glyphs"

# The ordinary startup stream is finite and leaves its last emoji in place.
drain_for 220
zpty -w "$PTY_NAME" '_dots_test_snapshot'$'\n'
read_until STATE_SNAPSHOT
assert_contains "startup animation finishes all 24 emoji frames" "STATE_SNAPSHOT ACTIVE_0 LAST_FRAMES_24 LAST_STATE_stream-complete" "$REPLY"
assert_contains "right prompt remains unchanged" "RPROMPT_BASE_RPROMPT" "$REPLY"

# Continuous mode loops while idle; accepting a command stops it before the
# helper changes the environment flag. The following prompt must stay static.
zpty -w "$PTY_NAME" '_dots_test_enable_continuous'$'\n'
read_until CONTINUOUS_ENABLED
assert_contains "continuous mode can be enabled through the environment" "CONTINUOUS_ENABLED" "$REPLY"
read_until "BASE_OUTPUT"
drain_for 220
zpty -w "$PTY_NAME" '_dots_test_disable_continuous'$'\n'
read_until CONTINUOUS_DISABLED
assert_contains "continuous mode disables cleanly at the next command" "CONTINUOUS_DISABLED ACTIVE_0" "$REPLY"
typeset continuous_frames="${REPLY##*LAST_FRAMES_}"
continuous_frames="${continuous_frames%%[^0-9]*}"
[[ "$continuous_frames" == <-> ]] || fail "continuous animation frame count was not reported"
(( continuous_frames > 36 )) || fail "continuous animation did not loop beyond one 24-frame cycle"
print -- "ok - continuous animation loops beyond one frame sequence"

print -- "All emoji-only and continuous animation integration tests passed."

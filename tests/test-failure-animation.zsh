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
STARSHIP_TEST_PROMPT=$'BASE_PATH\nBASE_OUTPUT ❯ '
PROMPT='$(print -rn -- "$STARSHIP_TEST_PROMPT")'
RPROMPT='BASE_RPROMPT'
source "$ZSH_DIR/failure-messages.zsh"
source "$ZSH_DIR/failure-animation.zsh"

_DOTS_FAILURE_ANIMATION_INTERVAL=0.05

_dots_test_snapshot() {
    print -r -- "STATE_SNAPSHOT ACTIVE_${_DOTS_FAILURE_ANIMATION_ACTIVE} LAST_FRAMES_${_DOTS_FAILURE_ANIMATION_LAST_FRAMES} LAST_STATE_${_DOTS_FAILURE_ANIMATION_LAST_STATE} STYLE_${_DOTS_FAILURE_ANIMATION_STYLE} RPROMPT_${RPROMPT}"
}
_dots_test_render_prompt() {
    _DOTS_FAILURE_ANIMATION_FRAME='😭'
    local rendered="$(_dots_failure_animation_render_prompt)"
    print -r -- "PROMPT_RENDERED:${rendered}"
}
_dots_test_assert_pool() {
    local style="$1"
    _dots_failure_animation_pool_for_style "$style"
    print -r -- "POOL_${style}_${#_DOTS_FAILURE_ANIMATION_POOL}_${(j: :)_DOTS_FAILURE_ANIMATION_POOL}"
}
_dots_test_enable_continuous() {
    export DOTS_FAILURE_ANIMATION_CONTINUOUS=1
    print -- CONTINUOUS_ENABLED
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
read_until "❯"
assert_contains "first interactive prompt renders the path line" "BASE_PATH" "$REPLY"
assert_contains "first interactive prompt renders the input marker" "❯" "$REPLY"
[[ "$REPLY" != *'BASE_PATH 💀'* && "$REPLY" != *'BASE_PATH 😭'* ]] || fail "animation was inserted on the path line"
print -- "ok - initial animation leaves the path line untouched"

# Let the initial one-shot animation finish before submitting another command.
drain_for 220
zpty -w "$PTY_NAME" '_dots_test_snapshot'$'\n'
read_until STATE_SNAPSHOT
assert_contains "startup animation finishes all 24 frames" "STATE_SNAPSHOT ACTIVE_0 LAST_FRAMES_24 LAST_STATE_stream-complete" "$REPLY"
assert_contains "startup uses the shared style" "STYLE_normal" "$REPLY"
assert_contains "right prompt remains unchanged" "RPROMPT_BASE_RPROMPT" "$REPLY"

# Deterministically render a frame and verify it is directly before the input marker.
zpty -w "$PTY_NAME" '_dots_test_render_prompt'$'\n'
read_until "BASE_OUTPUT 😭 ❯"
assert_contains "emoji appears immediately before the input marker" "BASE_OUTPUT 😭 ❯" "$REPLY"
assert_absent "path line stays free of the emoji" "BASE_PATH 😭" "$REPLY"

# Normal, sarcastic and dramatic styles must share one pool; special styles
# must each have their own pool.
zpty -w "$PTY_NAME" '_dots_test_assert_pool normal'$'\n'
read_until "POOL_normal_12_👀 😳 ✨ 💀 😂 🤡 🪿 🔥 💔 🖤 🤎 💜"
assert_contains "ordinary styles use the common 12-emoji pool" "POOL_normal_12_" "$REPLY"
zpty -w "$PTY_NAME" '_dots_test_assert_pool sarcastic'$'\n'
read_until "POOL_sarcastic_12_👀 😳 ✨ 💀 😂 🤡 🪿 🔥 💔 🖤 🤎 💜"
assert_contains "sarcastic uses the common pool" "POOL_sarcastic_12_" "$REPLY"
assert_contains "sarcastic pool includes the common reactions" "💀 😂 🤡 🪿" "$REPLY"
zpty -w "$PTY_NAME" '_dots_test_assert_pool dramatic'$'\n'
read_until "POOL_dramatic_12_👀 😳 ✨ 💀 😂 🤡 🪿 🔥 💔 🖤 🤎 💜"
assert_contains "dramatic uses the common pool" "POOL_dramatic_12_" "$REPLY"
zpty -w "$PTY_NAME" '_dots_test_assert_pool anime'$'\n'
read_until "POOL_anime_7_😭 🥰 🥺 💖 💗 💓 💕"
assert_contains "anime has its dedicated seven-emoji pool" "POOL_anime_7_😭 🥰 🥺 💖 💗 💓 💕" "$REPLY"
zpty -w "$PTY_NAME" '_dots_test_assert_pool ecchi'$'\n'
read_until "POOL_ecchi_5_😏 🫠 ❤️ 🩷 💘"
assert_contains "ecchi has its dedicated five-emoji pool" "POOL_ecchi_5_😏 🫠 ❤️ 🩷 💘" "$REPLY"
zpty -w "$PTY_NAME" '_dots_test_assert_pool rainbow'$'\n'
read_until "POOL_rainbow_5_🧡 💛 💚 💙 🤍"
assert_contains "rainbow has its dedicated five-emoji pool" "POOL_rainbow_5_🧡 💛 💚 💙 🤍" "$REPLY"

# Continuous mode loops while idle; accepting a command stops it before the
# helper changes the environment flag. The following prompt must stay static.
zpty -w "$PTY_NAME" '_dots_test_enable_continuous'$'\n'
read_until CONTINUOUS_ENABLED
assert_contains "continuous mode can be enabled through the environment" "CONTINUOUS_ENABLED" "$REPLY"
read_until "❯"
drain_for 220
zpty -w "$PTY_NAME" '_dots_test_disable_continuous'$'\n'
read_until CONTINUOUS_DISABLED
assert_contains "continuous mode disables cleanly at the next command" "CONTINUOUS_DISABLED ACTIVE_0" "$REPLY"
typeset continuous_frames="${REPLY##*LAST_FRAMES_}"
continuous_frames="${continuous_frames%%[^0-9]*}"
[[ "$continuous_frames" == <-> ]] || fail "continuous animation frame count was not reported"
(( continuous_frames > 36 )) || fail "continuous animation did not loop beyond one 24-frame cycle"
print -- "ok - continuous animation loops beyond one frame sequence"

print -- "All style-aware prompt animation integration tests passed."

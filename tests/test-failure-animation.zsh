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
_dots_test_render_gradients() {
    local rendered=''

    _dots_failure_animation_gradient_line 'LEGENDARY BANNER' legendary 0
    [[ "$_DOTS_FAILURE_ANIMATION_GRADIENT_LINE" == *'L'* &&
       "$_DOTS_FAILURE_ANIMATION_GRADIENT_LINE" == *'Y'* &&
       "$_DOTS_FAILURE_ANIMATION_GRADIENT_LINE" == *'B'* &&
       "$_DOTS_FAILURE_ANIMATION_GRADIENT_LINE" == *'R'* ]] || return 1
    [[ "$_DOTS_FAILURE_ANIMATION_GRADIENT_LINE" == *$'\e[38;2;74;50;12m'* ]] || return 1

    _dots_failure_animation_gradient_line '🌠 MYTHIC STARFALL 🌠' mythic 0
    [[ "$_DOTS_FAILURE_ANIMATION_GRADIENT_LINE" == *'M'* &&
       "$_DOTS_FAILURE_ANIMATION_GRADIENT_LINE" == *'C'* &&
       "$_DOTS_FAILURE_ANIMATION_GRADIENT_LINE" == *'S'* &&
       "$_DOTS_FAILURE_ANIMATION_GRADIENT_LINE" == *'R'* ]] || return 1
    [[ "$_DOTS_FAILURE_ANIMATION_GRADIENT_LINE" == *$'\e[38;2;15;17;21m'* ]] || return 1
    [[ "$_DOTS_FAILURE_ANIMATION_GRADIENT_LINE" != *$'\e[38;2;255;0;0m'* ]] || return 1
    local first_frame=''
    _dots_failure_animation_gradient_line 'LEGENDARY ANIMATED FAILURE BANNER' legendary 0
    first_frame="$_DOTS_FAILURE_ANIMATION_GRADIENT_LINE"
    local first_color_zero="${first_frame#*38;2;}"
    first_color_zero="${first_color_zero%%m*}"
    _dots_failure_animation_gradient_line 'LEGENDARY ANIMATED FAILURE BANNER' legendary 20
    [[ "$_DOTS_FAILURE_ANIMATION_GRADIENT_LINE" != "$first_frame" ]] || return 1
    local first_color_twenty="${_DOTS_FAILURE_ANIMATION_GRADIENT_LINE#*38;2;}"
    first_color_twenty="${first_color_twenty%%m*}"
    # At phase 20 the leftmost character has advanced into the later part
    # of the palette; adding the phase would move the highlight the other way.
    [[ "$first_color_zero" == '74;50;12' &&
       "$first_color_twenty" == '190;145;55' ]] || return 1

    _DOTS_FAILURE_ANIMATION_MODE='mythic'
    _DOTS_FAILURE_ANIMATION_BANNER='🌠 MYTHIC STARFALL 🌠'
    rendered="$(_dots_failure_animation_render_prompt)"
    [[ "$rendered" == *'M'* && "$rendered" == *'S'* ]] || return 1

    _DOTS_FAILURE_ANIMATION_MODE='emoji'
    _DOTS_FAILURE_ANIMATION_BANNER=''
    print -- GRADIENTS_OK
}
_dots_test_queue_special_animation() {
    local style="$1"
    local probe=''
    local saved_no_color="${NO_COLOR-}"
    probe="$(_dots_failure_animation_stream "$style" "$style" 1 | command head -n 3)"
    [[ "$probe" == $'0\\n4\\n8' ]] || {
        print -r -- "STREAM_PROBE_FAILED_${style}_${(qqq)probe}"
        return 1
    }
    unset NO_COLOR
    _dots_failure_animation_start "$style" "$style ANIMATED FAILURE BANNER" "↳ live gradient test"
    if [[ -n "$saved_no_color" ]]; then export NO_COLOR="$saved_no_color"; fi
    print -r -- "STREAM_PROBE_OK_${style}"
    print -r -- "SPECIAL_QUEUED_${style}"
}
_dots_test_snapshot_special_animation() {
    local banner_set=0
    [[ -n "$_DOTS_FAILURE_ANIMATION_BANNER" ]] && banner_set=1
    print -r -- "SPECIAL_STATE_ACTIVE_${_DOTS_FAILURE_ANIMATION_ACTIVE}_LAST_FRAMES_${_DOTS_FAILURE_ANIMATION_LAST_FRAMES}_LAST_STATE_${_DOTS_FAILURE_ANIMATION_LAST_STATE}_MODE_${_DOTS_FAILURE_ANIMATION_MODE}_BANNER_${banner_set}"
}
clear() {
    print -r -- CLEAR_EXECUTED
}
_dots_test_enable_infinite() {
    export DOTS_FAILURE_ANIMATION_INFINITE=1
    print -- INFINITE_ENABLED
}
_dots_test_disable_infinite() {
    export DOTS_FAILURE_ANIMATION_INFINITE=0
    print -r -- "INFINITE_DISABLED ACTIVE_${_DOTS_FAILURE_ANIMATION_ACTIVE} LAST_FRAMES_${_DOTS_FAILURE_ANIMATION_LAST_FRAMES} LAST_STATE_${_DOTS_FAILURE_ANIMATION_LAST_STATE}"
}
_dots_test_legacy_infinite_aliases() {
    unset DOTS_FAILURE_ANIMATION_INFINITE
    export DOTS_FAILURE_EMOJI_ANIMATION_INFINITE=1
    _dots_failure_animation_infinite_enabled || return 1
    unset DOTS_FAILURE_EMOJI_ANIMATION_INFINITE
    export DOTS_FAILURE_ANIMATION_CONTINUOUS=1
    _dots_failure_animation_infinite_enabled || return 1
    export DOTS_FAILURE_ANIMATION_CONTINUOUS=0
    print -- INFINITE_ALIASES_OK
}
ZSH_INIT

trap 'zpty -d "$PTY_NAME" 2>/dev/null || true; rm -f "$INIT_FILE"' EXIT

zpty -b "$PTY_NAME" env TERM=xterm-256color COLUMNS=120 LINES=30 \
    DOTS_FAILURE_MESSAGE_CHANCE=100 DOTS_FAILURE_ANIMATION_CHANCE=100 \
    DOTS_FAILURE_STYLE=normal DOTS_FAILURE_MESSAGE_ESCALATION=0 DOTS_FAILURE_ANIMATION=1 \
    DOTS_FAILURE_ANIMATION_INTERVAL=0.02 \
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

# Let the shorter initial one-shot animation finish before submitting another command.
drain_for 100
zpty -w "$PTY_NAME" '_dots_test_snapshot'$'\n'
read_until STATE_SNAPSHOT
assert_contains "startup animation finishes all 12 frames" "STATE_SNAPSHOT ACTIVE_0 LAST_FRAMES_12 LAST_STATE_stream-complete" "$REPLY"
assert_contains "startup uses the shared style" "STYLE_normal" "$REPLY"
assert_contains "right prompt remains unchanged" "RPROMPT_BASE_RPROMPT" "$REPLY"

# Deterministically render a frame and verify it is directly before the input marker.
zpty -w "$PTY_NAME" '_dots_test_render_prompt'$'\n'
read_until "BASE_OUTPUT 😭 ❯"
assert_contains "emoji appears immediately before the input marker" "BASE_OUTPUT 😭 ❯" "$REPLY"
assert_absent "path line stays free of the emoji" "BASE_PATH 😭" "$REPLY"

# Normal, sarcastic and dramatic styles share one pool, including the melting-face reaction.
zpty -w "$PTY_NAME" '_dots_test_assert_pool normal'$'\n'
read_until "POOL_normal_13_👀 😳 ✨ 💀 😂 🤡 🪿 🔥 💔 🖤 🤎 💜 🫠"
assert_contains "ordinary styles use the common 13-emoji pool" "POOL_normal_13_" "$REPLY"
zpty -w "$PTY_NAME" '_dots_test_assert_pool sarcastic'$'\n'
read_until "POOL_sarcastic_13_👀 😳 ✨ 💀 😂 🤡 🪿 🔥 💔 🖤 🤎 💜 🫠"
assert_contains "sarcastic uses the common pool" "POOL_sarcastic_13_" "$REPLY"
assert_contains "sarcastic pool includes melting face" "🫠" "$REPLY"
zpty -w "$PTY_NAME" '_dots_test_assert_pool dramatic'$'\n'
read_until "POOL_dramatic_13_👀 😳 ✨ 💀 😂 🤡 🪿 🔥 💔 🖤 🤎 💜 🫠"
assert_contains "dramatic uses the common pool" "POOL_dramatic_13_" "$REPLY"
zpty -w "$PTY_NAME" '_dots_test_assert_pool anime'$'\n'
read_until "POOL_anime_7_😭 🥰 🥺 💖 💗 💓 💕"
assert_contains "anime has its dedicated seven-emoji pool" "POOL_anime_7_😭 🥰 🥺 💖 💗 💓 💕" "$REPLY"
zpty -w "$PTY_NAME" '_dots_test_assert_pool ecchi'$'\n'
read_until "POOL_ecchi_4_😏 ❤️ 🩷 💘"
assert_contains "ecchi has its dedicated four-emoji pool" "POOL_ecchi_4_😏 ❤️ 🩷 💘" "$REPLY"
assert_absent "Ecchi pool no longer contains melting face" "🫠" "$REPLY"
zpty -w "$PTY_NAME" '_dots_test_assert_pool rainbow'$'\n'
read_until "POOL_rainbow_5_🧡 💛 💚 💙 🤍"
assert_contains "rainbow has its dedicated five-emoji pool" "POOL_rainbow_5_🧡 💛 💚 💙 🤍" "$REPLY"

# Both historic environment-variable names remain compatible aliases.
zpty -w "$PTY_NAME" '_dots_test_legacy_infinite_aliases'$'\n'
read_until INFINITE_ALIASES_OK
assert_contains "Emoji-specific and Continuous variables remain Infinite aliases" "INFINITE_ALIASES_OK" "$REPLY"

# Both rare gradients render in their own palettes: metallic gold and monochrome Mythic.
zpty -w "$PTY_NAME" '_dots_test_render_gradients'$'\n'
read_until GRADIENTS_OK
assert_contains "Legendary and Mythic gradient renderers use their dedicated palettes" "GRADIENTS_OK" "$REPLY"

# Exercise both rare banners through the real ZLE async stream while the prompt is idle.
for style in legendary mythic; do
    zpty -w "$PTY_NAME" "_dots_test_queue_special_animation '$style'"$'\n'
    read_until "SPECIAL_QUEUED_${style}"
    # The queue marker is printed inside the command, before precmd redraws
    # the prompt and starts the async stream. Wait for that prompt explicitly.
    read_until "BASE_OUTPUT"
    drain_for 80
    zpty -w "$PTY_NAME" '_dots_test_snapshot_special_animation'$'\n'
    read_until SPECIAL_STATE_ACTIVE_
    assert_contains "${style} animation starts its ZLE stream" "SPECIAL_STATE_ACTIVE_0_LAST_FRAMES_" "$REPLY"
    assert_contains "${style} banner is retained in prompt state" "MODE_${style}_BANNER_1" "$REPLY"
    typeset special_state="$REPLY"
    typeset special_frames="${special_state##*LAST_FRAMES_}"
    special_frames="${special_frames%%[^0-9]*}"
    [[ "$special_frames" == <-> ]] || fail "${style} animation frame count was not reported: ${special_state}"
    (( special_frames >= 5 )) || fail "${style} gradient produced only ${special_frames} frames while idle: ${special_state}"

    # Submitting another command must preserve the banner and restart its
    # animation at the next prompt rather than discarding it on line-finish.
    zpty -w "$PTY_NAME" "print -r -- FOLLOWUP_${style}"

# Infinite emoji mode loops while idle; accepting a command stops it.
zpty -w "$PTY_NAME" '_dots_test_enable_infinite'$'\n'
read_until INFINITE_ENABLED
assert_contains "infinite emoji mode can be enabled with the environment variable" "INFINITE_ENABLED" "$REPLY"
read_until "❯"
drain_for 220
zpty -w "$PTY_NAME" '_dots_test_disable_infinite'$'\n'
read_until INFINITE_DISABLED
assert_contains "infinite mode stops cleanly when a command is submitted" "INFINITE_DISABLED ACTIVE_0" "$REPLY"
typeset infinite_frames="${REPLY##*LAST_FRAMES_}"
infinite_frames="${infinite_frames%%[^0-9]*}"
[[ "$infinite_frames" == <-> ]] || fail "infinite animation frame count was not reported"
(( infinite_frames > 36 )) || fail "infinite emoji animation did not loop beyond one 12-frame cycle"
print -- "ok - infinite emoji animation loops beyond one frame sequence"

print -- "All style-aware and rare-event prompt animation integration tests passed."
\\n'
    read_until "FOLLOWUP_${style}"
    drain_for 60
    zpty -w "$PTY_NAME" '_dots_test_snapshot_special_animation'

# Infinite emoji mode loops while idle; accepting a command stops it.
zpty -w "$PTY_NAME" '_dots_test_enable_infinite'$'\n'
read_until INFINITE_ENABLED
assert_contains "infinite emoji mode can be enabled with the environment variable" "INFINITE_ENABLED" "$REPLY"
read_until "❯"
drain_for 220
zpty -w "$PTY_NAME" '_dots_test_disable_infinite'$'\n'
read_until INFINITE_DISABLED
assert_contains "infinite mode stops cleanly when a command is submitted" "INFINITE_DISABLED ACTIVE_0" "$REPLY"
typeset infinite_frames="${REPLY##*LAST_FRAMES_}"
infinite_frames="${infinite_frames%%[^0-9]*}"
[[ "$infinite_frames" == <-> ]] || fail "infinite animation frame count was not reported"
(( infinite_frames > 36 )) || fail "infinite emoji animation did not loop beyond one 12-frame cycle"
print -- "ok - infinite emoji animation loops beyond one frame sequence"

print -- "All style-aware and rare-event prompt animation integration tests passed."
\\n'
    read_until SPECIAL_STATE_ACTIVE_
    assert_contains "${style} banner survives a submitted command" "MODE_${style}_BANNER_1" "$REPLY"
    special_state="$REPLY"
    special_frames="${special_state##*LAST_FRAMES_}"
    special_frames="${special_frames%%[^0-9]*}"
    [[ "$special_frames" == <-> ]] || fail "${style} post-command frame count was not reported: ${special_state}"
    (( special_frames >= 3 )) || fail "${style} animation did not resume after a submitted command: ${special_state}"
done
print -- "ok - Legendary and Mythic gradients resume at each prompt until the screen is cleared"

# Ctrl+L invokes the wrapped clear-screen widget and dismisses a persistent banner.
zpty -w "$PTY_NAME" 

# Infinite emoji mode loops while idle; accepting a command stops it.
zpty -w "$PTY_NAME" '_dots_test_enable_infinite'$'\n'
read_until INFINITE_ENABLED
assert_contains "infinite emoji mode can be enabled with the environment variable" "INFINITE_ENABLED" "$REPLY"
read_until "❯"
drain_for 220
zpty -w "$PTY_NAME" '_dots_test_disable_infinite'$'\n'
read_until INFINITE_DISABLED
assert_contains "infinite mode stops cleanly when a command is submitted" "INFINITE_DISABLED ACTIVE_0" "$REPLY"
typeset infinite_frames="${REPLY##*LAST_FRAMES_}"
infinite_frames="${infinite_frames%%[^0-9]*}"
[[ "$infinite_frames" == <-> ]] || fail "infinite animation frame count was not reported"
(( infinite_frames > 36 )) || fail "infinite emoji animation did not loop beyond one 12-frame cycle"
print -- "ok - infinite emoji animation loops beyond one frame sequence"

print -- "All style-aware and rare-event prompt animation integration tests passed."
\\x0c'
drain_for 30
zpty -w "$PTY_NAME" '_dots_test_snapshot_special_animation'

# Infinite emoji mode loops while idle; accepting a command stops it.
zpty -w "$PTY_NAME" '_dots_test_enable_infinite'$'\n'
read_until INFINITE_ENABLED
assert_contains "infinite emoji mode can be enabled with the environment variable" "INFINITE_ENABLED" "$REPLY"
read_until "❯"
drain_for 220
zpty -w "$PTY_NAME" '_dots_test_disable_infinite'$'\n'
read_until INFINITE_DISABLED
assert_contains "infinite mode stops cleanly when a command is submitted" "INFINITE_DISABLED ACTIVE_0" "$REPLY"
typeset infinite_frames="${REPLY##*LAST_FRAMES_}"
infinite_frames="${infinite_frames%%[^0-9]*}"
[[ "$infinite_frames" == <-> ]] || fail "infinite animation frame count was not reported"
(( infinite_frames > 36 )) || fail "infinite emoji animation did not loop beyond one 12-frame cycle"
print -- "ok - infinite emoji animation loops beyond one frame sequence"

print -- "All style-aware and rare-event prompt animation integration tests passed."
\\n'
read_until SPECIAL_STATE_ACTIVE_
assert_contains "Ctrl+L clears the persistent banner" "MODE_emoji_BANNER_0" "$REPLY"

# The clear command is also detected before it runs, so the next prompt stays clean.
zpty -w "$PTY_NAME" "_dots_test_queue_special_animation legendary"

# Infinite emoji mode loops while idle; accepting a command stops it.
zpty -w "$PTY_NAME" '_dots_test_enable_infinite'$'\n'
read_until INFINITE_ENABLED
assert_contains "infinite emoji mode can be enabled with the environment variable" "INFINITE_ENABLED" "$REPLY"
read_until "❯"
drain_for 220
zpty -w "$PTY_NAME" '_dots_test_disable_infinite'$'\n'
read_until INFINITE_DISABLED
assert_contains "infinite mode stops cleanly when a command is submitted" "INFINITE_DISABLED ACTIVE_0" "$REPLY"
typeset infinite_frames="${REPLY##*LAST_FRAMES_}"
infinite_frames="${infinite_frames%%[^0-9]*}"
[[ "$infinite_frames" == <-> ]] || fail "infinite animation frame count was not reported"
(( infinite_frames > 36 )) || fail "infinite emoji animation did not loop beyond one 12-frame cycle"
print -- "ok - infinite emoji animation loops beyond one frame sequence"

print -- "All style-aware and rare-event prompt animation integration tests passed."
\\n'
read_until SPECIAL_QUEUED_legendary
read_until BASE_OUTPUT
drain_for 60
zpty -w "$PTY_NAME" 'clear'

# Infinite emoji mode loops while idle; accepting a command stops it.
zpty -w "$PTY_NAME" '_dots_test_enable_infinite'$'\n'
read_until INFINITE_ENABLED
assert_contains "infinite emoji mode can be enabled with the environment variable" "INFINITE_ENABLED" "$REPLY"
read_until "❯"
drain_for 220
zpty -w "$PTY_NAME" '_dots_test_disable_infinite'$'\n'
read_until INFINITE_DISABLED
assert_contains "infinite mode stops cleanly when a command is submitted" "INFINITE_DISABLED ACTIVE_0" "$REPLY"
typeset infinite_frames="${REPLY##*LAST_FRAMES_}"
infinite_frames="${infinite_frames%%[^0-9]*}"
[[ "$infinite_frames" == <-> ]] || fail "infinite animation frame count was not reported"
(( infinite_frames > 36 )) || fail "infinite emoji animation did not loop beyond one 12-frame cycle"
print -- "ok - infinite emoji animation loops beyond one frame sequence"

print -- "All style-aware and rare-event prompt animation integration tests passed."
\\n'
read_until CLEAR_EXECUTED
zpty -w "$PTY_NAME" '_dots_test_snapshot_special_animation'

# Infinite emoji mode loops while idle; accepting a command stops it.
zpty -w "$PTY_NAME" '_dots_test_enable_infinite'$'\n'
read_until INFINITE_ENABLED
assert_contains "infinite emoji mode can be enabled with the environment variable" "INFINITE_ENABLED" "$REPLY"
read_until "❯"
drain_for 220
zpty -w "$PTY_NAME" '_dots_test_disable_infinite'$'\n'
read_until INFINITE_DISABLED
assert_contains "infinite mode stops cleanly when a command is submitted" "INFINITE_DISABLED ACTIVE_0" "$REPLY"
typeset infinite_frames="${REPLY##*LAST_FRAMES_}"
infinite_frames="${infinite_frames%%[^0-9]*}"
[[ "$infinite_frames" == <-> ]] || fail "infinite animation frame count was not reported"
(( infinite_frames > 36 )) || fail "infinite emoji animation did not loop beyond one 12-frame cycle"
print -- "ok - infinite emoji animation loops beyond one frame sequence"

print -- "All style-aware and rare-event prompt animation integration tests passed."
\\n'
read_until SPECIAL_STATE_ACTIVE_
assert_contains "clear command dismisses the persistent banner" "MODE_emoji_BANNER_0" "$REPLY"

# Infinite emoji mode loops while idle; accepting a command stops it.
zpty -w "$PTY_NAME" '_dots_test_enable_infinite'$'\n'
read_until INFINITE_ENABLED
assert_contains "infinite emoji mode can be enabled with the environment variable" "INFINITE_ENABLED" "$REPLY"
read_until "❯"
drain_for 220
zpty -w "$PTY_NAME" '_dots_test_disable_infinite'$'\n'
read_until INFINITE_DISABLED
assert_contains "infinite mode stops cleanly when a command is submitted" "INFINITE_DISABLED ACTIVE_0" "$REPLY"
typeset infinite_frames="${REPLY##*LAST_FRAMES_}"
infinite_frames="${infinite_frames%%[^0-9]*}"
[[ "$infinite_frames" == <-> ]] || fail "infinite animation frame count was not reported"
(( infinite_frames > 36 )) || fail "infinite emoji animation did not loop beyond one 12-frame cycle"
print -- "ok - infinite emoji animation loops beyond one frame sequence"

print -- "All style-aware and rare-event prompt animation integration tests passed."

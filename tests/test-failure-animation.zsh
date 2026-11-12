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

# Deterministic visible-screen coordinates for PTY integration tests.
_dots_failure_animation_query_cursor() {
    local -a banner_lines
    banner_lines=( "${(@f)_DOTS_FAILURE_ANIMATION_BANNER}" )
    _DOTS_FAILURE_ANIMATION_ANCHOR_ROW=10
    _DOTS_FAILURE_ANIMATION_ANCHOR_COL=1
    return 0
}

_DOTS_FAILURE_ANIMATION_INTERVAL=0.05

_dots_test_snapshot() {
    print -r -- "STATE_SNAPSHOT ACTIVE_${_DOTS_FAILURE_ANIMATION_ACTIVE} LAST_FRAMES_${_DOTS_FAILURE_ANIMATION_LAST_FRAMES} LAST_STATE_${_DOTS_FAILURE_ANIMATION_LAST_STATE} STYLE_${_DOTS_FAILURE_ANIMATION_STYLE} RPROMPT_${RPROMPT}"
}
_dots_test_render_prompt() {
    _DOTS_FAILURE_ANIMATION_FRAME='😭'
    local rendered="$(_dots_failure_animation_render_prompt)"
    print -r -- "PROMPT_RENDERED:${rendered}"
}
_dots_test_render_duplicate_prompt() {
    local saved_prompt="$_DOTS_FAILURE_ANIMATION_ORIGINAL_PROMPT"
    local saved_mode="$_DOTS_FAILURE_ANIMATION_PROMPT_MODE"
    _DOTS_FAILURE_ANIMATION_ORIGINAL_PROMPT='BASE_OUTPUT CODE=1 ❯ ❯ '
    _DOTS_FAILURE_ANIMATION_PROMPT_MODE='static'
    _DOTS_FAILURE_ANIMATION_FRAME='😭'
    local rendered="$(_dots_failure_animation_render_prompt)"
    _DOTS_FAILURE_ANIMATION_ORIGINAL_PROMPT="$saved_prompt"
    _DOTS_FAILURE_ANIMATION_PROMPT_MODE="$saved_mode"
    print -r -- "PROMPT_DUPLICATE_RENDERED:${rendered}"
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
    [[ "$rendered" != *'MYTHIC STARFALL'* ]] || return 1

    local palette_style expected_color
    for palette_style in normal anime ecchi rainbow; do
        _dots_failure_animation_gradient_line 'PALETTE CHECK' "$palette_style" 0
        case "$palette_style" in
            normal) expected_color='36;123;160' ;;
            anime) expected_color='255;190;220' ;;
            ecchi) expected_color='120;24;70' ;;
            rainbow) expected_color='255;82;82' ;;
        esac
        [[ "$_DOTS_FAILURE_ANIMATION_GRADIENT_LINE_RAW" == *$'\e[38;2;'$expected_color'm'* ]] || return 1
    done

    _DOTS_FAILURE_ANIMATION_MODE='emoji'
    _DOTS_FAILURE_ANIMATION_BANNER=''
    print -- GRADIENTS_OK
}
typeset -g _DOTS_TEST_SPECIAL_STYLE=''
typeset -g _DOTS_TEST_SPECIAL_BANNER=''
typeset -g _DOTS_TEST_SPECIAL_DETAIL=''
_dots_test_start_special_animation_precmd() {
    emulate -L zsh
    add-zsh-hook -d precmd _dots_test_start_special_animation_precmd

    local saved_no_color="\${NO_COLOR-}"
    unset NO_COLOR
    local -i start_status=0
    _dots_failure_animation_start \
        "$_DOTS_TEST_SPECIAL_STYLE" \
        "$_DOTS_TEST_SPECIAL_BANNER" \
        "$_DOTS_TEST_SPECIAL_DETAIL" || start_status=$?
    if [[ -n "$saved_no_color" ]]; then export NO_COLOR="$saved_no_color"; fi
    return "$start_status"
}
_dots_test_queue_special_animation() {
    local style="\${1}"
    _DOTS_TEST_SPECIAL_STYLE="$style"
    _DOTS_TEST_SPECIAL_BANNER="$style ANIMATED FAILURE BANNER"
    _DOTS_TEST_SPECIAL_DETAIL='live gradient test'
    add-zsh-hook precmd _dots_test_start_special_animation_precmd
    print -r -- "SPECIAL_QUEUED_$style"
}
_dots_test_snapshot_special_animation() {
    local banner_frames="$_DOTS_FAILURE_ANIMATION_LAST_BANNER_FRAMES"
    local kitty_calls="$(command wc -l < "$DOTS_TEST_KITTY_LOG" 2>/dev/null)"
    kitty_calls="\${kitty_calls//[[:space:]]/}"
    local rendered_frames="$(command grep -o 'MAGICK_INPUT_FRAMES_25' "$DOTS_TEST_ANIMATION_LOG" | command wc -l)"
    rendered_frames="\${rendered_frames//[[:space:]]/}"
    local animated_gifs="$(command grep -o 'ANIMATED_GIF_FRAMES_2_LOOP_1' "$DOTS_TEST_GIF_LOG" | command wc -l)"
    animated_gifs="\${animated_gifs//[[:space:]]/}"
    print -r -- "SPECIAL_STATE_GRADIENT_ACTIVE_\${_DOTS_FAILURE_GRADIENT_ACTIVE}_MODE_\${_DOTS_FAILURE_ANIMATION_MODE}_FRAMES_\${banner_frames}_PHASE_\${_DOTS_FAILURE_GRADIENT_PHASE}_PENDING_\${_DOTS_FAILURE_ANIMATION_PENDING}_KITTY_CALLS_\${kitty_calls}_RENDERED_25_\${rendered_frames}_ANIMATED_GIFS_\${animated_gifs}"
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

FAKE_BIN="$(mktemp -d)"
KITTY_LOG="$FAKE_BIN/kitty.log"
ANIMATION_LOG="$FAKE_BIN/animation.log"
GIF_LOG="$FAKE_BIN/gif.log"
: > "$KITTY_LOG"
: > "$ANIMATION_LOG"
: > "$GIF_LOG"
cat > "$FAKE_BIN/kitty" <<'FAKE_KITTY'
#!/usr/bin/env bash
if [[ "${1:-}" == +kitten && "${2:-}" == icat && "${3:-}" == --print-window-size ]]; then
    printf '1320x840\n'
    exit 0
fi
if [[ "${1:-}" == +kitten && "${2:-}" == icat ]]; then
    image_file="${@: -1}"
    if [[ ! -s "$image_file" ]]; then
        printf 'GIF_REJECTED_EMPTY|' >> "${DOTS_TEST_GIF_LOG:?}"
        exit 1
    fi
    if [[ "$(head -c 6 "$image_file")" != GIF89a ]]; then
        printf 'GIF_REJECTED_HEADER|' >> "${DOTS_TEST_GIF_LOG:?}"
        exit 1
    fi
    frame_count="$(LC_ALL=C tr -cd ',' < "$image_file" | wc -c)"
    frame_count="${frame_count//[[:space:]]/}"
    if (( frame_count < 2 )); then
        printf 'GIF_REJECTED_FRAMES_%s|' "$frame_count" >> "${DOTS_TEST_GIF_LOG:?}"
        exit 1
    fi
    if ! grep -aq 'NETSCAPE2.0' "$image_file"; then
        printf 'GIF_REJECTED_LOOP_EXTENSION|' >> "${DOTS_TEST_GIF_LOG:?}"
        exit 1
    fi
    printf 'ANIMATED_GIF_FRAMES_%s_LOOP_1|' "$frame_count" >> "${DOTS_TEST_GIF_LOG:?}"
fi
printf '%s ' "$@" >> "${DOTS_TEST_KITTY_LOG:?}"
printf '\n' >> "${DOTS_TEST_KITTY_LOG:?}"
FAKE_KITTY
cat > "$FAKE_BIN/magick" <<'FAKE_MAGICK'
#!/usr/bin/env bash
set -euo pipefail
frames=()
output=''
for arg in "$@"; do
    case "$arg" in
        *.svg) frames+=("$arg") ;;
        GIF:*) output="${arg#GIF:}" ;;
    esac
done
[[ "${#frames[@]}" -eq 25 && -n "$output" ]] || exit 1
if cmp -s "${frames[0]}" "${frames[24]}"; then
    exit 1
fi
printf 'MAGICK_INPUT_FRAMES_%s|' "${#frames[@]}" >> "${DOTS_TEST_ANIMATION_LOG:?}"
printf 'GIF89a\x01\x00\x01\x00\x80\x00\x00\x00\x00\x00\xff\xff\xff' > "$output"
printf '\x21\xff\x0bNETSCAPE2.0\x03\x01\x00\x00\x00' >> "$output"
for _ in 1 2; do
    printf '\x21\xf9\x04\x00\x08\x00\x00\x00\x2c\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02\x44\x01\x00' >> "$output"
done
printf '\x3b' >> "$output"
FAKE_MAGICK
cat > "$FAKE_BIN/fc-match" <<'FAKE_FONT'
#!/usr/bin/env sh
printf 'JetBrainsMono Nerd Font\n'
FAKE_FONT
chmod +x "$FAKE_BIN/kitty" "$FAKE_BIN/magick" "$FAKE_BIN/fc-match"

trap 'zpty -d "$PTY_NAME" 2>/dev/null || true; rm -f "$INIT_FILE"; rm -rf "$FAKE_BIN"' EXIT

zpty -b "$PTY_NAME" env TERM=xterm-256color COLUMNS=120 LINES=30 \
    PATH="$FAKE_BIN:$PATH" DOTS_TEST_KITTY_LOG="$KITTY_LOG" DOTS_TEST_ANIMATION_LOG="$ANIMATION_LOG" DOTS_TEST_GIF_LOG="$GIF_LOG" \
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

# A prompt that already contains duplicate markers (including one after the
# status code) must still render a single final marker after the emoji.
zpty -w "$PTY_NAME" '_dots_test_render_duplicate_prompt'$'\n'
read_until "PROMPT_DUPLICATE_RENDERED:"
assert_contains "exit code stays before the animated emoji" "BASE_OUTPUT CODE=1 😭 ❯" "$REPLY"
assert_absent "prompt contains only one final marker" "❯ ❯" "$REPLY"

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
drain_for 5

# The banner is part of the ZLE-managed prompt. Typing while its frame pipe is
# active must preserve the editable command buffer and must not block input.
zpty -w "$PTY_NAME" "_dots_test_queue_special_animation normal"$'\n'
read_until "SPECIAL_QUEUED_normal"
assert_contains "special message is queued before prompt rendering" "SPECIAL_QUEUED_normal" "$REPLY"
read_until "normal ANIMATED FAILURE BANNER"
assert_contains "gradient is rendered in the live prompt" "normal ANIMATED FAILURE BANNER" "$REPLY"
assert_contains "gradient is rendered with 24-bit colour" $'\e[38;2;' "$REPLY"
read_until "BASE_OUTPUT"
assert_contains "gradient prompt keeps the path and input prompt below it" "BASE_PATH" "$REPLY"

zpty -w "$PTY_NAME" 'print -r -- INPUT_DURING_GRADIENT'
read_until "INPUT_DURING_GRADIENT"
assert_contains "typed input appears while the gradient is still running" "INPUT_DURING_GRADIENT" "$REPLY"
drain_for 60
zpty -w "$PTY_NAME" $'\n'
read_until "INPUT_DURING_GRADIENT"
assert_contains "ZLE executes the exact input typed during the animation" "INPUT_DURING_GRADIENT" "$REPLY"
zpty -w "$PTY_NAME" '_dots_test_snapshot_special_animation'$'\n'
read_until SPECIAL_STATE_GRADIENT_ACTIVE_
assert_contains "input test completes all 25 gradient frames" "FRAMES_25" "$REPLY"
assert_contains "input test leaves no gradient worker" "GRADIENT_ACTIVE_0" "$REPLY"
assert_absent "animation never places a Kitty image" "--place" "$REPLY"

# Exercise every remaining message style and verify that the prompt animation
# completes without Kitty graphics or ImageMagick.
for style in sarcastic dramatic anime ecchi rainbow legendary mythic; do
    zpty -w "$PTY_NAME" "_dots_test_queue_special_animation '$style'"$'\n'
    read_until "SPECIAL_QUEUED_\${style}"
    assert_contains "\${style} queue is acknowledged" "SPECIAL_QUEUED_\${style}" "$REPLY"
    read_until "\${style} ANIMATED FAILURE BANNER"
    assert_contains "\${style} banner is shown in the editable prompt" "\${style} ANIMATED FAILURE BANNER" "$REPLY"
    assert_contains "\${style} uses a truecolour prompt gradient" $'\e[38;2;' "$REPLY"
    drain_for 60

    zpty -w "$PTY_NAME" '_dots_test_snapshot_special_animation'$'\n'
    read_until SPECIAL_STATE_GRADIENT_ACTIVE_
    assert_contains "\${style} completes all 25 gradient frames" "FRAMES_25" "$REPLY"
    assert_contains "\${style} leaves no asynchronous gradient worker" "GRADIENT_ACTIVE_0" "$REPLY"
    assert_contains "\${style} never invokes Kitty graphics" "KITTY_CALLS_0" "$REPLY"
    assert_contains "\${style} never invokes ImageMagick" "RENDERED_25_0" "$REPLY"
    assert_contains "\${style} never creates an animated GIF" "ANIMATED_GIFS_0" "$REPLY"
done
print -- "ok - all eight message styles animate through ZLE without intercepting input"

# Clearing the screen and running clear both cancel an active gradient.
zpty -w "$PTY_NAME" "_dots_test_queue_special_animation legendary"$'\n'
read_until "SPECIAL_QUEUED_legendary"
read_until "legendary ANIMATED FAILURE BANNER"
drain_for 3
zpty -w "$PTY_NAME" $'\x0c'
drain_for 3
zpty -w "$PTY_NAME" '_dots_test_snapshot_special_animation'$'\n'
read_until SPECIAL_STATE_GRADIENT_ACTIVE_
assert_contains "Ctrl+L stops an active gradient worker" "GRADIENT_ACTIVE_0" "$REPLY"

zpty -w "$PTY_NAME" "_dots_test_queue_special_animation legendary"$'\n'
read_until "SPECIAL_QUEUED_legendary"
read_until "legendary ANIMATED FAILURE BANNER"
drain_for 3
zpty -w "$PTY_NAME" 'clear'$'\n'
read_until CLEAR_EXECUTED
zpty -w "$PTY_NAME" '_dots_test_snapshot_special_animation'$'\n'
read_until SPECIAL_STATE_GRADIENT_ACTIVE_
assert_contains "clear stops an active gradient worker" "GRADIENT_ACTIVE_0" "$REPLY"

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

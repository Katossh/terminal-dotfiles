#!/usr/bin/env zsh
# End-to-end tests for the asynchronous prompt animation.
#
# The suite drives a real interactive Zsh through zsh/zpty and models the
# resulting raw terminal stream with tests/helpers/vt_screen.py. That lets the
# tests assert what a terminal would actually display: the gradient block is
# above the edit line, frames redraw in place instead of adding scrollback
# lines, typed input survives animation frames, and the final banner remains as
# ordinary output exactly once.
setopt nounset

REPO_DIR="${0:A:h:h}"
ZSH_DIR="$REPO_DIR/config/terminal/zsh"
VT_HELPER="$REPO_DIR/tests/helpers/vt_screen.py"
PTY_NAME="dots_failure_animation_test_$$"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dots-failure-animation.XXXXXX")" || exit 1
INIT_FILE="$TMP_DIR/init.zsh"
START_FILE="$TMP_DIR/start.sh"
RAW_FILE="$TMP_DIR/raw.terminal"
STATE_FILE="$TMP_DIR/state.log"
DIAG_LOG="$TMP_DIR/diag.log"
PALETTE_DIR="$TMP_DIR/palettes"
SNAP_RAW="$TMP_DIR/screen.raw"
COLS=100
ROWS=30
LAST_PID=''
RAW=''
: > "$RAW_FILE"
: > "$STATE_FILE"
mkdir -p "$PALETTE_DIR"
export PYTHONIOENCODING=utf-8

cleanup() {
    if [[ -n "${LAST_PID:-}" ]]; then
        kill -TERM "$LAST_PID" 2>/dev/null || true
    fi
    zpty -d "$PTY_NAME" 2>/dev/null || true
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

fail() {
    print -u2 -r -- "not ok - $*"
    if [[ -f "$RAW_FILE" && -f "$VT_HELPER" ]]; then
        print -u2 -- "--- visible screen ---"
        python3 "$VT_HELPER" --input "$RAW_FILE" --cols "$COLS" --rows "$ROWS" \
            --query screen 2>/dev/null | sed -n '1,35p' >&2 || true
    fi
    if [[ -f "$STATE_FILE" ]]; then
        print -u2 -- "--- state (last 20) ---"
        tail -n 20 "$STATE_FILE" >&2 || true
    fi
    if [[ -n "${DIAG_LOG:-}" && -f "$DIAG_LOG" ]]; then
        print -u2 -- "--- animation trace (last 60) ---"
        tail -n 60 "$DIAG_LOG" >&2 || true
    fi
    exit 1
}

assert_contains() {
    local label="$1" needle="$2" haystack="$3"
    [[ "$haystack" == *"$needle"* ]] ||
        fail "$label (missing: $needle; captured: $haystack)"
    print -- "ok - $label"
}

assert_absent() {
    local label="$1" needle="$2" haystack="$3"
    [[ "$haystack" != *"$needle"* ]] ||
        fail "$label (unexpected: $needle; captured: $haystack)"
    print -- "ok - $label"
}

snap_value() {
    local key="$1" line="$2"
    local rest="${line#*|$key=}"
    if [[ "$rest" == "$line" ]]; then
        REPLY=''
        return 1
    fi
    REPLY="${rest%%|*}"
    return 0
}

assert_field() {
    local label="$1" key="$2" expected="$3" line="$4"
    snap_value "$key" "$line" ||
        fail "$label (missing field $key; snapshot: $line)"
    [[ "$REPLY" == "$expected" ]] ||
        fail "$label (expected $key='$expected', got '$REPLY'; snapshot: $line)"
    print -- "ok - $label"
}

assert_int_field() {
    local label="$1" key="$2" minimum="$3" line="$4"
    snap_value "$key" "$line" ||
        fail "$label (missing field $key; snapshot: $line)"
    [[ "$REPLY" == <-> ]] ||
        fail "$label ($key is not an integer: '$REPLY'; snapshot: $line)"
    (( REPLY >= minimum )) ||
        fail "$label (expected $key >= $minimum, got $REPLY; snapshot: $line)"
    print -- "ok - $label"
}

zmodload zsh/zpty 2>/dev/null || {
    print -- "skip - zsh/zpty is unavailable"
    exit 0
}
command -v python3 >/dev/null 2>&1 || {
    print -u2 -- "python3 is required for the terminal screen model"
    exit 1
}

cat > "$INIT_FILE" <<'ZSH_INIT'
DOTS_TEST_ZSH_DIR=${DOTS_TEST_ZSH_DIR:?}
DOTS_TEST_STATE_FILE=${DOTS_TEST_STATE_FILE:?}
DOTS_TEST_PALETTE_DIR=${DOTS_TEST_PALETTE_DIR:?}

setopt promptsubst
unset NO_COLOR
zmodload zsh/datetime 2>/dev/null || true
export DOTS_FAILURE_MESSAGE_CHANCE=100
export DOTS_FAILURE_ANIMATION_CHANCE=100
export DOTS_FAILURE_STYLE=normal
export DOTS_FAILURE_MESSAGE_ESCALATION=0
export DOTS_FAILURE_LEGENDARY_CHANCE=0
export DOTS_FAILURE_MYTHIC_CHANCE=0
export DOTS_FAILURE_RAINBOW_CHANCE=0
export DOTS_FAILURE_ANIMATION=1
export DOTS_FAILURE_ANIMATION_INTERVAL=0.02
export DOTS_FAILURE_GRADIENT_INTERVAL=0.02

PROMPT=$'BASE_PATH\nBASE_STATUS\nBASE_OUTPUT ❯ '
RPROMPT='BASE_RPROMPT'

source "$DOTS_TEST_ZSH_DIR/command-state.zsh"
source "$DOTS_TEST_ZSH_DIR/failure-classifier.zsh"
source "$DOTS_TEST_ZSH_DIR/failure-messages.zsh"
source "$DOTS_TEST_ZSH_DIR/command-suggestions.zsh"
source "$DOTS_TEST_ZSH_DIR/diagnostics.zsh"
source "$DOTS_TEST_ZSH_DIR/handlers.zsh"
source "$DOTS_TEST_ZSH_DIR/failure-animation.zsh"

autoload -Uz compinit
compinit -u -D 2>/dev/null || true
dots-test-command() { print -r -- "DOTS_TEST_COMMAND:$*" }
_dots_test_complete() { compadd -- alpha beta gamma delta }
compdef _dots_test_complete dots-test-command 2>/dev/null || true

_dots_state() {
    print -r -- "$*" >> "$DOTS_TEST_STATE_FILE"
}

_dots_test_snapshot() {
    _dots_state "SNAP|buf=${BUFFER}|cursor=${CURSOR}|active=${_DOTS_FAILURE_ANIMATION_ACTIVE}|fd=${_DOTS_FAILURE_ANIMATION_FD}|pid=${_DOTS_FAILURE_ANIMATION_PRODUCER_PID}|gf=${_DOTS_FAILURE_ANIMATION_GRADIENT_FRAMES}|lastgf=${_DOTS_FAILURE_ANIMATION_LAST_BANNER_FRAMES}|phase=${_DOTS_FAILURE_ANIMATION_GRADIENT_PHASE}|frames=${_DOTS_FAILURE_ANIMATION_FRAMES}|lastframes=${_DOTS_FAILURE_ANIMATION_LAST_FRAMES}|mode=${_DOTS_FAILURE_ANIMATION_MODE}|style=${_DOTS_FAILURE_ANIMATION_STYLE}|state=${_DOTS_FAILURE_ANIMATION_STATE}|last=${_DOTS_FAILURE_ANIMATION_LAST_STATE}|frame=${_DOTS_FAILURE_ANIMATION_FRAME}|rprompt=${RPROMPT}"
}
zle -N _dots_test_snapshot
bindkey '^T' _dots_test_snapshot

_dots_test_queue() {
    local style="$1"
    local suffix="${2:-}"
    local marker_style="${style:u}"
    local banner="GRADIENT_BANNER_MARKER_${marker_style}"
    local detail="GRADIENT_DETAIL_MARKER_${marker_style}"
    if [[ -n "$suffix" ]]; then
        banner+="_${suffix:u}"
        detail+="_${suffix:u}"
    fi
    _dots_failure_animation_start "$style" "$banner" "$detail" || return 1
    print -r -- "QUEUED:${style}:${suffix}"
}

_dots_test_set_style() {
    export DOTS_FAILURE_STYLE="$1"
    print -r -- "STYLE_SET:$1"
}

_dots_test_pool() {
    local style="$1"
    _dots_failure_animation_pool_for_style "$style"
    _dots_state "POOL|${style}|${#_DOTS_FAILURE_ANIMATION_POOL}|${(j: :)${_DOTS_FAILURE_ANIMATION_POOL}}"
    print -r -- "POOL_READY:$style"
}

_dots_test_hooks() {
    local -i precmd=0 preexec=0 linefinish=0
    local fn
    for fn in ${precmd_functions[@]}; do
        [[ "$fn" == _dots_failure_animation_precmd ]] && precmd=$(( precmd + 1 ))
    done
    for fn in ${preexec_functions[@]}; do
        [[ "$fn" == _dots_failure_animation_preexec ]] && preexec=$(( preexec + 1 ))
    done
    local -a hook_widgets
    zstyle -a zle-line-finish widgets hook_widgets
    for fn in ${hook_widgets[@]}; do
        [[ "$fn" == *:_dots_failure_animation_line_finish ]] && linefinish=$(( linefinish + 1 ))
    done
    _dots_state "HOOKS|precmd=${precmd}|preexec=${preexec}|linefinish=${linefinish}|loaded=${_DOTS_FAILURE_ANIMATION_LOADED}|prompt=${PROMPT}"
    print -r -- HOOKS_READY
}

_dots_test_phase_zero() {
    local -i start_status=0
    _dots_failure_animation_start normal 'GRADIENT_PHASE_ZERO' 'GRADIENT_PHASE_ZERO_DETAIL' ||
        start_status=$?
    _dots_state "PHASE0|rc=${start_status}|gf=${_DOTS_FAILURE_ANIMATION_GRADIENT_FRAMES}|phase=${_DOTS_FAILURE_ANIMATION_GRADIENT_PHASE}|mode=${_DOTS_FAILURE_ANIMATION_MODE}|pending=${_DOTS_FAILURE_ANIMATION_PENDING}"
    _dots_failure_animation_reset
    print -r -- PHASE_ZERO_READY
}

_dots_test_gradient_motion() {
    local first='' second=''
    _dots_failure_animation_gradient_line 'LEGENDARY ANIMATED FAILURE BANNER' legendary 0
    first="$_DOTS_FAILURE_ANIMATION_GRADIENT_LINE"
    _dots_failure_animation_gradient_line 'LEGENDARY ANIMATED FAILURE BANNER' legendary 20
    second="$_DOTS_FAILURE_ANIMATION_GRADIENT_LINE"
    local first_color="${first#*38;2;}"
    first_color="${first_color%%m*}"
    local second_color="${second#*38;2;}"
    second_color="${second_color%%m*}"
    local -i same=1
    [[ "$first" == "$second" ]] || same=0
    _dots_state "GRADIENT_MOTION|same=${same}|first=${first_color}|second=${second_color}"
    print -r -- GRADIENT_MOTION_READY
}

_dots_test_duplicate_prompt() {
    local saved_prompt="$_DOTS_FAILURE_ANIMATION_ORIGINAL_PROMPT"
    local saved_mode="$_DOTS_FAILURE_ANIMATION_PROMPT_MODE"
    _DOTS_FAILURE_ANIMATION_ORIGINAL_PROMPT='BASE_OUTPUT CODE=1 ❯ ❯ '
    _DOTS_FAILURE_ANIMATION_PROMPT_MODE='static'
    _DOTS_FAILURE_ANIMATION_FRAME='😭'
    local rendered
    rendered="$(_dots_failure_animation_render_prompt)"
    _DOTS_FAILURE_ANIMATION_ORIGINAL_PROMPT="$saved_prompt"
    _DOTS_FAILURE_ANIMATION_PROMPT_MODE="$saved_mode"
    _dots_state "DUPLICATE_PROMPT|${rendered}"
    print -r -- DUPLICATE_PROMPT_READY
}

_dots_test_palettes() {
    local style message
    message=${(l:120::X:)}
    for style in normal sarcastic dramatic anime ecchi rainbow legendary mythic; do
        _dots_failure_animation_gradient_line "$message" "$style" 0
        print -rn -- "$_DOTS_FAILURE_ANIMATION_GRADIENT_LINE_RAW" \
            > "$DOTS_TEST_PALETTE_DIR/$style.raw"
    done
    print -r -- PALETTES_READY
}

_dots_test_infinite_aliases() {
    unset DOTS_FAILURE_ANIMATION_INFINITE DOTS_FAILURE_EMOJI_ANIMATION_INFINITE DOTS_FAILURE_ANIMATION_CONTINUOUS
    local -i found=0
    export DOTS_FAILURE_EMOJI_ANIMATION_INFINITE=1
    _dots_failure_animation_infinite_enabled && found=$(( found + 1 ))
    unset DOTS_FAILURE_EMOJI_ANIMATION_INFINITE
    export DOTS_FAILURE_ANIMATION_CONTINUOUS=1
    _dots_failure_animation_infinite_enabled && found=$(( found + 1 ))
    unset DOTS_FAILURE_ANIMATION_CONTINUOUS
    _dots_state "INFINITE_ALIASES|ok=${found}"
    print -r -- INFINITE_ALIASES_READY
}

_dots_test_enable_infinite() {
    export DOTS_FAILURE_ANIMATION_INFINITE=1
    print -r -- INFINITE_ENABLED
}

_dots_test_disable_infinite() {
    unset DOTS_FAILURE_ANIMATION_INFINITE
    _dots_state "INFINITE_DISABLED|active=${_DOTS_FAILURE_ANIMATION_ACTIVE}|lastframes=${_DOTS_FAILURE_ANIMATION_LAST_FRAMES}|last=${_DOTS_FAILURE_ANIMATION_LAST_STATE}"
    print -r -- INFINITE_DISABLED
}

_dots_state "ENV|columns=${COLUMNS}|lines=${LINES}|term=${TERM}"
ZSH_INIT

# zpty joins its command arguments without preserving shell quoting, so put
# the terminal-size setup in a small executable wrapper instead of nesting
# `sh -c` here.
cat > "$START_FILE" <<EOF
#!/bin/sh
stty rows $ROWS columns $COLS
exec zsh -f -i
EOF
chmod +x "$START_FILE"

zpty -b "$PTY_NAME" env \
    TERM=xterm-256color \
    DOTS_TEST_STATE_FILE="$STATE_FILE" \
    DOTS_TEST_DIAG_LOG="$DIAG_LOG" \
    DOTS_TEST_PALETTE_DIR="$PALETTE_DIR" \
    DOTS_TEST_ZSH_DIR="$ZSH_DIR" \
    "$START_FILE" ||
    fail "could not start the interactive test shell"

pump() {
    local chunk=''
    while zpty -r -t "$PTY_NAME" chunk 2>/dev/null; do
        RAW+="$chunk"
        print -rn -- "$chunk" >> "$RAW_FILE"
    done
}

wait_raw() {
    local needle="$1"
    local -i attempts=0
    while (( attempts < 750 )); do
        pump
        [[ "$RAW" == *"$needle"* ]] && return 0
        command sleep 0.02
        attempts=$(( attempts + 1 ))
    done
    fail "timed out waiting for output: $needle"
}

send_line() {
    zpty -w "$PTY_NAME" "$1"
}

send_keys() {
    zpty -w -n "$PTY_NAME" "$1"
}

vt_snapshot() {
    pump
    cp "$RAW_FILE" "$SNAP_RAW" || fail "could not snapshot the terminal stream"
}

vt_query() {
    local query="$1"
    shift
    python3 "$VT_HELPER" --input "$SNAP_RAW" --cols "$COLS" --rows "$ROWS" \
        --query "$query" "$@"
}

wait_visual() {
    local needle="$1"
    local -i attempts=0
    local screen=''
    while (( attempts < 750 )); do
        vt_snapshot
        screen="$(vt_query screen)"
        [[ "$screen" == *"$needle"* ]] && return 0
        command sleep 0.02
        attempts=$(( attempts + 1 ))
    done
    fail "timed out waiting for screen text: $needle"
}

count_state_lines() {
    local prefix="$1"
    awk -v p="$prefix" 'index($0, p) == 1 { n++ } END { print n + 0 }' \
        "$STATE_FILE" 2>/dev/null
}

last_state_line() {
    local prefix="$1"
    awk -v p="$prefix" 'index($0, p) == 1 { last = $0 } END { print last }' \
        "$STATE_FILE" 2>/dev/null
}

snap() {
    local -i before
    before=$(count_state_lines 'SNAP|')
    local -i attempts=0
    local line=''
    while (( attempts < 500 )); do
        # Ctrl+C can flush input that was already queued, so resend the
        # snapshot key when no widget has run after a short wait.
        if (( attempts % 20 == 0 )); then
            send_keys $'\x14'
        fi
        pump
        if (( $(count_state_lines 'SNAP|') > before )); then
            line=$(last_state_line 'SNAP|')
            local pid_value=''
            if snap_value pid "$line"; then
                pid_value="$REPLY"
            fi
            if [[ "$pid_value" == <-> ]] && (( pid_value > 0 )); then
                LAST_PID="$pid_value"
            else
                LAST_PID=''
            fi
            REPLY="$line"
            return 0
        fi
        command sleep 0.01
        attempts=$(( attempts + 1 ))
    done
    fail "the ZLE snapshot widget did not respond"
}

wait_animation_complete() {
    local -i attempts=0
    local line=''
    while (( attempts < 500 )); do
        snap
        line="$REPLY"
        if [[ "$line" == *'|active=0|'* &&
            "$line" == *'|lastgf=25|'* &&
            "$line" == *'|phase=96|'* &&
            "$line" == *'|last=stream-complete|'* ]]; then
            REPLY="$line"
            return 0
        fi
        command sleep 0.01
        attempts=$(( attempts + 1 ))
    done
    fail "the gradient animation did not complete all 25 frames; last snapshot: $line"
}

wait_clean_prompt() {
    local -i attempts=0
    local line=''
    while (( attempts < 500 )); do
        snap
        line="$REPLY"
        if [[ "$line" == *'|active=0|'* && "$line" == *'|mode=emoji|'* ]]; then
            REPLY="$line"
            return 0
        fi
        command sleep 0.01
        attempts=$(( attempts + 1 ))
    done
    fail "the prompt did not return to its idle state; last snapshot: $line"
}

marker_counts() {
    local marker="$1"
    vt_snapshot
    vt_query find --text "$marker"
}

count_marker_on_screen() {
    local counts="$1"
    local value="${counts#*screen=}"
    print -r -- "${value%% *}"
}

count_marker_in_scrollback() {
    local counts="$1"
    local value="${counts#*scrollback=}"
    print -r -- "${value%% *}"
}

assert_marker_once() {
    local label="$1" marker="$2"
    local counts screen_count scrollback_count
    counts=$(marker_counts "$marker")
    screen_count=$(count_marker_on_screen "$counts")
    scrollback_count=$(count_marker_in_scrollback "$counts")
    (( screen_count + scrollback_count == 1 )) ||
        fail "$label (marker appears $screen_count time(s) on screen and $scrollback_count in scrollback)"
    print -- "ok - $label"
}

vt_scrollback_rows() {
    vt_snapshot
    vt_query json |
        python3 -c 'import json, sys; print(len(json.load(sys.stdin)["scrollback"]))'
}

palette_colors() {
    python3 -c '
import re, sys
data = open(sys.argv[1], "rb").read().decode("utf-8", "replace")
colors = { ",".join(match) for match in re.findall(r"38;2;(\d+);(\d+);(\d+)m", data) }
print(" ".join(sorted(colors)))
' "$1"
}

# Expected pools are part of the public behaviour: ordinary styles share a
# pool, while anime, ecchi, and rainbow keep their own identities.
common_pool=(👀 😳 ✨ 💀 😂 🤡 🪿 🔥 💔 🖤 🤎 💜 🫠)
anime_pool=(😭 🥰 🥺 💖 💗 💓 💕)
ecchi_pool=(😏 ❤️ 🩷 💘)
rainbow_pool=(🧡 💛 💚 💙 🤍)

assert_pool() {
    local style="$1" expected_count="$2" expected_values="$3"
    local line
    line=$(last_state_line "POOL|$style|")
    [[ -n "$line" ]] || fail "pool $style was not recorded"
    local recorded_count="${line#POOL|$style|}"
    recorded_count="${recorded_count%%|*}"
    local recorded_values="${line#*|$expected_count|}"
    [[ "$recorded_count" == "$expected_count" ]] ||
        fail "$style pool size (expected $expected_count, got $recorded_count; line: $line)"
    [[ "$recorded_values" == "$expected_values" ]] ||
        fail "$style pool contents (expected '$expected_values', got '$recorded_values')"
    print -- "ok - $style uses its documented emoji pool"
}

# Screen/line helpers.
input_line_from_screen() {
    local screen="$1"
    local line="${${(f)screen}[(R)*BASE_OUTPUT*]}"
    [[ -n "$line" ]] || fail "the input prompt line is missing from the screen"
    REPLY="$line"
}

assert_input_emoji() {
    local label="$1" style="$2" screen="$3"
    local line emoji found=0 entry
    input_line_from_screen "$screen"
    line="$REPLY"
    emoji="${line#*BASE_OUTPUT }"
    emoji="${emoji%% ❯*}"
    emoji="${emoji## }"
    emoji="${emoji%% }"
    emoji="${emoji//$'\uFE0F'/}"
    local -a pool
    case "$style" in
        anime) pool=( "${anime_pool[@]}" ) ;;
        ecchi) pool=( "${ecchi_pool[@]}" ) ;;
        rainbow) pool=( "${rainbow_pool[@]}" ) ;;
        *) pool=( "${common_pool[@]}" ) ;;
    esac
    for entry in "${pool[@]}"; do
        entry="${entry//$'\uFE0F'/}"
        [[ "$emoji" == "$entry" ]] && found=1
    done
    (( found )) ||
        fail "$label (prompt emoji '$emoji' is not in the $style pool)"
    print -- "ok - $label"
}

assert_style_palette() {
    local style="$1" marker="$2"
    vt_snapshot
    local actual
    actual="$(vt_query colors --text "$marker")"
    [[ -n "$actual" ]] || fail "$style gradient produced no truecolour cells"
    local -a actual_colors
    actual_colors=( ${(s: :)actual} )
    (( ${#actual_colors} >= 6 )) ||
        fail "$style gradient used only ${#actual_colors} distinct colours"
    local expected=" ${PALETTE_COLORS[$style]} "
    local color
    for color in "${actual_colors[@]}"; do
        [[ "$expected" == *" $color "* ]] ||
            fail "$style gradient used unexpected colour $color (palette: $expected)"
    done
    print -- "ok - $style gradient uses its documented 24-bit palette"
}

clear_screen() {
    send_line 'command clear; print -r -- SCREEN_CLEARED'
    wait_raw SCREEN_CLEARED
    wait_clean_prompt
}

queue_gradient() {
    local style="$1" suffix="${2:-}"
    local marker="GRADIENT_BANNER_MARKER_${style:u}"
    if [[ -n "$suffix" ]]; then
        marker+="_${suffix:u}"
    fi
    send_line "_dots_test_queue $style${suffix:+ $suffix}"
    wait_raw "QUEUED:${style}:${suffix}"
    REPLY="$marker"
}

# Let the initial interactive prompt appear before sourcing the modules.
command sleep 0.2
pump

send_line "source '$INIT_FILE'"
wait_raw BASE_OUTPUT
sleep 0.05

env_line=$(last_state_line 'ENV|')
assert_field "the PTY is $COLS columns wide" columns "$COLS" "$env_line"
assert_field "the PTY is $ROWS rows tall" lines "$ROWS" "$env_line"

# Startup animation: the ordinary emoji prompt animation still completes on
# its own and leaves RPROMPT untouched.
startup_line=''
typeset -i startup_attempts=0
while (( startup_attempts < 500 )); do
    snap
    startup_line="$REPLY"
    if [[ "$startup_line" == *'|lastframes=12|'* &&
        "$startup_line" == *'|active=0|'* ]]; then
        break
    fi
    command sleep 0.01
    startup_attempts=$(( startup_attempts + 1 ))
done
assert_field "startup emoji animation completes all 12 frames" lastframes 12 "$startup_line"
assert_field "startup animation leaves no active worker" active 0 "$startup_line"
assert_field "startup worker ended by closing its stream" last stream-complete "$startup_line"
assert_field "startup animation uses the ordinary style" style normal "$startup_line"
assert_field "right prompt is unchanged by the startup animation" rprompt BASE_RPROMPT "$startup_line"

vt_snapshot
startup_screen="$(vt_query screen)"
assert_contains "the path line is rendered above the input line" BASE_PATH "$startup_screen"
assert_contains "the right prompt is still displayed" BASE_RPROMPT "$startup_screen"
assert_input_emoji "startup animation places an ordinary emoji before the marker" normal "$startup_screen"
path_line="${${(f)startup_screen}[(r)BASE_PATH*]}"
for entry in "${common_pool[@]}"; do
    assert_absent "the path line never receives animated emoji" "$entry" "$path_line"
done

# Re-sourcing must not wrap PROMPT twice or register duplicate hooks.
send_line 'source "$DOTS_TEST_ZSH_DIR/failure-animation.zsh"; print -r -- RESOURCED'
wait_raw RESOURCED
send_line '_dots_test_hooks'
wait_raw HOOKS_READY
hooks_line=$(last_state_line 'HOOKS|')
assert_field "re-sourcing keeps exactly one precmd hook" precmd 1 "$hooks_line"
assert_field "re-sourcing keeps exactly one preexec hook" preexec 1 "$hooks_line"
assert_field "re-sourcing keeps exactly one line-finish hook" linefinish 1 "$hooks_line"
assert_field "re-sourcing leaves the prompt wrapper in place" prompt '$(_dots_failure_animation_render_prompt)' "$hooks_line"

# Emoji pools are preserved exactly.
for pool_style in normal sarcastic dramatic anime ecchi rainbow legendary mythic; do
    send_line "_dots_test_pool $pool_style"
    wait_raw "POOL_READY:$pool_style"
done
assert_pool normal 13 "👀 😳 ✨ 💀 😂 🤡 🪿 🔥 💔 🖤 🤎 💜 🫠"
assert_pool sarcastic 13 "👀 😳 ✨ 💀 😂 🤡 🪿 🔥 💔 🖤 🤎 💜 🫠"
assert_pool dramatic 13 "👀 😳 ✨ 💀 😂 🤡 🪿 🔥 💔 🖤 🤎 💜 🫠"
assert_pool anime 7 "😭 🥰 🥺 💖 💗 💓 💕"
assert_pool ecchi 4 "😏 ❤️ 🩷 💘"
assert_pool rainbow 5 "🧡 💛 💚 💙 🤍"
assert_pool legendary 13 "👀 😳 ✨ 💀 😂 🤡 🪿 🔥 💔 🖤 🤎 💜 🫠"
assert_pool mythic 13 "👀 😳 ✨ 💀 😂 🤡 🪿 🔥 💔 🖤 🤎 💜 🫠"
ecchi_line=$(last_state_line 'POOL|ecchi|')
assert_absent "Ecchi pool does not contain the melting face" 🫠 "$ecchi_line"

# The phase-0 banner already counts as the first frame; the producer supplies
# the remaining 24 phases through the pipe.
send_line '_dots_test_phase_zero'
wait_raw PHASE_ZERO_READY
phase_zero_line=$(last_state_line 'PHASE0|')
assert_field "phase 0 is accepted as the first gradient frame" gf 1 "$phase_zero_line"
assert_field "phase 0 starts at the beginning of the palette" phase 0 "$phase_zero_line"
assert_field "phase 0 selects gradient mode" mode gradient "$phase_zero_line"
wait_clean_prompt

# Advancing the phase must actually move the colour sweep; a static banner
# would still satisfy the frame counters above.
send_line '_dots_test_gradient_motion'
wait_raw GRADIENT_MOTION_READY
motion_line=$(last_state_line 'GRADIENT_MOTION|')
assert_field "a new phase changes the rendered gradient" same 0 "$motion_line"
assert_field "phase 0 starts on the first metallic-gold stop" first '74;50;12' "$motion_line"
assert_field "phase 20 advances the first character through the palette" second '190;145;55' "$motion_line"

# Prompts that already contain several markers must keep exactly one final
# marker and leave the status text before the animated emoji.
send_line '_dots_test_duplicate_prompt'
wait_raw DUPLICATE_PROMPT_READY
duplicate_line=$(last_state_line 'DUPLICATE_PROMPT|')
assert_contains "the exit status stays before the animated emoji" 'BASE_OUTPUT CODE=1 😭 ❯' "$duplicate_line"
assert_absent "the rendered prompt keeps only one final marker" '❯ ❯' "$duplicate_line"

# Render the full palette of every style once so the screen assertions can
# verify that animation only uses documented colours.
send_line '_dots_test_palettes'
wait_raw PALETTES_READY
typeset -A PALETTE_COLORS
for palette_style in normal sarcastic dramatic anime ecchi rainbow legendary mythic; do
    PALETTE_COLORS[$palette_style]=$(palette_colors "$PALETTE_DIR/$palette_style.raw")
    [[ -n "${PALETTE_COLORS[$palette_style]}" ]] ||
        fail "could not extract the $palette_style palette"
done

# A real failed command must produce the real failure pipeline: the banner,
# exit status detail, style palette, and a completed asynchronous animation.
send_line '_dots_test_set_style legendary'
wait_raw STYLE_SET:legendary
send_line 'false'
wait_visual 'exit status 1'
wait_animation_complete
failure_line="$REPLY"
assert_field "a real failure uses the selected legendary style" style legendary "$failure_line"
assert_field "a real failure renders a gradient block" mode gradient "$failure_line"
assert_field "a real failure completes all 25 gradient frames" gf 25 "$failure_line"
assert_field "a real failure records all 25 banner frames" lastgf 25 "$failure_line"
assert_field "a real failure reaches the final gradient phase" phase 96 "$failure_line"
assert_field "a real failure releases the producer" active 0 "$failure_line"
assert_field "a real failure closes the producer stream cleanly" last stream-complete "$failure_line"
assert_field "a real failure closes the producer pipe" fd -1 "$failure_line"
assert_field "a real failure clears the producer pid" pid 0 "$failure_line"

vt_snapshot
failure_screen="$(vt_query screen)"
assert_contains "the selected legendary banner is visible" legendary "$failure_screen"
assert_contains "the failure detail reports the exit status" 'exit status 1' "$failure_screen"
assert_contains "the right prompt survives a real failure" BASE_RPROMPT "$failure_screen"
assert_style_palette legendary 'exit status 1'

# Real messages contain emoji. Verify that their prompt block still sits above
# the editable input line instead of wrapping onto it.
row_text=$(vt_query rows --text 'exit status 1')
typeset -a real_detail_rows
real_detail_rows=( ${(s: :)row_text} )
row_text=$(vt_query rows --text 'BASE_OUTPUT')
typeset -a real_input_rows
real_input_rows=( ${(s: :)row_text} )
(( ${#real_detail_rows} > 0 && ${#real_input_rows} > 0 )) ||
    fail "the real failure detail or input line is missing from the screen"
(( real_detail_rows[-1] < real_input_rows[-1] )) ||
    fail "the real failure banner overlaps or follows the input line"
print -- "ok - a real emoji-bearing failure block stays above the editable input line"

send_keys $'\n'
wait_clean_prompt
clean_line="$REPLY"
assert_field "the next prompt drops the gradient block" mode emoji "$clean_line"
assert_field "the next prompt resets the gradient counter" gf 0 "$clean_line"
assert_field "the next prompt has no producer" active 0 "$clean_line"

# Every style must animate through the same prompt block, use its palette, and
# commit the final message exactly once to ordinary output.
for style in normal sarcastic dramatic anime ecchi rainbow legendary mythic; do
    clear_screen
    queue_gradient "$style"
    marker="$REPLY"
    wait_visual "$marker"

    # Snapshot immediately: the worker should still be alive at this point.
    if [[ "$style" == normal ]]; then
        snap
        mid_line="$REPLY"
        assert_field "normal animation is active while the banner is visible" active 1 "$mid_line"
        assert_int_field "normal animation reports a live producer pid" pid 1 "$mid_line"
        snap_value fd "$mid_line"
        (( REPLY >= 0 )) || fail "normal animation did not register its pipe"
        print -- "ok - normal animation registers a real file descriptor"

        # Type without submitting. The producer must not consume the keys or
        # disturb BUFFER/CURSOR while frames continue.
        typed_command='print -r -- TYPED_DURING_ANIMATION'
        typed_length=${#typed_command}
        send_keys "$typed_command"
        snap
        typed_line="$REPLY"
        assert_field "typing during animation keeps the complete buffer" buf "$typed_command" "$typed_line"
        snap_value cursor "$typed_line"
        (( REPLY == typed_length )) ||
            fail "typing during animation moved the cursor (expected $typed_length, got $REPLY)"
        print -- "ok - typing during animation leaves the cursor at the end of the buffer"

        send_keys $'\x01'
        snap
        assert_field "Ctrl+A moves the cursor during animation" cursor 0 "$REPLY"
        send_keys $'\x05'
        snap
        post_ctrl_e="$REPLY"
        assert_field "Ctrl+E restores the cursor during animation" cursor "$typed_length" "$post_ctrl_e"
        assert_field "cursor movement never changes the animation buffer" buf "$typed_command" "$post_ctrl_e"

        wait_animation_complete
        animated_line="$REPLY"
        assert_field "normal animation completes all 25 frames with typed input" gf 25 "$animated_line"
        assert_field "normal animation keeps the typed buffer after completion" buf "$typed_command" "$animated_line"

        # Only an explicit Enter executes the command.
        send_keys $'\n'
        wait_visual $'\nTYPED_DURING_ANIMATION'
        wait_clean_prompt
        assert_field "Enter executes the unmodified typed command" mode emoji "$REPLY"
        vt_snapshot
        executed_screen="$(vt_query screen)"
        assert_contains "the typed command output is ordinary terminal text" $'\nTYPED_DURING_ANIMATION' "$executed_screen"
    else
        wait_animation_complete
        animated_line="$REPLY"
        assert_field "$style animation completes all 25 frames" gf 25 "$animated_line"
        assert_field "$style animation records all 25 banner frames" lastgf 25 "$animated_line"
        assert_field "$style animation reaches phase 96" phase 96 "$animated_line"
        assert_field "$style animation releases its producer" active 0 "$animated_line"
        assert_field "$style animation ends by closing its stream" last stream-complete "$animated_line"
        assert_field "$style animation leaves no producer pid" pid 0 "$animated_line"
        assert_field "$style animation leaves no producer pipe" fd -1 "$animated_line"
        assert_field "$style animation keeps the selected style" style "$style" "$animated_line"

        vt_snapshot
        style_screen="$(vt_query screen)"
        assert_contains "$style banner is above the input line" "$marker" "$style_screen"
        assert_contains "$style detail line is visible" "GRADIENT_DETAIL_MARKER_${style:u}" "$style_screen"
        assert_contains "$style animation preserves the right prompt" BASE_RPROMPT "$style_screen"
        assert_input_emoji "$style animation keeps its own prompt emoji" "$style" "$style_screen"
        assert_style_palette "$style" "$marker"

        # The gradient is a prompt block, so it must sit between the status
        # line and the editable input line, never on top of either.
        row_text=$(vt_query rows --text "$marker")
        local -a banner_rows
        banner_rows=( ${(s: :)row_text} )
        (( ${#banner_rows} == 1 )) ||
            fail "$style banner appears on ${#banner_rows} rows; expected exactly one"
        row_text=$(vt_query rows --text 'BASE_STATUS')
        local -a status_rows
        status_rows=( ${(s: :)row_text} )
        row_text=$(vt_query rows --text 'BASE_OUTPUT')
        local -a input_rows
        input_rows=( ${(s: :)row_text} )
        (( ${#status_rows} > 0 && ${#input_rows} > 0 )) ||
            fail "$style original prompt lines are missing"
        (( banner_rows[1] > status_rows[-1] )) ||
            fail "$style gradient block overlaps the status/path lines"
        (( banner_rows[1] < input_rows[-1] )) ||
            fail "$style gradient block overlaps or follows the input line"
        print -- "ok - $style gradient block sits above the editable input line"

        send_keys $'\n'
        wait_clean_prompt
        assert_marker_once "$style banner is preserved exactly once after submission" "$marker"
    fi

    # Submission must stop the worker even if it was still running.
    snap
    post_submit="$REPLY"
    assert_field "$style submission leaves no active animation" active 0 "$post_submit"
    assert_field "$style submission leaves no producer pid" pid 0 "$post_submit"
    assert_field "$style submission closes the producer pipe" fd -1 "$post_submit"
done

# Full-screen independence: with the prompt already at the bottom of the
# terminal, successive frames must not scroll or drag the gradient block.
clear_screen
send_line 'for i in {1..26}; do print -r -- "FILLER_LINE_$i"; done'
wait_raw FILLER_LINE_26
wait_clean_prompt
queue_gradient rainbow scroll
scroll_marker="$REPLY"
wait_visual "$scroll_marker"
command sleep 0.08
scroll_before=$(vt_scrollback_rows)
row_text=$(vt_query rows --text "$scroll_marker")
scroll_row_before="$row_text"
command sleep 0.25
scroll_after=$(vt_scrollback_rows)
row_text=$(vt_query rows --text "$scroll_marker")
scroll_row_after="$row_text"
[[ "$scroll_after" == "$scroll_before" ]] ||
    fail "animation added scrollback lines ($scroll_before -> $scroll_after)"
print -- "ok - animation frames redraw in place without adding scrollback lines"
[[ "$scroll_row_after" == "$scroll_row_before" ]] ||
    fail "animation dragged its block between rows ($scroll_row_before -> $scroll_row_after)"
print -- "ok - animation does not drag the gradient block while the screen is full"
wait_animation_complete
send_keys $'\n'
wait_clean_prompt
assert_marker_once "the scrolled animation commits its final frame once" "$scroll_marker"
send_line 'for i in {1..35}; do print -r -- "PUSH_LINE_$i"; done'
wait_raw PUSH_LINE_35
wait_clean_prompt
counts=$(marker_counts "$scroll_marker")
scrollback_count=$(count_marker_in_scrollback "$counts")
screen_count=$(count_marker_on_screen "$counts")
(( scrollback_count == 1 && screen_count == 0 )) ||
    fail "committed banner should be ordinary scrollback text (screen=$screen_count scrollback=$scrollback_count)"
print -- "ok - the committed banner survives scrolling as exactly one scrollback row"

# Ctrl+L must stop the animation and leave a usable prompt.
clear_screen
queue_gradient anime ctrll
ctrll_marker="$REPLY"
wait_visual "$ctrll_marker"
send_keys $'\x0c'
wait_clean_prompt
ctrll_line="$REPLY"
assert_field "Ctrl+L stops the gradient worker" active 0 "$ctrll_line"
assert_field "Ctrl+L closes the producer pipe" fd -1 "$ctrll_line"
assert_field "Ctrl+L clears the producer pid" pid 0 "$ctrll_line"
vt_snapshot
ctrll_screen="$(vt_query screen)"
assert_absent "Ctrl+L removes the unfinished gradient block" "$ctrll_marker" "$ctrll_screen"
assert_contains "Ctrl+L leaves the ordinary prompt intact" BASE_OUTPUT "$ctrll_screen"

# The actual clear command must do the same and still clear the screen.
clear_screen
queue_gradient ecchi clear
clear_marker="$REPLY"
wait_visual "$clear_marker"
send_line 'command clear; print -r -- CLEAR_RAN'
wait_raw CLEAR_RAN
wait_clean_prompt
clear_line="$REPLY"
assert_field "clear stops the gradient worker" active 0 "$clear_line"
assert_field "clear closes the producer pipe" fd -1 "$clear_line"
assert_field "clear clears the producer pid" pid 0 "$clear_line"
vt_snapshot
clear_screen_text="$(vt_query screen)"
assert_absent "clear removes the unfinished gradient block" "$clear_marker" "$clear_screen_text"
assert_contains "clear leaves an ordinary prompt" BASE_OUTPUT "$clear_screen_text"

# Ctrl+C is a send-break: it must abandon the line and stop the producer
# without executing the typed command.
clear_screen
queue_gradient rainbow ctrlc
ctrlc_marker="$REPLY"
wait_visual "$ctrlc_marker"
snap
ctrlc_mid="$REPLY"
assert_field "Ctrl+C test starts with an active producer" active 1 "$ctrlc_mid"
snap_value pid "$ctrlc_mid"
ctrlc_pid="$REPLY"
[[ "$ctrlc_pid" == <-> ]] && (( ctrlc_pid > 0 )) ||
    fail "Ctrl+C test could not observe the producer pid"
send_keys 'echo ABORTED_COMMAND'
snap
assert_field "the aborted line is present before Ctrl+C" buf 'echo ABORTED_COMMAND' "$REPLY"
send_keys $'\x03'
wait_clean_prompt
ctrlc_line="$REPLY"
assert_field "Ctrl+C stops the gradient worker" active 0 "$ctrlc_line"
assert_field "Ctrl+C closes the producer pipe" fd -1 "$ctrlc_line"
assert_field "Ctrl+C clears the producer pid" pid 0 "$ctrlc_line"
assert_field "Ctrl+C restores an empty edit buffer" buf '' "$ctrlc_line"
typeset -i orphan_wait=0
while (( orphan_wait < 100 )) && kill -0 "$ctrlc_pid" 2>/dev/null; do
    command sleep 0.02
    orphan_wait=$(( orphan_wait + 1 ))
done
kill -0 "$ctrlc_pid" 2>/dev/null &&
    fail "Ctrl+C left an orphan producer (pid $ctrlc_pid)"
print -- "ok - Ctrl+C terminates and reaps the producer"
vt_snapshot
ctrlc_screen="$(vt_query screen)"
assert_absent "Ctrl+C does not execute the abandoned command" $'\nABORTED_COMMAND' "$ctrlc_screen"
assert_contains "Ctrl+C leaves a fresh ordinary prompt" BASE_OUTPUT "$ctrlc_screen"

# Incremental history search must remain usable while frames are arriving.
clear_screen
send_line 'echo HISTORY_ALPHA'
wait_visual HISTORY_ALPHA
wait_clean_prompt
send_line 'echo HISTORY_BETA'
wait_visual HISTORY_BETA
wait_clean_prompt
queue_gradient dramatic hist
hist_marker="$REPLY"
wait_visual "$hist_marker"
send_keys $'\x12'
send_keys 'HISTORY_'
wait_visual 'bck-i-search'
sleep 0.1
vt_snapshot
hist_screen="$(vt_query screen)"
assert_contains "history search stays visible during animation" 'bck-i-search' "$hist_screen"
assert_contains "history search finds the most recent command during animation" HISTORY_BETA "$hist_screen"
command sleep 0.5
vt_snapshot
hist_screen="$(vt_query screen)"
assert_contains "history search survives all animation frames" 'bck-i-search' "$hist_screen"
assert_contains "history search keeps its match after animation completes" HISTORY_BETA "$hist_screen"
send_keys $'\x07'
command sleep 0.15
vt_snapshot
hist_screen="$(vt_query screen)"
if [[ "$hist_screen" == *'bck-i-search'* ]]; then
    send_keys $'\x07'
    command sleep 0.15
fi
send_keys $'\x03'
wait_clean_prompt
assert_field "history search leaves a clean prompt" mode emoji "$REPLY"
print -- "ok - incremental history search works through the animation"

# Completion menus must also remain visible and usable during animation.
clear_screen
queue_gradient ecchi comp
comp_marker="$REPLY"
wait_visual "$comp_marker"
send_keys 'dots-test-command '
send_keys $'\t'
wait_visual alpha
vt_snapshot
comp_screen="$(vt_query screen)"
assert_contains "completion menu shows the first candidate" alpha "$comp_screen"
assert_contains "completion menu shows the second candidate" beta "$comp_screen"
assert_contains "completion menu shows the third candidate" gamma "$comp_screen"
assert_contains "completion menu shows the fourth candidate" delta "$comp_screen"
command sleep 0.4
vt_snapshot
comp_screen="$(vt_query screen)"
assert_contains "completion menu survives animation frames" alpha "$comp_screen"
assert_contains "completion menu keeps its candidates after animation" delta "$comp_screen"
send_keys $'\x03'
command sleep 0.05
send_keys $'\x03'
wait_clean_prompt
assert_field "completion cancellation leaves a clean prompt" mode emoji "$REPLY"
print -- "ok - completion remains usable while animation frames are redrawn"

# Infinite emoji mode loops independently of failure messages, then stops when
# the next command is accepted.
clear_screen
send_line '_dots_test_enable_infinite'
wait_raw INFINITE_ENABLED
command sleep 0.6
snap
infinite_line="$REPLY"
assert_field "infinite emoji mode keeps an active worker" active 1 "$infinite_line"
snap_value frames "$infinite_line"
infinite_frames="$REPLY"
[[ "$infinite_frames" == <-> ]] && (( infinite_frames > 12 )) ||
    fail "infinite animation did not loop beyond one 12-frame cycle (frames=$infinite_frames)"
print -- "ok - infinite emoji animation loops beyond one cycle"
send_line '_dots_test_disable_infinite'
wait_raw INFINITE_DISABLED
infinite_line=$(last_state_line 'INFINITE_DISABLED|')
assert_field "infinite mode stops when a command is submitted" active 0 "$infinite_line"
assert_int_field "infinite mode records its completed frame count" lastframes 13 "$infinite_line"
send_line '_dots_test_infinite_aliases'
wait_raw INFINITE_ALIASES_READY
alias_line=$(last_state_line 'INFINITE_ALIASES|')
assert_field "both historical infinite aliases remain accepted" ok 2 "$alias_line"
wait_clean_prompt

# The animation is terminal-native; reject a raster-image or external graphics
# rendering path even if a future change adds one without touching the tests.
if grep -qE '(^|[^[:alnum:]_])(magick|icat)([^[:alnum:]_]|$)' \
    "$ZSH_DIR/failure-animation.zsh"; then
    fail "the animation module references an external image renderer"
fi
print -- "ok - the animation module has no external image-rendering dependency"

# Final resource check.
snap
final_line="$REPLY"
assert_field "the shell ends with no active animation" active 0 "$final_line"
assert_field "the shell ends with no producer pipe" fd -1 "$final_line"
assert_field "the shell ends with no producer pid" pid 0 "$final_line"
assert_field "the shell ends with the ordinary prompt mode" mode emoji "$final_line"
assert_field "the shell ends with RPROMPT unchanged" rprompt BASE_RPROMPT "$final_line"
[[ "$RAW" != *$'\e_G'* ]] || fail "the animation used a Kitty graphics escape"
[[ "$RAW" != *'--place'* ]] || fail "the animation attempted Kitty image placement"
print -- "ok - no graphics placement or external image protocol was used"

print -- "All asynchronous prompt animation PTY tests passed."

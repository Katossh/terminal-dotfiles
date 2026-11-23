#!/usr/bin/env zsh
setopt errexit nounset

REPO_DIR="${0:A:h:h}"
ZSH_DIR="$REPO_DIR/config/terminal/zsh"
TEST_ROOT="$(mktemp -d)"

fail() {
    print -u2 -r -- "not ok - $*"
    exit 1
}

assert_unique_batch() {
    typeset style="$1"
    local -i count="$2"
    local label="$3"
    typeset frame=''
    local -A seen=()

    for (( index = 1; index <= count; index++ )); do
        frame="$(_dots_failure_animation_next_startup_frame "$style")"
        [[ -n "$frame" ]] || fail "$label returned an empty emoji"
        [[ -z "${seen[$frame]-}" ]] || fail "$label repeated $frame before the pool was exhausted"
        seen[$frame]=1
    done

    (( ${#seen} == count )) || fail "$label did not consume the complete pool"
    print -- "ok - $label"
}

trap 'command rm -rf "$TEST_ROOT"' EXIT

export XDG_STATE_HOME="$TEST_ROOT/state"

# Only the shell inside tmux renders a prompt; the replaced outer shell must
# not consume a hidden startup selection before it execs tmux.
typeset tmux_exec_line animation_source_line
tmux_exec_line="$(command grep -nF 'exec tmux' "$ZSH_DIR/.zshrc" | command cut -d: -f1)"
animation_source_line="$(command grep -nF 'source "$ZDOTDIR/failure-animation.zsh"' "$ZSH_DIR/.zshrc" | command cut -d: -f1)"
(( tmux_exec_line < animation_source_line )) || fail "startup animation is sourced before the tmux handoff"
print -- "ok - only the prompt-rendering tmux shell consumes a startup emoji"

source "$ZSH_DIR/failure-animation.zsh"

_dots_failure_animation_pool_for_style normal
typeset -a expected_pool=(
    '👀' '😳' '✨' '💀' '😂' '🤡' '🪿' '🔥' '💔' '🫠'
    '😭' '🥰' '🥺' '😏' '❤️' '🐽'
)
normal_count="${#_DOTS_FAILURE_ANIMATION_POOL}"
(( normal_count == 16 )) || fail "unified emoji pool contains $normal_count entries instead of 16"
[[ "${_DOTS_FAILURE_ANIMATION_POOL[*]}" == "${expected_pool[*]}" ]] ||
    fail "unified emoji pool contents or ordering changed unexpectedly"

# Every former style now exposes exactly the same combined pool.
typeset style='' frame=''
for style in normal sarcastic dramatic anime ecchi rainbow; do
    _dots_failure_animation_pool_for_style "$style"
    [[ "${_DOTS_FAILURE_ANIMATION_POOL[*]}" == "${expected_pool[*]}" ]] ||
        fail "$style does not use the unified emoji pool"
done

# Keep only the broken heart and ordinary red heart; reject every other variant.
for frame in '💖' '💗' '💓' '💕' '🩷' '💘' '🖤' '🤎' '💜' '🤍' '🧡' '💛' '💚' '💙'; do
    [[ " ${expected_pool[*]} " != *" $frame "* ]] ||
        fail "removed heart variant unexpectedly remains in the pool: $frame"
done
for frame in '💔' '❤️' '🐽'; do
    [[ " ${expected_pool[*]} " == *" $frame "* ]] ||
        fail "required emoji is missing from the unified pool: $frame"
done
print -- "ok - all styles use one 20-emoji pool with only two heart variants and a pig snout"

# Reservations across different styles consume one shared no-repeat cycle.
typeset -A shared_seen=()
typeset -a shared_styles=( normal anime ecchi rainbow sarcastic dramatic )
typeset -i index=0
for (( index = 1; index <= normal_count; index++ )); do
    style="${shared_styles[$(( (index - 1) % ${#shared_styles} + 1 ))]}"
    frame="$(_dots_failure_animation_next_startup_frame "$style")"
    [[ -n "$frame" ]] || fail "shared emoji pool returned an empty emoji"
    [[ -z "${shared_seen[$frame]-}" ]] || fail "shared pool repeated $frame before exhaustion"
    shared_seen[$frame]=1
done
(( ${#shared_seen} == normal_count )) || fail "mixed styles did not consume one complete shared pool"
[[ -f "$XDG_STATE_HOME/dots/failure-animation/all.state" ]] ||
    fail "unified reservations were not persisted to all.state"
print -- "ok - all prompt styles share one persistent no-repeat cycle"

# The next draw after exhaustion replenishes the pool, then that new cycle is
# also unique until every item has appeared.
assert_unique_batch normal "$normal_count" "unified pool starts a fresh unique cycle"

# Old releases kept one state file per style. The unified pool intentionally
# starts one clean shared cycle instead of mixing incompatible partial bags.
typeset legacy_home="$TEST_ROOT/legacy-state"
typeset legacy_normal_file="$legacy_home/dots/failure-animation/normal.state"
typeset legacy_anime_file="$legacy_home/dots/failure-animation/anime.state"
command mkdir -p "${legacy_normal_file:h}"
print -r -- 'legacy-normal-state' > "$legacy_normal_file"
print -r -- 'legacy-anime-state' > "$legacy_anime_file"
XDG_STATE_HOME="$legacy_home"
typeset -A legacy_seen=()
for style in normal anime ecchi; do
    frame="$(_dots_failure_animation_next_startup_frame "$style")"
    [[ -z "${legacy_seen[$frame]-}" ]] ||
        fail "legacy state migration repeated a unified-pool reservation: $frame"
    legacy_seen[$frame]=1
done
[[ -f "$legacy_home/dots/failure-animation/all.state" ]] ||
    fail "unified pool did not create its shared state file"
[[ "$(<"$legacy_normal_file")" == 'legacy-normal-state' ]] ||
    fail "unified pool modified a legacy style-specific state file"
[[ "$(<"$legacy_anime_file")" == 'legacy-anime-state' ]] ||
    fail "unified pool modified a legacy style-specific state file"
print -- "ok - old per-style bags are left untouched while the unified bag starts cleanly"

# The reserved final emoji and transient animation frames use separate pools.
typeset animation_home="$TEST_ROOT/animation-state"
typeset startup_frame stream_output stream_frame wrapped_frame state_before state_after
typeset -a stream_frames=()
typeset -i stream_count=0
XDG_STATE_HOME="$animation_home"
_DOTS_FAILURE_ANIMATION_INTERVAL=0.01
_dots_failure_animation_pool_for_style normal
normal_count="${#_DOTS_FAILURE_ANIMATION_POOL}"
startup_frame="$(_dots_failure_animation_next_startup_frame anime)"
[[ -n "$startup_frame" ]] || fail "synchronous reservation returned an empty final emoji"
state_before="$(<"$animation_home/dots/failure-animation/all.state")"

stream_output="$(_dots_failure_animation_stream ecchi 0 "$startup_frame" 12)"
stream_frames=( "${(@f)stream_output}" )
(( ${#stream_frames} == 12 )) || fail "animation emitted ${#stream_frames} frames instead of 12"
[[ "${stream_frames[-1]}" == "$startup_frame" ]] ||
    fail "animation did not settle on its reserved final emoji"

for (( index = 1; index < ${#stream_frames}; index++ )); do
    stream_frame="${stream_frames[index]}"
    [[ " ${_DOTS_FAILURE_ANIMATION_POOL[*]} " == *" $stream_frame "* ]] ||
        fail "animation emitted a glyph outside the complete style pool: $stream_frame"
    (( stream_count += 1 ))
    if (( index > 1 )); then
        [[ "$stream_frame" != "${stream_frames[index - 1]}" ]] ||
            fail "animation displayed the same glyph in adjacent frames"
    fi
done
(( stream_count == 11 )) || fail "animation did not emit eleven transient frames"
[[ "${stream_frames[-2]}" != "$startup_frame" ]] ||
    fail "penultimate animation frame repeated the reserved final emoji"
state_after="$(<"$animation_home/dots/failure-animation/all.state")"
[[ "$state_after" == "$state_before" ]] ||
    fail "transient animation frames modified the persistent no-repeat reservation bag"
print -- "ok - animation uses the full style pool and finishes on the reserved emoji without consuming reservations"

# Concurrent terminals reserve distinct final emojis. Their animations may
# display entries already reserved by other shells, but cannot change the bag.
typeset concurrent_home="$TEST_ROOT/concurrent-state"
typeset -a pids=()
typeset -A concurrent_seen=()
typeset -i concurrent_sessions=3 concurrent_count=0
for (( index = 1; index <= concurrent_sessions; index++ )); do
    case "$index" in
        1) style=normal ;;
        2) style=anime ;;
        *) style=rainbow ;;
    esac
    DOTS_TEST_STYLE="$style" \
        DOTS_TEST_ZSH_FILE="$ZSH_DIR/failure-animation.zsh" \
        XDG_STATE_HOME="$concurrent_home" \
        zsh -f -c '
            source "$DOTS_TEST_ZSH_FILE"
            _DOTS_FAILURE_ANIMATION_INTERVAL=0.01
            reserved="$(_dots_failure_animation_next_startup_frame "$DOTS_TEST_STYLE")" || exit
            animation="$(_dots_failure_animation_stream "$DOTS_TEST_STYLE" 0 "$reserved" 12)" || exit
            print -r -- "reserved:$reserved"
            print -r -- "$animation"
        ' > "$TEST_ROOT/concurrent.$index" &
    pids+=( "$!" )
done
for pid in "${pids[@]}"; do wait "$pid"; done

for (( index = 1; index <= concurrent_sessions; index++ )); do
    typeset -a concurrent_frames=()
    typeset concurrent_output
    concurrent_output="$(<"$TEST_ROOT/concurrent.$index")"
    concurrent_frames=( "${(@f)concurrent_output}" )
    [[ "${concurrent_frames[1]}" == reserved:* ]] ||
        fail "concurrent shell $index did not report its reserved final emoji"
    typeset reserved="${concurrent_frames[1]#reserved:}"
    [[ -n "$reserved" ]] || fail "concurrent shell $index reserved an empty emoji"
    [[ -z "${concurrent_seen[$reserved]-}" ]] ||
        fail "concurrent shells repeated final emoji $reserved before pool exhaustion"
    concurrent_seen[$reserved]=1
    (( ${#concurrent_frames} == 13 )) ||
        fail "concurrent shell $index emitted ${#concurrent_frames} animation updates instead of 12"
    [[ "${concurrent_frames[-1]}" == "$reserved" ]] ||
        fail "concurrent shell $index did not finish on its reserved final emoji"
    _dots_failure_animation_pool_for_style normal
    for (( frame_index = 2; frame_index < ${#concurrent_frames}; frame_index++ )); do
        frame="${concurrent_frames[frame_index]}"
        [[ " ${_DOTS_FAILURE_ANIMATION_POOL[*]} " == *" $frame "* ]] ||
            fail "concurrent animation emitted an out-of-pool emoji: $frame"
    done
done
(( ${#concurrent_seen} == concurrent_sessions )) ||
    fail "concurrent terminal final emojis were not globally unique"

# The three animation workers must not have consumed the ten remaining entries.
XDG_STATE_HOME="$concurrent_home"
for (( index = 1; index <= normal_count - concurrent_sessions; index++ )); do
    frame="$(_dots_failure_animation_next_startup_frame normal)"
    [[ -z "${concurrent_seen[$frame]-}" ]] ||
        fail "a later terminal received previously reserved final emoji $frame"
    concurrent_seen[$frame]=1
done
(( ${#concurrent_seen} == normal_count )) ||
    fail "animation workers consumed more than one reservation per shell"
wrapped_frame="$(_dots_failure_animation_next_startup_frame normal)"
[[ "$wrapped_frame" != "$frame" ]] ||
    fail "the next shuffled reservation cycle repeated its previous final emoji"
print -- "ok - concurrent shell reservations stay unique while animations remain independent"

# The prompt renderer displays the current animation glyph and restores the
# reserved final glyph when the stream completes.
command grep -Fq 'if [[ -o interactive && -t 0 && -t 1 ]]; then' "$ZSH_DIR/failure-animation.zsh" ||
    fail "startup emoji reservation is not restricted to interactive TTY shells"
command grep -Fq '_DOTS_FAILURE_ANIMATION_RESERVED_FRAME="$(_dots_failure_animation_next_startup_frame' "$ZSH_DIR/failure-animation.zsh" ||
    fail "interactive startup does not reserve its final emoji before prompt rendering"

typeset saved_state_home="$XDG_STATE_HOME"
XDG_STATE_HOME="$TEST_ROOT/prompt-render-state"
DOTS_FAILURE_ANIMATION_PROMPT_MARKER=MARK
_DOTS_FAILURE_ANIMATION_ORIGINAL_PROMPT='SYNC_PROMPTMARK'
frame="$(_dots_failure_animation_next_startup_frame normal)"
_DOTS_FAILURE_ANIMATION_FRAME="$frame"
typeset rendered_prompt
_DOTS_FAILURE_ANIMATION_FRAME="$frame"
rendered_prompt="$(_dots_failure_animation_render_prompt)"
[[ "$rendered_prompt" == "SYNC_PROMPT $frame MARK" ]] ||
    fail "prompt renderer did not display the current animation glyph (got: $rendered_prompt)"
_DOTS_FAILURE_ANIMATION_RESERVED_FRAME="$frame"
_DOTS_FAILURE_ANIMATION_FRAME='temporary'
_DOTS_FAILURE_ANIMATION_FRAME="$_DOTS_FAILURE_ANIMATION_RESERVED_FRAME"
[[ "$_DOTS_FAILURE_ANIMATION_FRAME" == "$frame" ]] ||
    fail "animation cleanup did not restore the reserved final emoji"
XDG_STATE_HOME="$saved_state_home"
print -- "ok - prompt renderer animates the reserved emoji without replacing it"
print -- "All startup emoji state tests passed."

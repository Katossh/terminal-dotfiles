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
normal_count="${#_DOTS_FAILURE_ANIMATION_POOL}"

# Normal, sarcastic, and dramatic all draw from the same reaction pool.
typeset -A shared_seen=()
typeset frame=''
typeset style=''
typeset -i index=0
for (( index = 1; index <= normal_count; index++ )); do
    case $(( (index - 1) % 3 )) in
        0) style=normal ;;
        1) style=sarcastic ;;
        2) style=dramatic ;;
    esac
    frame="$(_dots_failure_animation_next_startup_frame "$style")"
    [[ -n "$frame" ]] || fail "shared reaction pool returned an empty emoji"
    [[ -z "${shared_seen[$frame]-}" ]] || fail "shared reaction pool repeated $frame"
    shared_seen[$frame]=1
done
(( ${#shared_seen} == normal_count )) || fail "shared reaction styles did not consume one complete pool"
print -- "ok - normal, sarcastic, and dramatic share a no-repeat cycle"

# The next draw after exhaustion replenishes the pool, then that new cycle is
# also unique until every item has appeared.
assert_unique_batch normal "$normal_count" "normal pool starts a fresh unique cycle"

_dots_failure_animation_pool_for_style anime
assert_unique_batch anime "${#_DOTS_FAILURE_ANIMATION_POOL}" "anime pool has an independent cycle"

_dots_failure_animation_pool_for_style ecchi
assert_unique_batch ecchi "${#_DOTS_FAILURE_ANIMATION_POOL}" "ecchi pool has an independent cycle"

_dots_failure_animation_pool_for_style rainbow
assert_unique_batch rainbow "${#_DOTS_FAILURE_ANIMATION_POOL}" "rainbow pool has an independent cycle"

# Upgrade the v1 state written by the previous implementation without
# throwing away its unconsumed shuffled entries.
typeset legacy_home="$TEST_ROOT/legacy-state"
typeset legacy_signature='v1:normal'
typeset legacy_state_file="$legacy_home/dots/failure-animation/normal.state"
typeset legacy_frame legacy_last_frame legacy_migrated_signature
typeset -a legacy_expected=()
typeset -A legacy_seen=()
_dots_failure_animation_pool_for_style normal
for emoji in "${_DOTS_FAILURE_ANIMATION_POOL[@]}"; do
    legacy_signature+="|$emoji"
done
legacy_expected=( "${_DOTS_FAILURE_ANIMATION_POOL[2]}" "${_DOTS_FAILURE_ANIMATION_POOL[4]}" "${_DOTS_FAILURE_ANIMATION_POOL[6]}" )
command mkdir -p "${legacy_state_file:h}"
print -r -- "$legacy_signature" > "$legacy_state_file"
print -r -- "2 4 6" >> "$legacy_state_file"
XDG_STATE_HOME="$legacy_home"

for (( index = 1; index <= 3; index++ )); do
    legacy_frame="$(_dots_failure_animation_next_startup_frame normal)"
    [[ " ${legacy_expected[*]} " == *" $legacy_frame "* ]] ||
        fail "v1 migration discarded unconsumed pool item ordering (selected $legacy_frame)"
    [[ -z "${legacy_seen[$legacy_frame]-}" ]] ||
        fail "v1 migration repeated $legacy_frame before exhausting its remaining bag"
    legacy_seen[$legacy_frame]=1
    legacy_last_frame="$legacy_frame"
done
(( ${#legacy_seen} == 3 )) || fail "v1 state migration did not preserve all three remaining entries"
IFS= read -r legacy_migrated_signature < "$legacy_state_file"
[[ "$legacy_migrated_signature" == v2:* ]] || fail "legacy state was not upgraded to v2"
legacy_frame="$(_dots_failure_animation_next_startup_frame normal)"
[[ "$legacy_frame" != "$legacy_last_frame" ]] ||
    fail "the new cycle repeated the migrated pool's final emoji"
print -- "ok - v1 pool state migrates without resetting the remaining bag"

# One shell consumes one emoji. The badge animation must not consume any more.
(( ${+functions[_dots_failure_animation_stream]} == 1 )) || fail "prompt emoji animation stream is missing"
typeset animation_home="$TEST_ROOT/animation-state" startup_frame stream_output stream_frame wrapped_frame
typeset -a stream_frames=()
typeset -A visible_cycle=() phase_seen=()
typeset -i stream_count=0
XDG_STATE_HOME="$animation_home"
_DOTS_FAILURE_ANIMATION_INTERVAL=0.01
startup_frame="$(_dots_failure_animation_next_startup_frame normal)"
[[ -n "$startup_frame" ]] || fail "synchronous startup selection returned an empty emoji"
visible_cycle[$startup_frame]=1
stream_output="$(_dots_failure_animation_stream normal 0 "$startup_frame" 12)"
stream_frames=( "${(@f)stream_output}" )
(( ${#stream_frames} == 12 )) || fail "startup animation emitted ${#stream_frames} phases instead of 12"
for stream_frame in "${stream_frames[@]}"; do
    [[ "$stream_frame" == <-> ]] || fail "animation emitted a non-numeric badge phase: $stream_frame"
    [[ -z "${phase_seen[$stream_frame]-}" ]] || fail "animation repeated badge phase $stream_frame"
    phase_seen[$stream_frame]=1
    (( stream_count += 1 ))
done
(( stream_count == 12 && ${#phase_seen} == 12 )) || fail "badge animation did not emit 12 distinct phases"
for (( index = 1; index < normal_count; index++ )); do
    frame="$(_dots_failure_animation_next_startup_frame normal)"
    [[ -z "${visible_cycle[$frame]-}" ]] || fail "pool repeated $frame before all entries were drawn"
    visible_cycle[$frame]=1
done
(( ${#visible_cycle} == normal_count )) || fail "animation consumed or skipped shared pool entries"
wrapped_frame="$(_dots_failure_animation_next_startup_frame normal)"
[[ "$wrapped_frame" != "$frame" ]] || fail "new cycle repeated the previous cycle's final emoji"
print -- "ok - the prompt badge animates without consuming additional emoji reservations"

# Three simultaneously launched shells reserve one emoji each; their 36
# animation frames must not consume the other ten entries in the shared pool.
typeset concurrent_home="$TEST_ROOT/concurrent-state"
typeset -a pids=()
typeset -A concurrent_seen=()
typeset -i concurrent_sessions=3 frames_per_session=12 concurrent_count=0 phase_count=0
for (( index = 1; index <= concurrent_sessions; index++ )); do
    DOTS_TEST_ZSH_FILE="$ZSH_DIR/failure-animation.zsh" \
        XDG_STATE_HOME="$concurrent_home" \
        zsh -f -c '
            source "$DOTS_TEST_ZSH_FILE"
            _DOTS_FAILURE_ANIMATION_INTERVAL=0.01
            startup="$(_dots_failure_animation_next_startup_frame normal)" || exit
            animation="$(_dots_failure_animation_stream normal 0 "$startup" 12)" || exit
            print -r -- "emoji:$startup"
            print -r -- "$animation"
        ' > "$TEST_ROOT/concurrent.$index" &
    pids+=( "$!" )
done
for pid in "${pids[@]}"; do wait "$pid"; done
for (( index = 1; index <= concurrent_sessions; index++ )); do
    while IFS= read -r frame; do
        if [[ "$frame" == emoji:* ]]; then
            frame="${frame#emoji:}"
            [[ -n "$frame" ]] || fail "concurrent shell reserved an empty emoji"
            [[ -z "${concurrent_seen[$frame]-}" ]] || fail "concurrent shells repeated reserved emoji $frame"
            concurrent_seen[$frame]=1
            (( concurrent_count += 1 ))
        else
            [[ "$frame" == <-> ]] || fail "concurrent animation emitted invalid phase: $frame"
            (( phase_count += 1 ))
        fi
    done < "$TEST_ROOT/concurrent.$index"
done
(( concurrent_count == concurrent_sessions && ${#concurrent_seen} == concurrent_sessions )) || fail "shell reservations were not globally unique"
(( phase_count == concurrent_sessions * frames_per_session )) || fail "animation workers did not complete their badge sequences"

XDG_STATE_HOME="$concurrent_home"
for (( index = 1; index <= normal_count - concurrent_sessions; index++ )); do
    frame="$(_dots_failure_animation_next_startup_frame normal)"
    [[ -z "${concurrent_seen[$frame]-}" ]] || fail "animation workers consumed a future shell reservation ($frame)"
    concurrent_seen[$frame]=1
done
(( ${#concurrent_seen} == normal_count )) || fail "animation workers consumed more than one pool entry per shell"
wrapped_frame="$(_dots_failure_animation_next_startup_frame normal)"
[[ "$wrapped_frame" != "$frame" ]] || fail "concurrent cycle repeated its previous final emoji"
print -- "ok - concurrent animated shells reserve one unique emoji apiece"

# The prompt renderer keeps the synchronously reserved glyph unchanged
# while the animation phase changes only its decorative badge.
command grep -Fq 'if [[ -o interactive && -t 0 && -t 1 ]]; then' "$ZSH_DIR/failure-animation.zsh" ||
    fail "startup emoji reservation is not restricted to interactive TTY shells"
command grep -Fq '_DOTS_FAILURE_ANIMATION_FRAME="$(_dots_failure_animation_next_startup_frame' "$ZSH_DIR/failure-animation.zsh" ||
    fail "interactive startup does not reserve an emoji before prompt rendering"

typeset saved_state_home="$XDG_STATE_HOME"
XDG_STATE_HOME="$TEST_ROOT/prompt-render-state"
DOTS_FAILURE_ANIMATION_PROMPT_MARKER=MARK
_DOTS_FAILURE_ANIMATION_ORIGINAL_PROMPT='SYNC_PROMPTMARK'
frame="$(_dots_failure_animation_next_startup_frame normal)"
_DOTS_FAILURE_ANIMATION_FRAME="$frame"
typeset rendered_prompt
_DOTS_FAILURE_ANIMATION_ACTIVE=1
_DOTS_FAILURE_ANIMATION_EMOJI_PHASE=4
rendered_prompt="$(_dots_failure_animation_render_prompt)"
[[ "$rendered_prompt" == *"$frame"* && "$rendered_prompt" == *
XDG_STATE_HOME="$saved_state_home"
print -- "ok - prompt renderer animates the reserved emoji without replacing it"
print -- "All startup emoji state tests passed."
\e[48;2;'* ]] ||
    fail "prompt renderer did not preserve the reserved emoji inside its animated badge (got: $rendered_prompt)"
XDG_STATE_HOME="$saved_state_home"
print -- "ok - prompt renderer animates the reserved emoji without replacing it"
print -- "All startup emoji state tests passed."

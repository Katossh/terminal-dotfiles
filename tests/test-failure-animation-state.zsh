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

# Confirm the chosen persistent startup emoji is actually the first frame shown
# by the regular animation stream, without changing the remaining frame logic.
typeset startup_frame stream_output
typeset -a stream_frames=()
startup_frame="$(_dots_failure_animation_next_startup_frame rainbow)"
_DOTS_FAILURE_ANIMATION_INTERVAL=0.01
stream_output="$(_dots_failure_animation_stream rainbow 0 "$startup_frame")"
stream_frames=( "${(@f)stream_output}" )
[[ "${stream_frames[1]}" == "$startup_frame" ]] || fail "the selected startup emoji was not the first animation frame"
print -- "ok - persistent selection is used as the animation's first frame"

# Start every draw in a separate Zsh process at once. The atomic lock must
# serialize them so concurrent terminals still receive one complete unique bag.
typeset concurrent_home="$TEST_ROOT/concurrent-state"
typeset -a pids=()
typeset -A concurrent_seen=()
for (( index = 1; index <= normal_count; index++ )); do
    DOTS_TEST_ZSH_FILE="$ZSH_DIR/failure-animation.zsh" \
        XDG_STATE_HOME="$concurrent_home" \
        zsh -f -c 'source "$DOTS_TEST_ZSH_FILE"; _dots_failure_animation_next_startup_frame normal' \
        > "$TEST_ROOT/concurrent.$index" &
    pids+=( "$!" )
done
for pid in "${pids[@]}"; do
    wait "$pid"
done
for (( index = 1; index <= normal_count; index++ )); do
    IFS= read -r frame < "$TEST_ROOT/concurrent.$index"
    [[ -n "$frame" ]] || fail "concurrent terminal $index returned an empty emoji"
    [[ -z "${concurrent_seen[$frame]-}" ]] || fail "concurrent terminals repeated $frame"
    concurrent_seen[$frame]=1
done
(( ${#concurrent_seen} == normal_count )) || fail "concurrent terminals did not consume one complete unique pool"
print -- "ok - concurrent terminal starts are serialized without repeats"

print -- "All startup emoji state tests passed."

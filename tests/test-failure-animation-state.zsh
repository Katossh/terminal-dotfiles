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

# Confirm the chosen persistent startup emoji is actually the first frame shown
# by the regular animation stream, without changing the remaining frame logic.
typeset startup_frame stream_output
typeset -a stream_frames=()
startup_frame="$(_dots_failure_animation_next_startup_frame rainbow)"
_DOTS_FAILURE_ANIMATION_INTERVAL=0.01
stream_output="$(_dots_failure_animation_stream rainbow 0 "$startup_frame")"
stream_frames=( "${(@f)stream_output}" )
[[ "${stream_frames[-1]}" == "$startup_frame" ]] || fail "the animation did not settle on the preselected startup emoji"
print -- "ok - animation settles on the emoji selected before it starts"

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



# Start interactive shells first, then load the module into each live PTY.
# Loading the module synchronously reserves the emoji before the next prompt;
# disabling animation makes the first visible value directly testable.
zmodload zsh/zpty 2>/dev/null || {
    print -- "skip - zsh/zpty is unavailable for startup prompt integration"
    print -- "All startup emoji state tests passed."
    exit 0
}

typeset pty_state="$TEST_ROOT/pty-state"
typeset -a pty_names=()
typeset -A pty_seen=()

for (( index = 1; index <= normal_count; index++ )); do
    typeset pty_name="dots_startup_emoji_${index}"
    pty_names+=( "$pty_name" )
    zpty -b "$pty_name" env TERM=xterm-256color COLUMNS=120 LINES=30 XDG_STATE_HOME="$pty_state" DOTS_FAILURE_ANIMATION=0 zsh -f -i
done

for pty_name in "${pty_names[@]}"; do
    zpty -w "$pty_name" "PROMPT='SYNC_PROMPT ❯ '; source '$ZSH_DIR/failure-animation.zsh'"
done

for pty_name in "${pty_names[@]}"; do
    typeset output='' data='' visible='' frame=''
    typeset -i tries=0
    while (( tries < 120 )); do
        if zpty -r -t "$pty_name" data; then
            output+="$data"
        fi
        [[ "$output" == *"SYNC_PROMPT"* ]] && break
        command sleep 0.02
        (( tries += 1 ))
    done

    visible="$(print -rn -- "$output" | command python3 -c 'import re, sys; sys.stdout.write(re.sub(r"(?:\\x1b|\\^\\[)\\[[0-9;?]*[ -/]*[@-~]", "", sys.stdin.read()))')"
    frame="$(print -rn -- "$visible" | command python3 -c 'import re, sys; m=re.search(r"SYNC_PROMPT (\\S+) ❯", sys.stdin.read()); print(m.group(1) if m else "")')"
    [[ -n "$frame" ]] || fail "$pty_name did not render a synchronously selected startup emoji (output: $visible)"
    [[ -z "${pty_seen[$frame]-}" ]] || fail "first visible prompts repeated $frame across concurrent terminals"
    pty_seen[$frame]=1
    print -- "ok - $pty_name rendered $frame before any animation started"
    zpty -d "$pty_name" 2>/dev/null || true
done

(( ${#pty_seen} == normal_count )) || fail "concurrent interactive prompts did not receive unique startup emojis"


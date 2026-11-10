#!/usr/bin/env zsh
setopt errexit nounset

REPO_DIR="${0:A:h:h}"
ZSH_DIR="$REPO_DIR/config/terminal/zsh"

fail() {
    print -u2 -r -- "not ok - $*"
    exit 1
}

assert_contains() {
    local label="$1"
    local needle="$2"
    local haystack="$3"
    [[ "$haystack" == *"$needle"* ]] || fail "$label (missing '$needle')"
    print -- "ok - $label"
}

# Exercise the real ZLE event loop in a pseudo-terminal: the animation should
# update the right prompt, accept a command while frames are still arriving,
# and restore the user's original RPROMPT when the line is submitted.
zmodload zsh/zpty 2>/dev/null || {
    print -- "skip - zsh/zpty is unavailable"
    exit 0
}

typeset pty_name="dots_failure_animation_test"
zpty -b "$pty_name" env TERM=xterm-256color zsh -f -i
trap 'zpty -d "$pty_name" 2>/dev/null || true' EXIT

command sleep 0.2
typeset init_command="source ${(q)ZSH_DIR}/failure-animation.zsh; RPROMPT='BASE_RPROMPT'; _DOTS_FAILURE_ANIMATION_PENDING=1; print -r -- ANIMATION_ARMED"
zpty -w "$pty_name" "$init_command"

typeset captured='' chunk=''
typeset -i attempt=0
while (( attempt < 20 )); do
    if zpty -r -t "$pty_name" chunk; then
        captured+="$chunk"
    fi
    if [[ "$captured" == *ANIMATION_ARMED* &&
          ( "$captured" == *"✦"* || "$captured" == *"🌙"* || "$captured" == *"♡"* ) ]]; then
        break
    fi
    command sleep 0.05
    (( attempt += 1 ))
done

assert_contains "interactive child shell loaded animation module" "ANIMATION_ARMED" "$captured"
if [[ "$captured" != *"✦"* && "$captured" != *"🌙"* && "$captured" != *"♡"* ]]; then
    fail "ZLE did not render an animation frame in the active input prompt"
fi
print -- "ok - animation frame rendered while ZLE was active"

# This input is sent before the 24-frame animation (about 3.36 seconds) ends.
zpty -w "$pty_name" 'print -r -- "DOTS_INPUT_ACCEPTED:$RPROMPT"'

captured=''
attempt=0
while (( attempt < 30 )); do
    if zpty -r -t "$pty_name" chunk; then
        captured+="$chunk"
    fi
    [[ "$captured" == *"DOTS_INPUT_ACCEPTED:BASE_RPROMPT"* ]] && break
    command sleep 0.05
    (( attempt += 1 ))
done

assert_contains "keyboard input is accepted during the animation" "DOTS_INPUT_ACCEPTED" "$captured"
assert_contains "original right prompt is restored after Enter" "BASE_RPROMPT" "$captured"

print -- "All non-blocking failure-animation tests passed."

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

# Exercise the real ZLE event loop in a pseudo-terminal. Wait for the child
# shell's first prompt before sending input; otherwise zpty can race startup.
zmodload zsh/zpty 2>/dev/null || {
    print -- "skip - zsh/zpty is unavailable"
    exit 0
}

typeset pty_name="dots_failure_animation_test"
zpty -b "$pty_name" env TERM=xterm-256color COLUMNS=120 LINES=30 zsh -f -i
trap 'zpty -d "$pty_name" 2>/dev/null || true' EXIT

typeset captured='' chunk=''
typeset -i attempt=0
while (( attempt < 40 )); do
    if zpty -r -t "$pty_name" chunk; then
        captured+="$chunk"
    fi
    [[ "$captured" == *"%"* ]] && break
    command sleep 0.05
    (( attempt += 1 ))
done
assert_contains "interactive child shell reached its first prompt" "%" "$captured"

# Load the module in its own short command so the terminal cannot truncate
# the command before the interactive shell has started accepting input.
zpty -w "$pty_name" "source ${(q)ZSH_DIR}/failure-animation.zsh"$'\n'
command sleep 0.1
zpty -w "$pty_name" "RPROMPT='BASE_RPROMPT'; _DOTS_FAILURE_ANIMATION_PENDING=1; print -r -- ANIMATION_ARMED"$'\n'

captured=''
attempt=0
while (( attempt < 60 )); do
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

assert_contains "animation setup command ran" "ANIMATION_ARMED" "$captured"
if [[ "$captured" != *"✦"* && "$captured" != *"🌙"* && "$captured" != *"♡"* ]]; then
    print -u2 -r -- "Captured terminal output: ${(qqq)captured}"
    fail "ZLE did not render an animation frame in the active input prompt"
fi
print -- "ok - animation frame rendered while ZLE was active"

# Submit a command while the remaining frames are still being produced.
zpty -w "$pty_name" 'print -r -- "DOTS_INPUT_ACCEPTED:$RPROMPT"'$'\n'

captured=''
attempt=0
while (( attempt < 60 )); do
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

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

zmodload zsh/zpty 2>/dev/null || {
    print -- "skip - zsh/zpty is unavailable"
    exit 0
}

typeset pty_name="dots_failure_animation_test"
zpty -b "$pty_name" env TERM=xterm-256color COLUMNS=120 LINES=30 zsh -f -i
trap 'zpty -d "$pty_name" 2>/dev/null || true' EXIT

# Wait for the first prompt before typing into the pseudo-terminal.
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

zpty -w "$pty_name" "source ${(q)ZSH_DIR}/failure-animation.zsh"$'\n'
command sleep 0.1
zpty -w "$pty_name" "RPROMPT='BASE_RPROMPT'; _DOTS_FAILURE_ANIMATION_PENDING=1; print -r -- ANIMATION_ARMED"$'\n'

captured=''
attempt=0
while (( attempt < 40 )); do
    if zpty -r -t "$pty_name" chunk; then
        captured+="$chunk"
    fi
    [[ "$captured" == *ANIMATION_ARMED* ]] && break
    command sleep 0.05
    (( attempt += 1 ))
done
assert_contains "animation setup command ran" "ANIMATION_ARMED" "$captured"

# Send a short command well before the 24-frame stream (about 3.3 seconds)
# finishes. Short lines avoid overflowing zpty's PTY write buffer.
command sleep 0.45
zpty -w "$pty_name" 'print -r -- "FRAMES=$_DOTS_FAILURE_ANIMATION_FRAMES"'$'\n'

captured=''
attempt=0
while (( attempt < 60 )); do
    if zpty -r -t "$pty_name" chunk; then
        captured+="$chunk"
    fi
    [[ "$captured" == *FRAMES=* ]] && break
    command sleep 0.05
    (( attempt += 1 ))
done

assert_contains "keyboard input is accepted during the animation" "FRAMES=" "$captured"
if [[ "$captured" == *"FRAMES=0"* ]]; then
    print -u2 -r -- "Animation test capture: ${(qqq)captured}"
    fail "no animation frame was handled before input was submitted"
fi
print -- "ok - asynchronous frame callback ran before input was submitted"

# Check that the original right prompt was restored by the line-finish hook.
zpty -w "$pty_name" 'print -r -- "RPROMPT=$RPROMPT"'$'\n'
command sleep 0.05
captured=''
attempt=0
while (( attempt < 30 )); do
    if zpty -r -t "$pty_name" chunk; then
        captured+="$chunk"
    fi
    [[ "$captured" == *"RPROMPT=BASE_RPROMPT"* ]] && break
    command sleep 0.05
    (( attempt += 1 ))
done
assert_contains "original right prompt is restored after Enter" "RPROMPT=BASE_RPROMPT" "$captured"

print -- "All non-blocking failure-animation tests passed."

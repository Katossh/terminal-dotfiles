#!/usr/bin/env zsh
setopt errexit nounset

REPO_DIR="${0:A:h:h}"
ZSH_DIR="$REPO_DIR/config/terminal/zsh"

fail() { print -u2 -r -- "not ok - $*"; exit 1; }
assert_contains() {
    local label="$1" needle="$2" haystack="$3"
    [[ "$haystack" == *"$needle"* ]] || fail "$label (missing '$needle')"
    print -- "ok - $label"
}

zmodload zsh/zpty 2>/dev/null || {
    print -- "skip - zsh/zpty is unavailable"
    exit 0
}

typeset pty_name="dots_failure_animation_test"
zpty -b "$pty_name" env TERM=xterm-256color COLUMNS=120 LINES=30 \
    "DOTS_FAILURE_MESSAGE_CHANCE=100" "DOTS_FAILURE_ANIMATION_CHANCE=100" \
    "DOTS_FAILURE_STYLE=normal" "DOTS_FAILURE_MESSAGE_ESCALATION=0" \
    "ZSH_DIR=$ZSH_DIR" zsh -f -i
trap 'zpty -d "$pty_name" 2>/dev/null || true' EXIT

read_until() {
    local needle="$1"
    local -i attempts=0
    local output='' chunk=''
    while (( attempts < 80 )); do
        if zpty -r -t "$pty_name" chunk; then
            output+="$chunk"
        fi
        [[ "$output" == *"$needle"* ]] && break
        command sleep 0.05
        (( attempts += 1 ))
    done
    REPLY="$output"
}

command sleep 0.2
zpty -w "$pty_name" 'print -r -- SHELL_READY'$'\n'
read_until SHELL_READY
assert_contains "interactive child shell reached its first prompt" "SHELL_READY" "$REPLY"

zpty -w "$pty_name" 'source "$ZSH_DIR/failure-messages.zsh"; print -r -- MESSAGES_READY'$'\n'
read_until MESSAGES_READY
assert_contains "message renderer loaded" "MESSAGES_READY" "$REPLY"

zpty -w "$pty_name" 'source "$ZSH_DIR/failure-animation.zsh"; print -r -- ANIMATION_READY'$'\n'
read_until ANIMATION_READY
assert_contains "animation module loaded" "ANIMATION_READY" "$REPLY"

zpty -w "$pty_name" "RPROMPT='BASE_RPROMPT'; print -r -- PROMPT_READY"$'\n'
read_until PROMPT_READY
assert_contains "base right prompt configured" "PROMPT_READY" "$REPLY"

# Queue animation through the public renderer, not by mutating its internal flag.
zpty -w "$pty_name" 'dots_failure_message generic animation-integration-test'$'\n'
read_until animation-integration-test
assert_contains "public failure-message function ran" "animation-integration-test" "$REPLY"

# Let the asynchronous watcher render several frames, then submit a command.
command sleep 0.45
zpty -w "$pty_name" 'printf "%s%s%s\n" FRAME COUNT_ "$_DOTS_FAILURE_ANIMATION_FRAMES"'

print -- "All non-blocking failure-animation integration tests passed."
\n'
read_until FRAMECOUNT_
assert_contains "keyboard input is accepted during animation" "FRAMECOUNT_" "$REPLY"
[[ "$REPLY" =~ "FRAMECOUNT_[1-9][0-9]*" ]] || fail "no animation frame callback ran before input"

zpty -w "$pty_name" 'printf "%s%s%s\n" RP ROMPT_ "$RPROMPT"'

print -- "All non-blocking failure-animation integration tests passed."
\n'
read_until RPROMPT_BASE_RPROMPT
assert_contains "original right prompt is restored after Enter" "RPROMPT_BASE_RPROMPT" "$REPLY"

print -- "All non-blocking failure-animation integration tests passed."

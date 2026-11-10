#!/usr/bin/env zsh
setopt errexit nounset

REPO_DIR="${0:A:h:h}"
ZSH_DIR="$REPO_DIR/config/terminal/zsh"

fail() { print -u2 -r -- "not ok - $*"; exit 1; }
assert_contains() {
    local label="$1" needle="$2" haystack="$3"
    [[ "$haystack" == *"$needle"* ]] || fail "$label (missing: $needle)"
    print -- "ok - $label"
}

zmodload zsh/zpty 2>/dev/null || {
    print -- "skip - zsh/zpty is unavailable"
    exit 0
}

typeset pty_name="dots_failure_animation_test"
zpty -b "$pty_name" env TERM=xterm-256color COLUMNS=120 LINES=30 \
    DOTS_FAILURE_MESSAGE_CHANCE=100 DOTS_FAILURE_ANIMATION_CHANCE=100 \
    DOTS_FAILURE_STYLE=normal DOTS_FAILURE_MESSAGE_ESCALATION=0 DOTS_FAILURE_ANIMATION=1 \
    "ZSH_DIR=$ZSH_DIR" zsh -f -i
trap 'zpty -d "$pty_name" 2>/dev/null || true' EXIT

# Wait until either the ordinary-user (%) or root (#) prompt appears.
typeset captured='' chunk=''
typeset -i attempt=0
while (( attempt < 40 )); do
    if zpty -r -t "$pty_name" chunk; then captured+="$chunk"; fi
    [[ "$captured" == *"%"* || "$captured" == *"#"* ]] && break
    command sleep 0.05
    (( attempt += 1 ))
done
if [[ "$captured" != *"%"* && "$captured" != *"#"* ]]; then fail "interactive child shell did not reach its prompt"; fi
print -- "ok - interactive child shell reached its prompt"

read_until() {
    local needle="$1"
    local -i tries=0
    local output='' data=''
    while (( tries < 80 )); do
        if zpty -r -t "$pty_name" data; then output+="$data"; fi
        [[ "$output" == *"$needle"* ]] && break
        command sleep 0.05
        (( tries += 1 ))
    done
    REPLY="$output"
}

# Source the real modules in the PTY shell.
zpty -w "$pty_name" 'source "$ZSH_DIR/failure-messages.zsh"; printf "%s%s\n" MESSAGE RENDERER_READY'$'\n'
read_until MESSAGERENDERER_READY
assert_contains "message renderer loaded" MESSAGERENDERER_READY "$REPLY"

zpty -w "$pty_name" 'source "$ZSH_DIR/failure-animation.zsh"; printf "%s%s\n" ANIMATION MODULE_READY'$'\n'
read_until ANIMATIONMODULE_READY
assert_contains "animation module loaded" ANIMATIONMODULE_READY "$REPLY"

zpty -w "$pty_name" 'RPROMPT="BASE_RPROMPT"; printf "%s%s\n" PROMPT BASE_READY'$'\n'
read_until PROMPTBASE_READY
assert_contains "base right prompt configured" PROMPTBASE_READY "$REPLY"

# Invoke the public renderer and wait for its completion marker. Its output is
# deliberately not the marker, so PTY command echo cannot satisfy the check.
zpty -w "$pty_name" 'dots_failure_message generic animation-integration-test; printf "%s%s\n" FAILURE CALL_FINISHED'$'\n'
read_until FAILURECALL_FINISHED
assert_contains "public failure-message function ran" FAILURECALL_FINISHED "$REPLY"

# Give the ZLE file-descriptor watcher time to deliver frames, then type while
# the animation is active. The split printf arguments avoid echo false-positives.
command sleep 0.45
zpty -w "$pty_name" 'printf "%s%s%s%s%s\n" FRAME COUNT_ "$_DOTS_FAILURE_ANIMATION_FRAMES" STATE_ "$_DOTS_FAILURE_ANIMATION_STATE"'
read_until FRAMECOUNT_
assert_contains "keyboard input was accepted during animation" FRAMECOUNT_ "$REPLY"
[[ "$REPLY" == *FRAMECOUNT_[1-9]* ]] || fail "no animation frame callback ran before Enter"

# Check prompt restoration after line-finish. The expected marker is assembled
# from separate printf arguments so it cannot be matched in the echoed command.
zpty -w "$pty_name" 'printf "%s%s%s\n" RP ROMPT_ "$RPROMPT"'$'\n'
read_until RPROMPT_BASE_RPROMPT
assert_contains "original right prompt restored after Enter" RPROMPT_BASE_RPROMPT "$REPLY"

print -- "All non-blocking failure-animation integration tests passed."
\n'
read_until FRAMECOUNT_
assert_contains "keyboard input was accepted during animation" FRAMECOUNT_ "$REPLY"
[[ "$REPLY" == *FRAMECOUNT_[1-9]* ]] || fail "no animation frame callback ran before Enter"

# Check prompt restoration after line-finish. The expected marker is assembled
# from separate printf arguments so it cannot be matched in the echoed command.
zpty -w "$pty_name" 'printf "%s%s%s\n" RP ROMPT_ "$RPROMPT"'$'\n'
read_until RPROMPT_BASE_RPROMPT
assert_contains "original right prompt restored after Enter" RPROMPT_BASE_RPROMPT "$REPLY"

print -- "All non-blocking failure-animation integration tests passed."

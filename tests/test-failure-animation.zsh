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
typeset result_file="$(mktemp "${TMPDIR:-/tmp}/dots-failure-animation.XXXXXX")" || fail "could not create result file"
command rm -f "$result_file"
zpty -b "$pty_name" env TERM=xterm-256color COLUMNS=120 LINES=30 \
    DOTS_FAILURE_MESSAGE_CHANCE=100 DOTS_FAILURE_ANIMATION_CHANCE=100 \
    DOTS_FAILURE_STYLE=normal DOTS_FAILURE_MESSAGE_ESCALATION=0 DOTS_FAILURE_ANIMATION=1 \
    "ZSH_DIR=$ZSH_DIR" "RESULT_FILE=$result_file" zsh -f -i
trap 'zpty -d "$pty_name" 2>/dev/null || true; command rm -f "$result_file"' EXIT

# Wait for either ordinary-user (%) or root (#) prompt.
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

# Load the real message and animation modules.
zpty -w "$pty_name" 'source "$ZSH_DIR/failure-messages.zsh"; printf "%s%s\n" MESSAGE RENDERER_READY'$'\n'
read_until MESSAGERENDERER_READY
assert_contains "message renderer loaded" MESSAGERENDERER_READY "$REPLY"

zpty -w "$pty_name" 'source "$ZSH_DIR/failure-animation.zsh"; printf "%s%s\n" ANIMATION MODULE_READY'$'\n'
read_until ANIMATIONMODULE_READY
assert_contains "animation module loaded" ANIMATIONMODULE_READY "$REPLY"

zpty -w "$pty_name" 'RPROMPT="BASE_RPROMPT"; printf "%s%s\n" PROMPT BASE_READY'$'\n'
read_until PROMPTBASE_READY
assert_contains "base right prompt configured" PROMPTBASE_READY "$REPLY"

# Simulate the real failure notification lifecycle: the public renderer is
# called by precmd after a completed command and before the next ZLE session.
zpty -w "$pty_name" 'typeset -gi DOTS_TEST_TRIGGER_FAILURE=0; _dots_test_queue_failure_precmd() { (( DOTS_TEST_TRIGGER_FAILURE )) || return 0; DOTS_TEST_TRIGGER_FAILURE=0; dots_failure_message generic animation-integration-test; printf "%s%s%s%s%s%s%s%s\n" FAILURE CALL_FINISHED PENDING_ "$_DOTS_FAILURE_ANIMATION_PENDING" ACTIVE_ "$_DOTS_FAILURE_ANIMATION_ACTIVE" STATE_ "$_DOTS_FAILURE_ANIMATION_STATE"; }; typeset -ga precmd_functions; precmd_functions+=(_dots_test_queue_failure_precmd); printf "%s%s\n" PRECMD HOOK_READY'$'\n'
read_until PRECMDHOOK_READY
assert_contains "failure precmd hook was installed" PRECMDHOOK_READY "$REPLY"

zpty -w "$pty_name" 'DOTS_TEST_TRIGGER_FAILURE=1; printf "%s%s\n" TRIGGER COMMAND_DONE'$'\n'
read_until FAILURECALL_FINISHED
assert_contains "precmd invoked the public failure-message function" FAILURECALL_FINISHED "$REPLY"
assert_contains "animation was queued by the public function" PENDING_1 "$REPLY"
assert_contains "animation FD was registered before ZLE starts" STATE_registered "$REPLY"
assert_contains "animation process is active" ACTIVE_1 "$REPLY"

# The ZLE event loop should receive frames while the next line is being edited.
# Send a shell command after a short animation interval; it writes the final
# frame count and restored prompt to a file, avoiding PTY echo/output races.
command sleep 0.45
zpty -w "$pty_name" 'printf "%s%s%s%s%s%s%s%s%s%s%s\n" FRAME COUNT_ "$_DOTS_FAILURE_ANIMATION_FRAMES" STATE_ "$_DOTS_FAILURE_ANIMATION_LAST_STATE" PREVIOUS_FRAMES_ "$_DOTS_FAILURE_ANIMATION_LAST_FRAMES" PROMPT_ "$RPROMPT" > "$RESULT_FILE"'$'\n'

typeset -i result_attempt=0
while [[ ! -s "$result_file" ]] && (( result_attempt < 100 )); do
    command sleep 0.05
    (( result_attempt += 1 ))
done
[[ -s "$result_file" ]] || fail "keyboard input was not processed while animation was active"

typeset animation_result="$(<"$result_file")"
assert_contains "animation callback rendered at least one frame" "FRAMECOUNT_" "$animation_result"
[[ "$animation_result" == *FRAMECOUNT_[1-9]* ]] || {
    print -u2 -r -- "Animation result: $animation_result"
    fail "no animation frame callback ran before Enter"
}
assert_contains "original right prompt was restored after Enter" "PROMPT_BASE_RPROMPT" "$animation_result"

print -- "All non-blocking failure-animation integration tests passed."
\n'


assert_contains "animation callback rendered at least one frame" "FRAMECOUNT_" "$animation_result"
[[ "$animation_result" == *FRAMECOUNT_[1-9]* ]] || {
    print -u2 -r -- "Animation result: $animation_result"
    fail "no animation frame callback ran before Enter"
}
assert_contains "original right prompt was restored after Enter" "PROMPT_BASE_RPROMPT" "$animation_result"

print -- "All non-blocking failure-animation integration tests passed."

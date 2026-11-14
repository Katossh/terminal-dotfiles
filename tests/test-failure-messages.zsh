#!/usr/bin/env zsh
setopt nounset

REPO_DIR="${0:A:h:h}"
source "$REPO_DIR/config/terminal/zsh/failure-messages.zsh"

typeset -g DOTS_TEST_ANIMATION_STYLE=''
typeset -g DOTS_TEST_ANIMATION_BANNER=''
typeset -g DOTS_TEST_ANIMATION_DETAIL=''
typeset -g DOTS_TEST_ANIMATION_AVAILABLE=1
_dots_failure_animation_start() {
    DOTS_TEST_ANIMATION_STYLE="${1:-normal}"
    DOTS_TEST_ANIMATION_BANNER="${2-}"
    DOTS_TEST_ANIMATION_DETAIL="${3-}"
    (( DOTS_TEST_ANIMATION_AVAILABLE ))
}

fail() {
    print -u2 -r -- "not ok - $*"
    exit 1
}

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    [[ "$actual" == "$expected" ]] || fail "$label (expected: ${(qqq)expected}; got: ${(qqq)actual})"
    print -- "ok - $label"
}

assert_absent() {
    local label="$1" needle="$2" haystack="$3"
    [[ "$haystack" != *"$needle"* ]] || fail "$label (unexpected: ${(qqq)needle})"
    print -- "ok - $label"
}

assert_control_free() {
    local label="$1" value="$2"
    value="${value//$'\n'/}"
    [[ "$value" != *[[:cntrl:]]* ]] || fail "$label (control character remained)"
    print -- "ok - $label"
}

capture_message() {
    local capture_file
    capture_file="$(mktemp "${TMPDIR:-/tmp}/dots-failure-message.XXXXXX")" || return 1
    dots_failure_message "$@" > "$capture_file"
    DOTS_TEST_OUTPUT="$(<"$capture_file")"
    rm -f "$capture_file"
}

export NO_COLOR=1
export DOTS_FAILURE_MESSAGE_CHANCE=100
export DOTS_FAILURE_ANIMATION=1
export DOTS_FAILURE_STYLE=ecchi
export DOTS_FAILURE_ANIMATION_CHANCE=0
export DOTS_FAILURE_MESSAGE_ESCALATION=1

# Every failure category must use the same wording and the same single palette.
for category in not_found permission missing_path git nix network generic unknown; do
    DOTS_TEST_ANIMATION_STYLE=''
    DOTS_TEST_ANIMATION_BANNER=''
    DOTS_TEST_ANIMATION_DETAIL=''
    capture_message "$category" 'cargo test'
    assert_eq "$category uses the common gradient style" normal "$DOTS_TEST_ANIMATION_STYLE"
    assert_eq "$category uses the one message template" '✖ Command "cargo test" failed.' "$DOTS_TEST_ANIMATION_BANNER"
    assert_eq "$category has no extra message detail" '' "$DOTS_TEST_ANIMATION_DETAIL"
    assert_eq "$category emits no static duplicate when animation starts" '' "$DOTS_TEST_OUTPUT"
done

# Message text remains deterministic across repeated calls and ignores legacy style knobs.
first="$DOTS_TEST_ANIMATION_BANNER"
capture_message not_found 'cargo test'
assert_eq "repeated failures use identical wording" "$first" "$DOTS_TEST_ANIMATION_BANNER"

# Optional detail is passed separately so the animator can lay it out on the next row.
capture_message git 'git push' 'remote rejected the update'
assert_eq "detail does not create another message variant" '✖ Command "git push" failed.' "$DOTS_TEST_ANIMATION_BANNER"
assert_eq "diagnostic detail is preserved" 'remote rejected the update' "$DOTS_TEST_ANIMATION_DETAIL"

# If animation cannot start, the same message falls back to plain output.
DOTS_TEST_ANIMATION_AVAILABLE=0
capture_message generic 'static-fallback' 'inspect stderr'
assert_eq "plain fallback keeps the one message format" $'✖ Command "static-fallback" failed.\n  ↳ inspect stderr' "$DOTS_TEST_OUTPUT"
DOTS_TEST_ANIMATION_AVAILABLE=1

# Sanitise terminal controls in both the command and diagnostic detail.
DOTS_TEST_ANIMATION_AVAILABLE=0
unsafe_command=$'curl\a\b\t\v\f\r\n\e\x7fhttps://example.invalid'
capture_message network "$unsafe_command"
assert_control_free "command fallback contains no control bytes" "$DOTS_TEST_OUTPUT"
assert_absent "command newline is replaced, not rendered as a new message" $'\n  ↳' "$DOTS_TEST_OUTPUT"

unsafe_detail=$'detail\a\b\t\v\f\r\n\e\x7ftext'
capture_message network curl "$unsafe_detail"
assert_control_free "detail fallback contains no control bytes" "$DOTS_TEST_OUTPUT"
detail_lines=( "${(@f)DOTS_TEST_OUTPUT}" )
assert_eq "detail is kept on one additional row" 2 "${#detail_lines}"

# A zero chance remains a supported opt-out and never invokes the animator.
export DOTS_FAILURE_MESSAGE_CHANCE=0
DOTS_TEST_ANIMATION_STYLE=''
capture_message generic suppressed
assert_eq "zero chance suppresses the message" '' "$DOTS_TEST_OUTPUT"
assert_eq "zero chance skips the animator" '' "$DOTS_TEST_ANIMATION_STYLE"

# Rendering must not alter the failed command's status.
dots_failure_message generic status-check >/dev/null
assert_eq "renderer returns success" 0 "$?"

print -- "All single-template failure-message tests passed."

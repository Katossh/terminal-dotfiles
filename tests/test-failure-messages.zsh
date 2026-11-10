#!/usr/bin/env zsh
setopt nounset

REPO_DIR="${0:A:h:h}"
source "$REPO_DIR/config/terminal/zsh/failure-messages.zsh"

fail() {
    print -u2 -- "not ok - $1"
    exit 1
}

assert_contains() {
    local label="$1"
    local needle="$2"
    local haystack="$3"

    [[ "$haystack" == *"$needle"* ]] || {
        print -u2 -- "not ok - $label (missing: '$needle')"
        print -u2 -- "$haystack"
        exit 1
    }
    print -- "ok - $label"
}

assert_absent() {
    local label="$1"
    local needle="$2"
    local haystack="$3"

    [[ "$haystack" != *"$needle"* ]] || {
        print -u2 -- "not ok - $label (unexpected control character)"
        print -u2 -r -- "  offending character: ${(qqq)needle}"
        print -u2 -r -- "  rendered output: ${(qqq)haystack}"
        exit 1
    }
    print -- "ok - $label"
}

assert_control_free() {
    local label="$1"
    local value="$2"
    # A single LF between the primary message and optional detail is deliberate.
    value="${value//$'\n'/}"
    [[ "$value" != *[[:cntrl:]]* ]] || {
        print -u2 -- "not ok - $label (control character remained)"
        exit 1
    }
    print -- "ok - $label"
}

# Capture output while running the message function in this shell. This is
# necessary because its anti-repeat and escalation state is intentionally
# persistent between calls.
typeset -g DOTS_TEST_OUTPUT=''
capture_message() {
    local capture_file
    capture_file="$(mktemp "${TMPDIR:-/tmp}/dots-failure-message.XXXXXX")" || return 1
    dots_failure_message "$@" > "$capture_file"
    DOTS_TEST_OUTPUT="$(<"$capture_file")"
    rm -f "$capture_file"
}

export NO_COLOR=1
export DOTS_FAILURE_MESSAGE_CHANCE=100
export DOTS_FAILURE_RARE_CHANCE=0
export DOTS_FAILURE_RAINBOW_CHANCE=0
export DOTS_FAILURE_ANIMATION_CHANCE=0
export DOTS_FAILURE_STYLE=normal
export DOTS_FAILURE_MESSAGE_ESCALATION=0

capture_message not_found gti
assert_contains "command-not-found category" "gti" "$DOTS_TEST_OUTPUT"
capture_message permission chmod
assert_contains "permission category" "chmod" "$DOTS_TEST_OUTPUT"
capture_message missing_path /tmp/missing
assert_contains "missing-path category" "/tmp/missing" "$DOTS_TEST_OUTPUT"
capture_message git 'git push'
assert_contains "Git category" "git push" "$DOTS_TEST_OUTPUT"
capture_message nix 'nix build'
assert_contains "Nix category" "nix build" "$DOTS_TEST_OUTPUT"
integer generic_index=0
typeset generic_output=''
while (( generic_index < 30 )); do
    capture_message generic 'cargo test'
    generic_output+="$DOTS_TEST_OUTPUT"
    (( generic_index += 1 ))
done
assert_contains "generic category retains command context across sampled messages" "cargo test" "$generic_output"


# Every style can be forced for previews and deterministic testing.
export DOTS_FAILURE_STYLE=anime
integer anime_index=0
typeset anime_output=''
while (( anime_index < 30 )); do
    capture_message not_found anime-style-test
    anime_output+="$DOTS_TEST_OUTPUT"
    (( anime_index += 1 ))
done
assert_contains "anime style retains command context" "anime-style-test" "$anime_output"
if [[ "$anime_output" != *"💢"* && "$anime_output" != *"⚡"* &&
      "$anime_output" != *"🜂"* && "$anime_output" != *"✨"* &&
      "$anime_output" != *"🐾"* && "$anime_output" != *"🌙"* &&
      "$anime_output" != *"🔥"* && "$anime_output" != *"🌀"* &&
      "$anime_output" != *"🎴"* && "$anime_output" != *"💫"* &&
      "$anime_output" != *"🪽"* && "$anime_output" != *"🔮"* &&
      "$anime_output" != *"🐉"* && "$anime_output" != *"🎀"* &&
      "$anime_output" != *"🍡"* && "$anime_output" != *"🌸"* ]]; then
    fail "anime style should include a themed emoji"
fi
print -- "ok - anime style includes themed emoji"

export DOTS_FAILURE_STYLE=ecchi
integer ecchi_index=0
typeset ecchi_output=''
while (( ecchi_index < 200 )); do
    capture_message generic ecchi-style-test
    printf -v ecchi_output '%s\n%s' "$ecchi_output" "$DOTS_TEST_OUTPUT"
    (( ecchi_index += 1 ))
done
assert_contains "ecchi pool includes the Nyaa opening" "Nyaa~" "$ecchi_output"
assert_contains "ecchi pool varies its openings" "Well, well" "$ecchi_output"
assert_contains "ecchi pool varies its dialogue style" "Darling" "$ecchi_output"
typeset -U unique_ecchi_messages
unique_ecchi_messages=( "${(@f)ecchi_output}" )
(( ${#unique_ecchi_messages} >= 20 )) || fail "ecchi pool should provide at least twenty distinct messages"
print -- "ok - ecchi pool has broad message diversity"

export DOTS_FAILURE_STYLE=sarcastic
capture_message generic sarcasm-style-test
[[ -n "$DOTS_TEST_OUTPUT" ]] || fail "sarcastic style should produce a notice"
print -- "ok - sarcastic style produces a notice"

export DOTS_FAILURE_STYLE=dramatic
capture_message generic dramatic-style-test
assert_contains "dramatic style retains command context" "dramatic-style-test" "$DOTS_TEST_OUTPUT"

export DOTS_FAILURE_STYLE=rainbow
capture_message generic rainbow-style-test
assert_contains "rainbow style retains command context" "rainbow-style-test" "$DOTS_TEST_OUTPUT"
assert_contains "rainbow style includes rainbow emoji" "🌈" "$DOTS_TEST_OUTPUT"
assert_control_free "rainbow output stays control-free when redirected" "$DOTS_TEST_OUTPUT"

# Animations are never emitted into redirected output, even at a 100% chance.
export DOTS_FAILURE_STYLE=normal
export DOTS_FAILURE_ANIMATION_CHANCE=100
capture_message generic redirected-animation-test
assert_absent "animation stays off when output is redirected" "Consulting the machine spirits" "$DOTS_TEST_OUTPUT"
export DOTS_FAILURE_ANIMATION_CHANCE=0

# Network messages must remain distinct from generic fallback messages.
capture_message network 'curl https://example.invalid'
assert_contains "network category" "network" "${DOTS_TEST_OUTPUT:l}"
assert_contains "network command context" "curl https://example.invalid" "$DOTS_TEST_OUTPUT"

integer network_index=1
while (( network_index < 30 )); do
    capture_message network 'curl https://example.invalid'
    assert_contains "network category survives repeat escalation" "network" "${DOTS_TEST_OUTPUT:l}"
    network_index=$((network_index + 1))
done

# NUL cannot be held in a shell variable. Test every other C0 control and DEL.
unsafe_command=$'curl\a\b\t\v\f\r\n\e\x7fhttps://example.invalid'
capture_message network "$unsafe_command"
# Check the entire output against the POSIX control-character class rather
# than glob-matching individual control bytes as shell pattern fragments.
command_lines=( "${(@f)DOTS_TEST_OUTPUT}" )
(( ${#command_lines[@]} == 1 )) || fail "command controls must not create extra terminal lines"
assert_control_free "command rendering has no control characters" "$DOTS_TEST_OUTPUT"

unsafe_detail=$'detail\a\b\t\v\f\r\n\e\x7ftext'
capture_message network curl "$unsafe_detail"
# The same complete control-byte check applies to optional detail output.
detail_lines=( "${(@f)DOTS_TEST_OUTPUT}" )
(( ${#detail_lines[@]} == 2 )) || fail "detail controls must not create extra terminal lines"
assert_control_free "detail rendering has no control characters" "$DOTS_TEST_OUTPUT"

# The same helper sanitises the username before it is interpolated.
unsafe_user=$'katossh\a\b\t\v\f\r\n\e\x7f'
_dots_failure_message_sanitize "$unsafe_user"
assert_contains "username is retained" "katossh" "$REPLY"
assert_control_free "username is sanitised" "$REPLY"

integer fallback_index=0
typeset fallback_output=''
while (( fallback_index < 30 )); do
    capture_message unexpected fallback-command
    fallback_output+="$DOTS_TEST_OUTPUT"
    (( fallback_index += 1 ))
done
assert_contains "unknown categories fall back to generic" "fallback-command" "$fallback_output"

# The renderer's state must survive between calls, and adjacent templates
# must never repeat.
typeset -g _DOTS_FAILURE_MESSAGE_LAST_KEY=''
typeset -g _DOTS_FAILURE_MESSAGE_LAST_TEMPLATE=''
typeset -gi _DOTS_FAILURE_MESSAGE_STREAK=0
capture_message generic repeated-command
first="$DOTS_TEST_OUTPUT"
capture_message generic repeated-command
second="$DOTS_TEST_OUTPUT"
[[ "$first" != "$second" ]] || fail "adjacent messages must not repeat"
print -- "ok - adjacent messages do not repeat"

# The second and third identical failures advance the escalation counter.
typeset -g _DOTS_FAILURE_MESSAGE_LAST_KEY=''
typeset -g _DOTS_FAILURE_MESSAGE_LAST_TEMPLATE=''
typeset -gi _DOTS_FAILURE_MESSAGE_STREAK=0
export DOTS_FAILURE_MESSAGE_ESCALATION=1
capture_message generic escalation-command
first="$DOTS_TEST_OUTPUT"
capture_message generic escalation-command
second="$DOTS_TEST_OUTPUT"
[[ "$_DOTS_FAILURE_MESSAGE_STREAK" == 2 ]] || fail "second failure increments streak"
capture_message generic escalation-command
third="$DOTS_TEST_OUTPUT"
[[ "$_DOTS_FAILURE_MESSAGE_STREAK" == 3 ]] || fail "third failure increments streak"
[[ "$first" != "$second" && "$second" != "$third" ]] || fail "escalation avoids adjacent repeats"
print -- "ok - escalation state and anti-repeat"

export DOTS_FAILURE_MESSAGE_CHANCE=0
capture_message generic suppressed
[[ -z "$DOTS_TEST_OUTPUT" ]] || fail "zero chance suppresses output"
print -- "ok - zero chance suppresses output"

dots_failure_message generic status-check >/dev/null
[[ "$?" == 0 ]] || fail "renderer must return success"
print -- "ok - renderer returns success"

print -- "All failure-message tests passed."

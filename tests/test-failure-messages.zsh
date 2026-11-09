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
        print -u2 -- "output was:"
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
        print -u2 -- "not ok - $label (unexpected control character found)"
        exit 1
    }

    print -- "ok - $label"
}

export NO_COLOR=1
export DOTS_FAILURE_MESSAGE_CHANCE=100
export DOTS_FAILURE_RARE_CHANCE=0
export DOTS_FAILURE_MESSAGE_ESCALATION=0

output="$(dots_failure_message network 'curl https://example.invalid')"
assert_contains "network category has dedicated messaging" "network" "${output:l}"
assert_contains "network message includes the command" "curl https://example.invalid" "$output"

# Every C0 control character and DEL must be removed/replaced before the
# supplied command text is rendered. The output should remain one line.
unsafe_command=$'curl\a\b\t\r\n\x1b\x7fhttps://example.invalid'
output="$(dots_failure_message network "$unsafe_command")"
assert_absent "BEL is removed" $'\a' "$output"
assert_absent "backspace is removed" $'\b' "$output"
assert_absent "tab is removed" $'\t' "$output"
assert_absent "carriage return is removed" $'\r' "$output"
assert_absent "ESC is removed" $'\e' "$output"
assert_absent "DEL is removed" $'\x7f' "$output"
lines=( "${(@f)output}" )
(( ${#lines[@]} == 1 )) || fail "command control characters must not create extra lines"

# Detail and username are user-influenced values too; neither may inject
# terminal controls into the rendered output.
unsafe_detail=$'remote said\a\b\x1bno\r\nnext'
output="$(dots_failure_message network 'curl' "$unsafe_detail")"
assert_absent "detail control characters are removed" $'\a' "$output"
assert_absent "detail ESC is removed" $'\e' "$output"
detail_lines=( "${(@f)output}" )
(( ${#detail_lines[@]} == 2 )) || fail "detail control characters must not create extra lines"

unsafe_user=$'katossh\a\x1b'
original_user="$USER"
export USER="$unsafe_user"
output="$(dots_failure_message permission 'chmod')"
export USER="$original_user"
assert_absent "username control characters are removed" $'\a' "$output"
assert_absent "username ESC is removed" $'\e' "$output"

# Unknown categories degrade to generic rather than causing an empty message
# pool or an arithmetic failure.
output="$(dots_failure_message unknown-category 'some-command')"
assert_contains "unknown category falls back to generic messaging" "some-command" "$output"

print -- "All failure-message tests passed."

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

assert_control_free() {
    local label="$1"
    local value="$2"
    # The renderer intentionally separates message and detail with one LF.
    value="${value//$'\\n'/}"
    [[ "$value" != *[[:cntrl:]]* ]] || {
        print -u2 -- "not ok - $label (control character remained)"
        exit 1
    }
    print -- "ok - $label"
}

# Capture output without putting the function call itself in a subshell.
# The message engine has state (anti-repeat and escalation) that must persist
# between calls for those behaviours to be tested correctly.
typeset -g DOTS_TEST_OUTPUT=''
capture_message() {
    local capture_file
    capture_file="$(mktemp "${TMPDIR:-/tmp}/dots-failure-message.XXXXXX")" || return 1
    dots_failure_message "$@" > "$capture_file"
    DOTS_TEST_OUTPUT="$(<"$capture_file")"
    rm -f -- "$capture_file"
}

export NO_COLOR=1
export DOTS_FAILURE_MESSAGE_CHANCE=100
export DOTS_FAILURE_RARE_CHANCE=0
export DOTS_FAILURE_MESSAGE_ESCALATION=0

capture_message not_found gti
output="$DOTS_TEST_OUTPUT"
assert_contains "command-not-found message includes the command" "gti" "$output"

capture_message permission chmod
output="$DOTS_TEST_OUTPUT"
assert_contains "permission category has a dedicated pool" "chmod" "$output"

capture_message missing_path /tmp/missing
output="$DOTS_TEST_OUTPUT"
assert_contains "missing-path category has a dedicated pool" "/tmp/missing" "$output"

capture_message git 'git push'
output="$DOTS_TEST_OUTPUT"
assert_contains "Git category has a dedicated pool" "git push" "$output"

capture_message nix 'nix build'
output="$DOTS_TEST_OUTPUT"
assert_contains "Nix category has a dedicated pool" "nix build" "$output"

# Every standard network message must identify the category and retain the
# command context. Repeated calls sample the whole pool without fixing RANDOM.
integer network_index=0
while (( network_index < 30 )); do
    capture_message network 'curl https://example.invalid'
    output="$DOTS_TEST_OUTPUT"
    assert_contains "network category is recognised" "network" "${output:l}"
    assert_contains "network message retains command context" "curl https://example.invalid" "$output"
    network_index=$((network_index + 1))
done

capture_message generic 'cargo test'
output="$DOTS_TEST_OUTPUT"
assert_contains "generic category remains available" "cargo test" "$output"

# NUL cannot be stored in a shell variable. Test every other C0 control plus
# DEL; CR/LF must not create extra terminal lines.
unsafe_command=$'curl\\a\\b\\t\\v\\f\\r\\n\\e\\x7fhttps://example.invalid'
capture_message network "$unsafe_command"
output="$DOTS_TEST_OUTPUT"
assert_absent "BEL is removed from command text" $'\\a' "$output"
assert_absent "backspace is removed from command text" $'\\b' "$output"
assert_absent "tab is removed from command text" $'\\t' "$output"
assert_absent "vertical tab is removed from command text" $'\\v' "$output"
assert_absent "form feed is removed from command text" $'\\f' "$output"
assert_absent "carriage return is removed from command text" $'\\r' "$output"
assert_absent "ESC is removed from command text" $'\\e' "$output"
assert_absent "DEL is removed from command text" $'\\x7f' "$output"
command_lines=( "${(@f)output}" )
(( ${#command_lines[@]} == 1 )) || fail "command controls must not create extra lines"
assert_control_free "command output contains no terminal controls" "$output"

# Detail is also interpolated into terminal output and must use the same
# sanitization. The one expected message/detail separator is preserved.
unsafe_detail=$'remote said\\a\\b\\t\\v\\f\\r\\n\\e\\x7fnext'
capture_message network curl "$unsafe_detail"
output="$DOTS_TEST_OUTPUT"
assert_absent "BEL is removed from detail" $'\\a' "$output"
assert_absent "backspace is removed from detail" $'\\b' "$output"
assert_absent "tab is removed from detail" $'\\t' "$output"
assert_absent "vertical tab is removed from detail" $'\\v' "$output"
assert_absent "form feed is removed from detail" $'\\f' "$output"
assert_absent "carriage return is removed from detail" $'\\r' "$output"
assert_absent "ESC is removed from detail" $'\\e' "$output"
assert_absent "DEL is removed from detail" $'\\x7f' "$output"
detail_lines=( "${(@f)output}" )
(( ${#detail_lines[@]} == 2 )) || fail "detail controls must not create extra lines"
assert_control_free "detail output contains no terminal controls" "$output"

unsafe_user=$'katossh\\a\\b\\t\\v\\f\\r\\n\\e\\x7f'
_dots_failure_message_sanitize "$unsafe_user"
sanitized_user="$REPLY"
assert_contains "username is retained after sanitization" "katossh" "$sanitized_user"
assert_control_free "username sanitization removes all controls" "$sanitized_user"

# Unknown categories degrade to generic instead of producing an empty pool.
capture_message unexpected 'fallback-command'
output="$DOTS_TEST_OUTPUT"
assert_contains "unknown categories fall back to generic" "fallback-command" "$output"

# Adjacent selections cannot repeat, and the state must persist across calls.
typeset -g _DOTS_FAILURE_MESSAGE_LAST_KEY=''
typeset -g _DOTS_FAILURE_MESSAGE_LAST_TEMPLATE=''
typeset -gi _DOTS_FAILURE_MESSAGE_STREAK=0
capture_message generic repeated-command
first="$DOTS_TEST_OUTPUT"
capture_message generic repeated-command
second="$DOTS_TEST_OUTPUT"
[[ "$first" != "$second" ]] || fail "adjacent messages must not repeat"
print -- "ok - adjacent messages do not repeat"

# Repeated identical failures progress through normal, repeat, and severe
# pools. Assert state as well as distinct output to prove escalation ran.
typeset -g _DOTS_FAILURE_MESSAGE_LAST_KEY=''
typeset -g _DOTS_FAILURE_MESSAGE_LAST_TEMPLATE=''
typeset -gi _DOTS_FAILURE_MESSAGE_STREAK=0
export DOTS_FAILURE_MESSAGE_ESCALATION=1
capture_message generic escalation-command
first="$DOTS_TEST_OUTPUT"
capture_message generic escalation-command
second="$DOTS_TEST_OUTPUT"
[[ "$_DOTS_FAILURE_MESSAGE_STREAK" == 2 ]] || fail "second failure must increment the streak"
capture_message generic escalation-command
third="$DOTS_TEST_OUTPUT"
[[ "$_DOTS_FAILURE_MESSAGE_STREAK" == 3 ]] || fail "third failure must increment the streak"
[[ "$first" != "$second" && "$second" != "$third" ]] ||
    fail "escalation must preserve adjacent anti-repeat behaviour"
print -- "ok - repeated failures escalate without adjacent repetition"

# Suppression must not turn message rendering into a command failure.
export DOTS_FAILURE_MESSAGE_CHANCE=0
capture_message generic suppressed
[[ -z "$DOTS_TEST_OUTPUT" ]] || fail "zero probability must suppress output"
print -- "ok - zero probability suppresses output"
dots_failure_message generic status-check >/dev/null
[[ "$?" == 0 ]] || fail "renderer must return success"
print -- "ok - renderer returns success"

print -- "All failure-message tests passed."

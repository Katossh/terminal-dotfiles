#!/usr/bin/env zsh
setopt nounset

REPO_DIR="${0:A:h:h}"
source "$REPO_DIR/config/terminal/zsh/diagnostics.zsh"

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

assert_eq() {
    local label="$1"
    local expected="$2"
    local actual="$3"

    [[ "$actual" == "$expected" ]] || {
        print -u2 -- "not ok - $label (expected '$expected', got '$actual')"
        exit 1
    }

    print -- "ok - $label"
}

# Stub the two optional integrations so this module remains independently
# testable before the command-state and classifier PRs have been merged.
typeset -gi DOTS_TEST_PRESERVE_CALLS=0
typeset -g DOTS_TEST_CATEGORY=generic
typeset -g DOTS_TEST_CLASSIFIER_COMMAND=''
typeset -g DOTS_TEST_CLASSIFIER_STATUS=''

dots_command_state_preserve_previous() {
    (( DOTS_TEST_PRESERVE_CALLS += 1 ))
    return 0
}

dots_classify_failure() {
    DOTS_TEST_CLASSIFIER_COMMAND="$1"
    DOTS_TEST_CLASSIFIER_STATUS="$2"
    REPLY="$DOTS_TEST_CATEGORY"
    return 0
}

typeset -g DOTS_LAST_COMMAND=''
typeset -g DOTS_LAST_EXECUTED_COMMAND=''
typeset -gi DOTS_LAST_STATUS=0
typeset -g DOTS_LAST_CWD=''
typeset -g DOTS_LAST_TIMESTAMP=''

output="$(why)"
assert_contains "empty state is handled" "No previous interactive command" "$output"

DOTS_LAST_COMMAND='cargo build'
DOTS_LAST_EXECUTED_COMMAND='cargo build'
DOTS_LAST_STATUS=0
DOTS_LAST_CWD='/tmp/project'
DOTS_LAST_TIMESTAMP=''
output="$(why)"
assert_contains "successful command is identified" "completed successfully" "$output"
assert_contains "successful command does not claim failure" "No failure to diagnose" "$output"

DOTS_LAST_COMMAND='gti status'
DOTS_LAST_EXECUTED_COMMAND='gti status'
DOTS_LAST_STATUS=127
DOTS_TEST_CATEGORY=not_found
output="$(why)"
assert_contains "command-not-found diagnosis is shown" "could not resolve the command name" "$output"
assert_contains "classifier receives the expanded command" "gti status" "$DOTS_TEST_CLASSIFIER_COMMAND"
assert_eq "classifier receives the exit code" "127" "$DOTS_TEST_CLASSIFIER_STATUS"

DOTS_LAST_COMMAND='cd ~/missing-project'
DOTS_LAST_EXECUTED_COMMAND='cd ~/missing-project'
DOTS_LAST_STATUS=1
DOTS_TEST_CATEGORY=missing_path
output="$(why)"
assert_contains "missing-path guidance is shown" "does not exist" "$output"

DOTS_LAST_COMMAND='git push'
DOTS_LAST_EXECUTED_COMMAND='git push'
DOTS_LAST_STATUS=1
DOTS_TEST_CATEGORY=git
output="$(why)"
assert_contains "Git failures are diagnosed conservatively" "cannot identify the exact Git error" "$output"

DOTS_LAST_COMMAND='curl https://example.invalid'
DOTS_LAST_EXECUTED_COMMAND='curl https://example.invalid'
DOTS_LAST_STATUS=6
DOTS_TEST_CATEGORY=network
output="$(why)"
assert_contains "network failures have targeted guidance" "DNS, connection, proxy, or timeout" "$output"

DOTS_LAST_COMMAND='sleep 30'
DOTS_LAST_EXECUTED_COMMAND='sleep 30'
DOTS_LAST_STATUS=130
DOTS_TEST_CATEGORY=generic
output="$(why)"
assert_contains "Ctrl+C status is identified" "interrupted by SIGINT" "$output"

DOTS_LAST_COMMAND='nix build .#workstation'
DOTS_LAST_EXECUTED_COMMAND='nix build .#workstation'
DOTS_LAST_STATUS=1
DOTS_LAST_CWD='/tmp/nix-project'
DOTS_TEST_CATEGORY=nix
output="$(why --verbose)"
assert_contains "verbose output includes working directory" "/tmp/nix-project" "$output"
assert_contains "verbose output identifies expanded command" "Expanded:" "$output"
assert_contains "Nix diagnosis remains cautious" "cannot distinguish evaluation, build, fetch, or activation" "$output"

# "why" must ask the state hook to preserve the record it is reading.
why >/dev/null
assert_eq "why requests preservation of the previous command" "1" "$DOTS_TEST_PRESERVE_CALLS"

# The module also works before the optional classifier is loaded.
unfunction dots_classify_failure
DOTS_LAST_COMMAND='missing-command'
DOTS_LAST_EXECUTED_COMMAND='missing-command'
DOTS_LAST_STATUS=127
output="$(why)"
assert_contains "fallback recognises conventional command-not-found status" "could not resolve the command name" "$output"

if why --unknown >/dev/null 2>&1; then
    fail "unknown options are rejected"
else
    assert_eq "unknown option returns usage error" "2" "$?"
fi

print -- "All diagnostics tests passed."

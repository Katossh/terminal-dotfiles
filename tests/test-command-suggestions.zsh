#!/usr/bin/env zsh
emulate -LR zsh
setopt err_return no_unset

REPO_DIR="${0:A:h:h}"
source "$REPO_DIR/config/terminal/zsh/command-suggestions.zsh"

fail() {
    print -u2 -r -- "FAIL: $*"
    exit 1
}

_dots_command_suggestion_distance gti git
[[ "$REPLY" == 1 ]] || fail "adjacent transposition should count as one edit"

_dots_command_suggestion_distance gti grit
[[ "$REPLY" == 2 ]] || fail "insertion should be counted"

_dots_command_suggestion_distance git git
[[ "$REPLY" == 0 ]] || fail "identical names should have distance zero"

function dots_suggestion_fixture_git() {
    :
}

function dots_suggestion_fixture_got() {
    :
}

alias dots_suggestion_fixture_gat='dots_suggestion_fixture_git'

candidate_output="$(_dots_command_suggestion_candidates dots_suggestion_fixture_gti)" ||
    fail "expected fixture functions to produce candidates"

first_candidate="${candidate_output%%$'\n'*}"
[[ "$first_candidate" == dots_suggestion_fixture_git ]] ||
    fail "the closest candidate should rank first (got: $first_candidate)"
[[ "$candidate_output" != *dots_suggestion_fixture_gat* ]] ||
    fail "aliases must not be offered as dynamically executed corrections"

if _dots_command_suggestion_candidates "../dots_suggestion_fixture_gti"; then
    fail "path-like command names must not be guessed"
fi

if _dots_command_suggestion_candidates x; then
    fail "single-character command names must not produce broad guesses"
fi

# A non-interactive caller gets printable suggestions, never a blocking prompt.
# Keep the function invocation in this shell so its REPLY contract is observable.
suggestion_output="$(mktemp "${TMPDIR:-/tmp}/dots-command-suggestions.XXXXXX")"
if dots_suggest_command dots_suggestion_fixture_gti >"$suggestion_output" 2>&1; then
    rm -f "$suggestion_output"
    fail "non-interactive suggestion lookup must not report a selected command"
else
    suggestion_status=$?
fi
suggestion_reply="$REPLY"
output="$(<"$suggestion_output")"
rm -f "$suggestion_output"
[[ "$suggestion_status" == 1 ]] ||
    fail "non-interactive suggestion lookup should return status 1"
[[ "$output" == *dots_suggestion_fixture_git* ]] ||
    fail "non-interactive output should include the best suggestion"
[[ -z "$suggestion_reply" ]] || fail "no selection should leave REPLY empty (got: '$suggestion_reply')"

print -- "command suggestion tests passed"

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

function dots_suggestion_fixture_gut() {
    :
}

alias dots_suggestion_fixture_got=":"

candidate_output="$(_dots_command_suggestion_candidates dots_suggestion_fixture_gti)" ||
    fail "expected fixture functions to produce candidates"

first_candidate="${candidate_output%%$'\n'*}"
[[ "$first_candidate" == dots_suggestion_fixture_git ]] ||
    fail "the closest candidate should rank first (got: $first_candidate)"
[[ "$candidate_output" != *dots_suggestion_fixture_alias* ]] ||
    fail "aliases must not be offered as executable corrections"

if _dots_command_suggestion_candidates "../dots_suggestion_fixture_gti"; then
    fail "path-like command names must not be guessed"
fi

if _dots_command_suggestion_candidates x; then
    fail "single-character command names must not produce broad guesses"
fi

# A non-interactive caller gets printable suggestions, never a blocking prompt.
if output="$(dots_suggest_command dots_suggestion_fixture_gti 2>&1)"; then
    fail "non-interactive suggestion lookup must not report a selected command"
fi
[[ "$output" == *dots_suggestion_fixture_git* ]] ||
    fail "non-interactive output should include the best suggestion"
[[ -z "$REPLY" ]] || fail "no selection should leave REPLY empty"

print -- "command suggestion tests passed"

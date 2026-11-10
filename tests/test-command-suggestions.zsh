#!/usr/bin/env zsh
emulate -LR zsh
setopt err_return no_unset

REPO_DIR="${0:A:h:h}"
source "$REPO_DIR/config/terminal/zsh/command-suggestions.zsh"

fail() {
    print -u2 -r -- "FAIL: $*"
    exit 1
}

_dots_command_suggestion_distance gti git 1
[[ "$REPLY" == 1 ]] || fail "adjacent transposition should count as one edit"

_dots_command_suggestion_distance gti grit 2
[[ "$REPLY" == 2 ]] || fail "insertion should be counted"

_dots_command_suggestion_distance git git 1
[[ "$REPLY" == 0 ]] || fail "identical names should have distance zero"

_dots_command_suggestion_distance abcdefgh xyz 2
[[ "$REPLY" == 3 ]] || fail "distance above the threshold should be capped at threshold + 1"

function dots_suggestion_fixture_git() {
    :
}

function dots_suggestion_fixture_got() {
    :
}

alias dots_suggestion_fixture_gat='dots_suggestion_fixture_git'

if ! _dots_command_suggestion_candidates dots_suggestion_fixture_gti; then
    fail "expected fixture functions to produce candidates"
fi
candidate_output="${(F)_DOTS_COMMAND_SUGGESTION_RESULTS}"
[[ "$_DOTS_COMMAND_SUGGESTION_CACHE_READY" == 1 ]] ||
    fail "command discovery cache must persist in the current shell"
[[ "$_DOTS_COMMAND_SUGGESTION_CACHE_PATH" == "$PATH" ]] ||
    fail "command discovery cache must record the current PATH"
[[ "$_DOTS_COMMAND_SUGGESTION_CACHE_FUNCTION_COUNT" == "${#functions}" ]] ||
    fail "function count must be recorded when the candidate cache is built"

first_candidate="${_DOTS_COMMAND_SUGGESTION_RESULTS[1]}"
[[ "$first_candidate" == dots_suggestion_fixture_git ]] ||
    fail "the closest candidate should rank first (got: $first_candidate)"
[[ "$candidate_output" != *dots_suggestion_fixture_gat* ]] ||
    fail "aliases must not be offered as dynamically executed corrections"

if builtin whence -p dots-suggest >/dev/null 2>&1; then
    [[ "$_DOTS_COMMAND_SUGGESTION_LAST_BACKEND" == rust ]] ||
        fail "the installed Rust helper should handle candidate ranking"
else
    [[ "$_DOTS_COMMAND_SUGGESTION_LAST_BACKEND" == zsh ]] ||
        fail "the pure-Zsh fallback should handle candidate ranking when Rust is absent"
fi

# The fallback remains independently testable even when dots-suggest exists.
if ! DOTS_SUGGEST_DISABLE_RUST=1 _dots_command_suggestion_candidates dots_suggestion_fixture_gti; then
    fail "the optimized Zsh fallback should still return candidates"
fi
[[ "$_DOTS_COMMAND_SUGGESTION_LAST_BACKEND" == zsh ]] ||
    fail "DOTS_SUGGEST_DISABLE_RUST=1 must force the Zsh fallback"

# A function added after the initial cache build invalidates the snapshot by
# count, rather than forcing the full function table to be enumerated per typo.
cached_function_count="$_DOTS_COMMAND_SUGGESTION_CACHE_FUNCTION_COUNT"
function dots_suggestion_fixture_dynamic() {
    :
}
(( ${#functions} > cached_function_count )) ||
    fail "the dynamic fixture function should increase the function count"

if ! _dots_command_suggestion_candidates dots_suggestion_fixture_dynamci; then
    fail "a function added after startup should be found after one cache refresh"
fi
[[ "$_DOTS_COMMAND_SUGGESTION_CACHE_FUNCTION_COUNT" == "${#functions}" ]] ||
    fail "the function cache count should refresh after a function is added"
[[ "${(F)_DOTS_COMMAND_SUGGESTION_RESULTS}" == *dots_suggestion_fixture_dynamic* ]] ||
    fail "the dynamically added function was not returned"

# A changed PATH must invalidate the executable-name cache. Discovery includes
# executable symlinks/files without spawning whence for every directory entry.
test_bin="$(mktemp -d "${TMPDIR:-/tmp}/dots-suggestion-path.XXXXXX")" ||
    fail "could not create temporary PATH directory"
old_path="$PATH"
trap 'PATH="$old_path"; rm -rf -- "$test_bin"' EXIT
printf '#!/bin/sh\nexit 0\n' > "$test_bin/dots_suggestion_fixture_new"
chmod +x "$test_bin/dots_suggestion_fixture_new"
PATH="$test_bin:$PATH"

if ! _dots_command_suggestion_candidates dots_suggestion_fixture_nwe; then
    fail "a new executable from the changed PATH should be discoverable"
fi
candidate_output="${(F)_DOTS_COMMAND_SUGGESTION_RESULTS}"
[[ "$_DOTS_COMMAND_SUGGESTION_CACHE_PATH" == "$PATH" ]] ||
    fail "the PATH cache did not refresh after PATH changed"
[[ "$candidate_output" == *dots_suggestion_fixture_new* ]] ||
    fail "a new executable from the changed PATH was not returned"

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

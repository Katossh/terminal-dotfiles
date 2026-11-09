#!/usr/bin/env zsh
setopt errexit nounset

SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/../config/terminal/zsh/failure-classifier.zsh"

fail() {
    print -u2 -r -- "FAIL: $*"
    return 1
}

expect_category() {
    local expected="$1"
    shift

    if ! dots_classify_failure "$@"; then
        fail "classifier rejected valid input: $*"
        return 1
    fi

    if [[ "$REPLY" != "$expected" ]]; then
        fail "expected '$expected', got '$REPLY' for: $*"
        return 1
    fi
}

expect_invalid_arguments() {
    if dots_classify_failure "$@"; then
        fail "expected invalid arguments to return 2"
        return 1
    else
        local actual_status=$?
        [[ "$actual_status" == 2 ]] || fail "expected status 2, got $actual_status"
    fi
}

expect_category none "git status" 0
expect_category not_found "does-not-exist" 127
expect_category permission "./not-executable" 126
expect_category git "git status" 1
expect_category git "FOO=bar sudo -u root git status" 128
expect_category git "env FOO=bar gh pr list" 1
expect_category nix "nix flake check" 1
expect_category nix "command nix develop" 1
expect_category network "curl https://example.invalid" 6
expect_category network "wget https://example.invalid" 4
expect_category generic "curl https://example.invalid" 22
expect_category generic "grep needle file.txt" 1
expect_category generic "printf test" 008
expect_category generic "" 1

test_root="$(mktemp -d "${TMPDIR:-/tmp}/dots-failure-classifier.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT
missing_dir="$test_root/path with spaces"

expect_category missing_path "cd '$missing_dir'" 1
expect_category generic "cd '$HOME/dots-classifier-do-not-expand'" 1
expect_category generic "cd -" 1
expect_category generic "cd '$test_root'" 1

expect_invalid_arguments "git status"
expect_invalid_arguments "git status" "not-a-status"
expect_invalid_arguments "git status" 256
expect_invalid_arguments "git status" -1

print -r -- "failure classifier tests passed"

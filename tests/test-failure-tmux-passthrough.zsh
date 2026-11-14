#!/usr/bin/env zsh
setopt errexit nounset

REPO_DIR="${0:A:h:h}"
ZSH_DIR="$REPO_DIR/config/terminal/zsh"
TMUX_CONFIG="$REPO_DIR/config/terminal/tmux/.tmux.conf.local"
CAPTURE="$(mktemp)"

fail() {
    print -u2 -r -- "not ok - $*"
    rm -f "$CAPTURE"
    exit 1
}

# The config must explicitly enable the feature required for DCS passthrough.
command grep -Fq '%if #{>=:#{version},3.3}' "$TMUX_CONFIG" ||
    fail "tmux version guard for passthrough is missing"
command grep -Fq 'set -g allow-passthrough on' "$TMUX_CONFIG" ||
    fail "tmux does not enable DCS passthrough for visible panes"
print -- "ok - tmux enables DCS passthrough on versions that support it"

source "$ZSH_DIR/failure-animation.zsh"

# Verify the exact wire format. ESC bytes inside the payload must be doubled;
# the outer DCS terminator remains a single ESC-backslash pair.
export TMUX="/tmp/tmux-test,123,0"
inner=$'\e]4;180;rgb:24/7b/a0\e\\'
expected=$'\ePtmux;\e\e]4;180;rgb:24/7b/a0\e\e\\\e\\'

exec {capture_fd}>"$CAPTURE"
_dots_failure_palette_write "$inner" "$capture_fd"
exec {capture_fd}>&-

actual="$(<"$CAPTURE")"
[[ "$actual" == "$expected" ]] ||
    fail "OSC 4 sequence is not encoded as valid tmux DCS passthrough"

rm -f "$CAPTURE"
print -- "ok - OSC 4 palette updates are correctly wrapped for tmux"
print -- "All tmux gradient-passthrough tests passed."

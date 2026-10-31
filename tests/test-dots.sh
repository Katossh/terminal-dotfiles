#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test ! -e "$REPO_DIR/install.sh"
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export DOTS_SKIP_DOWNLOADS=1
mkdir -p "$XDG_CONFIG_HOME/kitty" "$XDG_CONFIG_HOME/dots/overrides/kitty"
trap 'rm -rf "$TEST_ROOT"' EXIT

# Simulate a pre-existing user file and a file-level personal override.
printf '%s\n' 'user-owned kitty config' > "$XDG_CONFIG_HOME/kitty/kitty.conf"
printf '%s\n' '# personal kitty override' > "$XDG_CONFIG_HOME/dots/overrides/kitty/kitty.conf"

"$REPO_DIR/bin/dots" install --no-packages --yes > "$TEST_ROOT/install-1.log"
"$REPO_DIR/bin/dots" install --no-packages --yes > "$TEST_ROOT/install-2.log"

test -L "$HOME/.zshenv"
test -L "$XDG_CONFIG_HOME/zsh/.zshrc"
test -L "$XDG_CONFIG_HOME/kitty/kitty.conf"
test "$(readlink "$XDG_CONFIG_HOME/kitty/kitty.conf")" = "$XDG_CONFIG_HOME/dots/overrides/kitty/kitty.conf"
test -L "$HOME/.local/bin/dots"
test -L "$HOME/.local/bin/kp"
test -f "$XDG_CONFIG_HOME/kitty/themes/dots-palette.conf"
test -f "$HOME/.tmux/dots-theme.conf"
grep -Fq 'Already linked:' "$TEST_ROOT/install-2.log"

"$REPO_DIR/bin/dots" list > "$TEST_ROOT/list.log"
grep -Fq 'zsh' "$TEST_ROOT/list.log"
"$REPO_DIR/bin/dots" --health > "$TEST_ROOT/health.log"

backup_output="$("$REPO_DIR/bin/dots" backup)"
snapshot_id="$(printf '%s\n' "$backup_output" | sed -n '1p')"
test -n "$snapshot_id"
rm -f "$XDG_CONFIG_HOME/kitty/kitty.conf"
printf '%s\n' 'temporary mutation' > "$XDG_CONFIG_HOME/kitty/kitty.conf"
"$REPO_DIR/bin/dots" restore "$snapshot_id" --yes > "$TEST_ROOT/restore.log"
test -L "$XDG_CONFIG_HOME/kitty/kitty.conf"

"$REPO_DIR/bin/dots" uninstall --yes > "$TEST_ROOT/uninstall.log"
test "$(cat "$XDG_CONFIG_HOME/kitty/kitty.conf")" = 'user-owned kitty config'
test -f "$XDG_CONFIG_HOME/dots/overrides/kitty/kitty.conf"
test ! -e "$HOME/.zshenv"
test ! -e "$HOME/.local/bin/kp"
test ! -e "$XDG_CONFIG_HOME/kitty/themes/dots-palette.conf"
test ! -e "$HOME/.tmux/dots-theme.conf"

echo 'dots lifecycle tests passed'

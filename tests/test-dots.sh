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

# NixOS gets the same user configuration links and installs dependencies into
# the invoking user's Nix profile. A fake nix executable keeps this test safe.
mkdir -p "$TEST_ROOT/bin"
cat > "$TEST_ROOT/bin/nix" <<'NIX'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "${NIX_TEST_LOG:?}"
NIX
chmod +x "$TEST_ROOT/bin/nix"
export NIX_TEST_LOG="$TEST_ROOT/nix.log"
printf '%s\n' 'ID=nixos' 'ID_LIKE=""' > "$TEST_ROOT/nixos-os-release"
nixos_output="$(PATH="$TEST_ROOT/bin:$PATH" DOTS_PLATFORM=Linux DOTS_OS_RELEASE="$TEST_ROOT/nixos-os-release" "$REPO_DIR/bin/dots" install --packages --yes)"
grep -Fq 'Installing terminal dependencies with Nix' <<< "$nixos_output"
grep -Fq "$REPO_DIR/nix/packages.nix" <<< "$nixos_output"
grep -Fq 'sudo nixos-rebuild switch' <<< "$nixos_output"
grep -Fq 'The installer never edits /etc/nixos' <<< "$nixos_output"
grep -Fq 'profile install' "$NIX_TEST_LOG"
grep -Fq 'nixpkgs#zsh' "$NIX_TEST_LOG"
grep -Fq 'nixpkgs#neovim' "$NIX_TEST_LOG"
awk -F '\t' '$1 == "nixpkgs" && $2 == "zsh" && $3 == "required" { found=1 } END { exit !found }' "$REPO_DIR/manifest/packages.tsv"
grep -Fq 'builtins.readFile ../manifest/packages.tsv' "$REPO_DIR/nix/packages.nix"
grep -Fq 'class == "optional"' "$REPO_DIR/nix/packages.nix"
echo 'dots lifecycle tests passed'

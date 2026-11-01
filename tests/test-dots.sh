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

# Simulate obsolete file-level links from the previous vendored .packages tree.
legacy_target="$XDG_CONFIG_HOME/zsh/.packages/old/plugin.zsh"
legacy_source="$REPO_DIR/config/terminal/zsh/.packages/old/plugin.zsh"
mkdir -p "$(dirname "$legacy_target")" "$XDG_DATA_HOME/dots"
ln -s "$legacy_source" "$legacy_target"
printf 'link\t%s\t%s\n' "$legacy_target" "$legacy_source" >> "$XDG_DATA_HOME/dots/state.tsv"

"$REPO_DIR/bin/dots" install --no-packages --yes > "$TEST_ROOT/install-2.log"
test ! -L "$legacy_target"

test -L "$HOME/.zshenv"
test -L "$XDG_CONFIG_HOME/zsh/.zshrc"
test ! -d "$REPO_DIR/config/terminal/zsh/.packages"
test -L "$XDG_CONFIG_HOME/kitty/kitty.conf"
test "$(readlink "$XDG_CONFIG_HOME/kitty/kitty.conf")" = "$XDG_CONFIG_HOME/dots/overrides/kitty/kitty.conf"
test -L "$HOME/.local/bin/dots"
test -L "$HOME/.local/bin/kp"
test -f "$XDG_CONFIG_HOME/kitty/themes/dots-palette.conf"
test -f "$HOME/.tmux/dots-theme.conf"

# Oh My Zsh and its custom plugins are installed outside the checkout.
# A fake Git executable validates clone paths and idempotency without network access.
mkdir -p "$TEST_ROOT/bin"
if command -v zsh >/dev/null 2>&1; then
    cat > "$TEST_ROOT/bin/git" <<'GIT'
#!/usr/bin/env bash
set -Eeuo pipefail
case "${1:-}" in
    clone)
        shift
        while [[ "${1:-}" == --* ]]; do
            case "$1" in
                --depth|--branch) shift 2 ;;
                *) shift ;;
            esac
        done
        url="$1"
        target="$2"
        printf 'clone %s\n' "$url" >> "${GIT_TEST_LOG:?}"
        mkdir -p "$target/.git"
        printf '%s\n' "$url" > "$target/.git/test-origin"
        case "$url" in
            https://github.com/ohmyzsh/ohmyzsh.git)
                mkdir -p "$target/plugins/zsh-autosuggestions"
                : > "$target/oh-my-zsh.sh"
                : > "$target/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh"
                ;;
            https://github.com/Aloxaf/fzf-tab.git)
                : > "$target/fzf-tab.plugin.zsh"
                ;;
            https://github.com/zdharma-continuum/fast-syntax-highlighting.git)
                : > "$target/fast-syntax-highlighting.plugin.zsh"
                ;;
            https://github.com/zsh-users/zsh-completions.git)
                mkdir -p "$target/src"
                ;;
        esac
        ;;
    -C)
        target="$2"
        if [[ "${3:-} ${4:-} ${5:-}" == "remote get-url origin" ]]; then
            cat "$target/.git/test-origin"
        else
            exit 1
        fi
        ;;
    *) exit 1 ;;
esac
GIT
    chmod +x "$TEST_ROOT/bin/git"
    export GIT_TEST_LOG="$TEST_ROOT/fake-git.log"
    PATH="$TEST_ROOT/bin:$PATH" DOTS_SKIP_DOWNLOADS=0 "$REPO_DIR/bin/dots" install --no-packages --yes > "$TEST_ROOT/zsh-install.log"
    test -f "$XDG_DATA_HOME/oh-my-zsh/oh-my-zsh.sh"
    test -f "$XDG_DATA_HOME/zsh/custom/plugins/fzf-tab/fzf-tab.plugin.zsh"
    test -f "$XDG_DATA_HOME/zsh/custom/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
    test -d "$XDG_DATA_HOME/zsh/custom/plugins/zsh-completions/src"
    grep -Fq "plugins+=(fzf-tab)" "$XDG_CONFIG_HOME/zsh/.zshrc"
    grep -Fq "plugins+=(zsh-autosuggestions)" "$XDG_CONFIG_HOME/zsh/.zshrc"
    grep -Fq "plugins+=(fast-syntax-highlighting)" "$XDG_CONFIG_HOME/zsh/.zshrc"
    clone_count="$(wc -l < "$GIT_TEST_LOG")"
    PATH="$TEST_ROOT/bin:$PATH" DOTS_SKIP_DOWNLOADS=0 "$REPO_DIR/bin/dots" install --no-packages --yes > "$TEST_ROOT/zsh-install-2.log"
    test "$(wc -l < "$GIT_TEST_LOG")" -eq "$clone_count"
    PATH="$TEST_ROOT/bin:$PATH" DOTS_SKIP_DOWNLOADS=0 "$REPO_DIR/bin/dots" uninstall --yes > "$TEST_ROOT/zsh-uninstall.log"
    test ! -e "$XDG_DATA_HOME/oh-my-zsh"
    test ! -e "$XDG_DATA_HOME/zsh/custom/plugins/fzf-tab"
    test ! -e "$XDG_DATA_HOME/zsh/custom/plugins/fast-syntax-highlighting"
    test ! -e "$XDG_DATA_HOME/zsh/custom/plugins/zsh-completions"
fi

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

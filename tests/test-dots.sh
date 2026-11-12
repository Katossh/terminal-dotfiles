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
test -L "$XDG_CONFIG_HOME/alacritty/alacritty.toml"
test -L "$XDG_CONFIG_HOME/alacritty/catppuccin-frappe.toml"
test -L "$XDG_CONFIG_HOME/alacritty/LICENSE"
grep -Fq 'import = ["catppuccin-frappe.toml"]' "$XDG_CONFIG_HOME/alacritty/alacritty.toml"
test -L "$HOME/.local/bin/dots"
test -L "$HOME/.local/bin/kp"
test -f "$XDG_CONFIG_HOME/kitty/themes/dots-palette.conf"
test -f "$HOME/.tmux/dots-theme.conf"
test -L "$XDG_CONFIG_HOME/yazi/yazi.toml"
test -L "$XDG_CONFIG_HOME/yazi/theme.toml"
test -L "$XDG_CONFIG_HOME/yazi/Catppuccin-frappe.tmTheme"
grep -Fq 'run = "nvim %s"' "$XDG_CONFIG_HOME/yazi/yazi.toml"
grep -Fq 'syntect_theme = "~/.config/yazi/Catppuccin-frappe.tmTheme"' "$XDG_CONFIG_HOME/yazi/theme.toml"
grep -Fq 'map ctrl+shift+c copy_or_noop' "$REPO_DIR/config/terminal/kitty/kitty.conf"
grep -Fq 'map ctrl+shift+v paste_from_clipboard' "$REPO_DIR/config/terminal/kitty/kitty.conf"
grep -Fq 'set -s extended-keys on' "$REPO_DIR/config/terminal/tmux/.tmux.conf.local"
grep -Fq 'set -s extended-keys-format csi-u' "$REPO_DIR/config/terminal/tmux/.tmux.conf.local"
grep -Fq "set -as terminal-features ',xterm-kitty:extkeys'" "$REPO_DIR/config/terminal/tmux/.tmux.conf.local"
grep -Fq 'bind -T copy-mode-vi C-S-c send -X copy-selection-and-cancel' "$REPO_DIR/config/terminal/tmux/.tmux.conf.local"

# Oh My Zsh and its custom plugins are installed outside the checkout.
# Provisioning must work even when zsh is absent from PATH (fresh/Nix hosts).
# A fake Git executable validates clone paths, partial failures and idempotency.
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/no-zsh-bin"
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
        if [[ "${GIT_FAIL_URL:-}" == "$url" ]]; then exit 1; fi
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

# Build an isolated PATH with every available executable except zsh. This
# keeps the test portable across Ubuntu/macOS and avoids relying on a short list
# of utilities that differs between runner images.
IFS=: read -r -a original_path_parts <<< "$PATH"
for path_dir in "${original_path_parts[@]}"; do
    [[ -d "$path_dir" ]] || continue
    for executable in "$path_dir"/*; do
        [[ -f "$executable" && -x "$executable" ]] || continue
        command_name="${executable##*/}"
        [[ "$command_name" == zsh || "$command_name" == git ]] && continue
        [[ -e "$TEST_ROOT/no-zsh-bin/$command_name" || -L "$TEST_ROOT/no-zsh-bin/$command_name" ]] && continue
        ln -s "$executable" "$TEST_ROOT/no-zsh-bin/$command_name"
    done
done
ln -s "$TEST_ROOT/bin/git" "$TEST_ROOT/no-zsh-bin/git"

if PATH="$TEST_ROOT/no-zsh-bin" command -v zsh >/dev/null 2>&1; then
    echo "test PATH unexpectedly contains zsh" >&2
    exit 1
fi

# A partial failure must be visible and must not prevent remaining clones.
if PATH="$TEST_ROOT/no-zsh-bin" GIT_FAIL_URL="https://github.com/Aloxaf/fzf-tab.git" \
    DOTS_GIT_CLONE_RETRIES=1 DOTS_SKIP_DOWNLOADS=0 \
    "$REPO_DIR/bin/dots" install --no-packages --yes > "$TEST_ROOT/zsh-install-failed.log" 2>&1; then
    echo "expected Zsh provisioning failure was not reported" >&2
    exit 1
fi
grep -Fq "Zsh framework/plugins are incomplete" "$TEST_ROOT/zsh-install-failed.log"
test -f "$XDG_DATA_HOME/oh-my-zsh/oh-my-zsh.sh"
test -f "$XDG_DATA_HOME/zsh/custom/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
test -d "$XDG_DATA_HOME/zsh/custom/plugins/zsh-completions/src"
test ! -e "$XDG_DATA_HOME/zsh/custom/plugins/fzf-tab"

# A normal rerun fills the missing checkout and validates each payload.
PATH="$TEST_ROOT/no-zsh-bin" DOTS_GIT_CLONE_RETRIES=1 DOTS_SKIP_DOWNLOADS=0 \
    "$REPO_DIR/bin/dots" install --no-packages --yes > "$TEST_ROOT/zsh-install.log"
test -f "$XDG_DATA_HOME/oh-my-zsh/oh-my-zsh.sh"
test -f "$XDG_DATA_HOME/oh-my-zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh"
test -f "$XDG_DATA_HOME/zsh/custom/plugins/fzf-tab/fzf-tab.plugin.zsh"
test -f "$XDG_DATA_HOME/zsh/custom/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
test -d "$XDG_DATA_HOME/zsh/custom/plugins/zsh-completions/src"
grep -Fq "plugins+=(fzf-tab)" "$XDG_CONFIG_HOME/zsh/.zshrc"
grep -Fq "plugins+=(zsh-autosuggestions)" "$XDG_CONFIG_HOME/zsh/.zshrc"
grep -Fq "plugins+=(fast-syntax-highlighting)" "$XDG_CONFIG_HOME/zsh/.zshrc"

# If an installer-owned clone later loses its required payload, repair it
# without deleting the old checkout. The backup is retained for inspection.
rm -f "$XDG_DATA_HOME/zsh/custom/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
PATH="$TEST_ROOT/no-zsh-bin" DOTS_GIT_CLONE_RETRIES=1 DOTS_SKIP_DOWNLOADS=0 \
    "$REPO_DIR/bin/dots" install --no-packages --yes > "$TEST_ROOT/zsh-repair.log"
test -f "$XDG_DATA_HOME/zsh/custom/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
test "$(find "$XDG_DATA_HOME/dots/backups/incomplete-downloads" -type d -name fast-syntax-highlighting | wc -l)" -eq 1

clone_count="$(wc -l < "$GIT_TEST_LOG")"
PATH="$TEST_ROOT/no-zsh-bin" DOTS_GIT_CLONE_RETRIES=1 DOTS_SKIP_DOWNLOADS=0 \
    "$REPO_DIR/bin/dots" install --no-packages --yes > "$TEST_ROOT/zsh-install-2.log"
test "$(wc -l < "$GIT_TEST_LOG")" -eq "$clone_count"

PATH="$TEST_ROOT/no-zsh-bin" DOTS_SKIP_DOWNLOADS=0 \
    "$REPO_DIR/bin/dots" uninstall --yes > "$TEST_ROOT/zsh-uninstall.log"
test ! -e "$XDG_DATA_HOME/oh-my-zsh"
test ! -e "$XDG_DATA_HOME/zsh/custom/plugins/fzf-tab"
test ! -e "$XDG_DATA_HOME/zsh/custom/plugins/fast-syntax-highlighting"
test ! -e "$XDG_DATA_HOME/zsh/custom/plugins/zsh-completions"

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
grep -Fq 'nixpkgs#alacritty' "$NIX_TEST_LOG"
for manager in apt dnf pacman zypper apk xbps pkg brew-cask nixpkgs; do
    awk -F '\t' -v manager="$manager" '$1 == manager && $2 == "alacritty" && $3 == "optional" { found=1 } END { exit !found }' "$REPO_DIR/manifest/packages.tsv"
done
awk -F '\t' '$1 == "nixpkgs" && $2 == "zsh" && $3 == "required" { found=1 } END { exit !found }' "$REPO_DIR/manifest/packages.tsv"
grep -Fq 'builtins.readFile ../manifest/packages.tsv' "$REPO_DIR/nix/packages.nix"
grep -Fq 'class == "optional"' "$REPO_DIR/nix/packages.nix"

# Homebrew casks are distinct from formulae and must be installed and tracked
# through the cask-specific commands. Fake Homebrew avoids touching the host.
cat > "$TEST_ROOT/bin/brew" <<'BREW'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\\n' "$*" >> "${BREW_TEST_LOG:?}"
case "${1:-} ${2:-}" in
    "list --formula") exit 0 ;;
    "list --cask") [[ -e "$BREW_TEST_ROOT/alacritty-installed" ]] ;;
    "info --cask")
        if [[ "${BREW_CASK_DISABLED:-0}" == 1 ]]; then
            printf '%s\\n' 'Alacritty is disabled'
        else
            printf '%s\\n' 'Alacritty 0.17.0'
        fi
        ;;
    "install --cask")
        [[ "${3:-}" == alacritty ]] || exit 1
        touch "$BREW_TEST_ROOT/alacritty-installed"
        ;;
    "uninstall --cask")
        [[ "${3:-}" == alacritty ]] || exit 1
        rm -f "$BREW_TEST_ROOT/alacritty-installed"
        ;;
    *) exit 1 ;;
esac
BREW
cat > "$TEST_ROOT/bin/starship" <<'STARSHIP'
#!/usr/bin/env bash
exit 0
STARSHIP
chmod +x "$TEST_ROOT/bin/brew" "$TEST_ROOT/bin/starship"
export BREW_TEST_LOG="$TEST_ROOT/brew.log"
export BREW_TEST_ROOT="$TEST_ROOT"
PATH="$TEST_ROOT/bin:$PATH" DOTS_PLATFORM=Darwin BREW_CASK_DISABLED=1 DOTS_SKIP_DOWNLOADS=1 \
    "$REPO_DIR/bin/dots" install --packages --yes > "$TEST_ROOT/brew-disabled.log"
! grep -Fq 'install --cask alacritty' "$BREW_TEST_LOG"
grep -Fq 'Optional package unavailable' "$TEST_ROOT/brew-disabled.log"
PATH="$TEST_ROOT/bin:$PATH" DOTS_PLATFORM=Darwin DOTS_SKIP_DOWNLOADS=1 \
    "$REPO_DIR/bin/dots" install --packages --yes > "$TEST_ROOT/brew-install.log"
grep -Fq 'install --cask alacritty' "$BREW_TEST_LOG"
grep -Fq 'brew-cask:alacritty' "$XDG_DATA_HOME/dots/state.tsv"
PATH="$TEST_ROOT/bin:$PATH" DOTS_PLATFORM=Darwin \
    "$REPO_DIR/bin/dots" uninstall --purge --yes > "$TEST_ROOT/brew-uninstall.log"
grep -Fq 'uninstall --cask alacritty' "$BREW_TEST_LOG"
test ! -e "$TEST_ROOT/alacritty-installed"
echo 'dots lifecycle tests passed'

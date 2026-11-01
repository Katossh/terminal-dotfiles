#!/usr/bin/env bash
set -Eeuo pipefail

# One-time history-preserving split of terminal configuration into its own repo.
# This script reads a fresh remote clone; it never changes the caller's checkout.

SOURCE_URL="${SOURCE_URL:-git@github.com:Katossh/dotfiles.git}"
TARGET_URL="${TARGET_URL:-git@github.com:Katossh/terminal-dotfiles.git}"
SOURCE_REF="${SOURCE_REF:-master}"
TARGET_REF="${TARGET_REF:-main}"
EXPECTED_TARGET_SHA="2883661b163261ea6e0ec6c19a86f86b74259322"

say() { printf '\n==> %s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null 2>&1 || die "Git is required."
git filter-repo -h >/dev/null 2>&1 || die "git-filter-repo is required. Install it with your distribution package manager or 'pipx install git-filter-repo'."

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/terminal-dotfiles-migration.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
MIRROR="$WORK_DIR/source.git"

say "Checking source branch and destination safety"
SOURCE_SHA="$(git ls-remote "$SOURCE_URL" "refs/heads/$SOURCE_REF" | awk 'NR == 1 { print $1 }')"
[[ -n "$SOURCE_SHA" ]] || die "Source branch not found: $SOURCE_REF"
TARGET_SHA="$(git ls-remote "$TARGET_URL" "refs/heads/$TARGET_REF" | awk 'NR == 1 { print $1 }')"
[[ "$TARGET_SHA" == "$EXPECTED_TARGET_SHA" ]] || die "Refusing to overwrite $TARGET_REF in the destination. Expected the untouched bootstrap commit $EXPECTED_TARGET_SHA, found '${TARGET_SHA:-no branch}'. Inspect the destination before proceeding."

say "Cloning the source repository without touching your local checkout"
git clone --mirror "$SOURCE_URL" "$MIRROR"
git --git-dir="$MIRROR" show-ref --verify --quiet "refs/heads/$SOURCE_REF" || die "The cloned source does not contain refs/heads/$SOURCE_REF."

say "Filtering the terminal-only history"
FILTER_PATHS=(
    --path .editorconfig
    --path .gitignore
    --path README.md
    --path .github/workflows/validate-installer.yml
    --path bin/
    --path config/terminal/
    --path dots/
    --path manifest/
    --path nix/
    --path resources/
    --path scripts/
    --path tests/
    --path themes/
)
git --git-dir="$MIRROR" filter-repo --force "${FILTER_PATHS[@]}" --refs "refs/heads/$SOURCE_REF"

for required_path in README.md bin/dots config/terminal/zsh/.zshrc dots/zshenv manifest/configs.tsv manifest/packages.tsv nix/packages.nix tests/test-dots.sh; do
    git --git-dir="$MIRROR" cat-file -e "refs/heads/$SOURCE_REF:$required_path" || die "Filtered history is missing required path: $required_path"
done

if git --git-dir="$MIRROR" ls-tree -r --name-only "refs/heads/$SOURCE_REF" | grep -Eq '^(config/ui/|legacy/ui/)'; then
    die "Desktop configuration unexpectedly appeared in the terminal-only result."
fi

say "Pushing the filtered branch to the new private repository"
git --git-dir="$MIRROR" push --force-with-lease="refs/heads/$TARGET_REF:$EXPECTED_TARGET_SHA" "$TARGET_URL" "refs/heads/$SOURCE_REF:refs/heads/$TARGET_REF"

EXPECTED_PUSH_SHA="$(git --git-dir="$MIRROR" rev-parse "refs/heads/$SOURCE_REF")"
ACTUAL_PUSH_SHA="$(git ls-remote "$TARGET_URL" "refs/heads/$TARGET_REF" | awk 'NR == 1 { print $1 }')"
[[ "$ACTUAL_PUSH_SHA" == "$EXPECTED_PUSH_SHA" ]] || die "Destination verification failed. Expected $EXPECTED_PUSH_SHA, found $ACTUAL_PUSH_SHA."

say "Migration verified"
printf 'Repository: %s\n' "$TARGET_URL"
printf 'Branch: %s\n' "$TARGET_REF"
printf 'Commit: %s\n' "$ACTUAL_PUSH_SHA"
printf '\nThe source repository was not modified. Verify the new repository before removing terminal files from the old one.\n'
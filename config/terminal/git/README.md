# Git configuration

- config — colors, aliases, diff/merge tools, user identity, and an optional per-directory include.
- gitignore_global — global ignore patterns referenced by core.excludesfile.

## Platform notes

- The bb alias invokes ~/.local/bin/copy-branch, which the installer links from bin/.
- The clipboard helper prefers clip.exe in WSL, wl-copy on Wayland, xclip on X11, and pbcopy on macOS.
- Git uses the standard less pager by default, so diff-so-fancy is not required.
- No OS-specific credential helper is hardcoded. Configure Git Credential Manager or a distribution-native helper separately if desired.
- The optional includeIf entry points to a local work-specific configuration that is intentionally not tracked.

The configured user.name and user.email are used for new commits. Update them with local Git config if this repository is being reused by another person.

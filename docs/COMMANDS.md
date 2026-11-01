# Command reference

Run commands from the repository root or use the dots symlink installed at ~/.local/bin/dots.

## Install

~~~sh
dots install [--packages|--no-packages] [--yes] [--dry-run] [--default-shell]
~~~

- --packages installs manifest packages for the detected native manager or Nix profile.
- --no-packages skips OS package installation but still downloads Oh My Zsh and its custom plugins.
- --yes answers prompts using each prompt's safe default.
- --dry-run previews configuration links and generated files; it does not clone or install anything.
- --default-shell offers to set Zsh as the login shell. On NixOS, configure this declaratively instead.

Install is idempotent. Existing managed links are retained when already correct. Existing files and directories are backed up before a managed link replaces them.

## Inspect

~~~sh
dots list
dots health
dots --health
~~~

list reports manifest components and tracked downloads/packages. health checks manifest sources, managed links, required CLI commands, generated themes and all expected Zsh runtime components. It is read-only and returns non-zero if a required source is missing.

## Back up and restore

~~~sh
dots backup
dots restore
dots restore latest
dots restore SNAPSHOT_ID
dots restore latest --dry-run
~~~

Snapshots include manifest target paths, personal overrides and the generated tmux theme adapter. Restore first moves currently existing targets into a safety directory. Inspect that safety copy if you need to roll back.

## Uninstall

~~~sh
dots uninstall
dots uninstall --dry-run
dots uninstall --yes
dots uninstall --purge --yes
~~~

Uninstall removes only symlinks still pointing to the exact source recorded by the installer, removes installer-managed downloads only when their expected path and Git origin match, and restores collision backups where the destination is free.

- Native packages are kept by default.
- --purge additionally removes only packages recorded as newly installed by dots.
- Nix profile packages are not removed by this command.
- Modified generated files and manually changed links are preserved.

## Prune

~~~sh
dots prune
dots prune --dry-run
dots prune --yes
~~~

Prune removes broken managed links and stale state records. It does not search for or delete arbitrary files.

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| XDG_CONFIG_HOME | ~/.config | Configuration target root |
| XDG_DATA_HOME | ~/.local/share | Installer state and Oh My Zsh/plugin checkouts |
| XDG_CACHE_HOME | ~/.cache | Zsh and Oh My Zsh caches |
| DOTS_SKIP_DOWNLOADS | 0 | Set to 1 to skip Git downloads |
| DOTS_GIT_CLONE_RETRIES | 3 | Attempts per required Zsh Git checkout |
| DOTS_GIT_CLONE_RETRY_DELAY | 2 seconds | Delay between failed clone attempts |
| DOTS_PLATFORM | uname -s | Test override for platform detection |
| DOTS_OS_RELEASE | /etc/os-release | Test override for Linux distro detection |

See [Installation](INSTALLATION.md), [Zsh setup](ZSH.md), and [Troubleshooting](TROUBLESHOOTING.md).

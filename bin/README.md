# Helper scripts

These scripts are optional convenience commands. They are not required to start Zsh.

| Script | Purpose | Requirements / notes |
|---|---|---|
| `copy-branch` | Copy the current Git branch to the host clipboard when a supported clipboard command is available | Tries Windows `clip.exe`, Wayland `wl-copy`, X11 `xclip`, then macOS `pbcopy`; otherwise prints the branch |
| `did` | Pick a running Docker container and print its ID | Docker CLI and `fzf`; intended for command substitution, e.g. `docker logs "$(did)"` |
| `extract` | Extract common archive formats | Install the relevant extractor for the archive type; default behavior creates a directory first |
| `fzf-preview` | Show a selected file and line with syntax coloring | `bat` |
| `kp` | Pick one or more processes and send a signal | `fzf`; its default signal is `KILL` (signal 9), so selected processes cannot clean up normally |
| `project` | Pick a project directory and change the current Zsh directory | Must be sourced by Zsh; uses `fzf` |

The `project` helper is loaded from `.zshrc` only when `OPEN_PROJECT=1`. It searches immediate child directories under the home directory and common roots such as `~/src`, `~/projects`, `~/Code`, `~/workspaces`, and `~/docker`.

Review scripts before running them with elevated privileges. These are personal helpers, not a security boundary.

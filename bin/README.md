# Helper commands

Executable helpers in this directory are linked to `~/.local/bin/` by `dots install`. They are optional and are not required to start Zsh.

| Command | Purpose | Requirements / notes |
|---|---|---|
| `copy-branch` | Copy the current Git branch to the host clipboard, with a printed fallback. | Tries Windows `clip.exe`, Wayland `wl-copy`, X11 `xclip`, then macOS `pbcopy`. |
| `did` | Pick a running Docker container and print its ID. | Docker CLI and `fzf`; useful for command substitution, e.g. `docker logs "$(did)"`. |
| `extract` | Extract common archive formats. | Install the relevant extractor; default behavior creates a directory first. |
| `fzf-preview` | Preview a selected file and line with syntax coloring. | `bat`. |
| `kp` | Pick one or more processes and send a signal. | `fzf`; defaults to SIGKILL (signal 9), which prevents normal cleanup. Pass `TERM` or `15` for a graceful signal. Kept because it may still be useful. |
| `project` | Define a Zsh project picker and change to the selected directory. | Must be sourced by Zsh; uses `fzf`. Loaded from `.zshrc` only when `OPEN_PROJECT=1`. |
| `dots` | Manifest-driven terminal configuration manager. | Bash; see the root README. |

`project` searches immediate child directories under `$HOME` and common roots such as `~/src`, `~/projects`, `~/Code`, `~/workspaces`, and `~/docker`.

Review scripts before running them with elevated privileges. These are personal helpers, not a security boundary.
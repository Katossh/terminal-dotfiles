# Terminal dotfiles

Cross-distribution terminal configuration and CLI environment managed by `dots`.

## Install

```sh
git clone https://github.com/Katossh/terminal-dotfiles.git "$HOME/terminal-dotfiles"
cd "$HOME/terminal-dotfiles"
./bin/dots install
```

For a preview without changing the system:

```sh
./bin/dots install --dry-run --no-packages --yes
```

The installer links the tracked configuration and can install its declared dependencies through the detected native package manager. On NixOS it can install the same packages into the invoking user's Nix profile, while `nix/packages.nix` remains available for declarative, system-wide installation.

Run `./bin/dots --help` for commands and options. Never run the installer through `sudo`.

# Installation guide

## Requirements

- Bash and the standard userland tools used by the installer.
- Git, for downloading Oh My Zsh and its custom plugins.
- Network access to GitHub for upstream downloads.
- A supported native package manager or Nix only when you also request package installation.

The installer can provision the Zsh framework even if Zsh is not installed yet. On a fresh host, this keeps package installation and configuration bootstrap independent.

## 1. Get the repository

~~~sh
git clone https://github.com/Katossh/terminal-dotfiles.git "$HOME/terminal-dotfiles"
cd "$HOME/terminal-dotfiles"
~~~

Do not run the installer through sudo; it must operate on the invoking user's home and XDG directories.

## 2. Preview

~~~sh
./bin/dots install --dry-run --no-packages --yes
~~~

A dry run displays planned links and generated files. It does not download upstream repositories or install packages.

## 3. Install

~~~sh
# Configurations + Oh My Zsh + custom Zsh plugins; no native package changes.
./bin/dots install --no-packages

# Same configuration/downloads, plus packages declared for this OS.
./bin/dots install --packages
~~~

Without either flag, dots install asks whether recommended packages should be installed when run interactively. A non-interactive invocation defaults to skipping package installation.

--yes answers prompts using their safe defaults. It is not a substitute for --packages; use --packages --yes when package installation is explicitly intended.

## Downloaded Zsh components

Unless DOTS_SKIP_DOWNLOADS=1 is set, the installer downloads:

| Component | Destination | Required payload |
|---|---|---|
| Oh My Zsh | $XDG_DATA_HOME/oh-my-zsh | oh-my-zsh.sh |
| fzf-tab | $XDG_DATA_HOME/zsh/custom/plugins/fzf-tab | fzf-tab.plugin.zsh |
| fast-syntax-highlighting | $XDG_DATA_HOME/zsh/custom/plugins/fast-syntax-highlighting | fast-syntax-highlighting.plugin.zsh |
| zsh-completions | $XDG_DATA_HOME/zsh/custom/plugins/zsh-completions | src/ |

zsh-autosuggestions is included in the Oh My Zsh checkout and activated by the Zsh configuration. The git and z plugins are also built into Oh My Zsh.

The default XDG data directory is ~/.local/share. If XDG_DATA_HOME is set when the installer runs, repositories are installed under that path. Zsh reads the same variable through dots/zshenv.

Every clone uses a temporary staging directory. It is moved into place only after git clone succeeds and the required payload is present. The installer does not overwrite existing directories with an unrecognised Git origin or an incomplete checkout.

Failed clones are retried three times by default. Set DOTS_GIT_CLONE_RETRIES to a positive integer to change the retry count:

~~~sh
DOTS_GIT_CLONE_RETRIES=5 ./bin/dots install --no-packages
~~~

If a required repository still cannot be downloaded, installation exits non-zero and names the failed repository. Fix the network/proxy/TLS issue and rerun the same command; valid checkouts are left in place, and missing repositories are fetched.

## Offline or config-only installation

~~~sh
DOTS_SKIP_DOWNLOADS=1 ./bin/dots install --no-packages
~~~

This links local configuration but intentionally skips upstream Git downloads (including the optional tmux plugin). The shell falls back to native Zsh completion until Oh My Zsh is installed. To complete setup later:

~~~sh
unset DOTS_SKIP_DOWNLOADS
./bin/dots install --no-packages
~~~

## Package managers

The package manifest contains entries for apt, dnf, pacman, zypper, apk, xbps, FreeBSD pkg, Homebrew and Nixpkgs.

- --no-packages: do not invoke the native package manager.
- --packages: install entries matching the detected manager.
- Required packages are requested directly; optional packages are installed only when available.
- Package operations may request administrator privileges through sudo or doas. Configuration linking and Git downloads run as the normal user.

## NixOS

dots install --packages installs declared packages into the current user's Nix profile. It does not modify /etc/nixos, generate a host configuration or execute nixos-rebuild.

For declarative system-wide packages, import nix/packages.nix from the host's NixOS configuration, review the result, then run sudo nixos-rebuild build followed by sudo nixos-rebuild switch. JetBrainsMono Nerd Font is installed declaratively through fonts.packages by the repository's NixOS module. Set the account's login shell in the NixOS configuration, for example:

~~~nix
users.users.<name>.shell = pkgs.zsh;
~~~

For more detail, see the NixOS section in the root README.

## After installation

~~~sh
./bin/dots health
./bin/dots list
~~~

Open a new terminal or start Zsh explicitly:

~~~sh
exec zsh
~~~

If Zsh is already your login shell but Oh My Zsh was missing, rerun dots install --no-packages; package installation is not necessary just to restore the framework.

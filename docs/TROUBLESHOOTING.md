# Troubleshooting

## Oh My Zsh is missing

The message means the interactive shell cannot find:

~~~sh
"$XDG_DATA_HOME/oh-my-zsh/oh-my-zsh.sh"
~~~

The normal repair command is:

~~~sh
dots install --no-packages
~~~

--no-packages skips native package installation but still downloads the framework and plugins. You do not need to reinstall Zsh or every CLI package just to restore Oh My Zsh.

## Confirm installer and shell use the same XDG directory

~~~sh
printf 'XDG_DATA_HOME=%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}"
ls -la "${XDG_DATA_HOME:-$HOME/.local/share}/oh-my-zsh"
~~~

dots/zshenv and the installer use the same default (~/.local/share). If you override XDG_DATA_HOME, make sure it is exported in the environment that launches both the installer and Zsh.

## Inspect repository downloads

~~~sh
data="${XDG_DATA_HOME:-$HOME/.local/share}"
git -C "$data/oh-my-zsh" remote get-url origin
git -C "$data/zsh/custom/plugins/fzf-tab" remote get-url origin
git -C "$data/zsh/custom/plugins/fast-syntax-highlighting" remote get-url origin
git -C "$data/zsh/custom/plugins/zsh-completions" remote get-url origin
~~~

The expected origins are listed in resources/upstream-sources.md.

## GitHub/network failures

The installer retries Zsh clones three times by default and exits non-zero if a required clone still fails. Test connectivity without changing the repository:

~~~sh
git ls-remote https://github.com/ohmyzsh/ohmyzsh.git HEAD
~~~

If this fails, inspect Git proxy/TLS configuration and network access to GitHub. Then rerun:

~~~sh
DOTS_GIT_CLONE_RETRIES=5 dots install --no-packages
~~~

A clone failure is no longer silently ignored. The installer validates that every successful clone contains its expected entry file or directory.

## Existing path or unexpected Git origin

The installer never replaces an existing directory that is not a recognised checkout of the expected upstream. It also refuses to treat a matching-origin checkout as valid when its required payload is missing.

Inspect the directory and its contents before moving it aside. For example:

~~~sh
data="${XDG_DATA_HOME:-$HOME/.local/share}"
mv "$data/oh-my-zsh" "$data/oh-my-zsh.backup"
dots install --no-packages
~~~

Only do this after confirming that the existing directory contains nothing you need. Apply the same care to paths under "$data/zsh/custom/plugins/".

## Downloads were intentionally skipped

If DOTS_SKIP_DOWNLOADS=1 is exported in your environment, upstream downloads are skipped. Unset it for the repair run:

~~~sh
unset DOTS_SKIP_DOWNLOADS
dots install --no-packages
~~~

## Broken prompt glyphs or missing prompt

Starship provides the prompt when its executable is available. Otherwise, the configuration uses a plain Zsh prompt. Nerd Font glyphs require a compatible terminal font; missing glyphs are a font/rendering issue, not an Oh My Zsh download failure.

## Diagnostic command

~~~sh
dots health
~~~

Health checks report missing framework/plugin paths, ordinary command dependencies, changed managed links and generated theme files. The command is read-only.

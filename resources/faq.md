# FAQ (my own reference)

## Docker fails with error creating new backup file '/var/lib/dpkg/status-old?

`echo N | sudo tee /sys/module/overlay/parameters/metacopy`

## `i3` workspace switching screws up PyCharm focus:

`https://intellij-support.jetbrains.com/hc/en-us/community/posts/360001411659-Lose-Focus-after-Switching-Workspace-in-i3wm`

## Default Google Chrome with `i3`

Edit `~/.config/mimeapps.list` and/or 
`~/.local/share/applications/mimeapps.list` and make sure that it looks 
something like this:

```ini
[Default Applications]
x-scheme-handler/mailto=google-chrome.desktop
text/html=google-chrome.desktop
x-scheme-handler/http=google-chrome.desktop
x-scheme-handler/https=google-chrome.desktop
x-scheme-handler/about=google-chrome.desktop
x-scheme-handler/unknown=google-chrome.desktop
```

## Overriding environment variables

If you want to override environment variables without polluting the Git status,
then you can create a new file `config/terminal/zsh/zprofile.local`. This will link that
file to `~/.config/zsh/zprofile.local` and source it inside `profile`. Feel free
to override any environment variables here (for example, monitors).

## To change terminal colors

1. For Kitty, edit `config/terminal/kitty/kitty.conf` and select a file from its `themes/` directory.
2. FZF colors are configured in `dots/zshenv`.

Neovim configuration is not maintained in this repository.


## Slow Yabai controls

Fix slow `yabai` controls by using `dash` as the shell.

* `zsh` is the default shell and is horribly slow, so let's use a faster 
    shell for running `skhd`
* Edit `/usr/local/Cellar/skhd/0.3.4/homebrew.mxcl.skhd.plist`
* Add environment variable `SHELL = /usr/local/bin/dash`
* More info at [this GitHub issue](https://github.com/koekeishiya/chunkwm/issues/232)

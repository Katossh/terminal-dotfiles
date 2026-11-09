# Yazi configuration

Yazi's user configuration is owned by this repository and installed through
`manifest/configs.tsv` as the `yazi` tree component:

- Source: `config/terminal/yazi/`
- Destination: `$XDG_CONFIG_HOME/yazi/` (normally `~/.config/yazi/`)

## Defaults

- **Editor:** the `edit` opener runs `nvim` and blocks until Neovim exits.
  Yazi's shipped open rules continue to send text files and supported code
  formats to the `edit` opener. Other file types retain Yazi's built-in
  handlers; this configuration does not replace the default open rules.
- **Theme:** Catppuccin **Frappé Sapphire**, using the dedicated upstream
  Sapphire variant rather than a generic Frappé theme.
- **Syntax highlighting:** the accompanying
  `Catppuccin-frappe.tmTheme` file gives Yazi's text preview the matching
  Catppuccin Frappé syntax colours.

The theme is vendored from
[catppuccin/yazi](https://github.com/catppuccin/yazi), and its syntax theme is
from [catppuccin/bat](https://github.com/catppuccin/bat). Both upstream
projects are MIT-licensed; the license is included beside the files.

## NixOS integration

Home Manager in the workstation configuration enables Yazi and its Zsh
integration. It supplies the application and the `y` shell wrapper; it does
not generate Yazi settings or theme files. Keep those files in
`terminal-dotfiles` rather than adding competing
`programs.yazi.settings` or `programs.yazi.theme` definitions to Home Manager.

After updating this repository, refresh the pinned `terminal-dotfiles` input
in the NixOS flake and rebuild the Home Manager generation. The `dots`
installer links each file independently and preserves local overrides under
`~/.config/dots/overrides/yazi/`.

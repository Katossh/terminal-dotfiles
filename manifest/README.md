# Configuration and package manifests

`configs.tsv` is the manager's declarative inventory. The CLI does not maintain a second list of components.

Each non-comment row has five tab-separated fields:

| Field | Meaning |
|---|---|
| `component` | Stable component/override namespace. |
| `kind` | `file` for one file, or `tree` for a directory whose files are linked individually. |
| `source` | Path relative to the repository root. |
| `target` | Destination expressed as `home:`, `config:`, `localbin:`, or `data:` plus a relative path. |
| `platform` | `all`, `linux`, `macos`, or `bsd`. |

Example:

```text
kitty    tree    config/terminal/kitty    config:kitty    all
alacritty tree    config/terminal/alacritty config:alacritty all
starship file    config/terminal/starship.toml config:starship.toml all
```

A `tree` entry does not symlink the whole application directory. The manager traverses its files and symlinks, maps each relative path into the destination, and checks for a matching file under `~/.config/dots/overrides/<component>/` first. This is what permits one file to be customized without copying the rest of an application configuration.

`packages.tsv` is the package inventory with three fields: package-manager identifier, package name, and `required` or `optional`. Native package managers use their own package names; `nixpkgs` rows use Nixpkgs attribute names and are consumed by `nix/packages.nix`. Homebrew casks use the `brew-cask` identifier and are installed, checked and tracked separately from formulas. Noto Color Emoji is a required platform font package; the NixOS-specific `nixpkgs-fonts` entry is added to `fonts.packages`. Required packages are requested directly. Optional packages are installed only when available; the NixOS module skips missing optional Nixpkgs attributes. Alacritty is declared as an optional application package. Noto Color Emoji is a required platform font package, with `nixpkgs-fonts` rows resolved into `fonts.packages`.

When adding a component, update this manifest rather than adding another hardcoded component list. The same data is consumed by install, list, health, backup/restore target discovery, and CI source validation.

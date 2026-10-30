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
starship file    config/terminal/starship.toml config:starship.toml all
```

A `tree` entry does not symlink the whole application directory. The manager traverses its files and symlinks, maps each relative path into the destination, and checks for a matching file under `~/.config/dots/overrides/<component>/` first. This is what permits one file to be customized without copying the rest of an application configuration.

`packages.tsv` is a separate package inventory with three fields: package-manager identifier, package name, and `required` or `optional`. Required packages are installed when package installation is selected. Optional packages are installed only when available in the currently configured repositories.

When adding a component, update this manifest rather than adding another hardcoded component list. The same data is consumed by install, list, health, backup/restore target discovery, and CI source validation.
# pmget

> Package Manager Getter — fuzzy search and install packages.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/gabrielmsilva00/pmget/main/pmget | bash -s -- --self-install
```

###### This installs `pmget` to `~/.local/bin` by default. For other locations:

```bash
curl -fsSL https://raw.githubusercontent.com/gabrielmsilva00/pmget/main/pmget | bash -s -- --self-install --usr     # /usr/local/bin (requires sudo)
```

```bash
curl -fsSL https://raw.githubusercontent.com/gabrielmsilva00/pmget/main/pmget | bash -s -- --self-install --root    # /root/.local/bin (requires sudo)
```

**Requires:** `fzf` and one of: `apt`, `dnf`, `pacman`, `zypper`, `apk`

To update, re-run the install command or use `pmget --self-install`.

## Usage

```bash
pmget                    # TUI mode
pmget -s                 # TUI with sudo
pmget -c -i vim htop     # CLI: install packages
pmget -c -r nano         # CLI: remove packages
pmget --info curl        # Show package info
pmget --self-install     # Update pmget itself
```

## Options

| Flag | Description |
|------|-------------|
| `-c, --cli` | CLI mode (non-interactive) |
| `-s, --sudo` | Use sudo |
| `-i PKG` | Packages to install |
| `-r PKG` | Packages to remove |
| `--info PKG` | Show package information |
| `--self-install` | Install/update pmget |
| `-v, --version` | Show version |
| `-h, --help` | Help |

## TUI Controls

| Key | Action |
|-----|--------|
| `↑`/`↓` | Navigate |
| `→`/`←` | Cycle state: none → install → remove |
| `Space` | Toggle selection |
| `Tab` | Toggle sudo |
| `Enter` | Execute |
| `Esc` | Exit |

## States

| Symbol | Meaning |
|--------|---------|
| `[ ]` | Not selected |
| `[✓]` | Installed (blue) |
| `[^]` | Upgradeable (yellow) |
| `[+]` | Marked for install (green) |
| `[-]` | Marked for remove (red) |

## Uninstall

```bash
rm $(which pmget)
```

## License

MIT

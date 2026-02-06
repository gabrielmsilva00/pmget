# pmget

> Package Manager Getter — fuzzy search and install packages.

## Install

To install this utility tool, simply run:
```bash
curl -fsSL https://raw.githubusercontent.com/gabrielmsilva00/pmget/main/install.sh | bash
```
##### This will install `pmget` to `~/.local/bin` by default.

To install system-wide, use the `--usr` or `--root` flags:
```bash
curl ... | bash -s -- --usr     # System-wide install
curl ... | bash -s -- --root    # Root install
```

### Install Options

| Flag | Location | Requires sudo |
|------|----------|---------------|
| `--local` | `~/.local/bin` (default) | No |
| `--usr` | `/usr/local/bin` | Yes |
| `--root` | `/root/.local/bin` | Yes |

```bash
# Examples
curl ... | bash -s -- --local   # User install (default)
curl ... | bash -s -- --usr     # System-wide install
```

**Requires:** `fzf` and one of:
- `pkg` (Termux)
- `nala`
- `apt`
- `dpkg`
- `dnf`
- `yum`
- `pacman`
- `zypper`
- `apk`

## Usage

```bash
pmget              # TUI mode
pmget -s           # TUI with sudo
pmget -c -i vim    # CLI: install vim
pmget -c -r nano   # CLI: remove nano  
pmget -c -s -i git -r vim   # Both operations with sudo
```

## Options

| Flag | Description |
|------|-------------|
| `-c` | CLI mode (non-interactive) |
| `-s` | Use sudo |
| `-i` | Packages to install |
| `-r` | Packages to remove |
| `-v` | Show version |
| `-h` | Help |

## TUI Controls

| Key | Action |
|-----|--------|
| `↑`/`↓` | Navigate |
| `Enter` | Select for install / Execute if selected |
| `→` | Cycle: none → install → remove |
| `←` | Cycle: none → remove → install |
| `?` | Toggle info |
| `Esc` | Exit |

## States

```
[ ]  Not selected
[+]  Install (green)
[-]  Remove (red)
```

## Uninstall

```bash
rm ~/.local/bin/pmget
```

## License

MIT

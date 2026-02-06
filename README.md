# pget

> Universal package manager TUI — install and remove packages with fuzzy search.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/GabrielNSD/Search/main/install.sh | bash
```

**Requires:** `fzf` and one of: apt, dnf, yum, pacman, zypper, apk

## Usage

```bash
pget              # TUI mode
pget -s           # TUI with sudo
pget -c -i vim    # CLI: install vim
pget -c -r nano   # CLI: remove nano  
pget -c -s -i git -r vim   # Both operations with sudo
```

## Options

| Flag | Description |
|------|-------------|
| `-c` | CLI mode (non-interactive) |
| `-s` | Use sudo |
| `-i` | Packages to install |
| `-r` | Packages to remove |
| `-h` | Help |

## TUI Controls

| Key | Action |
|-----|--------|
| `↑`/`↓` | Navigate |
| `Enter` | Mark for install / Execute if marked |
| `→` | Cycle: none → install → remove |
| `←` | Cycle: none → remove → install |
| `Ctrl+Enter` | Execute |
| `?` | Toggle info |
| `Esc` | Exit |

## States

```
[ ]  Not selected
[+]  Install (green)
[-]  Remove (red)
```

## Supported

apt · dnf · yum · pacman · zypper · apk

## Uninstall

```bash
rm ~/.local/bin/pget
```

## License

MIT

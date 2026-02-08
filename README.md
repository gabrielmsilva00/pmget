# pmget - Package Manager Getter

`pmget` is a wrapper for Linux system package managers, providing a unified TUI (Text User Interface) for searching, installing, and removing packages across multiple distributions. It supports `nala` (preferred), `apt`, `dnf`, `pacman`, `zypper`, and `apk`.

![pmget TUI](https://raw.githubusercontent.com/gabrielmsilva00/pmget/main/assets/preview.png)

## Features

- **Unified Interface**: Works with multiple package managers seamlessly.
- **Interactive TUI**: Browse, search, and manage packages with ease.
- **CLI Mode**: Scriptable operations for quick installs/removals.
- **Self-Contained**: Single bash script with minimal dependencies (`curl`, `fzf`).

## Installation

You can install `pmget` with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/gabrielmsilva00/pmget/main/pmget | bash -s -- --self-install
```

This will install `pmget` to `~/.local/bin` and add it to your PATH if necessary.

### Manual Installation

Alternatively, you can download the script manually:

```bash
wget https://raw.githubusercontent.com/gabrielmsilva00/pmget/main/pmget
chmod +x pmget
mv pmget /usr/local/bin/  # Or any directory in your PATH
```

## Usage

### TUI Mode (Interactive)

Simply run `pmget` to launch the interactive interface:

```bash
pmget
```

#### Navigation & Shortcuts

| Key | Action |
| --- | --- |
| `↑` / `↓` | Navigate list |
| `Space` | Toggle selection / Cycle state (Install/Remove/Upgrade) |
| `Enter` | Apply changes |
| `Tab` | Toggle Sudo |
| `Ctrl+V` / `Alt+V` | Toggle Package Info Preview |
| `Ctrl+T` / `Alt+T` | Jump to Top of list |
| `Ctrl+B` / `Alt+B` | Jump to Bottom of list |
| `Esc` | Go back / Exit |

**Search**: Type to filter packages instantly.
**Commands**:
- `:i` - Show installed packages only
- `:u` - Show upgradeable packages only
- `:` - Show all packages (clear filter)

### CLI Mode (Scripting)

Use flags to perform operations directly:

```bash
# Install packages
pmget -c -i vim htop

# Remove packages
pmget -c -r nano

# use Sudo
pmget -c -s -i docker

# Update cache
pmget -u
```

### Flags & Options

| Flag | Description |
| --- | --- |
| `-c`, `--cli` | Enable CLI mode (non-interactive) |
| `-s`, `--sudo` | Use `sudo` for operations |
| `-u`, `--update` | Update package manager cache |
| `--show [a/i/u]` | Show mode: (a)ll, (i)nstalled, (u)pgradeable |
| `-i [PKG]`, `--install` | Install package(s) |
| `-r [PKG]`, `--remove` | Remove package(s) |
| `--info [PKG]` | Show detailed package info |
| `--self-upgrade` | Update `pmget` to the latest version |
| `--self-install` | Install `pmget` to system |
| `-v`, `--version` | Show version |
| `-h`, `--help` | Show help message |

## Requirements

- `bash` (4.0+)
- `curl`
- `fzf`
- A supported package manager: `apt`, `nala`, `dnf`, `pacman`, `zypper`, or `apk`.

## License

Apache-2.0
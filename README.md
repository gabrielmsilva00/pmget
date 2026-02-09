# pmget - Package Manager Getter

`pmget` is a wrapper for Linux system package managers, providing a unified TUI (Text User Interface) for searching, installing, and removing packages across multiple distributions. It supports `nala` (preferred), `apt`, `dnf`, `pacman`, `zypper`, and `apk`.

![pmget Install](https://raw.githubusercontent.com/gabrielmsilva00/pmget/main/assets/install.webp)
![pmget TUI](https://raw.githubusercontent.com/gabrielmsilva00/pmget/main/assets/tui.webp)
![pmget Work(https://raw.githubusercontent.com/gabrielmsilva00/pmget/main/assets/work.webp)

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

This will install `pmget` to `~/.local/bin`, detech and fetch an updated cache of your package manager, and run the application.
For alternative install locations you can:

> Append `--usr` to install to `/usr/local/bin`
```bash
curl -fsSL https://raw.githubusercontent.com/gabrielmsilva00/pmget/main/pmget | bash -s -- --self-install --usr
```

> Append `--root` to install to `/root/.local/bin`
```bash
curl -fsSL https://raw.githubusercontent.com/gabrielmsilva00/pmget/main/pmget | bash -s -- --self-install --root
```

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
| `Space`/`←`/`→` | Toggle selection / Cycle state (Install/Remove/Upgrade) |
| `Enter` | Apply changes |
| `Tab` | Toggle Sudo |
| `Ctrl+V` / `Alt+V` | Toggle Package Info Preview |
| `Ctrl+T` / `Alt+T` | Jump to Top of list |
| `Ctrl+B` / `Alt+B` | Jump to Bottom of list |
| `Esc` | Go back / Exit |

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

CLI mode is used internally to execute the commands needed from TUI; Its usage is available but disencouraged: prefer the TUI mode.

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
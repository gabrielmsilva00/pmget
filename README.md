# pmget - Package Manager Getter

`pmget` provides a unified TUI (Text User Interface) for browsing, installing, removing, and upgrading packages on Linux, macOS, and Windows. It supports `nala`, `apt`, `dnf`, `pacman`, `zypper`, `apk`, Homebrew (`brew`), WinGet (`winget`), and Chocolatey (`choco`).

##### TLDR Install & Upgrade command:
```bash
curl -fsSL https://raw.githubusercontent.com/gabrielmsilva00/pmget/main/pmget | bash -s -- --self-install
```

![pmget Install](https://raw.githubusercontent.com/gabrielmsilva00/pmget/main/assets/install.webp)
![pmget TUI](https://raw.githubusercontent.com/gabrielmsilva00/pmget/main/assets/tui.webp)
![pmget Work](https://raw.githubusercontent.com/gabrielmsilva00/pmget/main/assets/work.webp)

> This utility tool was HEAVILY inspired by [Hydra0xetc's Search utility tool](https://github.com/Hydra0xetc/Search), be sure to check their work out too!

## Features

- **Unified Interface**: Works with multiple package managers seamlessly.
- **Interactive TUI**: Browse, search, and manage packages with ease.
- **CLI Mode**: Scriptable operations for quick installs/removals.
- **Cross-Platform**: Linux, macOS with Bash 4+, and Windows through Git Bash.
- **Manager Selection**: Choose a backend with `--pm` or the `PMGET_PM` environment variable.
- **Dependency Setup**: Offers to install missing dependencies using the selected package manager, then continues after checking the installation.
- **Self-Contained**: Single Bash implementation with minimal dependencies (`bash` & `fzf`; optionally `curl`) and native Windows launchers.

## Installation

You can install `pmget` with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/gabrielmsilva00/pmget/main/pmget | bash -s -- --self-install
```

This will install `pmget` to `~/.local/bin` and fetch an updated cache of your package manager, and run the application.
Refreshing Linux system package-manager metadata uses `sudo` when needed, including for a local installation; root, Homebrew, WinGet, and Chocolatey run without Unix sudo. If the initial update or startup fails, the installer keeps pmget installed, reports the failure, and exits with a nonzero status. Run `pmget -u` to retry.
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
pmget --self-install
# OR
mv pmget /usr/local/bin/  # Or any directory in your PATH
```

### Windows (PowerShell, CMD, and Git Bash)

Keep `pmget`, `pmget.ps1`, and `pmget.cmd` in the same folder (clone the repository or download all three files). You can launch from PowerShell:

```powershell
.\pmget.ps1 --pm winget
.\pmget.ps1 --pm choco -c --upgrade git
.\pmget.ps1 --wsl
```

Or from Command Prompt:

```bat
pmget.cmd --pm winget
pmget.cmd --pm choco
pmget.cmd --wsl --pm apt
```

`pmget.cmd` also works in PowerShell, including when its execution policy blocks direct `.ps1` invocation. It uses the bundled Windows PowerShell with a process-scoped execution policy; it does not change your saved policy. Add the folder containing these files to your Windows `PATH` to use `pmget.cmd` from other directories. The launchers preserve the current directory, console input/output, arguments, and exit status.

For Windows package managers, install [Git for Windows](https://git-scm.com/downloads/win) and have either WinGet or Chocolatey available in `PATH`. If `fzf` is missing, pmget offers to install it with the selected manager (`junegunn.fzf` with WinGet, or `fzf` with Chocolatey). The launchers locate Git Bash through Git's registry entries, installed Git, or common installation folders. Set `PMGET_BASH` to a full `bash.exe` path for a custom runtime. The `--wsl` launcher mode starts WSL directly and does not require Git Bash.

You can also install the TUI dependency manually from PowerShell or CMD:

```powershell
winget install --id junegunn.fzf --exact --source winget
.\pmget.ps1
```

Alternatively, use `choco install fzf` from an elevated terminal. Standard WinGet, Scoop, Chocolatey, and `~/.fzf/bin` locations are checked, including after accepting an installation prompt in an already-open PowerShell. CLI operations (`-c`) do not require `fzf`. With `--wsl`, dependencies are checked and installed inside the Linux distribution using its selected manager.

You can also run `pmget` from Git Bash. The curl installer above installs the Bash script; use the default `--local` installation location. For PowerShell/CMD, keep the two Windows launcher files beside that installed script as well.

```bash
pmget --pm winget
pmget --pm choco
pmget --pm winget -c -i Git.Git
pmget --pm choco -c --upgrade git
```

Windows auto-detection prefers WinGet, then Chocolatey. WinGet uses the `winget` community source and exact package IDs; Microsoft Store packages are not included. WinGet handles installer elevation itself. Run Git Bash as Administrator for Chocolatey operations that require it. `--sudo` and the TUI sudo toggle are inactive for these backends.

To run `pmget` **inside WSL**, add `--wsl` to any launcher. From Git Bash:

```bash
pmget --wsl
pmget --wsl --pm apt
pmget --wsl --pm apt -c -i vim
bash ./pmget --wsl --self-install
```

This launches the same saved script in the default WSL distribution and forwards all other arguments, including `--pm`, `--info`, and installer options. It uses the Linux package managers and dependencies inside that distribution, so Bash 4+ and `fzf` must be available there for the TUI. `PMGET_PM` is forwarded as well; `--pm` still takes precedence. A failed WSL launch returns an error without continuing in Windows. Inside WSL/Linux, `--wsl` is a no-op, preventing repeated launches.

WSL and a Linux distribution must already be installed. When starting from Windows, `--wsl` requires a saved script; download `pmget` before invoking this option instead of piping it to Bash.

### Homebrew (macOS and Linux)

Use Bash 4 or newer; the Bash bundled with macOS is too old. With Homebrew, install the requirements using `brew install bash fzf` and launch `pmget` with the Homebrew Bash on your `PATH` (or use `"$(brew --prefix)/bin/bash" ./pmget`). Run the curl installer with that Bash as well.

```bash
pmget --pm brew
pmget --pm brew -c -i formula:wget
pmget --pm brew -c --upgrade cask:firefox
```

The TUI prefixes Homebrew entries with `formula:` and `cask:` to distinguish packages with the same name. Casks are included on macOS. Plain Homebrew names also work in CLI mode. Catalog entries show installed versions when available; use the info preview to inspect an uninstalled package's version. Homebrew runs without `sudo` and handles any cask elevation itself.

On macOS auto-detection prefers Homebrew. On Linux it prefers the system package manager. Set `PMGET_PM=brew` (or another supported manager) in your shell profile to choose a persistent default; `--pm` overrides it.

## Usage

### TUI Mode (Interactive)

Simply run `pmget` to launch the interactive interface:

```bash
pmget
```

The `SPEC` header shows the current operating system and selected package manager, for example `SPEC Windows | winget`, `SPEC macOS | brew`, or `SPEC Linux (WSL) | apt`.

Catalog results are cached for one hour. Installed packages are queried on every launch; upgrade checks are cached for up to 60 seconds and refreshed immediately when the installed inventory changes. Use `pmget --refresh` to bypass these caches, or `pmget -u` to update the package-manager metadata and refresh the next catalog load. Installed-only and upgradeable-only views skip the full remote catalog.

The cache defaults to `${XDG_CACHE_HOME:-$HOME/.cache}/pmget`; set `PMGET_CACHE_DIR` to use another location. Failed queries never replace valid cached results. Successful previews and formatted package rows are reused within the current session, and rapid scrolling waits briefly before requesting detailed package information. Reloads replace the list as a complete batch, keeping it visible while selections update.

#### Navigation & Shortcuts

| Key | Action |
| --- | --- |
| `↑` / `↓` | Navigate list |
| `Space`/`←`/`→` | Toggle selection / Cycle state (Install/Remove/Upgrade) |
| `Enter` | Apply changes |
| `Tab` | Toggle Sudo (Linux system managers) |
| `Ctrl+V` / `Alt+V` | Toggle Package Info Preview |
| `Ctrl+T` / `Alt+T` | Jump to Top of list |
| `Ctrl+B` / `Alt+B` | Jump to Bottom of list |
| `Ctrl+U` / `Alt+U` | Select all available upgrades |
| `Esc` | Go back / Exit |

### CLI Mode (Scripting)

Use flags to perform operations directly:

```bash
# Install packages
pmget -c -i vim htop

# Remove packages
pmget -c -r nano

# Upgrade selected packages
pmget --pm winget -c --upgrade Git.Git

# use Sudo
pmget -c -s -i docker

# Update cache
pmget -u
```

CLI mode is used internally to execute the commands needed from TUI; Its usage is available but discouraged: prefer using the TUI mode directly.

### Flags & Options

| Flag | Description |
| --- | --- |
| `-c`, `--cli` | Enable CLI mode (non-interactive) |
| `--pm MANAGER` | Choose a package manager (overrides `PMGET_PM`) |
| `--wsl` | On Windows, execute inside the default WSL distribution |
| `--refresh` | Bypass the catalog and upgrade-check caches |
| `-s`, `--sudo` | Use `sudo` for operations |
| `-u`, `--update` | Update package manager cache |
| `--show [a/i/u]` | Show mode: (a)ll, (i)nstalled, (u)pgradeable |
| `-i [PKG]`, `--install` | Install package(s) |
| `-r [PKG]`, `--remove` | Remove package(s) |
| `--upgrade [PKG]` | Upgrade selected package(s) |
| `--info [PKG]` | Show detailed package info |
| `--self-upgrade` | Update `pmget` to the latest version |
| `--self-install` | Install `pmget` to system |
| `-v`, `--version` | Show version |
| `-h`, `--help` | Show help message |

## Requirements

When a required `fzf` (TUI) or `curl` (installer/self-upgrade) is missing, pmget prompts `Install ... using MANAGER? [y/N]`. Installation requires an explicit `y` or `yes`; declining, EOF, or a non-interactive run exits with guidance. A successful install is checked before continuing. Linux system managers use `sudo` when needed; Homebrew and Windows managers handle their own privileges. Bash, standard Unix utilities, and a supported package manager must already be available to start pmget. Optional background update checks do not prompt for dependencies.

- `bash` (4.0+)
- `curl` (to install and fetch newest version; Optional)
- `fzf` 0.36+ (TUI mode; CLI operations do not require it)
- A supported package manager: `apt`, `nala`, `dnf`, `pacman`, `zypper`, `apk`, `brew`, `winget`, or Chocolatey CLI 2+ (`choco`).
- Standard Unix utilities supplied by Linux/macOS or Git Bash on Windows (`awk`, `sed`, `sort`, `mktemp`, etc.).

## Development

Run the isolated backend checks without installing or removing packages:

```bash
bash -n pmget
bash tests/backends.sh
bash tests/dependencies.sh
bash tests/installer.sh
# On Linux/macOS/WSL, also exercise the real terminal prompt:
python3 tests/dependency-prompts.py
```

The tests cover detection, command routing, WSL forwarding, output parsing, dependency consent and installation failures, and TUI helper generation. Backend and dependency checks run in CI on Linux, macOS, and Windows (Git Bash). On Windows, also run the launcher tests:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/windows-launchers.ps1
```

These exercise PowerShell 5.1, PowerShell 7 when available, and CMD with a native argument-capture fixture. They check quoting, paths containing spaces, empty arguments, WSL dispatch, and exit codes without changing installed packages. Native package installation requires testing on the corresponding operating system.

## Roadmap

The utility tool itself is in a perfectly working state AFAIK.

However, I still plan on:

- [x] Support WinGet, Chocolatey, and Homebrew
- [ ] Bugfixes (no currently known bugs, but we can never be 100% sure)

## License

Apache-2.0

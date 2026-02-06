#!/usr/bin/env bash
set -e

# Colors (fallback to empty if tput unavailable)
B=$(tput bold 2>/dev/null) || B=""
R=$(tput sgr0 2>/dev/null) || R=""
G=$(tput setaf 2 2>/dev/null) || G=""
E=$(tput setaf 1 2>/dev/null) || E=""
C=$(tput setaf 6 2>/dev/null) || C=""
Y=$(tput setaf 3 2>/dev/null) || Y=""

URL="https://raw.githubusercontent.com/gabrielmsilva00/pget/main"
PM=""
INSTALL_MODE=""
NEED_SUDO=false

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --root|--usr|--local)
            [[ -n "$INSTALL_MODE" ]] && { echo "${E}Error: Only one of --root, --usr, --local allowed${R}"; exit 1; }
            INSTALL_MODE="${arg#--}"
            ;;
        -h|--help)
            echo "Usage: install.sh [--root | --usr | --local]"
            echo "  --local  Install to ~/.local/bin (default)"
            echo "  --usr    Install to /usr/local/bin (requires sudo)"
            echo "  --root   Install to /root/.local/bin (requires sudo)"
            exit 0
            ;;
        *)
            echo "${E}Unknown option: $arg${R}"; exit 1
            ;;
    esac
done

# Set install directory based on mode
case "${INSTALL_MODE:-local}" in
    local) DIR="$HOME/.local/bin" ;;
    usr)   DIR="/usr/local/bin"; NEED_SUDO=true ;;
    root)  DIR="/root/.local/bin"; NEED_SUDO=true ;;
esac

echo "${B}${C}pget installer${R}"
echo "${C}Target:${R} $DIR"
echo

# Detect package manager first (required for dependency installation)
for p in apt dnf yum pacman zypper apk; do
    command -v "$p" &>/dev/null && { PM="$p"; break; }
done

[[ -z "$PM" ]] && { echo "${E}No supported package manager (apt, dnf, yum, pacman, zypper, apk)${R}"; exit 1; }
echo "${G}✓${R} Package manager: $PM"

# Helper to install a package
pkg_install() {
    local pkg="$1"
    echo "${Y}→${R} Installing $pkg..."
    case "$PM" in
        apt)    sudo apt update -qq && sudo apt install -y "$pkg" ;;
        dnf)    sudo dnf install -y "$pkg" ;;
        yum)    sudo yum install -y "$pkg" ;;
        pacman) sudo pacman -S --noconfirm "$pkg" ;;
        zypper) sudo zypper install -y "$pkg" ;;
        apk)    sudo apk add "$pkg" ;;
    esac
}

# Check and install dependencies
check_dep() {
    local cmd="$1" pkg="${2:-$1}"
    if command -v "$cmd" &>/dev/null; then
        echo "${G}✓${R} $cmd"
    else
        echo "${Y}!${R} $cmd not found"
        pkg_install "$pkg" || { echo "${E}Failed to install $pkg${R}"; exit 1; }
        echo "${G}✓${R} $cmd installed"
    fi
}

# Core dependencies
check_dep curl

# fzf package name varies by distro
FZF_PKG="fzf"
check_dep fzf "$FZF_PKG"

# ncurses (for tput) - package name varies
case "$PM" in
    apt)    NCURSES_PKG="ncurses-bin" ;;
    dnf|yum) NCURSES_PKG="ncurses" ;;
    pacman) NCURSES_PKG="ncurses" ;;
    zypper) NCURSES_PKG="ncurses-utils" ;;
    apk)    NCURSES_PKG="ncurses" ;;
esac
if ! command -v tput &>/dev/null; then
    echo "${Y}!${R} tput not found"
    pkg_install "$NCURSES_PKG" || { echo "${E}Failed to install ncurses${R}"; exit 1; }
    echo "${G}✓${R} tput installed"
else
    echo "${G}✓${R} tput"
fi

echo

# Install pget
if [[ "$NEED_SUDO" == true ]]; then
    sudo mkdir -p "$DIR"
    curl -fsSL "$URL/pget" | sudo tee "$DIR/pget" > /dev/null && sudo chmod +x "$DIR/pget" || { echo "${E}Download failed${R}"; exit 1; }
else
    mkdir -p "$DIR"
    curl -fsSL "$URL/pget" -o "$DIR/pget" && chmod +x "$DIR/pget" || { echo "${E}Download failed${R}"; exit 1; }
fi
echo "${G}✓${R} Installed to $DIR/pget"

# Configure PATH (skip for system directories - already in PATH)
if [[ "$NEED_SUDO" == false && ":$PATH:" != *":$DIR:"* ]]; then
    SHELL_NAME=$(basename "$SHELL")
    case "$SHELL_NAME" in
        zsh)  RC="$HOME/.zshrc" ;;
        bash) RC="${HOME}/.bashrc"; [[ ! -f "$RC" ]] && RC="$HOME/.profile" ;;
        *)    RC="$HOME/.profile" ;;
    esac
    
    LINE="export PATH=\"\$PATH:$DIR\""
    if [[ -f "$RC" ]] && grep -qF "$DIR" "$RC" 2>/dev/null; then
        echo "${G}✓${R} PATH already configured in $RC"
    else
        echo "$LINE" >> "$RC"
        echo "${G}✓${R} Added to PATH in $RC"
        echo "${C}Note:${R} Restart your shell or run: source ~/${RC##*/}"
        export PATH="$PATH:$DIR"
    fi
fi

echo -e "\n${G}Done!${R} Run: pget"

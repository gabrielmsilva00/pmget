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
INSTALL_MODE=""
NEED_SUDO=false
MISSING_DEPS=()

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

# Check for existing pget
EXISTING_PGET=$(command -v pget 2>/dev/null) || true
if [[ -n "$EXISTING_PGET" ]]; then
    # Check if it's our pget by looking for signature
    if grep -q "github.com/gabrielmsilva00/pget" "$EXISTING_PGET" 2>/dev/null; then
        CURRENT_VER=$("$EXISTING_PGET" -v 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "?")
        echo "${C}→${R} Updating pget v${CURRENT_VER}"
    else
        echo "${Y}⚠${R} Different 'pget' found: $EXISTING_PGET"
        echo "  Will install to: $DIR/pget"
    fi
    echo
fi

# Check dependencies (no auto-install)
command -v curl &>/dev/null && echo "${G}✓${R} curl" || { echo "${E}✗${R} curl (required)"; MISSING_DEPS+=("curl"); }
command -v fzf &>/dev/null && echo "${G}✓${R} fzf" || { echo "${E}✗${R} fzf (required)"; MISSING_DEPS+=("fzf"); }

PM=""
for p in pkg nala apt dpkg dnf yum pacman zypper apk; do
    command -v "$p" &>/dev/null && { PM="$p"; echo "${G}✓${R} $p"; break; }
done
[[ -z "$PM" ]] && { echo "${E}✗${R} package manager (pkg/nala/apt/dpkg/dnf/yum/pacman/zypper/apk)"; MISSING_DEPS+=("package-manager"); }

# Exit if missing dependencies
if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    echo
    echo "${E}Missing dependencies:${R} ${MISSING_DEPS[*]}"
    echo "Please install them and re-run the installer."
    exit 1
fi

echo

# Create directory
if [[ "$NEED_SUDO" == true ]]; then
    sudo mkdir -p "$DIR"
else
    mkdir -p "$DIR"
fi

# Download pget
TMPFILE=$(mktemp)
if ! curl -fsSL "$URL/pget" -o "$TMPFILE"; then
    echo "${E}Download failed${R}"
    rm -f "$TMPFILE"
    exit 1
fi

# Verify download (check it's not empty and contains our signature)
if [[ ! -s "$TMPFILE" ]] || ! grep -q "github.com/gabrielmsilva00/pget" "$TMPFILE"; then
    echo "${E}Download invalid or corrupted${R}"
    rm -f "$TMPFILE"
    exit 1
fi

# Install
if [[ "$NEED_SUDO" == true ]]; then
    sudo mv "$TMPFILE" "$DIR/pget"
    sudo chmod +x "$DIR/pget"
else
    mv "$TMPFILE" "$DIR/pget"
    chmod +x "$DIR/pget"
fi

echo "${G}✓${R} Installed to $DIR/pget"

# Print PATH instructions if needed (don't modify shell config)
if [[ "$NEED_SUDO" == false && ":$PATH:" != *":$DIR:"* ]]; then
    echo
    echo "${C}Add to PATH:${R}"
    echo "  export PATH=\"\$PATH:$DIR\""
fi

echo -e "\n${G}Done!${R} Run: pget"

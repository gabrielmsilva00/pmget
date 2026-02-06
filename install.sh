#!/usr/bin/env bash
set -e

B=$(tput bold 2>/dev/null) || B=""
R=$(tput sgr0 2>/dev/null) || R=""
G=$(tput setaf 2 2>/dev/null) || G=""
E=$(tput setaf 1 2>/dev/null) || E=""
C=$(tput setaf 6 2>/dev/null) || C=""

URL="https://raw.githubusercontent.com/gabrielmsilva00/pget/main"
DIR="$HOME/.local/bin"

echo "${B}${C}pget installer${R}"
echo

command -v fzf &>/dev/null || { echo "${E}fzf required${R}"; exit 1; }
echo "${G}✓${R} fzf"

for pm in apt dnf yum pacman zypper apk; do
    command -v "$pm" &>/dev/null && { echo "${G}✓${R} $pm"; break; }
done

mkdir -p "$DIR"
curl -fsSL "$URL/pget" -o "$DIR/pget" && chmod +x "$DIR/pget" || { echo "${E}Download failed${R}"; exit 1; }
echo "${G}✓${R} Installed to $DIR/pget"

if [[ ":$PATH:" != *":$DIR:"* ]]; then
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

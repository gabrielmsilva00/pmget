#!/usr/bin/env bash
set -e

B=$(tput bold 2>/dev/null) || B=""
R=$(tput sgr0 2>/dev/null) || R=""
G=$(tput setaf 2 2>/dev/null) || G=""
E=$(tput setaf 1 2>/dev/null) || E=""
C=$(tput setaf 6 2>/dev/null) || C=""

URL="https://raw.githubusercontent.com/GabrielNSD/Search/main"
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

[[ ":$PATH:" != *":$DIR:"* ]] && echo -e "\n${C}Add to PATH:${R}\n  export PATH=\"\$PATH:$DIR\""

echo -e "\n${G}Done!${R} Run: pget"

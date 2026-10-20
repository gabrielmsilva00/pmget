#!/usr/bin/env bash
# Isolated backend tests: no package installation or system changes.
set -eo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./pmget
TEST_DIR=$(mktemp -d)
export PMGET_CACHE_DIR="$TEST_DIR/cache"
trap 'rm -rf "$TEST_DIR"' EXIT
LOG="$TEST_DIR/commands"
export LOG
checks=0

assert_eq() {
    if [[ "$1" != "$2" ]]; then
        printf 'FAIL: %s\nExpected: %q\nActual:   %q\n' "$3" "$2" "$1" >&2
        exit 1
    fi
    checks=$((checks + 1))
}

# Keep the curl | bash installation entry point working after adding sourcing.
assert_eq "$(cat ./pmget | TERM=dumb "$BASH" -s -- --version)" "pmget v$VERSION" 'piped script entry point'

record() { printf '<%s>' "$@" >> "$LOG"; printf '\n' >> "$LOG"; }
winget() { record "$@"; [[ "$*" != *Broken.Package* ]]; }
choco() { record "$@"; return "${CHOCO_STATUS:-0}"; }
brew() { record "$@"; }
sudo() { echo 'Unexpected sudo invocation' >&2; return 1; }

uname() {
    case "$1" in
        -r) echo "${TEST_RELEASE:-generic}" ;;
        *) echo "${TEST_OS:-Linux}" ;;
    esac
}
for pair in 'MINGW64_NT-10.0 Windows' 'MSYS_NT-10.0 Windows' 'CYGWIN_NT-10.0 Windows' 'Darwin macOS' 'Linux Linux'; do
    read -r TEST_OS expected <<< "$pair"
    assert_eq "$(WSL_DISTRO_NAME= WSL_INTEROP= os_label)" "$expected" "OS label on $TEST_OS"
done
TEST_OS=Linux
assert_eq "$(WSL_DISTRO_NAME=Ubuntu os_label)" 'Linux (WSL)' 'WSL environment OS label'
assert_eq "$(WSL_DISTRO_NAME= WSL_INTEROP= TEST_RELEASE=6.6.87.2-microsoft-standard-WSL2 os_label)" 'Linux (WSL)' 'WSL kernel OS label'

# WSL dispatch runs before local actions, preserves argument boundaries and
# exit status, and never falls back to native Windows operations on failure.
cygpath() { printf '%s\n' 'C:\Users\Test User\pmget'; }
wsl.exe() {
    record "$1" "$2" "$3" "$5" "$6" "${@:7}"
    assert_eq "$MSYS_NO_PATHCONV:$MSYS2_ARG_CONV_EXCL" '1:*' 'WSL argument conversion disabled'
    return "${WSL_STATUS:-0}"
}
TEST_OS=MINGW64_NT-10.0; : > "$LOG"
(PMGET_PM=brew; forward_to_wsl --pm apt --wsl -c -i 'package with spaces' 'literal;$(echo unsafe)' --wsl)
assert_eq "$(cat "$LOG")" '<--exec><bash><-c><pmget-wsl><C:\Users\Test User\pmget><brew><--pm><apt><-c><-i><package with spaces><literal;$(echo unsafe)>' 'WSL arguments and script path'
: > "$LOG"
forward_to_wsl -c
assert_eq "$(cat "$LOG")" '' 'native Windows without --wsl'
WSL_STATUS=42
status=0; (main --help --wsl) || status=$?
assert_eq "$status" 42 'WSL exit code and dispatch before help'
WSL_STATUS=0
command() {
    [[ "$1:$2" == '-v:wsl.exe' ]] && return 1
    builtin command "$@"
}
status=0; (main --wsl -c) 2>/dev/null || status=$?
assert_eq "$status" 1 'missing WSL fails without native fallback'
unset -f command
for TEST_OS in Linux Darwin; do
    : > "$LOG"; forward_to_wsl --wsl -c
    assert_eq "$(cat "$LOG")" '' "no WSL relaunch on $TEST_OS"
done
parse_args --wsl
unset -f cygpath wsl.exe

# Platform-aware detection and explicit selection, without depending on host PMs.
command() {
    if [[ "$1" == -v ]]; then
        case "$2" in
            winget|choco|brew|apt) printf '/mock/%s\n' "$2"; return 0 ;;
            nala|dnf|pacman|zypper|apk) return 1 ;;
        esac
    fi
    builtin command "$@"
}
for pair in 'Linux apt' 'Darwin brew' 'MINGW64_NT-10.0 winget' 'CYGWIN_NT-10.0 winget'; do
    read -r TEST_OS expected <<< "$pair"
    DETECTED_PM=''; REQUESTED_PM=''; detect_pm
    assert_eq "$DETECTED_PM" "$expected" "detection on $TEST_OS"
done
REQUESTED_PM=choco; DETECTED_PM=''; detect_pm
assert_eq "$DETECTED_PM" choco 'explicit backend selection'
REQUESTED_PM=invalid; DETECTED_PM=''
if detect_pm 2>/dev/null; then echo 'Invalid manager accepted' >&2; exit 1; fi
unset -f command

# Unattended runs report missing dependencies without installing anything.
command() {
    [[ "$1:$2" == '-v:fzf' ]] && return 1
    builtin command "$@"
}
TEST_OS=MINGW64_NT-10.0; DETECTED_PM=winget
status=0; message=$(require_fzf </dev/null 2>&1) || status=$?
assert_eq "$status" 1 'missing fzf exits with failure'
[[ "$message" == *'package: junegunn.fzf; manager: winget'* && "$message" == *'No interactive terminal'* ]] || { echo 'Missing Windows dependency guidance' >&2; exit 1; }
checks=$((checks + 1))
TEST_OS=Linux; DETECTED_PM=apt
status=0; message=$(require_fzf </dev/null 2>&1) || status=$?
[[ "$message" == *'package: fzf; manager: apt'* ]] || { echo 'Missing Linux dependency guidance' >&2; exit 1; }
checks=$((checks + 1))
unset -f command

parse_args --info Git.Git --pm winget
assert_eq "$REQUESTED_PM:$INFO_PKG" 'winget:Git.Git' '--pm after --info'
INFO_PKG=''; parse_args -c --upgrade Git.Git Microsoft.PowerShell
assert_eq "${UPGRADE_PKGS[*]}" 'Git.Git Microsoft.PowerShell' 'upgrade argument collection'

# Exact IDs, multiple packages, failure aggregation, and no Unix sudo.
DETECTED_PM=winget; USE_SUDO=true; : > "$LOG"
run_pm install Git.Git Microsoft.PowerShell
assert_eq "$(cat "$LOG")" $'<install><--id><Git.Git><--exact><--source><winget><--accept-source-agreements><--disable-interactivity><--accept-package-agreements>\n<install><--id><Microsoft.PowerShell><--exact><--source><winget><--accept-source-agreements><--disable-interactivity><--accept-package-agreements>' 'WinGet install exact IDs'
: > "$LOG"; run_pm remove Git.Git
assert_eq "$(cat "$LOG")" '<uninstall><--id><Git.Git><--exact><--source><winget><--accept-source-agreements><--disable-interactivity>' 'WinGet removal flags'
: > "$LOG"; run_pm upgrade Git.Git
assert_eq "$(cat "$LOG")" '<upgrade><--id><Git.Git><--exact><--source><winget><--accept-source-agreements><--disable-interactivity><--accept-package-agreements>' 'WinGet upgrade'
: > "$LOG"
if run_pm install Broken.Package Git.Git; then echo 'Failure was swallowed' >&2; exit 1; fi
assert_eq "$(wc -l < "$LOG" | tr -d ' ')" 2 'continue after failed package'

DETECTED_PM=choco; : > "$LOG"
run_pm install git 7zip; run_pm remove git; run_pm upgrade 7zip
assert_eq "$(cat "$LOG")" $'<install><git><7zip><--yes><--no-progress>\n<uninstall><git><--yes><--no-progress>\n<upgrade><7zip><--yes><--no-progress>' 'Chocolatey operations'
for CHOCO_STATUS in 105 194; do run_pm install git; done
CHOCO_STATUS=1
if run_pm install git; then echo 'Chocolatey failure was swallowed' >&2; exit 1; fi
CHOCO_STATUS=0

DETECTED_PM=brew; : > "$LOG"
run_pm install formula:wget cask:firefox; run_pm remove cask:firefox; run_pm upgrade formula:wget
assert_eq "$(cat "$LOG")" $'<install><--formula><wget>\n<install><--cask><firefox>\n<uninstall><--cask><firefox>\n<upgrade><--formula><wget>' 'Homebrew formula/cask routing'

# Existing Linux backends still route package upgrades correctly.
apt() { record apt "$@"; }
nala() { record nala "$@"; }
dnf() { record dnf "$@"; }
pacman() { record pacman "$@"; }
zypper() { record zypper "$@"; }
apk() { record apk "$@"; }
USE_SUDO=false; : > "$LOG"
for DETECTED_PM in apt nala dnf pacman zypper apk; do run_pm upgrade vim; done
assert_eq "$(cat "$LOG")" $'<apt><install><-y><vim>\n<nala><install><-y><vim>\n<dnf><upgrade><-y><vim>\n<pacman><-S><--noconfirm><vim>\n<zypper><update><-y><vim>\n<apk><upgrade><vim>' 'Linux upgrade compatibility'

# Localized headers, CRLF, tight columns, whitespace within names, truncation.
table=$(printf '%-20s %-25s %s\r\n' 'Nome' 'Id' 'Versão     Disponível Origem'
    printf '%s\r\n' '------------------------------------------------------------------------'
    printf '%-20s %-25s %-10s %-10s %s\r\n' 'Git  for Windows' 'Git.Git' '2.50.0' '2.55.0' winget
    printf '%-20s %-25s %-10s %-10s %s\r\n' 'Truncated' 'Publisher.Truncated…' '1.0' '2.0' winget
    printf '%s\r\n' '1 atualização disponível.')
assert_eq "$(printf '%s\n' "$table" | parse_winget_table packages)" $'Git.Git\t2.50.0\tGit  for Windows' 'WinGet catalog table'
assert_eq "$(printf '%s\n' "$table" | LC_ALL=C parse_winget_table packages)" $'Git.Git\t2.50.0\tGit  for Windows' 'localized WinGet table with a C-locale parent'
accented_table=$'Nome       Id      Versão Disponível Origem\n-------------------------------------------\nAplicação  Git.Git 2.50.0 2.55.0     winget'
assert_eq "$(printf '%s\n' "$accented_table" | parse_winget_table packages)" $'Git.Git\t2.50.0\tAplicação' 'WinGet table preserves accented package names'
assert_eq "$(printf '%s\n' "$accented_table" | parse_winget_table upgradeable)" $'Git.Git\t2.55.0' 'WinGet upgrade columns after accented names and headers'
assert_eq "$(printf '%s\n' "$table" | parse_winget_table installed)" $'Git.Git\t2.50.0' 'WinGet installed table'
assert_eq "$(printf '%s\n' "$table" | parse_winget_table upgradeable)" $'Git.Git\t2.55.0' 'WinGet upgrade table'
assert_eq "$(printf 'Name Id      Version\n---------------------\nGit  Git.Git 2.55.0.5\n' | parse_winget_table packages)" $'Git.Git\t2.55.0.5\tGit' 'single-space column boundary'
assert_eq "$(printf 'No packages found.\n' | parse_winget_table installed)" '' 'empty WinGet table'

winget() { record "$@"; printf '%s\n' "$table"; return "${WINGET_STATUS:-0}"; }
DETECTED_PM=winget
: > "$LOG"
assert_eq "$(fetch_packages)" $'Git.Git\t2.50.0\tGit  for Windows' 'WinGet catalog integration'
assert_eq "$(cat "$LOG")" '<search><--query><><--source><winget><--accept-source-agreements><--disable-interactivity>' 'WinGet catalog requests an explicit empty query'
assert_eq "$(fetch_installed)" $'Git.Git\t2.50.0' 'WinGet installed integration'
assert_eq "$(fetch_upgradeable)" $'Git.Git\t2.55.0' 'WinGet upgrade integration'
WINGET_STATUS=20
assert_eq "$(fetch_installed)" '' 'WinGet no applications exit code'
WINGET_STATUS=1
if fetch_packages 2>/dev/null; then echo 'WinGet query failure was swallowed' >&2; exit 1; fi
WINGET_STATUS=0
winget() { record "$@"; }

assert_eq "$(printf 'git|2.50.0\r\n7zip|24.0\r\n' | parse_choco_table packages)" $'git\t2.50.0\tgit\n7zip\t24.0\t7zip' 'Chocolatey catalog CRLF'
assert_eq "$(printf 'git|2.50.0\r\n' | parse_choco_table installed)" $'git\t2.50.0' 'Chocolatey installed'
assert_eq "$(printf 'git|2.50.0|2.55.0|false\r\nheld|1|2|true\r\n' | parse_choco_table upgradeable)" $'git\t2.55.0' 'Chocolatey outdated ignores pinned packages'

# Real fetch functions against command fixtures.
brew() {
    record "$@"
    case "$1:$2" in
        search:--formula) printf 'wget\nshared\n' ;;
        search:--cask) printf 'firefox\nshared\n' ;;
        list:--formula) printf 'wget 1.24 1.25\n' ;;
        list:--cask) printf 'firefox 140.0\n' ;;
        outdated:--formula) printf 'wget (1.25) < 1.26\nheld (1.0) < 2.0 [pinned at 1.0]\n' ;;
        outdated:--cask) printf 'firefox (140.0) != 141.0\nheld (1.0) != 2.0 [pinned at 1.0]\n' ;;
    esac
}
TEST_OS=Darwin; DETECTED_PM=brew
assert_eq "$(fetch_packages)" $'formula:wget\t \twget\nformula:shared\t \tshared\ncask:firefox\t \tfirefox\ncask:shared\t \tshared' 'Homebrew catalog avoids token collisions'
assert_eq "$(fetch_installed)" $'formula:wget\t1.25\ncask:firefox\t140.0' 'Homebrew installed versions'
assert_eq "$(fetch_upgradeable)" $'formula:wget\t1.26\ncask:firefox\t141.0' 'Homebrew upgrade versions'
TEST_OS=Linux
assert_eq "$(fetch_packages)" $'formula:wget\t \twget\nformula:shared\t \tshared' 'Homebrew on Linux excludes casks'

DETECTED_PM=choco
choco() {
    record "$@"
    case "$1" in search|list) printf 'git|2.50.0\r\n' ;; outdated) printf 'git|2.50.0|2.55.0|false\r\n' ;; esac
    return "${CHOCO_STATUS:-0}"
}
assert_eq "$(fetch_packages)" $'git\t2.50.0\tgit' 'Chocolatey search integration'
assert_eq "$(fetch_installed)" $'git\t2.50.0' 'Chocolatey list integration'
assert_eq "$(fetch_upgradeable)" $'git\t2.55.0' 'Chocolatey outdated integration'
CHOCO_STATUS=2
assert_eq "$(fetch_upgradeable)" $'git\t2.55.0' 'Chocolatey enhanced outdated exit code'
CHOCO_STATUS=1
if fetch_installed 2>/dev/null; then echo 'Chocolatey query failure was swallowed' >&2; exit 1; fi
CHOCO_STATUS=0

: > "$LOG"; show_package_info brew brew cask:firefox >/dev/null
show_package_info winget winget Git.Git >/dev/null
show_package_info choco choco git >/dev/null
assert_eq "$(cat "$LOG")" $'<info><--cask><firefox>\n<show><--id><Git.Git><--exact><--source><winget><--accept-source-agreements><--disable-interactivity>\n<info><git><--no-color>' 'package info and shared TUI previews'
: > "$LOG"
for DETECTED_PM in brew winget choco; do update_cache >/dev/null; done
assert_eq "$(cat "$LOG")" $'<update>\n<source><update><--disable-interactivity>' 'backend metadata refresh'

# Catalog cache reuse, refresh/expiry, and failed-query safety.
cache_fixture() { printf 'query\n' >> "$LOG"; printf 'cached-result\n'; return "${CACHE_STATUS:-0}"; }
: > "$LOG"; REFRESH_CACHE=false
assert_eq "$(cached_query fixture 3600 cache_fixture)" cached-result 'initial cached query'
assert_eq "$(cached_query fixture 3600 cache_fixture)" cached-result 'warm cached query'
assert_eq "$(wc -l < "$LOG" | tr -d ' ')" 1 'warm cache avoids the package-manager query'
printf '1\n' > "$(cache_directory)/fixture.v1.time"
cached_query fixture 3600 cache_fixture >/dev/null
assert_eq "$(wc -l < "$LOG" | tr -d ' ')" 2 'expired cache refetches'
REFRESH_CACHE=true
cached_query fixture 3600 cache_fixture >/dev/null
assert_eq "$(wc -l < "$LOG" | tr -d ' ')" 3 'explicit refresh bypasses the cache'
CACHE_STATUS=17; status=0
cached_query fixture 3600 cache_fixture >/dev/null || status=$?
assert_eq "$status" 17 'failed refresh preserves the error status'
assert_eq "$(cat "$(cache_directory)/fixture.v1")" cached-result 'failed refresh preserves the last valid cache'
CACHE_STATUS=0; REFRESH_CACHE=false
empty_upgrades() { printf 'query\n' >> "$TEST_DIR/empty-upgrade-queries"; }
cached_query upgrades-empty 60 empty_upgrades >/dev/null
cached_query upgrades-empty 60 empty_upgrades >/dev/null
assert_eq "$(wc -l < "$TEST_DIR/empty-upgrade-queries" | tr -d ' ')" 1 'no available upgrades is a valid cached result'

# Catalog and installed queries overlap; upgrades use the fresh inventory key.
(
    PKG_FILE="$TEST_DIR/parallel-packages"; INST_FILE="$TEST_DIR/parallel-installed"; UPGR_FILE="$TEST_DIR/parallel-upgrades"
    parallel_ready() {
        touch "$TEST_DIR/started-$1"
        local attempt
        for attempt in {1..50}; do
            [[ -f "$TEST_DIR/started-catalog" && -f "$TEST_DIR/started-installed" ]] && return 0
            sleep 0.02
        done
        return 1
    }
    fetch_packages() { parallel_ready catalog || return 1; printf 'git\t2\tGit\n'; }
    fetch_installed() { parallel_ready installed || return 1; printf 'git\t1\n'; }
    fetch_upgradeable() { parallel_ready upgrades || return 1; printf 'upgrade-query\n' >> "$TEST_DIR/upgrade-queries"; printf 'git\t2\n'; }
    REFRESH_CACHE=true; SHOW_MODE=ALL
    load_package_data || exit 1
    [[ -s "$PKG_FILE" && -s "$INST_FILE" && -s "$UPGR_FILE" ]] || exit 1
    REFRESH_CACHE=false
    fetch_packages() { echo 'Catalog should not be queried for an installed-only view' >&2; return 1; }
    SHOW_MODE=INSTALLED
    load_package_data || exit 1
    [[ ! -s "$PKG_FILE" && -s "$INST_FILE" && -s "$UPGR_FILE" ]] || exit 1
    [[ "$(wc -l < "$TEST_DIR/upgrade-queries")" -eq 1 ]] || exit 1
    fetch_installed() { printf 'git\t2\n'; }
    load_package_data || exit 1
    [[ "$(wc -l < "$TEST_DIR/upgrade-queries")" -eq 2 ]] || exit 1
    fetch_installed() { return 1; }
    if load_package_data; then exit 1; fi
) || { echo 'Parallel loading or filtered-view query handling failed' >&2; exit 1; }
checks=$((checks + 5))

# End-to-end TUI startup with a stand-in for fzf: compile the generated helper,
# render installed/upgrade rows, run its preview, then exit without changes.
unset -f choco
choco() {
    case "$1" in
        search|list) printf 'git|2.50.0\n' ;;
        outdated) printf 'git|2.50.0|2.55.0|false\n' ;;
        info)
            printf 'preview-%s\n' "$2" >> "$LOG"
            [[ "$2" == broken ]] && { echo 'Temporary preview failure'; return 1; }
            printf 'Git information\n' ;;
    esac
}
curl() { return 0; }
export -f choco curl
# A native Windows process relays each callback exactly as fzf receives it.
# Without the MSYS conversion exclusions, /usr/bin/bash becomes C:/Program
# Files/... inside the command string and executing it fails as in the UI.
printf '[Console]::Out.Write($args[0])\n' > "$TEST_DIR/relay.ps1"
fzf() {
    local preview_command='' next_command='' header_command='' arg
    for arg in "$@"; do
        case "$arg" in
            --preview=*) preview_command=${arg#--preview=} ;;
            right:reload-sync\(*) next_command=${arg#right:reload-sync\(}; next_command=${next_command%\)} ;;
            load:transform-header\(*) header_command=${arg#load:transform-header\(}; header_command=${header_command%\)} ;;
            --sync) touch "$TEST_DIR/synchronous-input" ;;
            --header-lines=*) printf '%s\n' "${arg#--header-lines=}" > "$TEST_DIR/header-count" ;;
            --header=*) printf '%s\n' "${arg#--header=}" > "$TEST_DIR/initial-header" ;;
        esac
    done
    cat > "$TEST_DIR/initial-rows"
    "$BASH" "$HELPER_SCRIPT" gen-list "$PKG_FILE" "$STATE_FILE" "$INST_FILE" "$UPGR_FILE" ALL > "$TEST_DIR/rendered" || return 1
    "$BASH" -n "$HELPER_SCRIPT" || return 1
    case "$(command uname -s)" in
        MINGW*|MSYS*|CYGWIN*)
            local relay_path
            relay_path=$(cygpath -w "$TEST_DIR/relay.ps1")
            preview_command=$(powershell.exe -NoLogo -NoProfile -File "$relay_path" "$preview_command") || return 1
            next_command=$(powershell.exe -NoLogo -NoProfile -File "$relay_path" "$next_command") || return 1
            header_command=$(powershell.exe -NoLogo -NoProfile -File "$relay_path" "$header_command") || return 1
            ;;
    esac
    preview_command=${preview_command//\{1\}/git}
    next_command=${next_command//\{1\}/git}
    "$BASH" -c "$preview_command" > "$TEST_DIR/preview" || return 1
    "$BASH" -c "$preview_command" > "$TEST_DIR/preview-again" || return 1
    "$BASH" "$HELPER_SCRIPT" info broken > /dev/null && return 1
    "$BASH" "$HELPER_SCRIPT" info broken > /dev/null && return 1
    "$BASH" -c "$next_command" > "$TEST_DIR/reloaded-rows" || return 1
    "$BASH" -c "$header_command" > "$TEST_DIR/updated-header" || return 1
    "$BASH" "$HELPER_SCRIPT" gen-list "$PKG_FILE" "$STATE_FILE" "$INST_FILE" "$UPGR_FILE" ALL > "$TEST_DIR/reloaded" || return 1
    cp "$STATE_FILE" "$TEST_DIR/selected-state"
    : > "$STATE_FILE"
    "$BASH" "$HELPER_SCRIPT" gen-list "$PKG_FILE" "$STATE_FILE" "$INST_FILE" "$UPGR_FILE" ALL > "$TEST_DIR/reset-list" || return 1
    return 130
}
DETECTED_PM=choco; PM_PATH=choco; USE_SUDO=false; SHOW_MODE=ALL
: > "$LOG"
mkdir "$TEST_DIR/temp with spaces"
(TMPDIR="$TEST_DIR/temp with spaces"; run_tui >/dev/null) || { echo 'TUI startup failed' >&2; exit 1; }
[[ "$(cat "$TEST_DIR/rendered")" == *git* ]] || { echo 'Missing TUI package' >&2; exit 1; }
[[ "$(cat "$TEST_DIR/preview")" == *'Git information'* ]] || { echo 'Missing TUI preview' >&2; exit 1; }
checks=$((checks + 2))
assert_eq "$(cat "$TEST_DIR/header-count")" 0 'dynamic headers are separate from buffered package rows'
assert_eq "$(wc -l < "$TEST_DIR/initial-header" | tr -d ' ')" 6 'fzf receives all six header lines'
assert_eq "$(cut -f1 "$TEST_DIR/initial-rows")" git 'header lines are not selectable package data'
assert_eq "$(test -f "$TEST_DIR/synchronous-input" && echo yes)" yes 'fzf waits for complete input before displaying results'
assert_eq "$(head -6 "$TEST_DIR/rendered" | awk -F'\t' '$1 == "_" {n++} END {print n}')" 6 'six non-selectable header rows'
assert_eq "$(sed -n '7p' "$TEST_DIR/rendered" | cut -f1)" git 'first package follows SPEC and the other headers'
[[ "$(head -1 "$TEST_DIR/rendered")" == *SPEC*"$(os_label) | choco"* ]] || { echo 'Missing OS/manager SPEC line' >&2; exit 1; }
checks=$((checks + 1))
assert_eq "$(grep '^git=' "$TEST_DIR/selected-state")" 'git=3' 'selection reload executes through the callback command'
updated_counter=$(awk 'NR == 3 {gsub(/\033\[[0-9;]*m/, ""); print}' "$TEST_DIR/reloaded")
[[ "$updated_counter" == *'[↑] 1'* ]] || { echo 'Selection counter was not updated with the cached row' >&2; exit 1; }
checks=$((checks + 1))
updated_counter=$(awk 'NR == 3 {gsub(/\033\[[0-9;]*m/, ""); print}' "$TEST_DIR/updated-header")
[[ "$updated_counter" == *'[↑] 1'* ]] || { echo 'Live header callback shows a stale counter' >&2; exit 1; }
checks=$((checks + 1))
assert_eq "$(grep -c '^preview-git$' "$LOG")" 1 'repeated previews reuse successful output'
assert_eq "$(grep -c '^preview-broken$' "$LOG")" 2 'failed previews are retried rather than cached'
cmp "$TEST_DIR/preview" "$TEST_DIR/preview-again" || { echo 'Cached preview changed content' >&2; exit 1; }
cmp "$TEST_DIR/rendered" "$TEST_DIR/reset-list" || { echo 'Cached rows failed to restore the original appearance' >&2; exit 1; }
checks=$((checks + 2))
[[ "$(head -1 "$TEST_DIR/reloaded")" == *SPEC*"$(os_label) | choco"* ]] || { echo 'Missing SPEC after reload' >&2; exit 1; }
checks=$((checks + 1))

printf 'Passed %s backend checks.\n' "$checks"

#!/usr/bin/env bash
# No real package managers or dependency installations are used in these tests.
set -eo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./pmget
original_refresh_dependency_path=$(declare -f refresh_dependency_path)
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
LOG="$TEST_DIR/commands"
checks=0
assert_eq() {
    if [[ "$1" != "$2" ]]; then
        printf 'FAIL: %s\nExpected: %q\nActual: %q\n' "$3" "$2" "$1" >&2
        exit 1
    fi
    checks=$((checks + 1))
}
record() { printf '<%s>' "$@" >> "$LOG"; printf '\n' >> "$LOG"; }

# Keep both dependency availability and all managers independent of the host.
dependency_present=false
command() {
    if [[ "$1" == -v ]]; then
        case "$2" in
            fzf|curl) [[ "$dependency_present" == true ]]; return ;;
            pmget) return 1 ;;
            winget|choco|brew|nala|apt|dnf|pacman|zypper|apk|sudo) echo "/mock/$2"; return 0 ;;
        esac
    fi
    builtin command "$@"
}
refresh_dependency_path() { record refresh "$1"; }
installed_dependency() {
    record "$@"
    [[ "${INSTALL_FAIL:-false}" != true ]] || return 1
    [[ "${INSTALL_UNAVAILABLE:-false}" == true ]] || dependency_present=true
}
for manager in winget choco brew nala apt dnf pacman zypper apk; do
    eval "$manager() { installed_dependency $manager \"\$@\"; }"
done
sudo() { record sudo; "$@"; }
DETECTED_PM=winget

# A piped 'yes' must never count as installation consent without a terminal.
: > "$LOG"
status=0
require_dependency fzf >"$TEST_DIR/output" 2>&1 <<< yes || status=$?
assert_eq "$status" 1 'noninteractive dependency request fails'
assert_eq "$(cat "$LOG")" '<refresh><fzf>' 'unattended run never invokes manager'
[[ "$(cat "$TEST_DIR/output")" == *'No interactive terminal'* ]] || exit 1
checks=$((checks + 1))

confirm_dependency_install() { record prompt "$1"; return "${CONFIRM_STATUS:-0}"; }
dependency_present=true; : > "$LOG"
require_dependency fzf
assert_eq "$(cat "$LOG")" '' 'installed dependency needs no prompt or queries'

dependency_present=false; CONFIRM_STATUS=1; : > "$LOG"
status=0; require_dependency fzf >"$TEST_DIR/output" 2>&1 || status=$?
assert_eq "$status" 1 'declining dependency installation fails cleanly'
assert_eq "$(cat "$LOG")" $'<refresh><fzf>\n<prompt><Install fzf using winget?>' 'decline never invokes manager'
CONFIRM_STATUS=0

for DETECTED_PM in winget choco brew nala apt dnf pacman zypper apk; do
    for dependency in fzf curl; do
        dependency_present=false; USE_SUDO=false; : > "$LOG"
        require_dependency "$dependency" >"$TEST_DIR/output" 2>&1
        case "$DETECTED_PM" in
            winget)
                package=junegunn.fzf; [[ "$dependency" != curl ]] || package=cURL.cURL
                expected="<winget><install><--id><$package><--exact><--source><winget><--accept-source-agreements><--disable-interactivity><--accept-package-agreements>" ;;
            choco) expected="<choco><install><$dependency><--yes><--no-progress>" ;;
            brew) expected="<brew><install><--formula><$dependency>" ;;
            nala|apt|dnf|zypper) expected="<$DETECTED_PM><install><-y><$dependency>" ;;
            pacman) expected="<pacman><-S><--noconfirm><$dependency>" ;;
            apk) expected="<apk><add><$dependency>" ;;
        esac
        expected_log=$(printf '<refresh><%s>\n<prompt><Install %s using %s?>\n' "$dependency" "$dependency" "$DETECTED_PM"
            if supports_sudo && (( EUID != 0 )); then echo '<sudo>'; fi
            printf '%s\n<refresh><%s>' "$expected" "$dependency")
        assert_eq "$(cat "$LOG")" "$expected_log" "$DETECTED_PM installs $dependency after consent and rechecks PATH"
        assert_eq "$dependency_present:$USE_SUDO" true:false 'installation available; privilege choice does not leak'
    done
done

DETECTED_PM=winget; dependency_present=false; INSTALL_FAIL=true; : > "$LOG"
status=0; require_dependency fzf >"$TEST_DIR/output" 2>&1 || status=$?
assert_eq "$status" 1 'manager failure stops startup'
assert_eq "$(tail -1 "$LOG")" '<winget><install><--id><junegunn.fzf><--exact><--source><winget><--accept-source-agreements><--disable-interactivity><--accept-package-agreements>' 'failed install does not pretend dependency is available'
INSTALL_FAIL=false; INSTALL_UNAVAILABLE=true
status=0; require_dependency fzf >"$TEST_DIR/output" 2>&1 || status=$?
assert_eq "$status" 1 'successful manager exit still requires an executable'
[[ "$(cat "$TEST_DIR/output")" == *'still unavailable'* ]] || exit 1
checks=$((checks + 1))
INSTALL_UNAVAILABLE=false

# Missing dependencies are also handled by the installer and self-upgrade.
# Stub the download and stop there, before any files or system metadata change.
curl() { record download; return 1; }
for action in '--self-install --local' --self-upgrade; do
    : > "$LOG"; status=0
    (DETECTED_PM=''; dependency_present=false; main --pm choco $action) >"$TEST_DIR/output" 2>&1 || status=$?
    assert_eq "$status" 1 "$action stops on deliberately failed download"
    [[ "$(cat "$LOG")" == *'<choco><install><curl><--yes><--no-progress>'* ]] || exit 1
    assert_eq "$(tail -1 "$LOG")" '<download>' "$action installs required dependency before download"
done
: > "$LOG"; status=0
(DETECTED_PM=''; dependency_present=false; main --self-upgrade --pm choco) >"$TEST_DIR/output" 2>&1 || status=$?
assert_eq "$status" 1 'self-upgrade manager flag after action'
[[ "$(cat "$LOG")" == *'<choco><install><curl><--yes><--no-progress>'* ]] || exit 1
checks=$((checks + 1))

# A WinGet portable link created by the install must become visible in this
# Bash process, even when its parent PowerShell still has the old PATH.
(
    eval "$original_refresh_dependency_path"
    LOCALAPPDATA="$TEST_DIR/User Data"
    directory="$LOCALAPPDATA/Microsoft/WinGet/Links"
    DETECTED_PM=winget
    uname() { echo MINGW64_NT-10.0; }
    cygpath() { printf '%s\n' "$2"; }
    command() {
        if [[ "$1:$2" == -v:fzf ]]; then
            [[ ":$PATH:" == *":$directory:"* && -x "$directory/fzf.exe" ]]
            return
        fi
        builtin command "$@"
    }
    winget() { mkdir -p "$directory"; touch "$directory/fzf.exe"; chmod +x "$directory/fzf.exe"; }
    require_dependency fzf
    [[ ":$PATH:" == *":$directory:"* ]]
) >"$TEST_DIR/output" 2>&1
checks=$((checks + 1))

# The curl | bash entry point must finish defining the dependency helpers
# before invoking its installer, and must not read the script as consent.
export -f command
status=0
cat ./pmget | PMGET_PM=choco "$BASH" -s -- --self-install --local >"$TEST_DIR/output" 2>&1 || status=$?
assert_eq "$status" 1 'piped installer stops when dependency installation is not confirmed'
[[ "$(cat "$TEST_DIR/output")" == *'Missing dependency: curl'* && "$(cat "$TEST_DIR/output")" == *'No interactive terminal'* ]] || exit 1
checks=$((checks + 1))
export -n -f command

printf 'Passed %s dependency checks.\n' "$checks"

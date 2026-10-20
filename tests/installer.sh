#!/usr/bin/env bash
# Exercise installation and cache refresh using only temporary files and stubs.
set -eo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source ./pmget
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
export PMGET_TEST_SOURCE="$PWD/pmget"
export INSTALL_LOG="$TEST_DIR/commands"
checks=0
assert_eq() {
    if [[ "$1" != "$2" ]]; then
        printf 'FAIL: %s\nExpected: %q\nActual: %q\n' "$3" "$2" "$1" >&2
        exit 1
    fi
    checks=$((checks + 1))
}
record() { printf '<%s>' "$@" >> "$INSTALL_LOG"; printf '\n' >> "$INSTALL_LOG"; }
command() {
    if [[ "$1:$2" == -v:pmget ]]; then return 1; fi
    if [[ "$1:$2" == -v:sudo && "${NO_SUDO:-false}" == true ]]; then return 1; fi
    builtin command "$@"
}
sudo() {
    record sudo "$@"
    [[ "${SUDO_FAIL:-false}" != true ]] || return 29
    "$@"
}
mock_manager() {
    record "$@"
    case "$2" in
        clean|-Sc|cache) return "${CLEAN_STATUS:-0}" ;;
        *) return "${UPDATE_STATUS:-0}" ;;
    esac
}
for manager in apt nala dnf pacman zypper apk brew winget choco; do
    eval "$manager() { mock_manager $manager \"\$@\"; }"
done
fzf() { :; }
curl() {
    local output
    while (( $# )); do
        if [[ "$1" == -o ]]; then output="$2"; break; fi
        shift
    done
    cat > "$output" <<'FIXTURE'
#!/usr/bin/env bash
# github.com/gabrielmsilva00/pmget
source "$PMGET_TEST_SOURCE"
run_tui() { record tui; }
main "$@"
FIXTURE
}
export -f command sudo mock_manager record apt nala dnf pacman zypper apk brew winget choco fzf curl

assert_eq "$VERSION" 1.0.1 'patch version'

for DETECTED_PM in apt nala dnf pacman zypper apk brew winget choco; do
    : > "$INSTALL_LOG"
    task_home="$TEST_DIR/$DETECTED_PM"
    mkdir -p "$task_home"
    (export HOME="$task_home" SHELL=/bin/bash; self_install --local) > "$TEST_DIR/output" 2>&1
    assert_eq "$(test -x "$task_home/.local/bin/pmget" && echo installed)" installed "$DETECTED_PM local installation completes"
    if supports_sudo && (( EUID != 0 )); then
        assert_eq "$(grep -c '^<sudo>' "$INSTALL_LOG")" 2 "$DETECTED_PM metadata refresh uses sudo for non-root"
    else
        assert_eq "$(grep -c '^<sudo>' "$INSTALL_LOG" || true)" 0 "$DETECTED_PM metadata refresh needs no Unix sudo"
    fi
    assert_eq "$(tail -1 "$INSTALL_LOG")" '<tui>' "$DETECTED_PM launches TUI after update"
    [[ "$(cat "$TEST_DIR/output")" == *'Done!'* ]] || exit 1
    checks=$((checks + 1))
done

# Errors survive the installed child process and prevent a false Done message.
for failure in clean update; do
    : > "$INSTALL_LOG"
    task_home="$TEST_DIR/fail-$failure"
    mkdir -p "$task_home"
    status=0
    (export HOME="$task_home" SHELL=/bin/bash
        export CLEAN_STATUS=0 UPDATE_STATUS=0
        if [[ "$failure" == clean ]]; then export CLEAN_STATUS=23; else export UPDATE_STATUS=37; fi
        DETECTED_PM=apt; self_install --local
    ) > "$TEST_DIR/output" 2>&1 || status=$?
    expected=23; [[ "$failure" != update ]] || expected=37
    assert_eq "$status" "$expected" "installer preserves $failure failure status"
    assert_eq "$(test -f "$task_home/.local/bin/pmget" && echo installed)" installed 'failed initialization keeps installed script'
    assert_eq "$(grep -c '^<tui>' "$INSTALL_LOG" || true)" 0 'failed refresh never launches TUI'
    [[ "$(cat "$TEST_DIR/output")" == *'pmget remains installed'* && "$(cat "$TEST_DIR/output")" != *'Done!'* ]] || exit 1
    checks=$((checks + 1))
done

DETECTED_PM=apt; USE_SUDO=false
if (( EUID != 0 )); then
    : > "$INSTALL_LOG"; status=0
    NO_SUDO=true update_cache > "$TEST_DIR/output" 2>&1 || status=$?
    assert_eq "$status" 1 'missing sudo fails before unprivileged package-manager calls'
    assert_eq "$(cat "$INSTALL_LOG")" '' 'missing sudo runs no package-manager commands'
    : > "$INSTALL_LOG"; status=0
    SUDO_FAIL=true update_cache > "$TEST_DIR/output" 2>&1 || status=$?
    assert_eq "$status" 29 'sudo rejection propagates'
    assert_eq "$(wc -l < "$INSTALL_LOG" | tr -d ' ')" 1 'sudo rejection stops refresh immediately'
fi
: > "$INSTALL_LOG"
update_cache > "$TEST_DIR/output" 2>&1
assert_eq "$USE_SUDO" false 'metadata privilege choice does not change later TUI selection'

printf 'Passed %s installer checks (EUID %s).\n' "$checks" "$EUID"

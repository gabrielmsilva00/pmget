"""Exercise the real Bash confirmation prompt in a disposable POSIX terminal.

Package operations are shell stubs; no dependency is installed on the host.
"""
import os
import sys

if os.name == "nt":
    print("Terminal prompt checks run on Linux/macOS (or inside WSL).")
    sys.exit(0)

import errno
import pty
import select
import signal
import time
from pathlib import Path

os.chdir(Path(__file__).resolve().parent.parent)
probe = r'''
source ./pmget
DETECTED_PM=winget
present=false
command() {
    if [[ "$1:$2" == -v:fzf ]]; then
        [[ "$present" == true ]]; return
    fi
    builtin command "$@"
}
refresh_dependency_path() { :; }
winget() { echo TEST_INSTALL; present=true; }
require_fzf || exit 1
echo TEST_CONTINUED
'''


def check(answer, accepted, piped_stdin=False):
    child, terminal = pty.fork()
    if child == 0:
        # Match curl | bash: stdin isn't a terminal, stderr still is one.
        prefix = "exec </dev/null\n" if piped_stdin else ""
        os.execvp("bash", ["bash", "-c", prefix + probe])
    output = b""
    sent = False
    status = None
    exited = 0
    reaped = False
    try:
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if select.select([terminal], [], [], 0.1)[0]:
                try:
                    chunk = os.read(terminal, 65536)
                except OSError as error:
                    if error.errno != errno.EIO:
                        raise
                    break
                if not chunk:
                    break
                output += chunk
                if b"[y/N]" in output and not sent:
                    os.write(terminal, answer)
                    sent = True
            exited, status = os.waitpid(child, os.WNOHANG)
            if exited:
                reaped = True
                break
        else:
            raise AssertionError(f"Prompt timed out: {output!r}")
        if status is None or not exited:
            _, status = os.waitpid(child, 0)
            reaped = True
        exit_code = os.waitstatus_to_exitcode(status)
        assert sent, output
        assert exit_code == (0 if accepted else 1), output
        assert (b"TEST_INSTALL" in output) == accepted, output
        assert (b"TEST_CONTINUED" in output) == accepted, output
    finally:
        os.close(terminal)
        if not reaped:
            try:
                os.kill(child, signal.SIGKILL)
            except ProcessLookupError:
                pass
            os.waitpid(child, 0)


answers = [(b"\n", False), (b"n\n", False), (b"no\n", False),
           (b"y\n", True), (b"Y\n", True), (b"yes\n", True),
           (b"Yes\n", True), (b"\x04", False)]
for answer, accepted in answers:
    check(answer, accepted)
check(b"yes\n", True, piped_stdin=True)
print(f"Passed {len(answers) + 1} terminal prompt checks.")

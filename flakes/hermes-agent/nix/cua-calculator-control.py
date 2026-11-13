"""Ours: trusted-user-only CuaDriver control; Nix substitutes immutable paths."""
import hashlib
import contextlib
import fcntl
import os
from pathlib import Path
import pwd
import stat
import subprocess
import sys
import time

DIRECTORY = Path("@directory@")
SOCKET = DIRECTORY / "driver.sock"
MANIFEST = Path("@manifest@")
APP = "@app@"
DRIVER = "@driver@"
USER = "@user@"


@contextlib.contextmanager
def locked(create=False):
    if os.environ.get("HERMES_SANDBOX"):
        raise RuntimeError("run from a trusted user terminal, not the Hermes sandbox")
    if pwd.getpwuid(os.getuid()).pw_name != USER:
        raise RuntimeError(f"run as the configured user {USER}, never root")
    # No symlink ancestors: Seatbelt grants the exact canonical endpoint.
    for path in [*reversed(DIRECTORY.parents), DIRECTORY]:
        if path.is_symlink():
            raise RuntimeError(f"symlink in endpoint directory: {path}")
    if create:
        DIRECTORY.mkdir(mode=0o700, exist_ok=True)
    info = DIRECTORY.stat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700:
        raise RuntimeError("endpoint directory must be owned by the user and mode 0700")
    fd = os.open(DIRECTORY / "control.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_nlink != 1:
            raise RuntimeError("unsafe control lock")
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise RuntimeError("another control operation is running") from exc
        yield
    finally:
        os.close(fd)


def start():
    if not sys.stdin.isatty():
        raise RuntimeError("start requires interactive manifest review in a trusted user terminal")
    with locked(create=True):
        if os.path.lexists(SOCKET):
            raise RuntimeError(f"socket collision at {SOCKET}; refusing to unlink or replace it")
        pending = DIRECTORY / "launch.pending"
        if os.path.lexists(pending):
            raise RuntimeError(f"launch pending at {pending}; inspect status before recovery")
        content = MANIFEST.read_bytes()
        digest = hashlib.sha256(content).hexdigest()
        print(f"Immutable policy: {MANIFEST}\nSHA-256: {digest}\n{content.decode()}")
        print("Review this exact policy. Starting may display macOS permission UI; this command does not grant permissions.")
        if input(f"Type 'approve {digest}' to launch: ") != f"approve {digest}":
            raise RuntimeError("manifest not approved; nothing launched")
        subprocess.run([
            "/usr/bin/codesign", "--verify", "--deep", "--strict", "-R",
            '=anchor apple generic and identifier "com.trycua.driver" and certificate leaf[subject.OU] = "YCK386LBJ7"',
            APP,
        ], check=True, timeout=30)
        # Retain the intent marker even if open fails or is interrupted: LaunchServices
        # may already have accepted the request. Never race a delayed daemon startup.
        with pending.open("x") as handle:
            handle.write(f"{MANIFEST}\n{digest}\n")
        subprocess.run([
            "/usr/bin/open", "-n", "-g", "-a", APP, "--args", "serve",
            "--socket", str(SOCKET), "--permission-mode", "bounded",
            "--capability-manifest", str(MANIFEST), "--approve-capability-manifest",
            "--no-overlay",
        ], check=True, timeout=30)
        print("Launch requested (not a readiness assertion). Run hermes-cua-calculator status.")


def inspect(command):
    if not os.path.lexists(DIRECTORY):
        print("Not started; endpoint directory does not exist.")
        return
    with locked():
        pending = DIRECTORY / "launch.pending"
        print(f"Endpoint: {SOCKET}\nPolicy: {MANIFEST}\nLaunch intent: {os.path.lexists(pending)}")
        if not os.path.lexists(SOCKET):
            if command == "stop" and os.path.lexists(pending):
                raise RuntimeError("launch pending but no socket; inspect the user processes before manually clearing launch.pending")
            print("No socket. A pending launch may still be starting; no readiness claim.")
            return
        info = SOCKET.lstat()
        if not stat.S_ISSOCK(info.st_mode) or info.st_uid != os.getuid():
            raise RuntimeError("unsafe socket collision; no command sent and nothing removed")
        subprocess.run([DRIVER, command, "--socket", str(SOCKET)], check=True, timeout=15,
                       env={"HOME": pwd.getpwuid(os.getuid()).pw_dir, "PATH": "/usr/bin:/bin",
                            "CUA_DRIVER_RS_TELEMETRY_ENABLED": "0"})
        if command == "stop":
            for _ in range(50):
                if not os.path.lexists(SOCKET):
                    pending.unlink(missing_ok=True)
                    print("Dedicated socket removed by driver; launch intent cleared.")
                    return
                time.sleep(0.1)
            raise RuntimeError("stop did not remove the socket; preserving launch intent, no automatic unlink")


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("start", "status", "stop", "manifest"):
        raise RuntimeError("usage: hermes-cua-calculator {manifest|start|status|stop}")
    if sys.argv[1] == "manifest":
        print(f"{MANIFEST}\n{MANIFEST.read_text()}")
    elif sys.argv[1] == "start":
        start()
    else:
        inspect(sys.argv[1])


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, EOFError, subprocess.SubprocessError) as exc:
        print(f"hermes-cua-calculator: {exc}", file=sys.stderr)
        sys.exit(1)

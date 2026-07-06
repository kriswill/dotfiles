# 1Password-backed backend for python-keyring (Gajim et al.), selected via
# keyringrc.cfg. No keyring daemon, no at-rest secret store: every read shells
# out to `op`, gated by the 1Password app's lock state (the CLI integration
# shares lock state only — no per-use prompt while unlocked, unlike the
# SSH-agent path backing sudo/git-signing on this machine).
#
# Items land in the default vault as Password-category entries titled
# "python-keyring/<service>/<username>", tagged "python-keyring".
import contextlib
import datetime
import fcntl
import json
import pathlib
import shutil
import subprocess

from keyring import backend
from keyring.errors import PasswordDeleteError, PasswordSetError

OP = shutil.which("op") or "/run/wrappers/bin/op"
TIMEOUT = 120  # seconds; long enough to answer the 1Password unlock prompt
STATE = pathlib.Path.home() / ".local/state"
LOG = STATE / "op_keyring.log"
LOCK = STATE / "op_keyring.lock"

# The 1Password desktop-app integration channel resets some connections when
# `op` calls hit it concurrently (verified 2026-07-05: sequential calls never
# fail, 6-way parallel calls drop 1-3). Gajim fetches two accounts at connect
# (the JID + a legacy account-name migration probe) and asks the keyring only
# once each with no retry, so a collision → "connection reset" → offline +
# password prompt. Serialize every `op` invocation with a cross-process file
# lock so calls never collide. This does NOT retry on the UI thread (a blocking
# retry froze Gajim into "not responding") — serialization alone fixes it.


def _log(msg):
    # Failures are otherwise invisible (callers just see None and prompt);
    # never let logging itself break a password fetch.
    try:
        STATE.mkdir(parents=True, exist_ok=True)
        with LOG.open("a") as f:
            f.write(f"{datetime.datetime.now():%F %T} {msg}\n")
    except OSError:
        pass


def _title(service, username):
    return f"python-keyring/{service}/{username}"


def _op(args, **kwargs):
    STATE.mkdir(parents=True, exist_ok=True)
    # flock serializes op across every keyring consumer + Gajim's own parallel
    # fetches; released when the with-block closes even on exception/timeout.
    with LOCK.open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        with contextlib.suppress(OSError):
            LOCK.chmod(0o600)
        return subprocess.run(
            [OP, *args], capture_output=True, text=True, timeout=TIMEOUT, **kwargs
        )


class OnePasswordKeyring(backend.KeyringBackend):
    priority = 20

    def get_password(self, service, username):
        title = _title(service, username)
        try:
            r = _op(["item", "get", title, "--fields", "password", "--reveal"])
        except subprocess.TimeoutExpired:
            _log(f"get {title!r} TIMEOUT after {TIMEOUT}s")
            return None
        if r.returncode != 0:
            _log(f"get {title!r} rc={r.returncode} stderr={r.stderr.strip()!r}")
            return None
        return r.stdout.strip()

    def set_password(self, service, username, password):
        # Password travels via stdin JSON, never argv (argv is world-readable
        # in /proc for the lifetime of the op call).
        item = {
            "title": _title(service, username),
            "category": "PASSWORD",
            "tags": ["python-keyring"],
            "fields": [
                {
                    "id": "password",
                    "type": "CONCEALED",
                    "purpose": "PASSWORD",
                    "value": password,
                }
            ],
        }
        try:
            self.delete_password(service, username)
        except PasswordDeleteError:
            pass
        r = _op(["item", "create", "-"], input=json.dumps(item))
        if r.returncode != 0:
            raise PasswordSetError(r.stderr.strip())

    def delete_password(self, service, username):
        r = _op(["item", "delete", _title(service, username)])
        if r.returncode != 0:
            raise PasswordDeleteError(r.stderr.strip())

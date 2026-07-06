# 1Password-backed backend for python-keyring (Gajim et al.), selected via
# keyringrc.cfg. No keyring daemon, no at-rest secret store: every read shells
# out to `op`, gated by the 1Password app's authorization prompt — same trust
# path as sudo/git-signing on this machine.
#
# Items land in the default vault as Password-category entries titled
# "python-keyring/<service>/<username>", tagged "python-keyring".
import json
import shutil
import subprocess

from keyring import backend
from keyring.errors import PasswordDeleteError, PasswordSetError

OP = shutil.which("op") or "/run/wrappers/bin/op"
TIMEOUT = 120  # seconds; long enough to answer the 1Password unlock prompt


def _title(service, username):
    return f"python-keyring/{service}/{username}"


def _op(args, **kwargs):
    return subprocess.run(
        [OP, *args], capture_output=True, text=True, timeout=TIMEOUT, **kwargs
    )


class OnePasswordKeyring(backend.KeyringBackend):
    priority = 20

    def get_password(self, service, username):
        try:
            r = _op(
                ["item", "get", _title(service, username), "--fields", "password", "--reveal"]
            )
        except subprocess.TimeoutExpired:
            return None
        return r.stdout.strip() if r.returncode == 0 else None

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

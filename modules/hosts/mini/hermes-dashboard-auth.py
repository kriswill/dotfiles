"""Provision private dashboard credentials once; never emit secret values."""

import base64
import hashlib
import json
import os
from pathlib import Path
import secrets
import sys
import tempfile


def provision(directory: Path) -> None:
    if directory.is_symlink() or not directory.is_dir():
        raise ValueError("Dashboard credential directory must be a real directory")
    login = directory / "login.json"
    environment = directory / "auth.env"
    for path in (login, environment):
        if path.is_symlink():
            raise ValueError("Dashboard credential files must not be symlinks")
    if environment.exists() and not login.exists():
        raise ValueError("Login file missing; refusing to rotate existing credentials")
    if login.exists() and environment.exists():
        for path in (login, environment):
            path.chmod(0o600)
        return

    def save(path: Path, content: str) -> None:
        fd, temporary = tempfile.mkstemp(prefix=".provision-", dir=directory)
        try:
            with os.fdopen(fd, "w") as stream:
                stream.write(content)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temporary, path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)

    if login.exists():
        credentials = json.loads(login.read_text())
    else:
        credentials = {
            "url": "https://mini.home.lan:9443",
            "username": "hermes",
            "password": secrets.token_urlsafe(32),
        }
        save(login, json.dumps(credentials, indent=2) + "\n")
    salt = secrets.token_bytes(16)
    digest = hashlib.scrypt(
        credentials["password"].encode(), salt=salt, n=16384, r=8, p=1, dklen=32
    )
    encoded = "scrypt$16384$8$1$" + "$".join(
        base64.b64encode(value).decode() for value in (salt, digest)
    )
    save(
        environment,
        "HERMES_DASHBOARD_BASIC_AUTH_USERNAME=" + credentials["username"] + "\n"
        "HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH='" + encoded + "'\n",
    )


if __name__ == "__main__":
    provision(Path(sys.argv[1]))

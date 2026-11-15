#!/usr/bin/env python3
"""Exercise both loader sources with disposable keys; no production vault access."""

import os
from pathlib import Path
import pwd
import re
import signal
import subprocess
import sys
import tempfile
import time
import unittest


class LoaderTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="gsa-test-", dir="/tmp")
        self.root = Path(self.tmp.name)
        self.key = self.root / "key"
        subprocess.run(["/usr/bin/ssh-keygen", "-q", "-t", "ed25519", "-N", "",
                        "-f", str(self.key)], check=True)
        self.token = self.root / "token"
        self.socket = self.root / "agent" / "agent.sock"
        self.log = self.root / "loader.log"
        self.attempts = self.root / "attempts"
        op = self.root / "op"
        op.write_text(f"#!{sys.executable}\n" + '''
import os, pathlib, sys, time
root = pathlib.Path(__file__).parent
assert os.environ["OP_SERVICE_ACCOUNT_TOKEN"] == "test-only-token"
with (root / "attempts").open("a") as log:
    log.write(str(time.monotonic()) + "\\n")
if (root / "fail").exists():
    print("fixture network failure", file=sys.stderr)
    sys.exit(1)
sys.stdout.write((root / "key").read_text())
''')
        op.chmod(0o700)
        self.env = dict({k: v for k, v in os.environ.items() if not k.startswith("GSA_")},
                        GSA_USER=pwd.getpwuid(os.getuid()).pw_name,
                        GSA_SOCKET_DIR=str(self.socket.parent), GSA_TOKEN_FILE=str(self.token),
                        GSA_OP_ITEM="fixture/key", GSA_PUBLIC_KEY=self.key.with_suffix(".pub").read_text().strip(),
                        GSA_OP=str(op), GSA_MAX_BACKOFF="2")
        self.proc = None
        self.stream = None

    def tearDown(self):
        if self.proc and self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait()
        if self.stream:
            self.stream.close()
        self.tmp.cleanup()

    def start(self):
        self.stream = self.log.open("w")
        self.proc = subprocess.Popen(["bash", str(Path(__file__).with_name("loader.sh"))],
                                     env=self.env, stdout=self.stream, stderr=subprocess.STDOUT)

    def publish(self):
        new = self.root / "new-token"
        new.write_text("test-only-token")
        new.chmod(0o400)
        new.replace(self.token)

    def wait_for(self, marker, timeout=4):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            text = self.log.read_text()
            if marker in text:
                return text
            if self.proc.poll() is not None:
                self.fail(f"loader exited {self.proc.returncode}: {text}")
            time.sleep(0.05)
        self.fail(f"timed out waiting for {marker}: {self.log.read_text()}")

    def test_late_token_does_not_consume_remote_backoff(self):
        self.env["GSA_MAX_BACKOFF"] = "300"
        self.start()
        self.wait_for("waiting for")
        time.sleep(2.2)
        self.assertFalse(self.attempts.exists())
        published = time.monotonic()
        self.publish()
        text = self.wait_for("signing key loaded", timeout=1.8)
        self.assertLess(time.monotonic() - published, 1.8)
        self.assertEqual(text.count("waiting for"), 1)
        self.assertEqual(len(self.attempts.read_text().splitlines()), 1)

    def use_key_file(self):
        self.secret_key = self.root / "published-key"
        self.env["GSA_KEY_FILE"] = str(self.secret_key)
        for name in ("GSA_TOKEN_FILE", "GSA_OP_ITEM", "GSA_OP"):
            self.env.pop(name)

    def publish_key(self):
        new = self.root / "new-key"
        new.write_bytes(self.key.read_bytes())
        new.chmod(0o400)
        new.replace(self.secret_key)

    def test_late_key_file_does_not_consume_backoff(self):
        self.use_key_file()
        self.env["GSA_MAX_BACKOFF"] = "300"
        self.start()
        self.wait_for("waiting for")
        time.sleep(2.2)
        published = time.monotonic()
        self.publish_key()
        text = self.wait_for("signing key loaded", timeout=1.8)
        self.assertLess(time.monotonic() - published, 1.8)
        self.assertEqual(text.count("waiting for"), 1)
        self.assertNotIn("retrying", text)
        self.assertFalse(self.attempts.exists())
        self.assertNotIn("PRIVATE KEY", text)

    def test_wrong_key_file_is_unloaded(self):
        self.use_key_file()
        self.env["GSA_PUBLIC_KEY"] = "ssh-ed25519 wrong-fixture-public-key"
        self.publish_key()
        self.start()
        self.wait_for("not the configured publicKey; unloaded it")
        result = subprocess.run(["/usr/bin/ssh-add", "-L"],
                                env=dict(os.environ, SSH_AUTH_SOCK=str(self.socket)),
                                capture_output=True)
        self.assertEqual(result.returncode, 1)
        self.assertFalse(self.attempts.exists())
        self.assertNotIn("signing key loaded", self.log.read_text())

    def test_remote_failures_keep_backoff(self):
        self.publish()
        (self.root / "fail").touch()
        self.start()
        self.wait_for("retrying in 2s")
        time.sleep(2.3)
        times = [float(t) for t in self.attempts.read_text().splitlines()]
        self.assertGreaterEqual(len(times), 2)
        self.assertGreaterEqual(times[1] - times[0], 1.9)
        (self.root / "fail").unlink()
        self.wait_for("signing key loaded")

    def test_wrong_key_is_unloaded(self):
        self.env["GSA_PUBLIC_KEY"] = "ssh-ed25519 wrong-fixture-public-key"
        self.publish()
        self.start()
        self.wait_for("not the configured publicKey; unloaded it")
        result = subprocess.run(["/usr/bin/ssh-add", "-L"],
                                env=dict(os.environ, SSH_AUTH_SOCK=str(self.socket)),
                                capture_output=True)
        self.assertEqual(result.returncode, 1)
        self.assertNotIn("signing key loaded", self.log.read_text())

    def test_termination_during_local_wait(self):
        self.start()
        self.wait_for("waiting for")
        self.proc.terminate()
        self.assertEqual(self.proc.wait(timeout=1), 0)
        self.assertFalse(self.socket.exists())

    def test_agent_death_restarts_loader(self):
        self.publish()
        self.start()
        text = self.wait_for("signing key loaded")
        pid = int(re.search(r"ssh-agent \(pid (\d+)\)", text)[1])
        os.kill(pid, signal.SIGTERM)
        self.assertEqual(self.proc.wait(timeout=2), 1)
        self.assertFalse(self.socket.exists())


if __name__ == "__main__":
    unittest.main()

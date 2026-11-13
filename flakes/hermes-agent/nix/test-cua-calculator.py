"""Non-GUI regression tests; never launch or contact a real driver."""
import importlib.util
import hashlib
import io
import os
import pwd
import socket
import sys
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True


class LauncherTests(unittest.TestCase):
    def setUp(self):
        source = Path(__file__).with_name("cua-calculator-control.py")
        self.assertTrue(source.exists(), "manual reviewed launcher is not implemented")
        spec = importlib.util.spec_from_file_location("control", source)
        assert spec is not None and spec.loader is not None
        self.control = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.control)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name).resolve() / "private"
        self.manifest = Path(self.temp.name) / "manifest.json"
        self.manifest.write_text('{"version":3}\n')
        self.settings = patch.multiple(
            self.control, DIRECTORY=self.directory,
            SOCKET=self.directory / "driver.sock", MANIFEST=self.manifest,
            USER=pwd.getpwuid(os.getuid()).pw_name,
        )
        self.settings.start()
        self.addCleanup(self.settings.stop)
        sandbox = patch.dict(os.environ)
        sandbox.start()
        self.addCleanup(sandbox.stop)
        os.environ.pop("HERMES_SANDBOX", None)
        quiet = patch("sys.stdout", new_callable=io.StringIO)
        quiet.start()
        self.addCleanup(quiet.stop)

    def test_start_without_interactive_review_never_runs_a_command(self):
        with patch.object(self.control.sys.stdin, "isatty", return_value=False), patch.object(
            self.control.subprocess, "run"
        ) as run:
            with self.assertRaisesRegex(RuntimeError, "interactive"):
                self.control.start()
            run.assert_not_called()

    def test_reviewed_start_uses_only_pinned_launchservices_argv(self):
        digest = hashlib.sha256(self.manifest.read_bytes()).hexdigest()
        with patch.object(self.control.sys.stdin, "isatty", return_value=True), patch(
            "builtins.input", return_value=f"approve {digest}"
        ), patch.object(self.control.subprocess, "run") as run:
            self.control.start()
        self.assertEqual(run.call_args_list[-1].args[0], [
            "/usr/bin/open", "-n", "-g", "-a", self.control.APP, "--args",
            "serve", "--socket", str(self.control.SOCKET), "--permission-mode", "bounded",
            "--capability-manifest", str(self.manifest), "--approve-capability-manifest",
            "--no-overlay",
        ])
        self.assertTrue((self.directory / "launch.pending").exists())

    def test_collision_including_dangling_symlink_is_never_unlinked(self):
        self.directory.mkdir(mode=0o700)
        self.control.SOCKET.symlink_to("nonexistent")
        with patch.object(self.control.sys.stdin, "isatty", return_value=True), patch.object(
            self.control.subprocess, "run"
        ) as run:
            with self.assertRaisesRegex(RuntimeError, "collision"):
                self.control.start()
            run.assert_not_called()
        self.assertTrue(self.control.SOCKET.is_symlink())

    def test_declining_review_never_launches(self):
        with patch.object(self.control.sys.stdin, "isatty", return_value=True), patch(
            "builtins.input", return_value="no"
        ), patch.object(self.control.subprocess, "run") as run:
            with self.assertRaisesRegex(RuntimeError, "not approved"):
                self.control.start()
            run.assert_not_called()

    def test_pending_attempt_blocks_repeat_start(self):
        self.directory.mkdir(mode=0o700)
        (self.directory / "launch.pending").touch()
        with patch.object(self.control.sys.stdin, "isatty", return_value=True), patch.object(
            self.control.subprocess, "run"
        ) as run:
            with self.assertRaisesRegex(RuntimeError, "pending"):
                self.control.start()
            run.assert_not_called()


    def test_insecure_directory_and_sandbox_are_refused(self):
        self.directory.mkdir(mode=0o755)
        self.directory.chmod(0o755)
        with self.assertRaisesRegex(RuntimeError, "0700"):
            with self.control.locked():
                pass
        with patch.dict(os.environ, HERMES_SANDBOX="1"):
            with self.assertRaisesRegex(RuntimeError, "trusted"):
                with self.control.locked():
                    pass

    def test_status_before_first_start_has_no_side_effects(self):
        with patch.object(self.control.subprocess, "run") as run:
            self.control.inspect("status")
        self.assertFalse(self.directory.exists())
        run.assert_not_called()

    def test_stop_missing_socket_preserves_pending_intent(self):
        self.directory.mkdir(mode=0o700)
        pending = self.directory / "launch.pending"
        pending.touch()
        with patch.object(self.control.subprocess, "run") as run:
            with self.assertRaisesRegex(RuntimeError, "pending"):
                self.control.inspect("stop")
        self.assertTrue(pending.exists())
        run.assert_not_called()

    def test_stop_targets_only_dedicated_socket_and_clears_confirmed_intent(self):
        self.directory.mkdir(mode=0o700)
        pending = self.directory / "launch.pending"
        pending.touch()
        sock = socket.socket(socket.AF_UNIX)
        self.addCleanup(sock.close)
        sock.bind(str(self.control.SOCKET))
        with patch.object(self.control.subprocess, "run", side_effect=lambda *a, **k: self.control.SOCKET.unlink()) as run:
            self.control.inspect("stop")
        self.assertEqual(run.call_args.args[0], [self.control.DRIVER, "stop", "--socket", str(self.control.SOCKET)])
        self.assertFalse(pending.exists())

    def test_status_and_stop_never_contact_non_socket_collision(self):
        self.directory.mkdir(mode=0o700)
        self.control.SOCKET.write_text("do not remove")
        with patch.object(self.control.subprocess, "run") as run:
            for command in ("status", "stop"):
                with self.assertRaisesRegex(RuntimeError, "socket"):
                    self.control.inspect(command)
            run.assert_not_called()
        self.assertEqual(self.control.SOCKET.read_text(), "do not remove")


    def test_signature_failure_never_requests_gui_launch(self):
        digest = hashlib.sha256(self.manifest.read_bytes()).hexdigest()
        with patch.object(self.control.sys.stdin, "isatty", return_value=True), patch(
            "builtins.input", return_value=f"approve {digest}"
        ), patch.object(self.control.subprocess, "run", side_effect=self.control.subprocess.CalledProcessError(1, "codesign")) as run:
            with self.assertRaises(self.control.subprocess.CalledProcessError):
                self.control.start()
        self.assertEqual(run.call_count, 1)
        self.assertEqual(run.call_args.args[0][0], "/usr/bin/codesign")
        self.assertFalse((self.directory / "launch.pending").exists())

    def test_launch_failure_keeps_intent_to_block_delayed_startup_race(self):
        digest = hashlib.sha256(self.manifest.read_bytes()).hexdigest()
        with patch.object(self.control.sys.stdin, "isatty", return_value=True), patch(
            "builtins.input", return_value=f"approve {digest}"
        ), patch.object(self.control.subprocess, "run", side_effect=[None, self.control.subprocess.TimeoutExpired("open", 30)]):
            with self.assertRaises(self.control.subprocess.TimeoutExpired):
                self.control.start()
        self.assertTrue((self.directory / "launch.pending").exists())

    def test_concurrent_control_and_symlink_directory_are_refused(self):
        with self.control.locked(create=True):
            with self.assertRaisesRegex(RuntimeError, "another control"):
                with self.control.locked():
                    pass
        target = self.directory.with_name("target")
        self.directory.rename(target)
        self.directory.symlink_to(target)
        with self.assertRaisesRegex(RuntimeError, "symlink"):
            with self.control.locked():
                pass

    def test_unknown_command_never_runs_a_command(self):
        with patch.object(self.control.sys, "argv", ["control", "permissions"]), patch.object(self.control.subprocess, "run") as run:
            with self.assertRaisesRegex(RuntimeError, "usage"):
                self.control.main()
            run.assert_not_called()


if __name__ == "__main__":
    unittest.main()

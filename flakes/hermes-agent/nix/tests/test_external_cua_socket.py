"""Focused, GUI-free tests against HERMES_TEST_SOURCE (a patched pinned tree).

Run with the packaged Hermes Python, so no environment is installed or changed:
  HERMES_TEST_SOURCE=/path/to/source <hermes-env>/bin/python this_file.py -v
Only driver/process boundaries are mocked; no real CuaDriver is started or stopped.
"""
import os
import contextlib
import importlib
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import unittest
from types import SimpleNamespace
from typing import Any
from unittest.mock import patch

SOURCE = Path(os.environ["HERMES_TEST_SOURCE"]).resolve()
if not (SOURCE / "tools/computer_use/cua_backend.py").is_file():
    raise RuntimeError(f"Pinned Hermes test source missing: {SOURCE}")
_home = tempfile.TemporaryDirectory(prefix="cua-test-home-", dir=os.environ["TMPDIR"])
unittest.addModuleCleanup(_home.cleanup)
_home_env = patch.dict(os.environ, {"HERMES_HOME": _home.name, "HERMES_MANAGED": "false"})
_home_env.start()
unittest.addModuleCleanup(_home_env.stop)
sys.path.insert(0, str(SOURCE))
_scratch_prune = patch("hermes_constants._prune_scratch_dir_once")
_scratch_prune.start()  # Never spawn the unrelated detached scratch pruner.
unittest.addModuleCleanup(_scratch_prune.stop)
cb = importlib.import_module("tools.computer_use.cua_backend")
driver = importlib.import_module("tools.computer_use.cua_backend_driver")
session_mod = importlib.import_module("tools.computer_use.cua_backend_session")
if not cb.__file__ or not Path(cb.__file__).resolve().is_relative_to(SOURCE):
    raise RuntimeError("Tests imported installed backend instead of the requested source")


class ExternalSocketTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cua-ext-", dir=os.environ["TMPDIR"])
        self.addCleanup(self.temp.cleanup)
        self.path = str(Path(self.temp.name) / "driver.sock")
        self.listener = socket.socket(socket.AF_UNIX)
        self.listener.bind(self.path)
        self.listener.listen()
        self.addCleanup(self.listener.close)
        self.cfg: dict[str, Any] = {"external_socket": self.path, "permission_mode": "bounded"}
        self.config = patch.object(cb, "_computer_use_cfg", side_effect=lambda: dict(self.cfg))
        self.config.start()
        self.addCleanup(self.config.stop)

    def test_external_bounded_uses_non_owning_adapter(self):
        # No local manifest: the outside runtime owns its immutable policy.
        with patch.object(cb, "_EmbeddedCuaDaemon", side_effect=AssertionError("must not own runtime")):
            backend = cb.CuaDriverBackend("bounded")
        adapter = backend._embedded_daemon
        self.assertEqual(adapter.socket_path, self.path)
        self.assertNotIsInstance(adapter, cb._EmbeddedCuaDaemon)

    def test_exact_target_capture_never_discovers_other_windows_or_apps(self):
        # Synthetic target/result fixture: no real app is opened or captured.
        fixture = {"data": 'test fixture\nAXWindow "Calculator fixture"',
                   "structuredContent": {}, "images": [], "isError": False}
        for mode in ("ax", "som"):
            with self.subTest(mode=mode):
                backend = cb.CuaDriverBackend("bounded")
                with patch.object(backend, "list_windows", side_effect=AssertionError("discovery not approved")), \
                     patch.object(backend, "list_apps", side_effect=AssertionError("discovery not approved")), \
                     patch.object(backend._session, "call_tool", return_value=fixture) as call, \
                     patch.object(backend._session, "_call_tool_via_cli", side_effect=AssertionError("no refetch needed")):
                    cap = backend.capture(mode=mode, app="Calculator", pid=101, window_id=202)
                call.assert_called_once_with("get_window_state", {
                    "pid": 101, "window_id": 202, "session": backend._session_id, "max_elements": 200})
                self.assertEqual(cap.window_title, "Calculator fixture")
                self.assertEqual(backend._last_target, {"pid": 101, "window_id": 202})

    def test_app_name_only_capture_attempts_discovery_and_policy_refusal_surfaces(self):
        backend = cb.CuaDriverBackend("bounded")
        with patch.object(backend._session, "call_tool", side_effect=RuntimeError("test fixture: discovery denied")) as call:
            with self.assertRaisesRegex(RuntimeError, "discovery denied"):
                backend.capture(mode="ax", app="Calculator")
        call.assert_called_once_with("list_windows", {"on_screen_only": True, "session": backend._session_id})
        self.assertIsNone(backend._last_target)

    def test_partial_exact_target_fails_without_discovery(self):
        for pid, window_id in ((101, None), (None, 202), (-1, 202)):
            with self.subTest(pid=pid, window_id=window_id):
                backend = cb.CuaDriverBackend("bounded")
                with patch.object(backend._session, "call_tool", side_effect=AssertionError("no driver call")) as call:
                    result = backend.capture(mode="ax", pid=pid, window_id=window_id)
                call.assert_not_called()
                self.assertIn("capture targeting requires", result.window_title)
                self.assertIsNone(backend._last_target)

    def test_external_configuration_exposes_tool_without_native_client(self):
        provider_mod = importlib.import_module("plugins.computer_use.cua")
        placement = importlib.import_module("tools.bot_desktop.placement")
        with patch.object(driver, "cua_driver_binary_available", return_value=False), \
             patch.object(cb, "cua_driver_binary_available", return_value=False), \
             patch.object(placement, "resolve", return_value=SimpleNamespace(where=placement.GATEWAY)), \
             patch.object(cb, "_run_quiet", side_effect=AssertionError("availability must not probe")):
            with self.subTest(surface="provider gate"):
                self.assertTrue(provider_mod.CuaDriverProvider().is_available())
            with self.subTest(surface="backend gate"):
                self.assertTrue(cb.CuaDriverBackend("bounded").is_available())
            self.cfg.clear()
            self.assertFalse(provider_mod.CuaDriverProvider().is_available())
            self.assertFalse(cb.CuaDriverBackend().is_available())

    def test_readiness_exposes_external_config_without_native_client(self):
        permissions = importlib.import_module("tools.computer_use.permissions")
        with patch.object(driver, "resolve_cua_driver_cmd", return_value=None), \
             patch.object(permissions, "_run", side_effect=AssertionError("no native permissions probe")):
            status = permissions.computer_use_status()
        self.assertIn("external_socket", status)
        self.assertEqual(status["external_socket"], self.path)
        self.assertEqual(status["permission_mode"], "bounded")
        self.assertFalse(status["installed"])
        self.assertIs(status["ready"], False)
        self.assertFalse(status["can_grant"])
        self.assertIn("client", status["error"])

    def test_readiness_probes_external_socket_not_native_tcc_or_default_daemon(self):
        permissions = importlib.import_module("tools.computer_use.permissions")
        for code, ready in ((0, True), (1, False)):
            with self.subTest(code=code), \
                 patch.object(driver, "resolve_cua_driver_cmd", return_value="/requested/client") as resolve, \
                 patch.object(cb, "cua_driver_child_env", return_value={}), \
                 patch.object(cb, "_run_quiet", return_value=SimpleNamespace(returncode=code)) as probe, \
                 patch.object(permissions, "_run", side_effect=AssertionError("no native TCC/doctor")) as native:
                status = permissions.computer_use_status(driver_cmd="/requested/client")
                self.assertIs(status["ready"], ready)
                self.assertEqual(status["external_socket"], self.path)
                self.assertFalse(status["can_grant"])
                self.assertIsNone(status["accessibility"])
                self.assertIsNone(status["screen_recording"])
                probe.assert_called_once()
                self.assertEqual(probe.call_args.args[0],
                                 ["/requested/client", "status", "--socket", self.path])
                native.assert_not_called()
                self.assertEqual([c.args for c in resolve.call_args_list],
                                 [("/requested/client",), ("/requested/client",)])

    def test_unconfigured_readiness_preserves_native_missing_client_result(self):
        permissions = importlib.import_module("tools.computer_use.permissions")
        self.cfg.clear()
        with patch.object(driver, "resolve_cua_driver_cmd", return_value=None), \
             patch.object(cb, "_run_quiet", side_effect=AssertionError("no socket probe")):
            status = permissions.computer_use_status()
        self.assertNotIn("external_socket", status)
        self.assertIsNone(status["ready"])
        self.assertFalse(status["installed"])

    def test_external_rejects_unsafe_configuration(self):
        for value in ("", "relative.sock", " /absolute.sock", "/bad\x00.sock", False, 12, []):
            with self.subTest(socket=value):
                self.cfg["external_socket"] = value
                with self.assertRaisesRegex(ValueError, "external_socket"):
                    cb.CuaDriverBackend("bounded")
        self.cfg["external_socket"] = self.path
        with self.assertRaisesRegex(ValueError, "external_socket.*unrestricted"):
            cb.CuaDriverBackend("unrestricted")
        self.cfg["permission_mode"] = "unrestricted"
        with self.assertRaisesRegex(ValueError, "external_socket.*unrestricted"):
            cb.CuaDriverBackend("standard")

    def test_external_lifecycle_validates_explicit_socket_without_owning_it(self):
        adapter = cb.CuaDriverBackend("bounded")._embedded_daemon
        self.assertTrue(callable(getattr(adapter, "start", None)), "external adapter needs start validation")
        env = {"PATH": "/safe", "OPENAI_API_KEY": "test-only-not-a-secret",
               "CUA_DRIVER_RS_TELEMETRY_ENABLED": "0", "CUA_DRIVER_PERMISSION_MODE": "unrestricted",
               "CUA_DRIVER_DANGEROUSLY_BYPASS_APPROVALS": "1"}
        with patch.object(driver, "resolve_cua_driver_cmd", return_value="/nix/store/test/cua-driver"), \
             patch.object(cb, "cua_driver_child_env", return_value=env), \
             patch.object(cb, "_run_quiet", return_value=SimpleNamespace(returncode=0)) as probe:
            adapter.start()
            self.assertEqual(probe.call_args.args[0],
                             ["/nix/store/test/cua-driver", "status", "--socket", self.path])
            self.assertEqual(adapter.proxy_invocation(),
                             ("/nix/store/test/cua-driver", ["mcp", "--embedded", "--socket", self.path]))
            self.assertNotIn("CUA_DRIVER_PERMISSION_MODE", adapter.child_env())
            self.assertNotIn("CUA_DRIVER_DANGEROUSLY_BYPASS_APPROVALS", adapter.child_env())
            self.assertNotIn("OPENAI_API_KEY", adapter.child_env())
            self.assertEqual(adapter.child_env()["CUA_DRIVER_RS_TELEMETRY_ENABLED"], "0")
            self.assertEqual(env["CUA_DRIVER_PERMISSION_MODE"], "unrestricted")
            probe.reset_mock()
            with patch("os.remove", side_effect=AssertionError("must not unlink")), \
                 patch("subprocess.Popen", side_effect=AssertionError("must not launch")), \
                 patch("os.kill", side_effect=AssertionError("must not kill")):
                adapter.stop()
                adapter.stop()
            probe.assert_not_called()
        self.assertTrue(Path(self.path).exists())

    def test_backend_external_selection_never_routes_to_sandbox_desktop(self):
        backend = cb.CuaDriverBackend("bounded")
        with patch.object(cb, "sandbox_mcp_invocation", side_effect=AssertionError("external socket must win")), \
             patch.dict(os.environ, {"HERMES_CUA_DRIVER_CMD": "/nix/store/test/cua-driver"}), \
             patch.object(cb, "cua_driver_runtime_contract_status", return_value={"ready": True}), \
             patch.object(driver, "resolve_cua_driver_cmd", return_value="/nix/store/test/cua-driver"), \
             patch.object(cb, "cua_driver_child_env", return_value={"PATH": "/safe"}), \
             patch.object(cb, "_run_quiet", return_value=SimpleNamespace(returncode=0)) as probe, \
             patch("pm.ensure_import"), patch.object(backend._session, "start"), \
             patch.object(backend, "_best_effort"):
            backend.start()
            self.assertEqual(probe.call_args.args[0][-2:], ["--socket", self.path])
            backend.stop()

    def test_session_missing_proxy_binary_never_consults_sandbox_fallback(self):
        backend = cb.CuaDriverBackend("bounded")
        self.addCleanup(backend._bridge.stop)
        with patch.object(driver, "resolve_cua_driver_cmd", return_value=None), \
             patch.object(cb, "sandbox_mcp_invocation", return_value=None) as sandbox:
            with self.assertRaises(RuntimeError):
                backend._session.start()
            sandbox.assert_not_called()

    def test_external_startup_and_teardown_need_only_approved_lifecycle_tools(self):
        backend = cb.CuaDriverBackend("bounded")
        self.cfg["max_image_dimension"] = 1456  # Must not trigger external set_config.
        result = {"isError": False, "data": None, "structuredContent": None}
        with patch.dict(os.environ, {"HERMES_CUA_DRIVER_CMD": "/driver"}), \
             patch.object(cb, "cua_driver_runtime_contract_status", return_value={"ready": True}), \
             patch.object(driver, "resolve_cua_driver_cmd", return_value="/driver"), \
             patch.object(cb, "cua_driver_child_env", return_value={}), \
             patch.object(cb, "_run_quiet", return_value=SimpleNamespace(returncode=0)) as probe, \
             patch.object(cb, "_cua_no_overlay", return_value=True), patch("pm.ensure_import"), \
             patch.object(backend._session, "start", side_effect=lambda: setattr(backend._session, "_started", True)), \
             patch.object(backend._session, "stop", side_effect=lambda: setattr(backend._session, "_started", False)), \
             patch.object(backend._session, "call_tool", return_value=result) as tool:
            backend.start()
            backend.stop()
        self.assertEqual([c.args[0] for c in tool.call_args_list], ["start_session", "end_session"])
        self.assertEqual([c.args[0] for c in probe.call_args_list], [["/driver", "status", "--socket", self.path]])
        self.assertTrue(Path(self.path).exists())

    def test_start_refuses_missing_non_socket_and_symlink_paths(self):
        ordinary = Path(self.temp.name) / "ordinary"
        ordinary.write_text("not a socket")
        link = Path(self.temp.name) / "alias.sock"
        link.symlink_to(self.path)
        for path in (str(ordinary), str(link), str(Path(self.temp.name) / "missing.sock")):
            with self.subTest(path=path):
                self.cfg["external_socket"] = path
                adapter = cb.CuaDriverBackend("bounded")._embedded_daemon
                with patch.object(driver, "resolve_cua_driver_cmd") as resolve, \
                     patch.object(cb, "_run_quiet") as probe:
                    with self.assertRaisesRegex(RuntimeError, "external_socket.*unavailable"):
                        adapter.start()
                    resolve.assert_not_called()
                    probe.assert_not_called()

    def test_status_failure_and_timeout_never_launch_or_use_default_socket(self):
        adapter = cb.CuaDriverBackend("bounded")._embedded_daemon
        for outcome in (None, SimpleNamespace(returncode=1), OSError("denied"),
                        subprocess.TimeoutExpired("status", 2)):
            with self.subTest(outcome=outcome), \
                 patch.object(driver, "resolve_cua_driver_cmd", return_value="/driver"), \
                 patch.object(cb, "cua_driver_child_env", return_value={}), \
                 patch.object(cb, "_run_quiet") as probe, \
                 patch("subprocess.Popen", side_effect=AssertionError("must not launch")):
                if isinstance(outcome, Exception):
                    probe.side_effect = outcome
                else:
                    probe.return_value = outcome
                with self.assertRaisesRegex(RuntimeError, "external_socket.*unavailable"):
                    adapter.proxy_invocation()
                probe.assert_called_once()
                self.assertEqual(probe.call_args.args[0], ["/driver", "status", "--socket", self.path])

    def test_external_cli_fallback_is_disabled_without_preflight_or_spawn(self):
        backend = cb.CuaDriverBackend("bounded")
        adapter = backend._embedded_daemon
        real_proxy = adapter.proxy_invocation

        def preflight_then_disappear():
            invocation = real_proxy()
            self.listener.close()
            Path(self.path).unlink()
            return invocation

        with patch.object(driver, "resolve_cua_driver_cmd", return_value="/driver"), \
             patch.object(cb, "cua_driver_child_env", return_value={"PATH": "/safe"}), \
             patch.object(cb, "_run_quiet", return_value=SimpleNamespace(returncode=0)) as probe, \
             patch.object(adapter, "proxy_invocation", side_effect=preflight_then_disappear) as proxy, \
             patch.object(session_mod, "_cli_run_json", return_value={"ok": True}) as run:
            with self.assertRaisesRegex(RuntimeError, "external.*CLI fallback.*disabled"):
                backend._session._call_tool_via_cli("get_cursor_position", {}, 2)
            run.assert_not_called()
            proxy.assert_not_called()
            probe.assert_not_called()
            with patch("tempfile.mkstemp") as temp:
                with self.assertRaisesRegex(RuntimeError, "external.*CLI fallback.*disabled"):
                    backend._session._call_tool_via_cli("get_window_state", {"pid": 101, "window_id": 202}, 2)
                temp.assert_not_called()

    def test_mcp_reconnect_revalidates_and_keeps_explicit_embedded_socket(self):
        mcp = importlib.import_module("mcp")
        backend = cb.CuaDriverBackend("bounded")
        session = backend._session
        self.addCleanup(backend._bridge.stop)
        self.addCleanup(session.stop)
        invocations = []

        @contextlib.asynccontextmanager
        async def stdio(params):
            invocations.append((params.command, params.args))
            yield (None, None)

        class Client:
            def __init__(self, *_):
                pass

            async def __aenter__(self):
                return self

            async def __aexit__(self, *_):
                pass

            async def initialize(self):
                pass

            async def list_tools(self):
                return SimpleNamespace(tools=[])

        with patch.object(driver, "resolve_cua_driver_cmd", return_value="/driver"), \
             patch.object(driver, "_resolve_mcp_invocation", side_effect=AssertionError("no default MCP")), \
             patch.object(cb, "sandbox_mcp_invocation", side_effect=AssertionError("no sandbox fallback")), \
             patch.object(cb, "cua_driver_child_env", return_value={"PATH": "/safe"}), \
             patch.object(cb, "_run_quiet", return_value=SimpleNamespace(returncode=0)) as probe, \
             patch("mcp.client.stdio.stdio_client", stdio), patch.object(mcp, "ClientSession", Client):
            session.start()
            with self.assertLogs("tools.computer_use.cua_backend", level="WARNING"):
                session._recreate_session("list_apps", 2, "test reconnect: %s")
            self.assertEqual(invocations, [("/driver", ["mcp", "--embedded", "--socket", self.path])] * 2)
            self.assertEqual(probe.call_count, 2)
            self.listener.close()
            Path(self.path).unlink()
            with self.assertLogs("tools.computer_use.cua_backend", level="WARNING"), \
                 self.assertRaisesRegex(RuntimeError, "external_socket.*unavailable"):
                session._recreate_session("list_apps", 2, "test missing runtime: %s")
            self.assertEqual(len(invocations), 2)
            self.assertFalse(session._started)

    def test_unconfigured_owned_and_standard_selection_are_unchanged(self):
        self.cfg.clear()
        standard = cb.CuaDriverBackend("standard")
        self.assertIsNone(standard._embedded_daemon)
        owned = cb.CuaDriverBackend("unrestricted")._embedded_daemon
        self.assertIsInstance(owned, cb._EmbeddedCuaDaemon)
        with self.assertRaisesRegex(ValueError, "capability_manifest"):
            cb.CuaDriverBackend("bounded")

    def test_yolo_session_mapping_is_rejected_before_any_owned_runtime(self):
        computer_use = importlib.import_module("tools.computer_use.tool")
        with patch("tools.approval.is_approval_bypass_active_for_session", return_value=True), \
             self.assertLogs("tools.computer_use.tool", level="WARNING"), \
             patch.object(cb, "_EmbeddedCuaDaemon", side_effect=AssertionError("no owned fallback")):
            mode = computer_use._cua_permission_mode("external-test-yolo")
            self.assertEqual(mode, "unrestricted")
            with self.assertRaisesRegex(ValueError, "external_socket.*unrestricted"):
                cb.CuaDriverBackend(mode)

    def test_failed_handshake_rollback_and_backend_stop_leave_external_socket(self):
        backend = cb.CuaDriverBackend("bounded")
        with patch.dict(os.environ, {"HERMES_CUA_DRIVER_CMD": "/driver"}), \
             patch.object(cb, "cua_driver_runtime_contract_status", return_value={"ready": True}), \
             patch.object(driver, "resolve_cua_driver_cmd", return_value="/driver"), \
             patch.object(cb, "cua_driver_child_env", return_value={}), \
             patch.object(cb, "_run_quiet", return_value=SimpleNamespace(returncode=0)) as probe, \
             patch("pm.ensure_import"), \
             patch.object(backend._session, "start", side_effect=RuntimeError("handshake refused")):
            with self.assertRaisesRegex(RuntimeError, "handshake refused"):
                backend.start()
            backend.stop()
            self.assertEqual([c.args[0] for c in probe.call_args_list],
                             [["/driver", "status", "--socket", self.path]])
        self.assertTrue(Path(self.path).exists())



if __name__ == "__main__":
    unittest.main()

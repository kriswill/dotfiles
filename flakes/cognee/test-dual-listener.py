"""Synthetic tests with the packaged Python/Uvicorn, not the Cognee app."""
import importlib.util
from pathlib import Path
import socket
import stat
import tempfile
import threading
import time
import unittest

spec = importlib.util.spec_from_file_location("cognee_listener", Path(__file__).with_name("dual-listener.py"))
assert spec is not None and spec.loader is not None
listener = importlib.util.module_from_spec(spec)
spec.loader.exec_module(listener)


async def app(scope, receive, send):
    if scope["type"] == "lifespan":
        await receive()
        await send({"type": "lifespan.startup.complete"})
        await receive()
        await send({"type": "lifespan.shutdown.complete"})
        return
    await send({"type": "http.response.start", "status": 200, "headers": []})
    await send({"type": "http.response.body", "body": scope["scheme"].encode()})


def request(client):
    with client:
        client.sendall(b"GET / HTTP/1.1\r\nHost: fixture.test\r\nConnection: close\r\n"
                       b"X-Forwarded-Proto: https\r\nX-Forwarded-For: 192.0.2.1\r\n\r\n")
        chunks = []
        while chunk := client.recv(4096):
            chunks.append(chunk)
        return b"".join(chunks)


class ListenerTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="uds-")
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name) / "api.sock"

    def test_single_uvicorn_accepts_tcp_and_unix_with_forwarded_https(self):
        config = listener.make_config(app, self.path)
        server = listener.Server(config)
        with listener.bind_unix(self.path) as unix, listener.bind_tcp(0) as tcp:
            self.assertEqual(stat.S_IMODE(self.path.stat().st_mode), 0o666)
            thread = threading.Thread(target=server.run, kwargs={"sockets": [tcp, unix]}, daemon=True)
            thread.start()
            try:
                for _ in range(300):
                    if server.started:
                        break
                    time.sleep(0.01)
                self.assertTrue(server.started)
                with socket.socket(socket.AF_UNIX) as client:
                    client.settimeout(1)
                    client.connect(str(self.path))
                    self.assertIn(b"\r\nhttps\r\n", request(client))
                self.assertIn(b"\r\nhttps\r\n", request(socket.create_connection(tcp.getsockname(), 1)))
            finally:
                server.should_exit = True
                thread.join(timeout=2)
                self.assertFalse(thread.is_alive())

    def test_only_a_stale_service_socket_can_be_replaced(self):
        self.path.write_text("keep me")
        with self.assertRaises(OSError):
            listener.bind_unix(self.path)
        self.assertEqual(self.path.read_text(), "keep me")
        self.path.unlink()
        self.path.symlink_to(self.path.parent / "absent")
        with self.assertRaises(OSError):
            listener.bind_unix(self.path)
        self.assertTrue(self.path.is_symlink())
        self.path.unlink()
        with listener.bind_unix(self.path) as live:
            live.listen()
            with self.assertRaises(OSError):
                listener.bind_unix(self.path)
        with listener.bind_unix(self.path):
            self.assertTrue(self.path.is_socket())
        self.path.parent.chmod(0o777)
        try:
            with self.assertRaises(OSError):
                listener.bind_unix(self.path)
        finally:
            self.path.parent.chmod(0o700)


if __name__ == "__main__":
    unittest.main()

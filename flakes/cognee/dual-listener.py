"""Run one Cognee/Uvicorn instance on loopback and a service-owned socket."""
import argparse
import os
from pathlib import Path
import socket
import stat

from uvicorn import Config, Server  # type: ignore[import-not-found]
from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware  # type: ignore[import-not-found]


def bind_unix(path):
    if not path.is_absolute() or path.suffix != ".sock" or len(os.fsencode(path)) >= 104:
        raise ValueError("Cognee requires a short absolute Unix socket path")
    parent = path.parent.lstat()
    if not stat.S_ISDIR(parent.st_mode) or parent.st_uid != os.getuid() or parent.st_mode & 0o022:
        raise PermissionError("The Cognee socket directory must be writable only by the service owner")
    try:
        existing = path.lstat()
    except FileNotFoundError:
        pass
    else:
        if not stat.S_ISSOCK(existing.st_mode) or existing.st_uid != parent.st_uid:
            raise PermissionError("Refusing to replace a non-service socket path")
        with socket.socket(socket.AF_UNIX) as probe:
            probe.settimeout(1)
            try:
                probe.connect(str(path))
            except ConnectionRefusedError:
                path.unlink()
            else:
                raise OSError("The Cognee socket is already listening")
    sock = socket.socket(socket.AF_UNIX)
    try:
        sock.bind(str(path))
        # Other services can connect but cannot replace the directory entry.
        path.chmod(0o666)
    except BaseException:
        sock.close()
        raise
    return sock


def bind_tcp(port):
    sock = socket.socket(socket.AF_INET)
    try:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind(("127.0.0.1", port))
    except BaseException:
        sock.close()
        raise
    return sock


def make_config(app, path, env_file=None):
    config = Config(app, env_file=env_file, workers=1, timeout_graceful_shutdown=10, proxy_headers=False)
    config.load()
    trusted = config.forwarded_allow_ips
    if isinstance(trusted, str):
        trusted = [item.strip() for item in trusted.split(",")]
    trusted = trusted if trusted == ["*"] else [*trusted, str(path)]
    proxied = ProxyHeadersMiddleware(config.loaded_app, trusted_hosts=trusted)

    async def with_unix_peer(scope, receive, send):
        # Unnamed Unix peers have no ASGI client address. Label only requests
        # arriving on this listener so the Caddy HTTPS scheme and client survive.
        if scope.get("server") == (str(path), None):
            scope = {**scope, "client": (str(path), 0)}
        await proxied(scope, receive, send)

    config.loaded_app = with_unix_peer
    return config


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--unix", type=Path, required=True)
    parser.add_argument("--env-file", type=Path)
    args = parser.parse_args()
    config = make_config("cognee.api.client:app", args.unix, args.env_file)
    with bind_tcp(args.port) as tcp, bind_unix(args.unix) as unix:
        server = Server(config)
        server.run(sockets=[tcp, unix])
        if not server.started:
            raise SystemExit(3)


if __name__ == "__main__":
    main()

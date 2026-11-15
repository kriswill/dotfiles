#!/usr/bin/env python3
"""Observe a Darwin host from another machine; emit JSONL without initiating a reboot."""

import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import json
import re
import socket
import subprocess
import threading
import time


PAYLOAD = (
    "set -eu; printf 'mini-readiness-v1\\n'; /bin/hostname; "
    "/usr/sbin/sysctl -n kern.boottime; /usr/bin/readlink /run/current-system"
)
BOOT_TIME = re.compile(r"sec\s*=\s*(\d+),\s*usec\s*=\s*(\d+)")


def probe(name, command, timeout):
    started = time.time()
    monotonic = time.monotonic()
    result = {"probe": name, "started_epoch": started}
    try:
        run = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
        result["exit_code"] = run.returncode
        match = BOOT_TIME.search(run.stdout)
        lines = run.stdout.splitlines()
        result["ready"] = (
            run.returncode == 0
            and bool(match)
            and len(lines) == 4
            and lines[0] == "mini-readiness-v1"
            and lines[3].startswith("/nix/store/")
        )
        if result["ready"]:
            result["boot_epoch"] = int(match[1]) + int(match[2]) / 1_000_000
            result["hostname"] = lines[1]
            result["system"] = lines[3]
    except subprocess.TimeoutExpired:
        result.update(ready=False, error="timeout")
    except OSError as error:
        result.update(ready=False, error=type(error).__name__)
    result["finished_epoch"] = time.time()
    result["duration_seconds"] = time.monotonic() - monotonic
    result["finished_utc"] = datetime.fromtimestamp(
        result["finished_epoch"], timezone.utc
    ).isoformat(timespec="microseconds")
    if result["ready"]:
        # Observer receipt time is an upper bound including transport latency;
        # compare clocks before interpreting this as time since remote boot.
        result["received_seconds_after_boot"] = (
            result["finished_epoch"] - result["boot_epoch"]
        )
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ssh", default="mini", help="existing SSH alias")
    parser.add_argument("--machine", default="mini", help="existing hc machine name")
    parser.add_argument("--interval", type=float, default=1.0)
    parser.add_argument("--timeout", type=int, default=3)
    parser.add_argument("--duration", type=float, default=180.0)
    args = parser.parse_args()
    if args.interval <= 0 or args.duration <= 0 or not 1 <= args.timeout <= 600:
        parser.error("interval/duration must be positive; timeout must be 1–600")
    if args.ssh.startswith("-") or args.machine.startswith("-"):
        parser.error("host aliases must not start with '-' ")

    commands = {
        "ssh": [
            "ssh", "-T", "-o", "BatchMode=yes", "-o", "ControlMaster=no",
            "-o", "ControlPath=none", "-o", "StrictHostKeyChecking=yes",
            "-o", "UpdateHostKeys=no", "-o", "ForwardAgent=no",
            "-o", "IdentityAgent=none", "-o", "IdentitiesOnly=yes",
            "-o", f"ConnectTimeout={args.timeout}", args.ssh, PAYLOAD,
        ],
        "core": [
            "hc", "exec", "--on", args.machine, "--timeout", str(args.timeout),
            "/bin/sh", "-c", PAYLOAD,
        ],
    }
    lock = threading.Lock()
    stop = threading.Event()
    deadline = time.monotonic() + args.duration

    def emit(record):
        with lock:
            print(json.dumps(record, sort_keys=True), flush=True)

    def observe(name, command):
        while not stop.is_set() and time.monotonic() < deadline:
            tick = time.monotonic()
            emit(probe(name, command, args.timeout + 1))
            stop.wait(max(0, min(deadline - time.monotonic(),
                                 args.interval - (time.monotonic() - tick))))

    emit({"observer": socket.gethostname(), "event": "measurement_start",
          "epoch": time.time(), "interval_seconds": args.interval,
          "duration_seconds": args.duration,
          "note": "Run externally before reboot; clocks must agree. No reboot is initiated."})
    with ThreadPoolExecutor(max_workers=2) as pool:
        jobs = [pool.submit(observe, name, command) for name, command in commands.items()]
        try:
            for job in jobs:
                job.result()
        except KeyboardInterrupt:
            stop.set()


if __name__ == "__main__":
    main()

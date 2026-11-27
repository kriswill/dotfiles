"""Emit only aggregate capacity metrics from Cognee's private state, never payloads."""
import json
import os
import sqlite3
import subprocess
import sys
import tempfile
import time
from pathlib import Path


def collect(root):
    result: dict = {"sampled": int(time.time())}
    try:
        out = subprocess.check_output(['/usr/bin/du', '-skx', str(root)], stderr=subprocess.DEVNULL, timeout=45)
        result['store_bytes'] = int(out.split()[0]) * 1024
    except (OSError, ValueError, subprocess.SubprocessError):
        pass
    with sqlite3.connect((root/'system/databases/cognee_db').as_uri() + '?mode=ro', uri=True, timeout=1) as db:
        deadline = time.monotonic() + 4
        db.set_progress_handler(lambda: int(time.monotonic() > deadline), 10000)
        for table in ('data', 'datasets'):
            result[table] = db.execute(f'SELECT count(*) FROM {table}').fetchone()[0]
        # A fixed trailing UTC hour; these are recorded operations, not HTTP traffic.
        rows = db.execute('''SELECT operation_name, count(*), sum(outcome='failed'),
            avg((julianday(ended_at)-julianday(started_at))*86400)
            FROM pipeline_runs WHERE created_at >= datetime('now','-1 hour')
            AND operation_name IN ('remember','recall') GROUP BY operation_name''').fetchall()
        result['ops_hour'] = {op: {'calls': n, 'failed': fail, 'mean_s': sec} for op,n,fail,sec in rows}
    return result


if __name__ == '__main__':
    out = Path(sys.argv[2]); data = collect(Path(sys.argv[1]))
    # Directory traversal is restricted to the service owner and the reader group.
    with tempfile.NamedTemporaryFile(mode='w', dir=out.parent, delete=False) as f:
        json.dump(data, f); f.flush(); os.fchmod(f.fileno(), 0o644)
    os.replace(f.name, out)

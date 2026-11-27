import { expect, test } from 'bun:test';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const viewer = 'operator@example.test';
const cookie = 'auth_token=synthetic-session';
const pageScript = join(import.meta.dir, 'cognee-capacity-page.js');

async function withPage(run, { viewerEmail = viewer, prepare = () => {} } = {}) {
  // Keep the paths short enough for Darwin's sockaddr_un.
  const dir = mkdtempSync(join(tmpdir(), 'cap-'));
  const pageSocket = join(dir, 'page.sock');
  const apiSocket = join(dir, 'api.sock');
  let child;
  try {
    const history = join(dir, 'history.json');
    writeFileSync(history, '[]');
    prepare(pageSocket);
    child = Bun.spawn([process.execPath, pageScript, 'serve', history, pageSocket, apiSocket], {
      env: { PATH: process.env.PATH, CAPACITY_VIEWER: viewerEmail, HTTP_PROXY: 'http://127.0.0.1:1' },
      cwd: dir, stdout: 'ignore', stderr: 'pipe',
    });
    const request = (path = '/capacity', init = {}) => fetch(`http://localhost${path}`, {
      unix: pageSocket, signal: AbortSignal.timeout(6000), ...init,
    });
    const ready = await (async () => {
      for (let i = 0; i < 100 && child.exitCode === null; i++) {
        if (await request().catch(() => null)) return true;
        await Bun.sleep(10);
      }
      return false;
    })();
    await run({ request, apiSocket, pageSocket, ready, child });
  } finally {
    if (child) {
      child.kill();
      await child.exited;
    }
    rmSync(dir, { recursive: true, force: true });
  }
}

test('capacity forwards the session only to Cognee auth over a Unix socket', async () => {
  await withPage(async ({ request, apiSocket, ready }) => {
    expect(ready).toBe(true);
    const seen = [];
    let result = () => Response.json({ email: viewer });
    const api = Bun.serve({ unix: apiSocket, fetch(req) {
      seen.push([req.method, new URL(req.url).pathname, req.headers.get('cookie'), req.headers.get('authorization')]);
      return result();
    } });
    const headers = { cookie, authorization: 'Bearer not-forwarded' };
    try {
      expect((await request()).status).toBe(401);
      expect((await request('/capacity/extra', { headers })).status).toBe(404);
      expect((await request('/capacity', { headers, method: 'POST' })).status).toBe(405);
      expect(seen).toEqual([]);

      const allowed = await request('/capacity/', { headers });
      expect(allowed.status).toBe(200);
      expect(allowed.headers.get('cache-control')).toBe('private, no-store');
      expect(await allowed.text()).toContain('Waiting for the first capacity sample');
      expect(seen).toEqual([['GET', '/api/v1/auth/me', cookie, null]]);
      expect(await (await request('/capacity', { headers, method: 'HEAD' })).text()).toBe('');

      result = () => Response.json({ email: 'other@example.test' });
      expect((await request('/capacity', { headers })).status).toBe(403);
      for (const status of [401, 403]) {
        result = () => new Response(null, { status });
        expect((await request('/capacity', { headers })).status).toBe(401);
      }
      result = () => new Response('not JSON');
      expect((await request('/capacity', { headers })).status).toBe(503);
      result = () => Response.redirect('http://localhost/credential-sink');
      expect((await request('/capacity', { headers })).status).toBe(503);
      expect(seen.every(([, path]) => path === '/api/v1/auth/me')).toBe(true);
    } finally {
      await api.stop(true);
      rmSync(apiSocket, { force: true });
    }
    expect((await request('/capacity', { headers })).status).toBe(503);
  });
});

test('capacity rejects an authenticated session without an operator allowlist', async () => {
  await withPage(async ({ request, apiSocket, ready }) => {
    expect(ready).toBe(true);
    const api = Bun.serve({ unix: apiSocket, fetch: () => Response.json({ email: viewer }) });
    try {
      expect((await request('/capacity', { headers: { cookie } })).status).toBe(403);
    } finally {
      await api.stop(true);
    }
  }, { viewerEmail: '' });
});

test('capacity refuses to replace a regular file at the listener path', async () => {
  await withPage(async ({ ready, child, pageSocket }) => {
    expect(ready).toBe(false);
    expect(child.exitCode).not.toBe(0);
    expect(readFileSync(pageSocket, 'utf8')).toBe('not a socket');
  }, { prepare: socket => writeFileSync(socket, 'not a socket') });
});

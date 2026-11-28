import { afterEach, describe, expect, test } from 'bun:test';
import { randomUUID } from 'node:crypto';
import { mkdirSync, mkdtempSync, rmSync, unlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';

import {
  formatUploadDocument,
  makeGitDoc,
  parseArgs,
  runSync,
  shouldIncludeDoc,
} from './okf-cognee-sync.ts';

const tempDirs: string[] = [];

afterEach(() => {
  while (tempDirs.length > 0) {
    rmSync(tempDirs.pop()!, { recursive: true, force: true });
  }
});

function git(repo: string, args: string[]): void {
  const proc = Bun.spawnSync(['git', '-C', repo, ...args], { stdout: 'pipe', stderr: 'pipe' });
  if (proc.exitCode !== 0) {
    throw new Error(`git ${args.join(' ')} failed: ${new TextDecoder().decode(proc.stderr)}`);
  }
}

function writeFile(root: string, rel: string, content: string): void {
  const target = join(root, rel);
  mkdirSync(dirname(target), { recursive: true });
  writeFileSync(target, content, 'utf8');
}

describe('okf-cognee-sync filtering and formatting', () => {
  test('excludes index.md, log.md, underscore dirs, and non-markdown', () => {
    const includes = ['patterns', 'playbooks', 'hosts', 'okf-profile.md'];
    expect(shouldIncludeDoc('patterns/dendritic-modules.md', includes)).toBe(true);
    expect(shouldIncludeDoc('okf-profile.md', includes)).toBe(true);
    expect(shouldIncludeDoc('patterns/index.md', includes)).toBe(false);
    expect(shouldIncludeDoc('patterns/log.md', includes)).toBe(false);
    expect(shouldIncludeDoc('decisions/foo.md', includes)).toBe(false);
    expect(shouldIncludeDoc('_okflight/scripts/main.md', includes)).toBe(false);
    expect(shouldIncludeDoc('hosts/viz.html', includes)).toBe(false);
  });

  test('prepends canonical Source header and rejects secret patterns', () => {
    const doc = makeGitDoc('hosts/mini.md', 'abc123');
    const out = new TextDecoder().decode(formatUploadDocument(doc, '---\ntype: Host\n---\nBody\n'));
    expect(out.startsWith('Source: knowledge/hosts/mini.md\n\n---\n')).toBe(true);
    expect(() => formatUploadDocument(doc, '-----BEGIN OPENSSH PRIVATE KEY-----\nabc')).toThrow();
    expect(() => formatUploadDocument(doc, 'token=sk-1234567890abcdefghijklmnop')).toThrow();
  });
});

describe('okf-cognee-sync end-to-end against mock Cognee', () => {
  test('seeds, no-ops, replaces modified, deletes removed, and reconciles without local state', async () => {
    const root = mkdtempSync(join(tmpdir(), 'okf-cognee-sync-test-'));
    tempDirs.push(root);
    const repo = join(root, 'repo');
    mkdirSync(repo, { recursive: true });

    git(repo, ['init', '-q']);
    git(repo, ['config', 'user.email', 'test@example.com']);
    git(repo, ['config', 'user.name', 'Test']);
    git(repo, ['config', 'commit.gpgsign', 'false']);

    writeFile(repo, 'knowledge/patterns/index.md', '# Patterns\n');
    writeFile(repo, 'knowledge/patterns/log.md', '# Log\n');
    writeFile(repo, 'knowledge/patterns/p1.md', '---\ntype: Pattern\n---\nPattern one.\n');
    writeFile(repo, 'knowledge/hosts/mini.md', '---\ntype: Host\n---\nMini host.\n');
    writeFile(repo, 'knowledge/decisions/d1.md', '---\ntype: Decision\n---\nExcluded.\n');
    git(repo, ['add', '.']);
    git(repo, ['commit', '-q', '-m', 'init']);

    // Dirty uncommitted file must be ignored.
    writeFile(repo, 'knowledge/hosts/dirty.md', 'uncommitted');

    const datasetId = randomUUID();
    const keyFile = join(root, 'key');
    const stateFile = join(root, 'state.json');
    writeFileSync(keyFile, 'test-api-key\n', 'utf8');

    const serverDocs = new Map<string, Record<string, unknown>>();
    const requests: Array<{ method: string; path: string }> = [];

    const server = Bun.serve({
      port: 0,
      async fetch(req) {
        const url = new URL(req.url);
        requests.push({ method: req.method, path: url.pathname });

        if (req.method === 'GET' && url.pathname === `/api/v1/datasets/${datasetId}/data`) {
          return Response.json([...serverDocs.values()]);
        }
        if (req.method === 'GET' && url.pathname === '/api/v1/datasets/status') {
          return Response.json({ [datasetId]: 'DATASET_PROCESSING_COMPLETED' });
        }
        if (req.method === 'POST' && url.pathname === '/api/v1/add') {
          const form = await req.formData();
          const metaList = JSON.parse(String(form.get('external_metadata') ?? '[]')) as Array<Record<string, string>>;
          for (const meta of metaList) {
            const id = randomUUID();
            serverDocs.set(id, {
              id,
              name: meta.relpath.replaceAll('/', '__'),
              extension: 'md',
              externalMetadata: meta,
            });
          }
          return Response.json({ status: 'ok' });
        }
        if (req.method === 'POST' && url.pathname === '/api/v1/cognify') {
          return Response.json({ [datasetId]: { pipeline_run_id: randomUUID() } });
        }
        if (req.method === 'DELETE' && url.pathname.startsWith(`/api/v1/datasets/${datasetId}/data/`)) {
          const id = url.pathname.slice(`/api/v1/datasets/${datasetId}/data/`.length);
          serverDocs.delete(id);
          return Response.json({ deleted: true });
        }
        return Response.json({ detail: 'not found' }, { status: 404 });
      },
    });

    try {
      const baseArgv = [
        '--repo', repo,
        '--base-url', `http://127.0.0.1:${server.port}`,
        '--dataset-id', datasetId,
        '--key-file', keyFile,
        '--state-file', stateFile,
        '--include', 'patterns', 'hosts',
      ];

      // 1. Seed initial 2 committed docs.
      expect(await runSync(parseArgs(baseArgv))).toBe(0);
      expect(serverDocs.size).toBe(2);
      const relpaths = new Set(
        [...serverDocs.values()].map((d) => (d.externalMetadata as Record<string, string>).relpath),
      );
      expect(relpaths).toEqual(new Set(['patterns/p1.md', 'hosts/mini.md']));

      // 2. Second run is a zero-HTTP no-op.
      requests.length = 0;
      expect(await runSync(parseArgs(baseArgv))).toBe(0);
      expect(requests).toEqual([]);

      // 3. Modify hosts/mini.md, remove patterns/p1.md, commit.
      writeFile(repo, 'knowledge/hosts/mini.md', '---\ntype: Host\n---\nUpdated mini.\n');
      unlinkSync(join(repo, 'knowledge/patterns/p1.md'));
      unlinkSync(join(repo, 'knowledge/hosts/dirty.md'));
      git(repo, ['add', '-A']);
      git(repo, ['commit', '-q', '-m', 'update and delete']);

      requests.length = 0;
      expect(await runSync(parseArgs(baseArgv))).toBe(0);
      expect(serverDocs.size).toBe(1);
      const only = [...serverDocs.values()][0];
      expect((only.externalMetadata as Record<string, string>).relpath).toBe('hosts/mini.md');
      expect(requests.filter((r) => r.method === 'DELETE')).toHaveLength(2);

      // 4. Delete state.json and reconcile: zero writes needed.
      unlinkSync(stateFile);
      requests.length = 0;
      expect(await runSync(parseArgs(baseArgv))).toBe(0);
      expect(requests.some((r) => r.method === 'POST' || r.method === 'DELETE')).toBe(false);
    } finally {
      server.stop(true);
    }
  });
});

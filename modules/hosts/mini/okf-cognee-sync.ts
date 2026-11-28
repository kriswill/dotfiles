#!/usr/bin/env bun
/**
 * Deterministic one-way sync from git HEAD's `knowledge/` OKF bundle into
 * Cognee's shared read-only `dotfiles-knowledge` dataset.
 *
 * Reads committed Markdown concept docs via `git ls-tree` / `git show` (never
 * the dirty working tree), skips generated `index.md`, `log.md`, `_okflight/`,
 * and `viz.html`, and mirrors changes via:
 *   - DELETE /api/v1/datasets/{dataset_id}/data/{data_id} (removed / modified)
 *   - Batched POST /api/v1/add (grouped by folder for clean node_set tagging)
 *   - Single POST /api/v1/cognify + status poll
 */

import { createHash } from 'node:crypto';
import { chmodSync, existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join, resolve } from 'node:path';

export const DEFAULT_BASE_URL = 'http://127.0.0.1:8000';
export const DEFAULT_REPO = join(homedir(), 'src', 'github', 'kriswill', 'dotfiles');
export const DEFAULT_KEY_FILE = join(homedir(), '.config', 'cognee', 'keys', 'dotfiles-sync');
export const DEFAULT_DATASET_ID_FILE = join(homedir(), '.config', 'cognee', 'dotfiles-knowledge.id');
export const DEFAULT_STATE_FILE = join(homedir(), '.local', 'state', 'okf-cognee-sync', 'state.json');
export const DEFAULT_INCLUDES = ['patterns', 'playbooks', 'hosts', 'okf-profile.md'] as const;

export const MAX_DOC_BYTES = 128 * 1024;
const STATUS_POLL_TIMEOUT_MS = 600_000;
const STATUS_POLL_INTERVAL_MS = 2_000;

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SECRET_PATTERNS = [
  /-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----/,
  /\b(?:sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,})\b/,
];

export interface GitDoc {
  relpath: string; // relative to knowledge/, e.g. "hosts/mini.md"
  blobSha: string;
  folder: string;
  uploadName: string;
}

export interface RemoteDocInfo {
  id: string;
  blobSha: string;
  name?: string;
}

export interface SyncState {
  datasetId?: string;
  commit?: string;
  includes?: string[];
  manifestDigest?: string;
  complete?: boolean;
  docs?: Record<string, { id: string; blobSha: string }>;
}

export interface SyncOptions {
  repo: string;
  ref: string;
  baseUrl: string;
  datasetId: string;
  datasetIdFile: string;
  keyFile: string;
  stateFile: string;
  includes: string[];
  batchSize: number;
  limit: number;
  dryRun: boolean;
  status: boolean;
  reconcile: boolean;
  allowMissingConfig: boolean;
}

export function makeGitDoc(relpath: string, blobSha: string): GitDoc {
  const slash = relpath.indexOf('/');
  return {
    relpath,
    blobSha,
    folder: slash === -1 ? 'root' : relpath.slice(0, slash),
    uploadName: relpath.replaceAll('/', '__'),
  };
}

export function shouldIncludeDoc(relpath: string, includes: readonly string[]): boolean {
  if (!relpath.endsWith('.md')) return false;
  const parts = relpath.split('/');
  if (parts.some((p) => p.startsWith('_') || p.startsWith('.'))) return false;
  const base = parts[parts.length - 1];
  if (base === 'index.md' || base === 'log.md') return false;
  if (includes.length === 0) return true;
  return includes.some((raw) => {
    const inc = raw.trim().replace(/^\/+|\/+$/g, '');
    return inc.length > 0 && (relpath === inc || relpath.startsWith(`${inc}/`));
  });
}

function runGit(repo: string, args: string[]): Uint8Array {
  const proc = Bun.spawnSync(['git', '-C', repo, ...args], {
    stdout: 'pipe',
    stderr: 'pipe',
  });
  if (proc.exitCode !== 0) {
    const err = new TextDecoder().decode(proc.stderr).trim();
    throw new Error(`git ${args.join(' ')} failed (${proc.exitCode}): ${err}`);
  }
  return proc.stdout;
}

export function listGitDocs(
  repo: string,
  includes: readonly string[],
  ref = 'HEAD',
): { commit: string; docs: GitDoc[] } {
  const commit = new TextDecoder().decode(runGit(repo, ['rev-parse', ref])).trim();
  const raw = new TextDecoder().decode(runGit(repo, ['ls-tree', '-r', '-z', ref, 'knowledge']));
  const docs: GitDoc[] = [];
  for (const entry of raw.split('\0')) {
    if (!entry) continue;
    const tab = entry.indexOf('\t');
    if (tab === -1) continue;
    const meta = entry.slice(0, tab).split(/\s+/);
    if (meta.length < 3 || meta[1] !== 'blob') continue;
    const fullPath = entry.slice(tab + 1);
    if (!fullPath.startsWith('knowledge/')) continue;
    const relpath = fullPath.slice('knowledge/'.length);
    if (shouldIncludeDoc(relpath, includes)) {
      docs.push(makeGitDoc(relpath, meta[2]));
    }
  }
  docs.sort((a, b) => a.relpath.localeCompare(b.relpath));
  return { commit, docs };
}

export function readGitBlob(repo: string, doc: GitDoc, ref = 'HEAD'): string {
  return new TextDecoder().decode(runGit(repo, ['show', `${ref}:knowledge/${doc.relpath}`]));
}

export function formatUploadDocument(doc: GitDoc, body: string): Uint8Array {
  const text = `Source: knowledge/${doc.relpath}\n\n${body.trimStart()}`;
  const encoded = new TextEncoder().encode(text);
  if (encoded.byteLength > MAX_DOC_BYTES) {
    throw new Error(`knowledge/${doc.relpath} exceeds ${MAX_DOC_BYTES} bytes (${encoded.byteLength} bytes)`);
  }
  for (const pattern of SECRET_PATTERNS) {
    if (pattern.test(text)) {
      throw new Error(`Refused to upload knowledge/${doc.relpath}: matched secret/key pattern`);
    }
  }
  return encoded;
}

export function manifestDigest(docs: readonly GitDoc[], includes: readonly string[]): string {
  const h = createHash('sha256');
  h.update(JSON.stringify([...includes].sort()));
  for (const doc of docs) {
    h.update(`\n${doc.relpath}:${doc.blobSha}`);
  }
  return h.digest('hex');
}

export function indexServerData(items: unknown[]): Record<string, RemoteDocInfo> {
  const indexed: Record<string, RemoteDocInfo> = {};
  for (const raw of items) {
    if (!raw || typeof raw !== 'object') continue;
    const item = raw as Record<string, unknown>;
    const id = String(item.id ?? '').trim();
    if (!id) continue;
    const extMeta = (item.externalMetadata ?? item.external_metadata) as Record<string, unknown> | undefined;
    let relpath = extMeta && typeof extMeta === 'object' ? String(extMeta.relpath ?? '').trim() : '';
    const blobSha = extMeta && typeof extMeta === 'object' ? String(extMeta.git_blob_sha ?? '').trim() : '';
    if (!relpath) {
      let name = String(item.name ?? '').trim();
      const ext = String(item.extension ?? '').trim().replace(/^\./, '');
      if (name) {
        if (ext && !name.endsWith(`.${ext}`)) name = `${name}.${ext}`;
        relpath = name.replaceAll('__', '/');
      }
    }
    if (relpath) {
      indexed[relpath] = { id, blobSha, name: typeof item.name === 'string' ? item.name : undefined };
    }
  }
  return indexed;
}

export function planSync(
  docs: readonly GitDoc[],
  remote: Record<string, RemoteDocInfo>,
  localDocs: Record<string, { id: string; blobSha: string }>,
): {
  adds: GitDoc[];
  updates: Array<{ doc: GitDoc; oldId: string }>;
  deletes: Array<{ relpath: string; id: string }>;
  unchanged: number;
} {
  const desired = new Set(docs.map((d) => d.relpath));
  const adds: GitDoc[] = [];
  const updates: Array<{ doc: GitDoc; oldId: string }> = [];
  const deletes: Array<{ relpath: string; id: string }> = [];
  let unchanged = 0;

  for (const relpath of Object.keys(remote).sort()) {
    if (!desired.has(relpath)) {
      deletes.push({ relpath, id: remote[relpath].id });
    }
  }

  for (const doc of docs) {
    const rInfo = remote[doc.relpath];
    if (!rInfo) {
      adds.push(doc);
      continue;
    }
    let remoteSha = rInfo.blobSha;
    const local = localDocs[doc.relpath];
    if (!remoteSha && local && local.id === rInfo.id) {
      remoteSha = local.blobSha;
    }
    if (remoteSha === doc.blobSha) {
      unchanged += 1;
    } else {
      updates.push({ doc, oldId: rInfo.id });
    }
  }
  return { adds, updates, deletes, unchanged };
}

async function readErrorDetail(resp: Response): Promise<string> {
  const raw = (await resp.text()).trim();
  if (!raw) return '';
  try {
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    for (const key of ['detail', 'message', 'error']) {
      if (typeof parsed[key] === 'string' && parsed[key].trim()) {
        return parsed[key].trim().slice(0, 300);
      }
    }
  } catch {
    // plain text body
  }
  return raw.replace(/\s+/g, ' ').slice(0, 300);
}

export class CogneeClient {
  readonly baseUrl: string;
  readonly apiKey: string;

  constructor(baseUrl: string, apiKey: string) {
    this.baseUrl = baseUrl.replace(/\/+$/, '');
    this.apiKey = apiKey;
  }

  private async requestJson(
    method: string,
    path: string,
    init: { body?: BodyInit; headers?: Record<string, string>; timeoutMs?: number } = {},
  ): Promise<unknown> {
    const resp = await fetch(`${this.baseUrl}${path}`, {
      method,
      headers: { 'X-Api-Key': this.apiKey, ...(init.headers ?? {}) },
      body: init.body,
      signal: AbortSignal.timeout(init.timeoutMs ?? 30_000),
    });
    if (!resp.ok) {
      const detail = await readErrorDetail(resp);
      throw new Error(`${method} ${path} returned HTTP ${resp.status}${detail ? `: ${detail}` : ''}`);
    }
    const text = (await resp.text()).trim();
    return text ? JSON.parse(text) : null;
  }

  async listDatasetData(datasetId: string): Promise<unknown[]> {
    try {
      const res = await this.requestJson('GET', `/api/v1/datasets/${encodeURIComponent(datasetId)}/data`);
      return Array.isArray(res) ? res : [];
    } catch (err) {
      if (err instanceof Error && err.message.includes('HTTP 404')) return [];
      throw err;
    }
  }

  async deleteData(datasetId: string, dataId: string): Promise<void> {
    await this.requestJson(
      'DELETE',
      `/api/v1/datasets/${encodeURIComponent(datasetId)}/data/${encodeURIComponent(dataId)}`,
      { timeoutMs: 60_000 },
    );
  }

  async addBatch(
    datasetId: string,
    folder: string,
    items: Array<{ doc: GitDoc; payload: Uint8Array; commitSha: string }>,
  ): Promise<unknown> {
    const form = new FormData();
    form.append('datasetId', datasetId);
    form.append('run_in_background', 'false');
    form.append('labels', JSON.stringify(items.map(() => folder)));
    form.append(
      'external_metadata',
      JSON.stringify(
        items.map(({ doc, commitSha }) => ({
          relpath: doc.relpath,
          folder: doc.folder,
          git_blob_sha: doc.blobSha,
          git_commit: commitSha,
          source: `knowledge/${doc.relpath}`,
        })),
      ),
    );
    form.append('node_set', 'okf');
    form.append('node_set', folder);
    for (const { doc, payload } of items) {
      form.append('data', new Blob([payload], { type: 'text/markdown; charset=utf-8' }), doc.uploadName);
    }
    return this.requestJson('POST', '/api/v1/add', { body: form, timeoutMs: 120_000 });
  }

  async cognify(datasetId: string, dataPerBatch = 5): Promise<unknown> {
    return this.requestJson('POST', '/api/v1/cognify', {
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        datasetIds: [datasetId],
        runInBackground: true,
        dataPerBatch,
      }),
      timeoutMs: 120_000,
    });
  }

  async pollCognify(
    datasetId: string,
    timeoutMs = STATUS_POLL_TIMEOUT_MS,
    intervalMs = STATUS_POLL_INTERVAL_MS,
  ): Promise<'completed' | 'errored' | 'running'> {
    const path = `/api/v1/datasets/status?dataset=${encodeURIComponent(datasetId)}&pipeline=cognify_pipeline`;
    const deadline = Date.now() + Math.max(0, timeoutMs);
    while (true) {
      let status = '';
      try {
        const parsed = (await this.requestJson('GET', path, { timeoutMs: 15_000 })) as Record<string, unknown> | null;
        if (parsed && typeof parsed === 'object') {
          let val: unknown = parsed[datasetId];
          if (val === undefined && Object.keys(parsed).length === 1) {
            val = Object.values(parsed)[0];
          }
          if (val && typeof val === 'object') {
            val = (val as Record<string, unknown>).cognify_pipeline;
          }
          status = String(val ?? '').toUpperCase();
        }
      } catch {
        // retry until deadline
      }
      if (status.endsWith('COMPLETED')) return 'completed';
      if (status.endsWith('ERRORED') || status.endsWith('FAILED')) return 'errored';
      if (Date.now() >= deadline) return 'running';
      await Bun.sleep(intervalMs);
    }
  }
}

function loadState(path: string): SyncState {
  if (!existsSync(path)) return {};
  try {
    const parsed = JSON.parse(readFileSync(path, 'utf8'));
    return parsed && typeof parsed === 'object' ? (parsed as SyncState) : {};
  } catch {
    return {};
  }
}

function saveState(path: string, state: SyncState): void {
  mkdirSync(dirname(path), { recursive: true });
  const tmp = `${path}.tmp`;
  writeFileSync(tmp, `${JSON.stringify(state, null, 2)}\n`, 'utf8');
  chmodSync(tmp, 0o600);
  renameSync(tmp, path);
}

function expandHome(p: string): string {
  return p.startsWith('~/') ? join(homedir(), p.slice(2)) : p;
}

export function parseArgs(argv: string[]): SyncOptions {
  const opts: SyncOptions = {
    repo: process.env.OKF_SYNC_REPO ?? DEFAULT_REPO,
    ref: 'HEAD',
    baseUrl: process.env.COGNEE_BASE_URL ?? DEFAULT_BASE_URL,
    datasetId: process.env.COGNEE_DATASET_ID ?? '',
    datasetIdFile: process.env.COGNEE_DATASET_ID_FILE ?? DEFAULT_DATASET_ID_FILE,
    keyFile: process.env.COGNEE_API_KEY_FILE ?? DEFAULT_KEY_FILE,
    stateFile: process.env.OKF_SYNC_STATE_FILE ?? DEFAULT_STATE_FILE,
    includes: [...DEFAULT_INCLUDES],
    batchSize: 10,
    limit: 0,
    dryRun: false,
    status: false,
    reconcile: false,
    allowMissingConfig: false,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = () => {
      if (i + 1 >= argv.length) throw new Error(`Missing value for ${arg}`);
      i += 1;
      return argv[i];
    };
    switch (arg) {
      case '--repo': opts.repo = next(); break;
      case '--ref': opts.ref = next(); break;
      case '--base-url': opts.baseUrl = next(); break;
      case '--dataset-id': opts.datasetId = next(); break;
      case '--dataset-id-file': opts.datasetIdFile = next(); break;
      case '--key-file': opts.keyFile = next(); break;
      case '--state-file': opts.stateFile = next(); break;
      case '--batch-size': opts.batchSize = Number.parseInt(next(), 10); break;
      case '--limit': opts.limit = Number.parseInt(next(), 10); break;
      case '--dry-run': opts.dryRun = true; break;
      case '--status': opts.status = true; break;
      case '--reconcile': opts.reconcile = true; break;
      case '--allow-missing-config': opts.allowMissingConfig = true; break;
      case '--include': {
        const vals: string[] = [];
        while (i + 1 < argv.length && !argv[i + 1].startsWith('--')) {
          i += 1;
          vals.push(argv[i]);
        }
        opts.includes = vals;
        break;
      }
      case '--all': opts.includes = []; break;
      case '-h':
      case '--help':
        console.log(
          'Usage: okf-cognee-sync [--repo DIR] [--base-url URL] [--dataset-id UUID] [--dataset-id-file PATH] [--key-file PATH] [--state-file PATH] [--include PATH... | --all] [--batch-size N] [--limit N] [--dry-run] [--status] [--reconcile] [--allow-missing-config]',
        );
        process.exit(0);
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }
  return opts;
}

export async function runSync(opts: SyncOptions): Promise<number> {
  const repo = resolve(expandHome(opts.repo));
  const keyPath = expandHome(opts.keyFile);
  const statePath = expandHome(opts.stateFile);
  const idFile = expandHome(opts.datasetIdFile);

  let datasetId = opts.datasetId.trim();
  if (!datasetId && idFile && existsSync(idFile)) {
    datasetId = readFileSync(idFile, 'utf8').trim();
  }
  if (!datasetId) {
    if (opts.allowMissingConfig) {
      console.error('okf-cognee-sync: dataset_id not configured; skipping.');
      return 0;
    }
    console.error('okf-cognee-sync: --dataset-id (or COGNEE_DATASET_ID) is required.');
    return 2;
  }
  if (!UUID_RE.test(datasetId)) {
    throw new Error(`Invalid dataset UUID: ${JSON.stringify(datasetId)}`);
  }

  if (!existsSync(keyPath)) {
    if (opts.allowMissingConfig) {
      console.error(`okf-cognee-sync: key file ${keyPath} absent; skipping.`);
      return 0;
    }
    console.error(`okf-cognee-sync: key file not found: ${keyPath}`);
    return 2;
  }
  const apiKey = readFileSync(keyPath, 'utf8').trim();
  if (!apiKey) {
    console.error(`okf-cognee-sync: key file is empty: ${keyPath}`);
    return 2;
  }

  const { commit, docs } = listGitDocs(repo, opts.includes, opts.ref);
  const digest = manifestDigest(docs, opts.includes);
  const state = loadState(statePath);

  if (
    !opts.dryRun &&
    !opts.status &&
    !opts.reconcile &&
    state.datasetId === datasetId &&
    state.manifestDigest === digest &&
    state.complete === true
  ) {
    console.log(`okf-cognee-sync: up to date (${docs.length} docs @ ${commit.slice(0, 8)})`);
    return 0;
  }

  const client = new CogneeClient(opts.baseUrl, apiKey);
  const remote = indexServerData(await client.listDatasetData(datasetId));
  const localDocs = state.docs ?? {};
  const { adds, updates, deletes, unchanged } = planSync(docs, remote, localDocs);

  const summary = `commit=${commit.slice(0, 8)} desired=${docs.length} remote=${Object.keys(remote).length} add=${adds.length} update=${updates.length} delete=${deletes.length} unchanged=${unchanged}`;
  if (opts.status || opts.dryRun) {
    console.log(`okf-cognee-sync: ${summary}`);
    if (opts.dryRun) {
      for (const d of deletes) console.log(`  - delete ${d.relpath}`);
      for (const u of updates) console.log(`  ~ update ${u.doc.relpath}`);
      for (const a of adds) console.log(`  + add    ${a.relpath}`);
    }
    return opts.status && (adds.length || updates.length || deletes.length) ? 1 : 0;
  }

  if (adds.length === 0 && updates.length === 0 && deletes.length === 0) {
    const synced: Record<string, { id: string; blobSha: string }> = {};
    for (const doc of docs) {
      if (remote[doc.relpath]) synced[doc.relpath] = { id: remote[doc.relpath].id, blobSha: doc.blobSha };
    }
    saveState(statePath, {
      datasetId,
      commit,
      includes: opts.includes,
      manifestDigest: digest,
      complete: true,
      docs: synced,
    });
    console.log(`okf-cognee-sync: already in sync (${summary})`);
    return 0;
  }

  let plannedDeletes = deletes;
  let plannedUpdates = updates;
  let plannedAdds = adds;
  let truncated = false;
  if (opts.limit > 0) {
    let rem = opts.limit;
    plannedDeletes = deletes.slice(0, rem);
    rem -= plannedDeletes.length;
    plannedUpdates = updates.slice(0, rem);
    rem -= plannedUpdates.length;
    plannedAdds = adds.slice(0, rem);
    truncated =
      plannedDeletes.length < deletes.length ||
      plannedUpdates.length < updates.length ||
      plannedAdds.length < adds.length;
  }

  for (const d of plannedDeletes) {
    console.log(`okf-cognee-sync: deleting ${d.relpath} (${d.id})`);
    await client.deleteData(datasetId, d.id);
  }
  for (const u of plannedUpdates) {
    console.log(`okf-cognee-sync: replacing ${u.doc.relpath} (deleting ${u.oldId})`);
    await client.deleteData(datasetId, u.oldId);
  }

  const toUpload = [...plannedUpdates.map((u) => u.doc), ...plannedAdds];
  if (toUpload.length > 0) {
    const byFolder = new Map<string, GitDoc[]>();
    for (const doc of toUpload) {
      const list = byFolder.get(doc.folder) ?? [];
      list.push(doc);
      byFolder.set(doc.folder, list);
    }
    const batchSize = Math.max(1, opts.batchSize);
    for (const folder of [...byFolder.keys()].sort()) {
      const folderDocs = byFolder.get(folder)!;
      for (let i = 0; i < folderDocs.length; i += batchSize) {
        const chunk = folderDocs.slice(i, i + batchSize);
        const prepared = chunk.map((doc) => ({
          doc,
          payload: formatUploadDocument(doc, readGitBlob(repo, doc, opts.ref)),
          commitSha: commit,
        }));
        console.log(`okf-cognee-sync: uploading ${prepared.length} doc(s) [folder=${folder}]`);
        await client.addBatch(datasetId, folder, prepared);
      }
    }

    console.log('okf-cognee-sync: running cognify...');
    await client.cognify(datasetId, Math.max(1, Math.min(opts.batchSize, 5)));
    const outcome = await client.pollCognify(datasetId);
    console.log(`okf-cognee-sync: cognify status=${outcome}`);
    if (outcome !== 'completed') return 1;
  }

  const refreshed = indexServerData(await client.listDatasetData(datasetId));
  const uploadedSet = new Set(toUpload.map((d) => d.relpath));
  const syncedDocs: Record<string, { id: string; blobSha: string }> = {};
  for (const doc of docs) {
    const r = refreshed[doc.relpath];
    if (!r) continue;
    const shaMatches =
      r.blobSha === doc.blobSha ||
      (!r.blobSha && uploadedSet.has(doc.relpath)) ||
      (!r.blobSha && localDocs[doc.relpath]?.id === r.id && localDocs[doc.relpath]?.blobSha === doc.blobSha);
    if (shaMatches) syncedDocs[doc.relpath] = { id: r.id, blobSha: doc.blobSha };
  }
  const desiredPaths = new Set(docs.map((d) => d.relpath));
  const remoteKeys = Object.keys(refreshed);
  const complete =
    !truncated &&
    Object.keys(syncedDocs).length === docs.length &&
    remoteKeys.length === desiredPaths.size &&
    remoteKeys.every((k) => desiredPaths.has(k));

  saveState(statePath, {
    datasetId,
    commit,
    includes: opts.includes,
    manifestDigest: complete ? digest : '',
    complete,
    docs: syncedDocs,
  });
  console.log(
    `okf-cognee-sync: done (uploaded=${toUpload.length} deleted=${plannedDeletes.length} complete=${complete})`,
  );
  return 0;
}

if (import.meta.main) {
  try {
    const code = await runSync(parseArgs(process.argv.slice(2)));
    process.exit(code);
  } catch (err) {
    console.error(`okf-cognee-sync: error: ${err instanceof Error ? err.message : String(err)}`);
    process.exit(1);
  }
}

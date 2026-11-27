import { expect, test } from 'bun:test';
import { Database } from 'bun:sqlite';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { page } from './cognee-capacity-page.js';

const G = 1024 ** 3;
const HOUR = 3600;
const DAY = 24 * HOUR;
const now = Date.UTC(2026, 10, 27, 20) / 1000;
const service = (t, overrides = {}) => ({
  sampled: t, data: 67, datasets: 12, store_bytes: 200 * 2 ** 20,
  ops_hour: { recall: { calls: 11, failed: 0, mean_s: 0.57 } }, ...overrides,
});
const sample = (t = now, overrides = {}) => ({
  t, total: 1800 * G, free: 1600 * G, pressure: 1, service: service(t),
  warnings: [], ...overrides,
});

test('publisher exports only validated display fields from private history', () => {
  const dir = mkdtempSync(join(tmpdir(), 'cognee-capacity-test-'));
  try {
    const history = join(dir, 'history.sqlite'), output = join(dir, 'history.json');
    const t = Math.floor(Date.now() / 1000) - 60;
    const diskWarning = 'plan: host storage reserve in ~84 days at 3.0 GiB/day over 15 sampled days. Compare Cognee store growth with other disk use; reclaim or provision storage.';
    const warnings = ['Critical host memory pressure now.', diskWarning];
    const row = sample(t, {
      load: 0.5, ram: 16 * G, swap: 0, cores: 8, rss: G, cpu: 2.5, health_s: 0.02,
      forecast: { eta: 84, days: 15, rate: 3 * G }, warnings,
    });
    const db = new Database(history);
    db.run('CREATE TABLE samples (hour INTEGER PRIMARY KEY, payload TEXT NOT NULL)');
    const insert = db.query('INSERT INTO samples VALUES (?, ?)');
    insert.run(1, JSON.stringify(sample(t - 3 * HOUR, { t: String(t - 3 * HOUR) })));
    insert.run(2, JSON.stringify({
      t: t - 2 * HOUR, total: '1800', free: {}, pressure: '1', health_s: null,
      service: { sampled: String(t - 2 * HOUR), store_bytes: 200, data: 0 },
      forecast: { days: '15', eta: 84, rate: G }, warnings: { note: 'not an assessment' },
    }));
    insert.run(3, JSON.stringify({
      t: t - HOUR, forecast: { days: 7, eta: null, rate: -G },
      service: { sampled: t - HOUR, ops_hour: {} }, warnings: [],
    }));
    insert.run(4, JSON.stringify({
      ...row,
      debug: 'private host data',
      forecast: { ...row.forecast, source: 'private forecast data' },
      warnings: [...warnings, 'private warning', `${diskWarning} Internal notes`, { text: 'private details' }],
      service: {
        ...row.service, owner: 'private service data',
        ops_hour: {
          recall: { ...row.service.ops_hour.recall, query: 'private operation data' },
          remember: { calls: 'many', failed: false, mean_s: {} },
          another_operation: { calls: 1, failed: 0, mean_s: 0.2 },
        },
      },
    }));
    db.close();

    const run = Bun.spawnSync([process.execPath, join(import.meta.dir, 'cognee-capacity-page.js'), 'publish', output, history], { cwd: dir });
    expect(run.exitCode).toBe(0);
    expect(JSON.parse(readFileSync(output, 'utf8'))).toEqual([
      { t: t - 2 * HOUR },
      { t: t - HOUR, forecast: { days: 7, eta: null, rate: -G }, service: { sampled: t - HOUR, ops_hour: {} }, warnings: [] },
      { ...row, service: { ...row.service, ops_hour: { ...row.service.ops_hour, remember: {} } } },
    ]);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('warnings and forecast lead the page, with raw readings last', () => {
  const html = page([sample(now, {
    warnings: ['Plan storage expansion <soon>'],
    forecast: { eta: 84, days: 15, rate: 3 * G },
  })], now);
  expect(html).toContain('Plan storage expansion &lt;soon&gt;');
  expect(html).not.toContain('<soon>');
  expect(html).toContain('84 days');
  expect(html.indexOf('Plan storage expansion')).toBeLessThan(html.indexOf('Disk runway'));
  expect(html.indexOf('Disk runway')).toBeLessThan(html.indexOf('Growth trends'));
  expect(html.indexOf('Performance trends')).toBeLessThan(html.indexOf('Raw measurements'));
});

test('warm-up, no trend, and breached reserve are distinct', () => {
  expect(page([], now)).toContain('Waiting for the first capacity sample');
  expect(page([sample()], now)).toContain('Collecting a baseline');
  expect(page([sample(now, { forecast: { eta: null, days: 7 } })], now)).toContain('No consistent decline');
  expect(page([sample(now, { free: 100 * G })], now)).toContain('Below operating reserve');
});

test('stale host data is never presented as current runway', () => {
  const html = page([sample(now - 3 * HOUR, { forecast: { eta: 82, days: 9, rate: G } })], now);
  expect(html).toContain('Stale readings');
  expect(html).not.toContain('82 days');
  expect(html).not.toContain('No active warnings');
});

test('missing service data is different from a measured zero-traffic hour', () => {
  const missing = page([sample(now, { service: undefined })], now);
  const inactive = page([sample(now, { service: service(now, { ops_hour: {} }) })], now);
  expect(missing).toContain('Service readings unavailable');
  expect(missing).toContain('<th scope="row">Recall</th><td>—</td><td>—</td>');
  expect(inactive).toContain('<th scope="row">Recall</th><td>0</td><td>0</td><td>—</td>');
});

test('missing days break growth lines rather than interpolating through gaps', () => {
  const rows = [3, 2, 0].map(d => sample(now - d * DAY, { free: (1600 + d) * G }));
  const html = page(rows, now);
  const line = html.match(/<path class="series" d="([^"]+)"/)[1];
  expect(line.match(/M/g)).toHaveLength(2);
  expect(line.match(/L/g)).toHaveLength(1);
});

test('daily Cognee history uses exporter days without changing host readings', () => {
  const day = Math.floor(now / DAY) * DAY;
  const earlier = service(day - 2 * DAY, { store_bytes: 180 * 2 ** 20, data: 60 });
  const latest = service(day - 15 * 60, { store_bytes: 220 * 2 ** 20, data: 70 });
  const rows = [
    sample(day - 2 * DAY, { service: earlier }),
    sample(day - 2 * HOUR),
    sample(day - 10 * 60, { service: latest }),
    sample(day - 5 * 60, { service: undefined, free: 1599 * G }),
    sample(day + 10 * 60, { service: latest, free: 1598 * G }),
  ];
  const html = page(rows, rows.at(-1).t);
  const storage = html.match(/<figure id="cognee-state"[\s\S]*?<\/figure>/)[0];
  expect(storage).toContain('2 sampled days');
  expect(storage).toContain('<span>2026-11-25</span><span>2026-11-26</span>');
  expect(storage).toMatch(/<path class="series" d="M[^"L]+L[^"M]+"/);
  expect(html).toContain('2026-11-26</th><td>1,599 GiB</td><td>220 MiB</td><td>70</td>');
  expect(html).toContain('2026-11-27</th><td>1,598 GiB</td><td>—</td><td>—</td>');
});

test('daily history includes exporter readings from days missing host observations', () => {
  const day = Math.floor(now / DAY) * DAY;
  const t = day + 10 * 60;
  const html = page([sample(t, { service: service(day - 10 * 60) })], t);
  expect(html).toContain('2026-11-26</th><td>—</td><td>200 MiB</td><td>67</td><td>—</td>');
});

test('latency uses distinct exporter hours and pauses across a zero-call hour', () => {
  const first = service(now - 3 * HOUR);
  const rows = [
    sample(now - 3 * HOUR, { service: first }),
    sample(now - 2 * HOUR, { service: first }),
    sample(now - HOUR, { service: service(now - HOUR, { ops_hour: {} }) }),
    sample(),
  ];
  const html = page(rows, now);
  expect(html).toContain('2 recorded hours with duration');
  const recall = html.match(/id="recall-latency"[\s\S]+?<path class="series" d="([^"]+)"/)[1];
  expect(recall.match(/M/g)).toHaveLength(2);
  expect(recall).not.toContain('L');
});

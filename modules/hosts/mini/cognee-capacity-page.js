// Two roles: a local publisher can read Hermes history; the web process only reads its snapshot.
import { Database } from 'bun:sqlite';
import { chmodSync, lstatSync, unlinkSync, writeFileSync, renameSync } from 'node:fs';
import { createConnection } from 'node:net';
import { dirname } from 'node:path';
const HOUR = 3600;
const DAY = 24 * HOUR;
const M = 1024 ** 2;
const G = 1024 ** 3;
const OPS = { recall: 'Recall', remember: 'Remember' };
const record = x => x !== null && typeof x === 'object' && !Array.isArray(x);
const nonnegative = x => Number.isFinite(x) && x >= 0;
const count = x => Number.isSafeInteger(x) && x >= 0;

// Match the watchdog's known messages, not arbitrary text from private history.
const WATCHDOG_WARNINGS = new Set([
  'Storage reserve breached. Reclaim space or add storage now.',
  'Critical host memory pressure now.',
  'Memory pressure persisted across three hourly samples. Compare API RSS and swap with other processes; reduce concurrency or plan more RAM if recurring.',
  'Host load exceeded CPU count across three hourly samples. Inspect API CPU and other workloads before moving hardware.',
  'Health endpoint took at least 3 s for three hourly probes. Check recall/ingest timings, DB contention and host pressure before sizing hardware.',
  'API process measurements unavailable. Check the process sampler.',
  'Cognee growth/usage snapshot missing or stale. Check org.nixos.cognee-capacity; host metrics are separate.',
  ...Object.keys(OPS).flatMap(op => [
    `${op} averaged over ${op === 'recall' ? 5 : 60}s in three sampled hours with at least five calls each. Check workload, model-provider latency and DB contention alongside host pressure before adding hardware.`,
    `At least 20% of recorded ${op} operations failed in three sampled hours. Inspect service errors; failure rate alone is not a hardware diagnosis.`,
  ]),
]);
const DISK_WARNING = /^(urgent|plan): host storage reserve in ~\d{1,2} days at \d{1,16}\.\d GiB\/day over \d{1,2} sampled days\. Compare Cognee store growth with other disk use; reclaim or provision storage\.$/;

function numericFields(source, keys, valid) {
  return Object.fromEntries(keys.filter(key => valid(source[key])).map(key => [key, source[key]]));
}

function publicSample(row, now) {
  const t = row?.t;
  if (!count(t) || t < now - 28 * DAY || t > now) return null;
  const snapshot = {
    t,
    ...numericFields(row, ['total', 'free', 'ram', 'swap', 'cores', 'rss'], count),
    ...numericFields(row, ['load', 'cpu', 'health_s'], nonnegative),
  };
  if ([1, 2, 4].includes(row.pressure)) snapshot.pressure = row.pressure;

  const f = row.forecast;
  if (count(f?.days) && Number.isFinite(f.rate) && (f.eta === null || nonnegative(f.eta))) {
    snapshot.forecast = { days: f.days, rate: f.rate, eta: f.eta };
  }
  const s = row.service;
  if (count(s?.sampled) && s.sampled <= t) {
    snapshot.service = { sampled: s.sampled, ...numericFields(s, ['store_bytes', 'data', 'datasets'], count) };
    if (record(s.ops_hour)) {
      const ops = snapshot.service.ops_hour = {};
      for (const op of Object.keys(OPS)) {
        if (!Object.hasOwn(s.ops_hour, op)) continue;
        const x = s.ops_hour[op];
        // A malformed reading is unknown, not evidence of zero calls.
        ops[op] = record(x) ? {
          ...numericFields(x, ['calls', 'failed'], count),
          ...numericFields(x, ['mean_s'], y => y === null || nonnegative(y)),
        } : {};
      }
    }
  }
  if (Array.isArray(row.warnings)) {
    const warnings = row.warnings.filter(w => typeof w === 'string' &&
      (WATCHDOG_WARNINGS.has(w) || DISK_WARNING.exec(w)?.[0] === w));
    // Only an explicitly empty assessment means "no warnings".
    if (warnings.length || !row.warnings.length) snapshot.warnings = warnings;
  }
  return snapshot;
}

const esc = Bun.escapeHTML;
const num = (x, unit = '', scale = 1, digits = 1) => Number.isFinite(x)
  ? `${(x / scale).toLocaleString('en-US', { maximumFractionDigits: digits })}${unit}` : '—';
const gib = x => num(x, ' GiB', G);
const mib = x => num(x, ' MiB', M);
const seconds = x => num(x, ' s', 1, 2);
const iso = t => new Date(t * 1000).toISOString();
const when = t => new Date(t * 1000).toLocaleString('en-US', {
  timeZone: 'America/Los_Angeles', dateStyle: 'medium', timeStyle: 'short',
});
const timestamp = t => Number.isFinite(t) ? `<time datetime="${iso(t)}">${when(t)} PT</time>` : '—';
const pressure = x => ({ 1: 'Normal', 2: 'Elevated', 4: 'Critical' })[x] ?? 'Unknown';

const css = `
  :root{color-scheme:dark;--bg:#151513;--panel:#1e1e1c;--line:#373633;--text:#edecea;--muted:#b8b6b2;--accent:#bc9bff;--good:#8dd7ad;--warn:#ffcb85;--bad:#ffaca6;font:15px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;background:var(--bg);color:var(--text)}
  *{box-sizing:border-box}body{margin:0}h1,h2,h3,p,dl,dd,figure{margin:0}h1{font-size:clamp(1.65rem,4vw,2.1rem);line-height:1.18;letter-spacing:-.03em}h2{font-size:1.15rem;letter-spacing:-.015em}h3{font-size:1rem;font-weight:600}small,.muted{color:var(--muted)}a{color:var(--accent);text-underline-offset:.22em}a:focus-visible,summary:focus-visible,.scroll:focus-visible{outline:2px solid var(--accent);outline-offset:3px}
  .bar{border-bottom:1px solid var(--line);background:var(--panel)}.wrap{max-width:72rem;padding-inline:clamp(1rem,4vw,2.5rem);margin-inline:auto}.bar .wrap{display:flex;align-items:center;justify-content:space-between;gap:1rem;min-height:3.35rem}.crumb{display:flex;align-items:center;gap:.65rem}.brand-dot{width:.65rem;height:.65rem;background:var(--accent);transform:rotate(45deg);margin-inline:.15rem .25rem}.bar a{display:inline-flex;align-items:center;min-height:44px}
  .title{display:flex;align-items:end;justify-content:space-between;gap:.75rem 2rem;flex-wrap:wrap;margin:1.65rem 0 1.05rem}.title p{font-size:.88rem}main section+section{margin-top:1.6rem}.panel{min-width:0;background:var(--panel);border:1px solid var(--line);border-radius:.75rem;padding:clamp(.9rem,2.5vw,1.3rem)}
  .attention{display:grid;grid-template-columns:auto 1fr;column-gap:.7rem;align-items:baseline;padding-block:.8rem}.attention p,.attention ul{grid-column:2;margin:.15rem 0 0}.attention ul{padding-inline-start:1.15rem}.attention li+li{margin-top:.25rem}.dot{width:.55rem;height:.55rem;border-radius:50%;display:inline-block;background:currentColor}.good{color:var(--good)}.warn{color:var(--warn)}.bad{color:var(--bad)}.unknown{color:var(--muted)}
  .runway{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1.15fr);gap:1.35rem;align-items:center}.runway p{margin-top:.35rem}.runway-value{font-size:clamp(1.2rem,3vw,1.55rem);font-weight:650;line-height:1.25;letter-spacing:-.025em}section.runway{margin-top:.85rem}.rail{height:.8rem;border-radius:1rem;overflow:hidden;background:#36343d;display:flex;margin-block:.65rem}.rail .used{background:#6b558d}.rail .reserve{background:#ae814d;margin-left:auto}.legend{display:flex;flex-wrap:wrap;gap:.35rem 1.2rem;font-size:.81rem}.swatch{display:inline-block;width:.55rem;height:.55rem;border-radius:2px;margin-right:.35rem;background:#ae814d}
  .section-head{margin-bottom:.55rem}.section-head p,figcaption{font-size:.86rem;color:var(--muted)}.pair{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:.75rem}.chart-head{display:flex;align-items:baseline;justify-content:space-between;gap:.3rem 1rem;flex-wrap:wrap}.chart-head strong,dd,td,.runway-value{font-variant-numeric:tabular-nums}.chart-head strong{color:var(--accent)}figure svg{display:block;width:100%;height:5.2rem;margin-top:.65rem;overflow:visible}.axis{stroke:var(--line);vector-effect:non-scaling-stroke}.series{fill:none;stroke:var(--accent);stroke-width:2;stroke-linecap:round;stroke-linejoin:round;vector-effect:non-scaling-stroke}.point{stroke:var(--accent);stroke-width:4;stroke-linecap:round;vector-effect:non-scaling-stroke}.chart-labels{display:flex;justify-content:space-between;gap:.5rem;line-height:1.35}.chart-labels span:last-child{text-align:right}.chart-empty{display:flex;min-height:6.3rem;align-items:center;font-size:.9rem;color:var(--muted)}
  .measurements summary{cursor:pointer;min-height:44px;padding:.65rem 0;font-weight:600}.measurements[open] summary{border-bottom:1px solid var(--line);margin-bottom:.85rem}.raw h3{margin-bottom:.4rem}.raw .pair{gap:1rem 2rem}.raw-fields{display:grid;grid-template-columns:minmax(0,1fr) auto;column-gap:.8rem;font-size:.89rem}.raw-fields dt,.raw-fields dd{border-bottom:1px solid var(--line);padding:.33rem 0}.raw-fields dt{color:var(--muted)}.raw-fields dd{text-align:right}.raw h3.table-heading{margin-top:1rem}.scroll{overflow:auto;max-width:100%}table{width:100%;border-collapse:collapse;text-align:right;font-size:.89rem}th,td{padding:.4rem .5rem;white-space:nowrap;border-bottom:1px solid var(--line)}th{font-weight:600;color:var(--muted)}th:first-child,td:first-child{text-align:left;padding-left:0}tr:last-child>*{border-bottom:0}
  footer{color:var(--muted);font-size:.83rem;padding-block:1rem 1.5rem;margin-top:.6rem}@media(max-width:43rem){.pair,.runway{grid-template-columns:minmax(0,1fr)}.runway{gap:.75rem}.title{margin-top:1.2rem}}`;

function shell(content, sampleTime) {
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Cognee capacity · mini</title><style>${css}</style></head><body>
    <nav class="bar" aria-label="Cognee"><div class="wrap"><span class="crumb"><span aria-hidden="true" class="brand-dot"></span><strong>Cognee</strong><span class="muted">/ mini</span></span><a href="/datasets">Back to datasets</a></div></nav>
    <main class="wrap"><header class="title"><h1>Capacity</h1>${Number.isFinite(sampleTime) ? `<p class="muted">Last host sample · ${timestamp(sampleTime)}</p>` : ''}</header>${content}</main>
    <footer class="wrap">Sampled hourly. Reload for the latest readings.</footer></body></html>`;
}

function attention(stale, warnings, service, hasAlerts) {
  const [tone, heading, note] = stale ? ['warn', 'Stale readings', 'The host sample is over two hours old. Check the hourly watchdog.']
    : warnings.length ? ['warn', 'Action recommended', service ? '' : 'Service readings unavailable.']
    : !service ? ['warn', 'Service readings unavailable', 'Host readings are current, but the Cognee exporter has no fresh sample.']
    : !hasAlerts ? ['unknown', 'Warning status unavailable', 'This sample did not include a warning assessment.']
    : ['good', 'No active warnings', 'Host and Cognee readings are current.'];
  return `<section class="panel attention" aria-label="Attention"><span class="dot ${tone}" aria-hidden="true"></span><h2 class="${tone}">${heading}</h2>${note ? `<p class="muted">${note}</p>` : ''}${warnings.length ? `${stale ? '<p>From the last host sample:</p>' : ''}<ul>${warnings.map(w => `<li>${esc(String(w))}</li>`).join('')}</ul>` : ''}</section>`;
}

function runway(r, stale) {
  if (!Number.isFinite(r.total) || r.total <= 0 || !Number.isFinite(r.free)) {
    return '<section class="panel runway"><h2>Disk runway</h2><p>Volume readings unavailable.</p></section>';
  }
  const reserve = Math.max(20 * G, r.total * .1);
  const f = r.forecast;
  const [value, note, tone] = stale ? ['Forecast unavailable', 'Disk figures are the last observed readings.', 'unknown']
    : r.free < reserve ? ['Below operating reserve', 'Reclaim space or add storage now.', 'bad']
    : !f ? ['Collecting a baseline', 'Needs seven days with at least 12 hourly samples per day.', 'unknown']
    : !Number.isFinite(f.eta) ? ['No consistent decline', `No date projected from ${num(f.days)} sampled days.`, 'unknown']
    : [`${f.eta < 1 ? 'Less than 1 day' : num(f.eta, ' days', 1, 0)} to reserve`,
      `Estimated from ${num(f.days)} sampled days at ${num(f.rate, ' GiB/day', G)} of host free space lost.`, f.eta <= 90 ? 'warn' : ''];
  const reservePct = Math.min(100, reserve / r.total * 100);
  const usedPct = Math.max(0, Math.min(100 - reservePct, (1 - r.free / r.total) * 100));
  return `<section class="panel runway" aria-labelledby="disk-runway"><div><h2 id="disk-runway">Disk runway</h2><p class="runway-value ${tone}">${value}</p><p class="muted">${note}</p></div>
    <div><strong>${gib(r.free)} free</strong> <span class="muted">of ${gib(r.total)}</span><div class="rail" aria-hidden="true"><span class="used" style="width:${usedPct}%"></span><span class="reserve" style="width:${reservePct}%"></span></div>
    <div class="legend muted"><span><i class="swatch" aria-hidden="true"></i>${gib(reserve)} operating reserve</span><span>${gib(Math.max(0, r.free - reserve))} above reserve</span></div></div></section>`;
}

function plot({ id, title, points, cadence, format, kind, current, label }) {
  const total = points.length;
  const count = `${total} ${kind === 'duration' ? 'recorded' : 'sampled'} ${kind === 'duration' ? (total === 1 ? 'hour with duration' : 'hours with duration') : (total === 1 ? 'day' : 'days')}`;
  if (total < 2) {
    return `<figure id="${id}" class="panel"><div class="chart-head"><h3>${title}</h3><strong>${format(current)}</strong></div><p class="chart-empty">${total === 0 ? 'No observations in this window.' : 'One observation. Waiting for another data point.'}</p><figcaption>${count}</figcaption></figure>`;
  }
  const first = points[0], last = points.at(-1);
  const min = Math.min(...points.map(p => p.y)), max = Math.max(...points.map(p => p.y));
  const x = p => (4 + 392 * (p.t - first.t) / (last.t - first.t)).toFixed(2);
  const y = p => (min === max ? 40 : 72 - 64 * (p.y - min) / (max - min)).toFixed(2);
  const line = points.map((p, i) => `${i && p.t - points[i - 1].t <= cadence ? 'L' : 'M'}${x(p)} ${y(p)}`).join(' ');
  const dots = points.filter((p, i) => p.t - (points[i - 1]?.t ?? -Infinity) > cadence && (points[i + 1]?.t ?? Infinity) - p.t > cadence);
  return `<figure id="${id}" class="panel"><div class="chart-head"><h3>${title}</h3><strong>${format(current)}</strong></div>
    <svg viewBox="0 0 400 80" preserveAspectRatio="none" role="img" aria-label="${title}: ${format(first.y)} at start, ${format(last.y)} at end; range ${format(min)} to ${format(max)}. Gaps indicate missing observations.">
      <path class="axis" d="M0 8H400 M0 40H400 M0 72H400"/><path class="series" d="${line}"/>
      ${dots.map(p => `<path class="point" d="M${x(p)} ${y(p)}h.01"/>`).join('')}
    </svg><figcaption><div class="chart-labels"><span>${label(first.t)}</span><span>${label(last.t)}</span></div><div>${count} · Range ${format(min)}–${format(max)}</div></figcaption></figure>`;
}

function trendData(rows, r) {
  const hostDays = new Map(), serviceDays = new Map(), serviceHours = new Map();
  const since = r.t - 28 * DAY;
  const latestExport = (buckets, cadence, s) => {
    const bucket = Math.floor(s.sampled / cadence) * cadence;
    if (!buckets.has(bucket) || s.sampled > buckets.get(bucket).sampled) buckets.set(bucket, s);
  };
  for (const row of rows) {
    if (row.t > since) hostDays.set(Math.floor(row.t / DAY) * DAY, row);
    const s = row.service;
    if (!Number.isFinite(s?.sampled) || s.sampled > row.t || s.sampled <= since) continue;
    // Host samples can repeat the last export. Bucket it by its own timestamp.
    latestExport(serviceDays, DAY, s);
    if (s.sampled > r.t - 48 * HOUR) latestExport(serviceHours, HOUR, s);
  }
  const series = (entries, measure) => Array.from(entries, ([t, source]) => ({ t, y: measure(source) }))
    .filter(p => Number.isFinite(p.y)).sort((a, b) => a.t - b.t);
  return {
    hostDays, serviceDays,
    hostFree: series(hostDays, row => row.free),
    serviceStorage: series(serviceDays, s => s.store_bytes),
    duration: op => series(serviceHours, s => {
      const reading = s.ops_hour?.[op];
      return reading?.calls > 0 ? reading.mean_s : null;
    }),
  };
}

const list = fields => `<dl class="raw-fields">${fields.map(([key, value]) => `<dt>${key}</dt><dd>${value}</dd>`).join('')}</dl>`;
const table = (name, columns, body) => `<div class="scroll" tabindex="0" role="region" aria-label="${name}"><table><thead><tr>${columns.map(c => `<th scope="col">${c}</th>`).join('')}</tr></thead><tbody>${body}</tbody></table></div>`;

function raw(r, s, hostDays, serviceDays) {
  const operations = Object.entries(OPS).map(([op, label]) => {
    const x = s?.ops_hour?.[op];
    const count = s?.ops_hour && !x ? 0 : null;
    return `<tr><th scope="row">${label}</th><td>${num(x?.calls ?? count)}</td><td>${num(x?.failed ?? count)}</td><td>${seconds(x?.calls > 0 ? x.mean_s : null)}</td></tr>`;
  }).join('');
  const dates = [...new Set([...hostDays.keys(), ...serviceDays.keys()])].sort((a, b) => b - a);
  const daily = dates.map(t => {
    const host = hostDays.get(t), service = serviceDays.get(t);
    return `<tr><th scope="row">${iso(t).slice(0, 10)}</th><td>${gib(host?.free)}</td><td>${mib(service?.store_bytes)}</td><td>${num(service?.data)}</td><td>${gib(host?.rss)}</td></tr>`;
  }).join('');
  return `<section><details class="panel measurements"><summary>Raw measurements</summary><div class="raw"><div class="pair">
    <div><h3>Host headroom</h3>${list([['Volume free', gib(r.free)], ['Volume capacity', gib(r.total)], ['Installed RAM', gib(r.ram)], ['Swap in use', mib(r.swap)], ['Memory pressure', pressure(r.pressure)], ['15-minute load / cores', `${num(r.load)} / ${num(r.cores)}`]])}</div>
    <div><h3>Cognee consumption</h3>${list([['Service state on disk', mib(s?.store_bytes)], ['Documents / datasets', `${num(s?.data)} / ${num(s?.datasets)}`], ['API account RSS (sum)', gib(r.rss)], ['API account CPU (100% = 1 core)', num(r.cpu, '%')], ['Health probe', num(r.health_s, ' ms', .001, 0)], ['Service sample', timestamp(s?.sampled)]])}</div></div>
    <h3 class="table-heading">Recorded operations · preceding hour</h3>${table('Recorded operations', ['Operation', 'Calls', 'Failed', 'Mean duration'], operations)}
    <h3 class="table-heading">Daily history</h3>${table('Daily history', ['UTC date', 'Host free', 'Cognee state', 'Documents', 'API RSS'], daily)}</div></details></section>`;
}

export function page(rows, now = Date.now() / 1000) {
  const r = rows.at(-1);
  if (!r) return shell('<section class="panel"><h2>Waiting for the first capacity sample</h2><p class="muted">The hourly watch has not published any readings yet.</p></section>');
  const stale = now - r.t > 2 * HOUR;
  const s = Number.isFinite(r.service?.sampled) && now - r.service.sampled <= 2 * HOUR ? r.service : null;
  const { hostDays, serviceDays, hostFree, serviceStorage, duration } = trendData(rows, r);
  const dateLabel = t => iso(t).slice(0, 10);
  const hourLabel = t => `${iso(t).slice(5, 10)} ${iso(t).slice(11, 16)} UTC`;
  return shell(`${attention(stale, r.warnings ?? [], s, Array.isArray(r.warnings))}${runway(r, stale)}
    <section><div class="section-head"><h2>Growth trends</h2><p>Up to 28 days · each source’s last reading per UTC day · gaps are not interpolated</p></div><div class="pair">
    ${plot({ id: 'host-free', title: 'Host free space', points: hostFree, cadence: DAY, format: gib, current: r.free, label: dateLabel })}
    ${plot({ id: 'cognee-state', title: 'Cognee storage', points: serviceStorage, cadence: DAY, format: mib, current: s?.store_bytes, label: dateLabel })}</div></section>
    <section><div class="section-head"><h2>Performance trends</h2><p>Up to 48 hours · mean duration of recorded operations, not total HTTP traffic · gaps mean no duration was recorded</p></div><div class="pair">
    ${Object.entries(OPS).map(([op, label]) => plot({ id: `${op}-latency`, title: `${label} latency`, points: duration(op), cadence: HOUR,
      format: seconds, kind: 'duration', current: s?.ops_hour?.[op]?.calls > 0 ? s.ops_hour[op].mean_s : null, label: hourLabel })).join('')}</div></section>
    ${raw(r, s, hostDays, serviceDays)}`, r.t);
}
async function prepareListener(path) {
  const dir = lstatSync(dirname(path));
  if (!dir.isDirectory() || dir.uid !== process.getuid() || (dir.mode & 0o022)) {
    throw new Error('Capacity listener requires a directory writable only by the service owner.');
  }
  const existing = lstatSync(path, { throwIfNoEntry: false });
  if (!existing) return;
  if (!existing.isSocket() || existing.uid !== dir.uid) {
    throw new Error('Refusing to replace a non-service socket path.');
  }
  await new Promise((resolve, reject) => {
    const socket = createConnection(path);
    socket.once('connect', () => {
      socket.destroy();
      reject(new Error('The capacity socket is already listening.'));
    });
    socket.once('error', error => error.code === 'ECONNREFUSED' ? resolve() : reject(error));
    socket.setTimeout(1000, () => socket.destroy(new Error('Capacity socket probe timed out.')));
  });
  unlinkSync(path);
}

const [mode,file,arg,apiSocket]=Bun.argv.slice(2);
if(mode==='publish'){
  const db = new Database(arg, { readonly: true });
  const now = Date.now() / 1000;
  const rows = [];
  try {
    for (const { payload } of db.query('select payload from samples order by hour desc limit 672').all()) {
      let row;
      try { row = JSON.parse(payload); } catch { continue; }
      const snapshot = publicSample(row, now);
      if (snapshot) rows.push(snapshot);
    }
  } finally {
    db.close();
  }
  rows.sort((a, b) => a.t - b.t);
  const tmp = `${file}.${crypto.randomUUID()}`;
  writeFileSync(tmp, JSON.stringify(rows), { mode: 0o644, flag: 'wx' });
  renameSync(tmp, file);
}else if(mode==='serve'){
  if (![arg, apiSocket].every(path => path?.startsWith('/') && path.endsWith('.sock') && Buffer.byteLength(path) < 104) || arg === apiSocket) {
    throw new Error('Capacity requires two distinct absolute Unix socket paths.');
  }
  await prepareListener(arg);
  const headers={'Content-Type':'text/html; charset=utf-8','Cache-Control':'private, no-store','Content-Security-Policy':"default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'none'; base-uri 'none'",'X-Content-Type-Options':'nosniff'};
  Bun.serve({unix: arg,async fetch(req){
    if(!['/capacity','/capacity/'].includes(new URL(req.url).pathname))return new Response(null,{status:404});
    if(req.method!=='GET'&&req.method!=='HEAD')return new Response(null,{status:405});
    const cookie=req.headers.get('cookie');const login=()=>new Response('<a href="/local-login">Sign in to Cognee</a>, then return to /capacity.',{headers,status:401});if(!cookie)return login();
    try {
      const who = await fetch('http://localhost/api/v1/auth/me', {
        unix: apiSocket, headers: { cookie }, redirect: 'error', signal: AbortSignal.timeout(5000),
      });
      if (who.status === 401 || who.status === 403) return login();
      if (!who.ok) throw new Error();
      const user = await who.json();
      if (!process.env.CAPACITY_VIEWER || user.email !== process.env.CAPACITY_VIEWER) {
        return new Response('Not authorized for operator metrics.', { status: 403, headers });
      }
    } catch {
      return new Response('Authentication service unavailable.', { status: 503, headers });
    }
    try{return new Response(page(await Bun.file(file).json()),{headers});}catch{return new Response(page([]),{headers,status:503});}
  }});
  chmodSync(arg, 0o666);
}

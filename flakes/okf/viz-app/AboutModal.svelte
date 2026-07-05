<script lang="ts">
  import { formatDate } from "./dates";
  import type { VizState } from "./state.svelte";

  const { viz, onClose }: { viz: VizState; onClose: () => void } = $props();
  const m = $derived(viz.model);
  const stats = $derived(viz.model.stats);

  const fmtBytes = (n: number) => (n >= 1024 * 1024 ? `${(n / 1024 / 1024).toFixed(2)} MB` : `${(n / 1024).toFixed(1)} KB`);
  const pct = (n: number, total: number) => {
    const p = (n / total) * 100;
    return p >= 1 ? `${p.toFixed(0)}%` : "<1%";
  };

  // Largest-first; the remainder up to totalBytes (template markup/CSS, repo
  // and commit metadata, facet maps, embedded config, the stats blob itself)
  // closes the table so the rows always sum to the total.
  const rows = $derived.by(() => {
    if (!stats) return [];
    const b = stats.bytes;
    const listed = [
      { label: "Embedded source files", count: Object.keys(m.files).length, bytes: b.files },
      { label: "Concept documents", count: m.nodes.length, bytes: b.nodes },
      { label: "Graph links", count: m.edges.length, bytes: b.edges },
      { label: "Directory listings", count: Object.keys(m.dirs).length, bytes: b.dirs },
      { label: "Viewer app (JS)", count: null, bytes: b.appJs },
      { label: "Viewer styles (CSS)", count: null, bytes: b.appCss },
    ].sort((a, b2) => b2.bytes - a.bytes);
    const rest = stats.totalBytes - listed.reduce((s, r) => s + r.bytes, 0);
    return [...listed, { label: "Page shell & metadata", count: null, bytes: rest }];
  });

  const generated = $derived.by(() => {
    if (!stats) return null;
    const date = formatDate(stats.generatedAt.slice(0, 10), m.cfg.display.dateFormat) ?? stats.generatedAt.slice(0, 10);
    return `${date} · ${stats.generatedAt.slice(11, 16)} UTC`;
  });
</script>

<!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions --
     the backdrop is a pointer-only dismiss affordance; Escape (svelte:window
     below) and the ✕ button are the keyboard paths -->
<div class="overlay" onclick={(e) => e.target === e.currentTarget && onClose()}>
  <div class="modal" role="dialog" aria-modal="true" aria-label="About this page">
    <header>
      <h2>{m.displayName} <span class="badge">{m.cfg.display.badge}</span></h2>
      <button class="close" aria-label="Close" onclick={onClose}>×</button>
    </header>
    <p class="about">{@html m.cfg.display.aboutHtml}</p>
    <p class="counts">{m.nodes.length} concepts · {m.edges.length} links · {Object.keys(m.files).length} embedded files</p>
    {#if stats}
      <h3>What's in this file</h3>
      <table>
        <thead><tr><th>Section</th><th class="num">Count</th><th class="num">Size</th><th class="num">%</th></tr></thead>
        <tbody>
          {#each rows as r (r.label)}
            <tr>
              <td>{r.label}</td>
              <td class="num">{r.count ?? ""}</td>
              <td class="num">{fmtBytes(r.bytes)}</td>
              <td class="num pct">{pct(r.bytes, stats.totalBytes)}</td>
            </tr>
          {/each}
        </tbody>
        <tfoot>
          <tr><td>Total</td><td></td><td class="num">{fmtBytes(stats.totalBytes)}</td><td></td></tr>
        </tfoot>
      </table>
      <p class="gen">Everything above is baked into this single HTML file — it works offline, straight from disk. Generated {generated}.</p>
    {/if}
  </div>
</div>
<svelte:window onkeydown={(e) => e.key === "Escape" && onClose()} />

<style>
  .overlay {
    position: fixed;
    inset: 0;
    z-index: 5; /* above the sidebar help bubble (4) */
    display: flex;
    align-items: center;
    justify-content: center;
    background: color-mix(in srgb, var(--page) 45%, transparent);
    backdrop-filter: blur(2px);
  }
  .modal {
    width: min(430px, calc(100vw - 32px));
    max-height: min(80vh, 640px);
    overflow-y: auto;
    background: var(--surface-1);
    border: 1px solid var(--grid);
    border-radius: 10px;
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.25);
    padding: 16px 18px;
  }
  header {
    display: flex;
    align-items: baseline;
    gap: 10px;
    margin-bottom: 8px;
  }
  h2 {
    font-size: 16px;
  }
  .badge {
    color: var(--ink-muted);
    font-weight: 500;
  }
  .close {
    margin-left: auto;
    flex: none;
    cursor: pointer;
    color: var(--ink-muted);
    font-size: 18px;
    line-height: 1;
    border: 0;
    background: none;
    padding: 0;
  }
  .close:hover {
    color: var(--ink-1);
  }
  .about {
    color: var(--ink-2);
    font-size: 12.5px;
  }
  .counts {
    color: var(--ink-muted);
    font-size: 12px;
    margin: 6px 0 12px;
  }
  h3 {
    font-size: 11px;
    font-weight: 600;
    color: var(--ink-muted);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin-bottom: 4px;
  }
  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 12.5px;
  }
  th {
    font-size: 10.5px;
    font-weight: 600;
    color: var(--ink-muted);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    text-align: left;
    padding: 3px 0;
    border-bottom: 1px solid var(--grid);
  }
  td {
    padding: 3px 0;
    color: var(--ink-2);
  }
  td.num,
  th.num {
    text-align: right;
    font-variant-numeric: tabular-nums;
    padding-left: 12px;
    white-space: nowrap;
  }
  td.pct {
    color: var(--ink-muted);
  }
  tfoot td {
    border-top: 1px solid var(--grid);
    font-weight: 600;
    color: var(--ink-1);
  }
  .gen {
    color: var(--ink-muted);
    font-size: 11.5px;
    margin-top: 10px;
  }
</style>

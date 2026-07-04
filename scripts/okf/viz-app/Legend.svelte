<script lang="ts">
  import type { VizState } from "./state.svelte";

  const { viz }: { viz: VizState } = $props();

  const toggle = (t: string, alt: boolean) => (alt ? viz.soloType(t) : viz.toggleType(t));
</script>

<div id="legend">
  <div class="leg-head">
    <span class="hint">types</span>
    <button class="lnk" onclick={() => viz.showAllTypes()}>all</button>
    <span class="sep">·</span>
    <button class="lnk" onclick={() => viz.hideAllTypes()}>none</button>
  </div>
  {#each viz.model.allTypes as t (t)}
    <div
      class="leg"
      class:off={viz.hidden.has(t)}
      role="button"
      tabindex="0"
      title="click toggles · alt-click isolates"
      onclick={(e) => toggle(t, e.altKey)}
      onkeydown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          toggle(t, e.altKey);
        }
      }}
    >
      <span class="dot" style="background:{viz.colorOf(t)}"></span>{t}
      <span class="n">{viz.model.typeCounts[t]}</span>
    </div>
  {/each}
</div>

<style>
  .leg-head {
    display: flex;
    align-items: center;
    gap: 5px;
    padding: 0 4px 3px;
  }
  .leg-head .hint {
    margin-right: auto;
    color: var(--ink-muted);
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }
  .leg-head .sep {
    color: var(--ink-muted);
    font-size: 12px;
  }
  .leg-head .lnk {
    padding: 0;
    font: inherit;
    font-size: 12px;
    color: var(--ink-muted);
    background: none;
    border: none;
    cursor: pointer;
  }
  .leg-head .lnk:hover {
    color: var(--ink-1);
    text-decoration: underline;
  }
  .leg {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 3px 4px;
    border-radius: 5px;
    cursor: pointer;
    user-select: none;
  }
  .leg:hover {
    background: var(--page);
  }
  .leg.off {
    opacity: 0.35;
  }
  .dot {
    width: 10px;
    height: 10px;
    border-radius: 50%;
    flex: none;
    box-shadow: 0 0 0 2px var(--surface-1);
  }
  .leg .n {
    margin-left: auto;
    color: var(--ink-muted);
    font-size: 12px;
    font-variant-numeric: tabular-nums;
  }
</style>

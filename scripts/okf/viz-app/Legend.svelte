<script lang="ts">
  import type { VizState } from "./state.svelte";

  const { viz }: { viz: VizState } = $props();

  const toggle = (t: string, alt: boolean) => (alt ? viz.soloType(t) : viz.toggleType(t));
  const toggleGroup = (g: string, alt: boolean) => (alt ? viz.soloGroup(g) : viz.toggleGroup(g));
  const onActivateKey = (fn: (alt: boolean) => void) => (e: KeyboardEvent) => {
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      fn(e.altKey);
    }
  };
  const groupOff = (g: string) => viz.model.groupTypes[g]!.every((t) => viz.hidden.has(t));
</script>

<div id="legend">
  <div class="leg-head">
    <span class="hint">types</span>
    <button class="lnk" onclick={() => viz.showAllTypes()}>all</button>
    <span class="sep">·</span>
    <button class="lnk" onclick={() => viz.hideAllTypes()}>none</button>
  </div>
  {#each viz.model.groupOrder as g (g)}
    <div class="grp">
      <div
        class="leg-group"
        class:off={groupOff(g)}
        role="button"
        tabindex="0"
        title="click toggles the group · alt-click isolates it"
        onclick={(e) => toggleGroup(g, e.altKey)}
        onkeydown={onActivateKey((alt) => toggleGroup(g, alt))}
      >
        {g}
      </div>
      {#each viz.model.groupTypes[g] as t (t)}
        <div
          class="leg"
          class:off={viz.hidden.has(t)}
          role="button"
          tabindex="0"
          title="click toggles · alt-click isolates"
          onclick={(e) => toggle(t, e.altKey)}
          onkeydown={onActivateKey((alt) => toggle(t, alt))}
        >
          <span class="dot" style="background:{viz.colorOf(t)}"></span>{t}
          <span class="n">{viz.model.typeCounts[t]}</span>
        </div>
      {/each}
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
  .grp {
    margin-bottom: 4px;
  }
  .leg-group {
    padding: 5px 4px 2px;
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    color: var(--ink-muted);
    border-radius: 5px;
    cursor: pointer;
    user-select: none;
  }
  .leg-group:hover {
    background: var(--page);
    color: var(--ink-1);
  }
  .leg-group.off {
    opacity: 0.35;
  }
  .leg {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 3px 4px 3px 10px;
    border-radius: 5px;
    cursor: pointer;
    user-select: none;
  }
  .leg:hover {
    background: var(--page);
    color: var(--ink-1);
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

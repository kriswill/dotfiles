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

{#snippet typeRow(t: string)}
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
{/snippet}

<div id="legend">
  <div class="leg-head">
    <button
      class="collapse-btn"
      aria-expanded={!viz.legendCollapsed}
      aria-label={viz.legendCollapsed ? "Expand type filters" : "Collapse type filters"}
      title="Toggle type filters"
      onclick={() => viz.setLegendCollapsed(!viz.legendCollapsed)}
    >
      <svg viewBox="0 0 16 16" width="13" height="13" aria-hidden="true" focusable="false">
        <path
          d="M2 3h12l-4.5 6v4l-3 1.5v-5.5L2 3z"
          fill="none"
          stroke="currentColor"
          stroke-width="1.4"
          stroke-linejoin="round"
          stroke-linecap="round"
        />
      </svg>
      <span class="hint">types</span>
    </button>
    <button class="lnk" onclick={() => viz.showAllTypes()}>all</button>
    <span class="sep">·</span>
    <button class="lnk" onclick={() => viz.hideAllTypes()}>none</button>
  </div>
  {#if !viz.legendCollapsed}
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
          {@render typeRow(t)}
        {/each}
      </div>
    {:else}
      <!-- No configured dir-groups: flat type list without cluster headers. -->
      {#each viz.model.allTypes as t (t)}
        {@render typeRow(t)}
      {/each}
    {/each}
  {/if}
</div>

<style>
  .leg-head {
    display: flex;
    align-items: center;
    gap: 5px;
    /* Flush with .top's own 14px inset (h1/search have none of their own),
       so the divider below this row lines up with everything above it. */
    padding: 0 0 3px;
  }
  .leg-head .sep {
    color: var(--ink-muted);
    font-size: 13px;
  }
  .leg-head .lnk {
    padding: 0;
    font: inherit;
    font-size: 13px;
    color: var(--ink-muted);
    background: none;
    border: none;
    cursor: pointer;
  }
  .leg-head .lnk:hover {
    color: var(--ink-1);
    text-decoration: underline;
  }
  .collapse-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    /* Padding grows the click/tap target around the icon+label; the equal
       negative margin cancels it back out for layout (so the icon stays
       flush-left and margin-right:auto still pushes all/none to the far
       edge, exactly like the plain .hint span used to). */
    padding: 5px 6px;
    margin: -5px auto -5px -6px;
    color: var(--ink-muted);
    background: none;
    border: none;
    border-radius: 5px;
    cursor: pointer;
  }
  .collapse-btn:hover,
  .collapse-btn:focus-visible {
    color: var(--ink-1);
    background: var(--page);
    outline: none;
  }
  /* .hint is the shared global primitive (viz.ts); sized up here only, so
     PLATFORM/NEIGHBORS keep their smaller caption size. */
  .collapse-btn .hint {
    font-size: 13px;
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

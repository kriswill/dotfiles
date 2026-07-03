<script lang="ts">
  import type { VizState } from "./state.svelte";

  const { viz }: { viz: VizState } = $props();

  const toggle = (t: string) => viz.toggleType(t);
</script>

<div id="legend">
  {#each viz.model.allTypes as t (t)}
    <div
      class="leg"
      class:off={viz.hidden.has(t)}
      role="button"
      tabindex="0"
      onclick={() => toggle(t)}
      onkeydown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          toggle(t);
        }
      }}
    >
      <span class="dot" style="background:{viz.colorOf(t)}"></span>{t}
      <span class="n">{viz.model.typeCounts[t]}</span>
    </div>
  {/each}
</div>

<style>
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

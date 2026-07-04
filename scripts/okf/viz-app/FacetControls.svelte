<script lang="ts">
  import type { VizState } from "./state.svelte";

  const { viz }: { viz: VizState } = $props();
</script>

{#each viz.model.facets as facet (facet.name)}
  <div class="facet">
    <span class="hint">{facet.name}</span>
    {#each ["all", ...facet.values] as v (v)}
      <button
        class="seg"
        class:active={viz.facetSel[facet.name] === v}
        onclick={() => viz.setFacet(facet.name, v)}>{v}</button
      >
    {/each}
  </div>
{/each}

<style>
  /* .hint / .seg are global primitives (viz.ts) shared with the other controls. */
  .facet {
    display: flex;
    align-items: center;
    gap: 5px;
    padding: 6px 4px;
    margin-bottom: 6px;
    border-top: 1px solid var(--grid);
  }
</style>

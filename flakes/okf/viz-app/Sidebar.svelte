<script lang="ts">
  import AboutModal from "./AboutModal.svelte";
  import ConceptList from "./ConceptList.svelte";
  import FacetControls from "./FacetControls.svelte";
  import IsolateControl from "./IsolateControl.svelte";
  import Legend from "./Legend.svelte";
  import Search from "./Search.svelte";
  import type { VizState } from "./state.svelte";

  const { viz }: { viz: VizState } = $props();
  let aboutOpen = $state(false);
</script>

<aside id="side">
  <div class="top">
    <h1>
      <span class="name">{viz.model.displayName} <span class="okf">{viz.model.cfg.display.badge}</span></span>
      <button class="help" aria-label="About this page" aria-haspopup="dialog" onclick={() => (aboutOpen = true)}>?</button>
    </h1>
    <div class="sub" id="counts">
      {#if viz.hidden.size > 0 || viz.query.trim() || viz.neighborIds || viz.facetActive}
        {viz.visibleSorted.length} of {viz.model.nodes.length} concepts · {viz.model.edges.length} links
      {:else}
        {viz.model.nodes.length} concepts · {viz.model.edges.length} links
      {/if}
    </div>
    <Search {viz} />
    <Legend {viz} />
  </div>
  <div class="scroll">
    <ConceptList {viz} />
  </div>
  <div class="bottom">
    <FacetControls {viz} />
    <IsolateControl {viz} />
  </div>
</aside>

{#if aboutOpen}
  <AboutModal {viz} onClose={() => (aboutOpen = false)} />
{/if}

<style>
  #side {
    /* Overlays the full-bleed canvas (Stage.svelte's SIDEBAR_WIDTH constant
       must match this). */
    position: absolute;
    top: 0;
    left: 0;
    bottom: 0;
    width: 260px;
    border-right: 1px solid var(--grid);
    /* Outside (left, screen edge) is fully opaque; inside (right, canvas
       edge) eases to 90% so the scene reads through faintly at the seam. */
    background: linear-gradient(
      to right,
      var(--surface-1),
      color-mix(in srgb, var(--surface-1) 90%, transparent)
    );
    display: flex;
    flex-direction: column;
    overflow: hidden;
    z-index: 2;
  }
  .top {
    flex: none;
    padding: 14px 14px 6px;
  }
  .scroll {
    flex: 1;
    min-height: 0; /* required: without it a flex column child with overflow
                      won't actually shrink/scroll — it'll push .bottom out
                      of the visible area instead */
    overflow-y: auto;
    padding: 0 14px 6px;
  }
  .bottom {
    /* No border-top of its own — FacetControls' .facet rule already draws
       one, which now sits right at this panel's top edge. */
    flex: none;
    padding: 0 14px 14px;
  }
  #side h1 {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    font-size: 15px;
    margin-bottom: 2px;
  }
  #side h1 .name {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  #side h1 .okf {
    color: var(--ink-muted);
    font-weight: 500;
  }
  .help {
    flex: none;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 22px;
    height: 22px;
    padding: 0;
    border: 1px solid var(--grid);
    border-radius: 50%;
    background: none;
    color: var(--ink-muted);
    font: inherit;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
  }
  .help:hover,
  .help:focus-visible {
    color: var(--ink-1);
    border-color: var(--ink-muted);
    background: color-mix(in srgb, var(--ink-muted) 12%, transparent);
    outline: none;
  }
  #side .sub {
    color: var(--ink-muted);
    font-size: 12px;
    margin-bottom: 12px;
  }
</style>

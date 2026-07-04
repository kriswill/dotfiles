<script lang="ts">
  import ConceptList from "./ConceptList.svelte";
  import FacetControls from "./FacetControls.svelte";
  import IsolateControl from "./IsolateControl.svelte";
  import Legend from "./Legend.svelte";
  import Search from "./Search.svelte";
  import type { VizState } from "./state.svelte";
  import ThemeSlider from "./ThemeSlider.svelte";

  const { viz }: { viz: VizState } = $props();
</script>

<aside id="side">
  <div class="scroll">
    <h1>
      {viz.model.displayName} <span class="okf">{viz.model.cfg.display.badge}</span>
      <!-- svelte-ignore a11y_no_noninteractive_tabindex -- ARIA tooltip pattern:
           focusable trigger, and a <button> can't host the bubble's link -->
      <span class="help" tabindex="0" aria-label="What is this?">?<span class="bubble" role="tooltip">
          {@html viz.model.cfg.display.aboutHtml}
        </span></span>
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
    <FacetControls {viz} />
    <IsolateControl {viz} />
    <ConceptList {viz} />
  </div>
  <ThemeSlider {viz} />
</aside>

<style>
  #side {
    border-right: 1px solid var(--grid);
    background: var(--surface-1);
    display: flex;
    flex-direction: column;
    overflow: hidden;
    z-index: 2;
  }
  .scroll {
    flex: 1;
    overflow-y: auto;
    padding: 14px;
  }
  #side h1 {
    position: relative;
    font-size: 15px;
    margin-bottom: 2px;
  }
  #side h1 .okf {
    color: var(--ink-muted);
    font-weight: 500;
  }
  .help {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 15px;
    height: 15px;
    border: 1px solid var(--grid);
    border-radius: 50%;
    color: var(--ink-muted);
    font-size: 10px;
    font-weight: 600;
    vertical-align: 2px;
    cursor: help;
  }
  .help:hover,
  .help:focus-visible {
    color: var(--ink-1);
    border-color: var(--ink-muted);
    outline: none;
  }
  .bubble {
    display: none;
    position: absolute;
    left: 0;
    right: 0;
    top: calc(100% + 6px);
    background: var(--surface-1);
    border: 1px solid var(--grid);
    border-radius: 8px;
    padding: 8px 10px;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12);
    z-index: 4;
    color: var(--ink-2);
    font-size: 12px;
    font-weight: 400;
    line-height: 1.45;
  }
  /* Invisible bridge over the gap (6px + the icon's line-box descent) so
     hover survives the transit from the (?) down into the bubble. */
  .bubble::before {
    content: "";
    position: absolute;
    left: 0;
    right: 0;
    top: -18px;
    height: 18px;
  }
  .help:hover .bubble,
  .help:focus-within .bubble {
    display: block;
  }
  #side .sub {
    color: var(--ink-muted);
    font-size: 12px;
    margin-bottom: 12px;
  }
</style>

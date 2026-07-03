<script lang="ts">
  import ConceptList from "./ConceptList.svelte";
  import Legend from "./Legend.svelte";
  import Search from "./Search.svelte";
  import type { VizState } from "./state.svelte";
  import ThemeSlider from "./ThemeSlider.svelte";

  const { viz }: { viz: VizState } = $props();
</script>

<aside id="side">
  <div class="scroll">
    <h1>knowledge/ bundle</h1>
    <div class="sub" id="counts">{viz.model.nodes.length} concepts · {viz.model.edges.length} links</div>
    <Search {viz} />
    <Legend {viz} />
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
    font-size: 15px;
    margin-bottom: 2px;
  }
  #side .sub {
    color: var(--ink-muted);
    font-size: 12px;
    margin-bottom: 12px;
  }
</style>

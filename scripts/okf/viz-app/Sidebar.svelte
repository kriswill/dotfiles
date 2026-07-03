<script lang="ts">
  import ConceptList from "./ConceptList.svelte";
  import Legend from "./Legend.svelte";
  import Search from "./Search.svelte";
  import type { VizState } from "./state.svelte";

  const { viz }: { viz: VizState } = $props();
</script>

<aside id="side">
  <h1>knowledge/ bundle</h1>
  <div class="sub" id="counts">{viz.model.nodes.length} concepts · {viz.model.edges.length} links</div>
  <Search {viz} />
  <Legend {viz} />
  <ConceptList {viz} />
</aside>

<style>
  #side {
    border-right: 1px solid var(--grid);
    background: var(--surface-1);
    padding: 14px;
    overflow-y: auto;
    z-index: 2;
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

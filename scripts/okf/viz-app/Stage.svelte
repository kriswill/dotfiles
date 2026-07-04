<script lang="ts">
  import DetailPanel from "./DetailPanel.svelte";
  import { GraphScene, type CreateScene, type SceneApi, type SceneNode } from "./scene";
  import type { VizState } from "./state.svelte";
  import Tooltip from "./Tooltip.svelte";

  interface Props {
    viz: VizState;
    createScene?: CreateScene;
    onSceneReady?: (scene: SceneApi) => void;
    onFirstFrame?: () => void;
  }

  const {
    viz,
    createScene = (el, nodes, edges, theme, cb) => new GraphScene(el, nodes, edges, theme, cb),
    onSceneReady,
    onFirstFrame,
  }: Props = $props();

  let el = $state<HTMLElement | null>(null);
  let scene = $state<SceneApi | null>(null);
  // clientWidth is not a signal — the window resize listener below bumps this
  // so width-derived state (view shift here, panel width in DetailPanel)
  // re-reads it.
  let resizeSeq = $state(0);

  // The scene keeps this array by reference; the theme bridge mutates entry
  // colors in place before applyTheme() re-reads them (legacy contract).
  // svelte-ignore state_referenced_locally -- viz's identity never changes
  const sceneNodes: SceneNode[] = viz.model.nodes.map((n, i) => ({
    x: n.x,
    y: n.y,
    z: n.z,
    r: viz.model.radii[i]!,
    color: viz.colorOf(n.type),
    title: n.title,
  }));

  const attach = (node: HTMLElement) => {
    const s = createScene(node, sceneNodes, viz.model.edgeIdx, viz.theme(), {
      onHover(i, cx, cy) {
        if (i === null) {
          viz.hover = null;
          return;
        }
        const rect = node.getBoundingClientRect();
        viz.hover = { i, x: Math.min(cx - rect.left + 14, rect.width - 330), y: cy - rect.top + 14 };
      },
      onSelect(i) {
        if (i === null) viz.clearSelection();
        else viz.selectConcept(viz.model.nodes[i]!.id, true);
      },
      onFirstFrame,
    });
    scene = s;
    onSceneReady?.(s);
  };

  // Reactive state → imperative scene. Dependencies must be read inside the
  // effect body — the closures handed to the scene run outside tracking.
  $effect(() => {
    void viz.query;
    void viz.hidden.size;
    void viz.isolateDepth;
    void viz.sel;
    scene?.setDim((i) => !viz.visible(viz.model.nodes[i]!));
  });

  $effect(() => {
    void viz.selSeq;
    scene?.setSelected(viz.sceneSelectedIndex, viz.fly);
  });

  $effect(() => {
    void resizeSeq;
    const open = viz.sel.kind !== "none";
    const px = viz.panelPx(el?.clientWidth ?? 0);
    scene?.setViewShift(open ? px : 0);
  });

  $effect(() => {
    void viz.dark;
    void viz.paletteVersion;
    const colors = viz.model.nodes.map((n) => viz.colorOf(n.type));
    const theme = viz.theme();
    if (!scene) return;
    sceneNodes.forEach((sn, i) => (sn.color = colors[i]!));
    scene.applyTheme(theme);
  });
</script>

<svelte:window onresize={() => resizeSeq++} />

<main id="stage" bind:this={el} {@attach attach}>
  <Tooltip {viz} />
  <DetailPanel {viz} stageEl={el} {resizeSeq} />
</main>

<style>
  #stage {
    position: relative;
    overflow: hidden;
  }
</style>

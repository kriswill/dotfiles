<script lang="ts">
  import { decodeHash, encodeHash } from "./hash";
  import { installPerf, mark, summary } from "./perf";
  import type { CreateScene, SceneApi } from "./scene";
  import Sidebar from "./Sidebar.svelte";
  import Stage from "./Stage.svelte";
  import type { VizState } from "./state.svelte";

  interface Props {
    viz: VizState;
    /** Test seam, forwarded to Stage. */
    createScene?: CreateScene;
  }
  const { viz, createScene }: Props = $props();

  /* --- URL state (hash) — selections survive reload and back/forward ------ */
  let currentState: string | null = null;

  function applyHash() {
    const h = decodeURIComponent(location.hash.slice(1));
    if (h === currentState) return;
    currentState = h;
    const sel = decodeHash(h, viz.model);
    if (sel.kind === "concept") viz.selectConcept(sel.id, true);
    else if (sel.kind === "file") viz.selectFile(sel.path);
    else viz.clearSelection();
  }

  $effect(() => {
    const h = encodeHash(viz.sel);
    if (currentState === h) return;
    currentState = h;
    if (location.hash.slice(1) !== h) {
      if (h) location.hash = h;
      else {
        try {
          history.pushState(null, "", location.pathname + location.search);
        } catch {
          location.hash = "";
        }
      }
    }
  });

  /* --- dark mode ----------------------------------------------------------- */
  $effect(() => {
    const m = matchMedia("(prefers-color-scheme: dark)");
    const on = () => viz.systemSchemeChanged(m.matches);
    m.addEventListener("change", on);
    return () => m.removeEventListener("change", on);
  });

  /* --- debug/scripting hook (also used by automated visual checks) --------- */
  let sceneRef: SceneApi | null = null;
  const okf: Record<string, unknown> = {
    select: (id: string, fly = true) => (viz.model.byId[id] ? viz.selectConcept(id, fly) : viz.clearSelection()),
    selectFile: (path: string) => viz.selectFile(path),
    get scene() {
      return sceneRef;
    },
    // svelte-ignore state_referenced_locally -- viz's identity never changes
    nodes: viz.model.nodes,
  };
  installPerf(okf);
  (window as unknown as { __okf: unknown }).__okf = okf;

  const onSceneReady = (s: SceneApi) => {
    sceneRef = s;
    mark("viz:scene-init");
  };
  const onFirstFrame = () => {
    mark("viz:first-frame");
    mark("viz:interactive");
    console.log(
      "okf viz startup: " +
        summary()
          .map((e) => `${e.name.slice(4)} ${e.ms}ms`)
          .join(" · "),
    );
  };

  applyHash();
</script>

<svelte:window onhashchange={applyHash} onpopstate={applyHash} />

<Sidebar {viz} />
<Stage {viz} {createScene} {onSceneReady} {onFirstFrame} />

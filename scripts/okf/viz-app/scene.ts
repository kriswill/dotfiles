// Three.js scene in the codebase-memory-mcp graph-ui style: one InstancedMesh
// of spheres whose per-instance colors are boosted past 1.0 so the bloom pass
// renders the excess as a glow corona; additive edge lines; canvas-texture
// sprite labels; OrbitControls with eased fly-to.
// Layout is precomputed at generation time — nothing simulates at runtime.

import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { LineMaterial } from "three/addons/lines/LineMaterial.js";
import { LineSegments2 } from "three/addons/lines/LineSegments2.js";
import { LineSegmentsGeometry } from "three/addons/lines/LineSegmentsGeometry.js";
import { BloomEffect, EffectComposer, EffectPass, RenderPass } from "postprocessing";

export interface SceneNode {
  x: number; y: number; z: number;
  r: number;          // world radius
  color: string;      // css hex
  title: string;
}

export interface Theme {
  bg: string;
  labelInk: string;
  labelStroke: string;
}

export interface Callbacks {
  onHover(index: number | null, clientX: number, clientY: number): void;
  onSelect(index: number | null): void;
  /** Fired once, right after the first composited frame (startup perf mark). */
  onFirstFrame?(): void;
}

/** The slice of GraphScene the reactive bridges drive (stubbable in tests). */
export interface SceneApi {
  setDim(fn: (i: number) => boolean): void;
  setSelected(i: number | null, fly?: boolean): void;
  applyTheme(theme: Theme): void;
  setViewShift(leftInset: number, rightInset: number): void;
  resize(): void;
}

export type CreateScene = (
  el: HTMLElement,
  nodes: SceneNode[],
  edges: [number, number][],
  theme: Theme,
  cb: Callbacks,
) => SceneApi;

const MAX_LABELS = 28;

export class GraphScene {
  private renderer: THREE.WebGLRenderer;
  private composer: EffectComposer;
  private scene = new THREE.Scene();
  private camera: THREE.PerspectiveCamera;
  private controls: OrbitControls;
  private mesh: THREE.InstancedMesh;
  private lines: LineSegments2;
  private lineMat: LineMaterial;
  private labels: THREE.Sprite[] = [];
  private nodes: SceneNode[];
  private edges: [number, number][];
  private dimmed: (i: number) => boolean = () => false;
  private selected: number | null = null;
  private theme: Theme;
  private anim: {
    fromPos: THREE.Vector3; fromTarget: THREE.Vector3;
    toPos: THREE.Vector3; toTarget: THREE.Vector3; t: number;
  } | null = null;
  private labelRank: number[];
  private viewShift = 0;
  private adj: Set<number>[] = [];
  private bloom!: BloomEffect;
  // Dark backgrounds get the glow look (additive lines, >1.0 bloom colors);
  // light ones get ink-on-paper (normal blending, colors fade toward the page).
  private darkBg = true;

  constructor(
    private container: HTMLElement,
    nodes: SceneNode[],
    edges: [number, number][],
    theme: Theme,
    private cb: Callbacks,
  ) {
    this.nodes = nodes;
    this.edges = edges;
    this.theme = theme;

    this.renderer = new THREE.WebGLRenderer({ antialias: false, powerPreference: "high-performance" });
    this.renderer.setPixelRatio(Math.min(Math.max(devicePixelRatio || 1, 1), 1.5));
    Object.assign(this.renderer.domElement.style, { position: "absolute", inset: "0", zIndex: "0" });
    container.appendChild(this.renderer.domElement);

    this.camera = new THREE.PerspectiveCamera(55, 1, 1, 6000);
    this.camera.position.set(0, 60, 620);

    // HalfFloat framebuffer: without it the >1.0 instance colors are clamped
    // before the bloom pass, killing the glow entirely.
    this.composer = new EffectComposer(this.renderer, {
      multisampling: 0,
      frameBufferType: THREE.HalfFloatType,
    });
    this.composer.addPass(new RenderPass(this.scene, this.camera));
    // Params mirror graph-ui's <Bloom> exactly (intensity retuned per theme).
    this.bloom = new BloomEffect({
      intensity: 1.2,
      luminanceThreshold: 0.3,
      luminanceSmoothing: 0.7,
      mipmapBlur: true,
      radius: 0.6,
    });
    this.composer.addPass(new EffectPass(this.camera, this.bloom));

    this.controls = new OrbitControls(this.camera, this.renderer.domElement);
    this.controls.enableDamping = true;
    this.controls.dampingFactor = 0.08;

    // Node spheres
    const geo = new THREE.SphereGeometry(1, 20, 20);
    const mat = new THREE.MeshBasicMaterial({ toneMapped: false });
    this.mesh = new THREE.InstancedMesh(geo, mat, nodes.length);
    const m = new THREE.Matrix4();
    nodes.forEach((n, i) => {
      m.makeScale(n.r, n.r, n.r).setPosition(n.x, n.y, n.z);
      this.mesh.setMatrixAt(i, m);
    });
    this.scene.add(this.mesh);

    // Edge lines (positions fixed; colors rewritten on state changes).
    // Fat lines (LineSegments2): WebGL ignores linewidth on basic line
    // materials, so screen-space width needs the addon material.
    const pos = new Float32Array(edges.length * 6);
    edges.forEach(([a, b], i) => {
      pos.set([nodes[a].x, nodes[a].y, nodes[a].z, nodes[b].x, nodes[b].y, nodes[b].z], i * 6);
    });
    const lineGeo = new LineSegmentsGeometry();
    lineGeo.setPositions(pos);
    lineGeo.setColors(new Float32Array(edges.length * 6));
    this.lineMat = new LineMaterial({
      vertexColors: true,
      transparent: true,
      opacity: 0.7,
      blending: THREE.AdditiveBlending,
      depthWrite: false,
      linewidth: 1.6, // px
    });
    this.lineMat.toneMapped = false;
    this.lines = new LineSegments2(lineGeo, this.lineMat);
    this.scene.add(this.lines);

    // Labels: rank by degree, show the busiest plus hover/selection
    const deg = new Array(nodes.length).fill(0);
    this.adj = nodes.map(() => new Set<number>());
    edges.forEach(([a, b]) => {
      deg[a]++; deg[b]++;
      this.adj[a].add(b); this.adj[b].add(a);
    });
    this.labelRank = nodes.map((_, i) => i).sort((a, b) => deg[b] - deg[a]);
    this.buildLabels();

    this.applyTheme(theme);
    this.repaint();

    // Interaction
    const el = this.renderer.domElement;
    const ray = new THREE.Raycaster();
    const ndc = new THREE.Vector2();
    let downX = 0, downY = 0, isDown = false, hovered: number | null = null;
    const pick = (e: PointerEvent): number | null => {
      const rect = el.getBoundingClientRect();
      ndc.set(((e.clientX - rect.left) / rect.width) * 2 - 1, -((e.clientY - rect.top) / rect.height) * 2 + 1);
      ray.setFromCamera(ndc, this.camera);
      const hit = ray.intersectObject(this.mesh, false)[0];
      return hit && hit.instanceId !== undefined && !this.dimmed(hit.instanceId) ? hit.instanceId : null;
    };
    el.addEventListener("pointermove", (e) => {
      if (e.buttons) return;
      const i = pick(e);
      if (i !== hovered) {
        hovered = i;
        this.setHoverLabel(i);
        el.style.cursor = i === null ? "grab" : "pointer";
      }
      this.cb.onHover(i, e.clientX, e.clientY);
    });
    // Grabbing the view cancels an in-flight fly-to instead of fighting it.
    el.addEventListener("pointerdown", (e) => { this.anim = null; isDown = true; downX = e.clientX; downY = e.clientY; });
    el.addEventListener("pointerup", (e) => {
      if (!isDown) return; // ignore synthetic pointerup with no matching down
      isDown = false;
      if (Math.hypot(e.clientX - downX, e.clientY - downY) > 4) return;
      this.cb.onSelect(pick(e));
    });

    new ResizeObserver(() => this.resize()).observe(container);
    this.resize();
    this.fitToView();

    let firstFrame = true;
    const loop = () => {
      requestAnimationFrame(loop);
      this.stepFly();
      this.controls.update();
      this.composer.render();
      if (firstFrame) {
        firstFrame = false;
        this.cb.onFirstFrame?.();
      }
    };
    requestAnimationFrame(loop);
  }

  private hoverLabel: number | null = null;
  private setHoverLabel(i: number | null) {
    this.hoverLabel = i;
    this.updateLabelVisibility();
  }

  /* --- colors ---------------------------------------------------------- */

  private isNeighbor(i: number): boolean {
    return this.selected !== null && this.adj[this.selected].has(i);
  }

  repaint() {
    const c = new THREE.Color();
    const bg = new THREE.Color(this.theme.bg);
    this.nodes.forEach((n, i) => {
      c.set(n.color);
      if (this.darkBg) {
        if (this.dimmed(i)) {
          c.multiplyScalar(0.12);
        } else {
          const brightness = (c.r + c.g + c.b) / 3;
          let boost = (1.2 + brightness * 0.8) * 1.875; // bloom feeds on the >1.0 excess
          if (this.selected !== null) {
            if (i === this.selected) boost *= 1.5;      // hero glow
            else if (this.isNeighbor(i)) boost *= 1.15; // linked nodes brighten
            else boost *= 0.4;                          // the rest recede
          }
          c.multiplyScalar(boost);
        }
      } else {
        // Ink-on-paper: de-emphasis fades toward the page, never toward black.
        // Non-neighbors keep ~40% presence — the dark path's 0.4× equivalent.
        if (this.dimmed(i)) c.lerp(bg, 0.88);
        else if (this.selected !== null) {
          if (this.isNeighbor(i)) c.lerp(bg, 0.08);
          else if (i !== this.selected) c.lerp(bg, 0.6);
        }
      }
      this.mesh.setColorAt(i, c);
    });
    this.mesh.instanceColor!.needsUpdate = true;

    const edgeColors = new Float32Array(this.edges.length * 6);
    const ca = new THREE.Color(), cbCol = new THREE.Color();
    this.edges.forEach(([a, b], i) => {
      const active =
        this.selected !== null ? (a === this.selected || b === this.selected) : true;
      const dim = this.dimmed(a) || this.dimmed(b) || !active;
      if (this.darkBg) {
        // Rest state: a uniform quiet web; edges only assert themselves for a selection.
        const k = dim ? (this.selected !== null && !active ? 0.04 : 0.08) : this.selected !== null ? 0.75 : 0.28;
        ca.set(this.nodes[a].color).multiplyScalar(k);
        cbCol.set(this.nodes[b].color).multiplyScalar(k);
      } else {
        // Normal blending: visibility comes from staying darker than the page.
        // The rest of the web stays a visible whisper during a selection.
        const t = dim ? (this.selected !== null && !active ? 0.8 : 0.84) : this.selected !== null ? 0.08 : 0.42;
        ca.set(this.nodes[a].color).lerp(bg, t);
        cbCol.set(this.nodes[b].color).lerp(bg, t);
      }
      edgeColors.set([ca.r, ca.g, ca.b, cbCol.r, cbCol.g, cbCol.b], i * 6);
    });
    (this.lines.geometry as LineSegmentsGeometry).setColors(edgeColors);
    this.updateLabelVisibility();
  }

  /** Selected node scales up and its label grows; everything else at rest. */
  private applyEmphasis() {
    const m = new THREE.Matrix4();
    this.nodes.forEach((n, i) => {
      const isSel = i === this.selected;
      const s = n.r * (isSel ? 1.3 : 1);
      m.makeScale(s, s, s).setPosition(n.x, n.y, n.z);
      this.mesh.setMatrixAt(i, m);
      const sp = this.labels[i];
      if (!sp) return;
      const base = sp.userData.base;
      const k = isSel ? 1.45 : 1;
      sp.scale.set(base.w * k, base.h * k, 1);
      sp.position.set(n.x, n.y - s - (isSel ? 8 : 7), n.z);
    });
    this.mesh.instanceMatrix.needsUpdate = true;
  }

  /* --- labels ----------------------------------------------------------- */

  private makeLabelTexture(text: string) {
    const font = `600 44px system-ui, -apple-system, "Segoe UI", sans-serif`;
    const cv = document.createElement("canvas");
    const ctx = cv.getContext("2d")!;
    ctx.font = font;
    const w = Math.ceil(ctx.measureText(text).width) + 24;
    cv.width = w; cv.height = 64;
    ctx.font = font;
    ctx.textBaseline = "middle";
    ctx.lineWidth = 7;
    ctx.strokeStyle = this.theme.labelStroke;
    ctx.strokeText(text, 12, 34);
    ctx.fillStyle = this.theme.labelInk;
    ctx.fillText(text, 12, 34);
    const tex = new THREE.CanvasTexture(cv);
    tex.colorSpace = THREE.SRGBColorSpace;
    return { tex, aspect: w / 64 };
  }

  private buildLabels() {
    for (const s of this.labels) { s.material.map?.dispose(); s.material.dispose(); this.scene.remove(s); }
    this.labels = this.nodes.map((n) => {
      const { tex, aspect } = this.makeLabelTexture(n.title);
      const sp = new THREE.Sprite(
        new THREE.SpriteMaterial({
          map: tex,
          transparent: true,
          depthWrite: false,
          depthTest: false, // text always reads — lines/spheres never overdraw it
          toneMapped: false,
        }),
      );
      sp.renderOrder = 2;
      const h = 7.5;
      sp.userData.base = { w: h * aspect, h };
      sp.scale.set(h * aspect, h, 1);
      sp.position.set(n.x, n.y - n.r - 7, n.z);
      this.scene.add(sp);
      return sp;
    });
    this.applyEmphasis();
    this.updateLabelVisibility();
  }

  private updateLabelVisibility() {
    const top = new Set(this.labelRank.slice(0, MAX_LABELS));
    this.labels.forEach((sp, i) => {
      sp.visible =
        !this.dimmed(i) &&
        (top.has(i) || i === this.selected || i === this.hoverLabel || this.isNeighbor(i));
    });
  }

  /** Initial placement: aim at the layout centroid and back off until the
   *  whole bounding sphere fits both the vertical and horizontal FOV. The
   *  layout is not origin-centered, so a fixed camera leaves the graph small
   *  and off-center. */
  private fitToView() {
    const center = new THREE.Vector3();
    for (const n of this.nodes) center.add(new THREE.Vector3(n.x, n.y, n.z));
    center.multiplyScalar(1 / Math.max(1, this.nodes.length));
    let radius = 60;
    for (const n of this.nodes) {
      radius = Math.max(radius, new THREE.Vector3(n.x, n.y, n.z).distanceTo(center) + n.r);
    }
    const vFov = (this.camera.fov * Math.PI) / 180;
    const hFov = 2 * Math.atan(Math.tan(vFov / 2) * this.camera.aspect);
    // /1.2 pulls the camera 20% closer than a full-fit frame; distant outliers
    // may clip out of view at rest, which is fine — orbit/pan still reaches them.
    const dist = (radius * 1.06) / Math.tan(Math.min(vFov, hFov) / 2) / 1.2;
    const dir = new THREE.Vector3(0, 0.12, 1).normalize(); // slight elevation, like the old default
    this.camera.position.copy(center).addScaledVector(dir, dist);
    this.controls.target.copy(center);
    this.controls.update();
  }

  /* --- public API -------------------------------------------------------- */

  setDim(fn: (i: number) => boolean) {
    this.dimmed = fn;
    this.repaint();
  }

  setSelected(i: number | null, fly = false) {
    this.selected = i;
    this.applyEmphasis();
    this.repaint();
    if (i !== null && fly) {
      const n = this.nodes[i];
      const target = new THREE.Vector3(n.x, n.y, n.z);
      // Approach from the side opposite the neighbor centroid so the node's
      // links fan out in view beyond it; fall back to the current view
      // direction for loners. The slight upward bias keeps the label (below
      // the node) clear of it.
      const dir = new THREE.Vector3();
      const nb = [...this.adj[i]];
      if (nb.length) {
        const centroid = new THREE.Vector3();
        for (const j of nb) centroid.add(new THREE.Vector3(this.nodes[j].x, this.nodes[j].y, this.nodes[j].z));
        dir.copy(target).sub(centroid.multiplyScalar(1 / nb.length));
      }
      if (dir.lengthSq() < 1) dir.copy(this.camera.position).sub(this.controls.target);
      if (dir.lengthSq() < 1) dir.set(0, 0.2, 1);
      dir.normalize().setY(dir.y + 0.25).normalize();

      // Hold the current zoom level rather than flying to a fixed framing
      // distance; only back off as far as needed to keep every direct
      // neighbor inside the view cone along the chosen approach direction.
      // A neighbor's raw 3D distance isn't the right yardstick — an edge
      // that runs mostly along the view axis (deep into the scene) needs no
      // pull-back at all, unlike a same-length edge that runs sideways. So
      // decompose each neighbor offset into axial (along dir) and
      // perpendicular components and solve for the distance that keeps its
      // perpendicular offset inside the FOV cone at that depth.
      const vFov = (this.camera.fov * Math.PI) / 180;
      const hFov = 2 * Math.atan(Math.tan(vFov / 2) * this.camera.aspect);
      const tanHalfFov = Math.tan(Math.min(vFov, hFov) / 2);
      let need = n.r / tanHalfFov;
      const offset = new THREE.Vector3();
      for (const j of nb) {
        const nbNode = this.nodes[j];
        offset.set(nbNode.x - n.x, nbNode.y - n.y, nbNode.z - n.z);
        const axial = offset.dot(dir);
        const perpLen = offset.addScaledVector(dir, -axial).length() + nbNode.r;
        need = Math.max(need, axial + perpLen / tanHalfFov);
      }
      const curDist = this.camera.position.distanceTo(this.controls.target);
      const dist = Math.max(curDist, need);

      this.anim = {
        fromPos: this.camera.position.clone(),
        fromTarget: this.controls.target.clone(),
        toPos: target.clone().add(dir.multiplyScalar(dist)),
        toTarget: target,
        t: 0,
      };
    }
  }

  private stepFly() {
    if (!this.anim) return;
    this.anim.t = Math.min(1, this.anim.t + 0.02);
    const e = 1 - Math.pow(1 - this.anim.t, 3);
    // Absolute interpolation lands exactly on the node, so any manual pan
    // offset is flown out rather than carried over (which clipped labels).
    this.camera.position.lerpVectors(this.anim.fromPos, this.anim.toPos, e);
    this.controls.target.lerpVectors(this.anim.fromTarget, this.anim.toTarget, e);
    if (this.anim.t >= 1) this.anim = null;
  }

  applyTheme(theme: Theme) {
    this.theme = theme;
    const bg = new THREE.Color(theme.bg);
    // Linear-space relative luminance; mid gray (~0.26) still counts as light.
    this.darkBg = 0.2126 * bg.r + 0.7152 * bg.g + 0.0722 * bg.b < 0.15;
    this.bloom.intensity = this.darkBg ? 1.95 : 0;
    this.lineMat.blending = this.darkBg ? THREE.AdditiveBlending : THREE.NormalBlending;
    this.lineMat.opacity = this.darkBg ? 0.7 : 1;
    this.lineMat.needsUpdate = true;
    this.scene.background = bg;
    this.buildLabels();
    this.repaint();
  }

  /** Both side panels overlay the full-bleed canvas rather than sharing
   *  layout space with it, so the scene itself always spans the whole
   *  viewport — only the projection center shifts, by half the imbalance
   *  between the two insets, to keep content centered in the strip that's
   *  actually clear of both panels. */
  setViewShift(leftInset: number, rightInset: number) {
    this.viewShift = rightInset - leftInset;
    this.resize();
  }

  resize() {
    const w = this.container.clientWidth, h = this.container.clientHeight;
    if (!w || !h) return;
    this.camera.aspect = w / h;
    if (this.viewShift !== 0) this.camera.setViewOffset(w, h, this.viewShift / 2, 0, w, h);
    else this.camera.clearViewOffset();
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(w, h);
    this.composer.setSize(w, h);
    this.lineMat.resolution.set(w, h);
  }
}

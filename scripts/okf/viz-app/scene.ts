// Three.js scene in the codebase-memory-mcp graph-ui style: one InstancedMesh
// of spheres whose per-instance colors are boosted past 1.0 so the bloom pass
// renders the excess as a glow corona; additive edge lines; canvas-texture
// sprite labels; OrbitControls with eased fly-to and idle auto-rotation.
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
}

const IDLE_MS = 45_000;
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
  private lastInteraction = Date.now();
  private anim: { toPos: THREE.Vector3; toTarget: THREE.Vector3; t: number } | null = null;
  private labelRank: number[];
  private viewShift = 0;
  private adj: Set<number>[] = [];

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
    // Params mirror graph-ui's <Bloom> exactly.
    this.composer.addPass(
      new EffectPass(
        this.camera,
        new BloomEffect({
          intensity: 1.2,
          luminanceThreshold: 0.3,
          luminanceSmoothing: 0.7,
          mipmapBlur: true,
          radius: 0.6,
        }),
      ),
    );

    this.controls = new OrbitControls(this.camera, this.renderer.domElement);
    this.controls.enableDamping = true;
    this.controls.dampingFactor = 0.08;
    this.controls.autoRotateSpeed = 0.35;

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
      this.poke();
      if (e.buttons) return;
      const i = pick(e);
      if (i !== hovered) {
        hovered = i;
        this.setHoverLabel(i);
        el.style.cursor = i === null ? "grab" : "pointer";
      }
      this.cb.onHover(i, e.clientX, e.clientY);
    });
    el.addEventListener("pointerdown", (e) => { this.poke(); isDown = true; downX = e.clientX; downY = e.clientY; });
    el.addEventListener("pointerup", (e) => {
      if (!isDown) return; // ignore synthetic pointerup with no matching down
      isDown = false;
      if (Math.hypot(e.clientX - downX, e.clientY - downY) > 4) return;
      this.cb.onSelect(pick(e));
    });
    el.addEventListener("wheel", () => this.poke(), { passive: true });

    new ResizeObserver(() => this.resize()).observe(container);
    this.resize();

    const loop = () => {
      requestAnimationFrame(loop);
      this.stepFly();
      this.controls.autoRotate = Date.now() - this.lastInteraction > IDLE_MS;
      this.controls.update();
      this.composer.render();
    };
    requestAnimationFrame(loop);
  }

  private poke() { this.lastInteraction = Date.now(); }

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
    this.nodes.forEach((n, i) => {
      c.set(n.color);
      if (this.dimmed(i)) {
        c.multiplyScalar(0.12);
      } else {
        const brightness = (c.r + c.g + c.b) / 3;
        let boost = 1.2 + brightness * 0.8; // bloom feeds on the >1.0 excess
        if (this.selected !== null) {
          if (i === this.selected) boost *= 1.5;      // hero glow
          else if (this.isNeighbor(i)) boost *= 1.15; // linked nodes brighten
          else boost *= 0.4;                          // the rest recede
        }
        c.multiplyScalar(boost);
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
      // Rest state: a uniform quiet web; edges only assert themselves for a selection.
      const k = dim ? (this.selected !== null && !active ? 0.04 : 0.08) : this.selected !== null ? 0.75 : 0.28;
      ca.set(this.nodes[a].color).multiplyScalar(k);
      cbCol.set(this.nodes[b].color).multiplyScalar(k);
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
        new THREE.SpriteMaterial({ map: tex, transparent: true, depthWrite: false, toneMapped: false }),
      );
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
      const dir = this.camera.position.clone().sub(this.controls.target).normalize();
      const toPos = target.clone().add(dir.multiplyScalar(n.r * 12 + 340));
      this.anim = { toPos, toTarget: target, t: 0 };
    }
  }

  private stepFly() {
    if (!this.anim) return;
    this.anim.t = Math.min(1, this.anim.t + 0.025);
    const e = 1 - Math.pow(1 - this.anim.t, 3);
    this.camera.position.lerp(this.anim.toPos, e * 0.12);
    this.controls.target.lerp(this.anim.toTarget, e * 0.12);
    if (this.anim.t >= 1) this.anim = null;
  }

  applyTheme(theme: Theme) {
    this.theme = theme;
    this.scene.background = new THREE.Color(theme.bg);
    this.buildLabels();
    this.repaint();
  }

  /** Shift the projection center left by px/2 so content centers in the area
   *  not covered by the detail panel (0 to clear). */
  setViewShift(px: number) {
    this.viewShift = px;
    this.resize();
  }

  resize() {
    const w = this.container.clientWidth, h = this.container.clientHeight;
    if (!w || !h) return;
    this.camera.aspect = w / h;
    if (this.viewShift > 0) this.camera.setViewOffset(w, h, this.viewShift / 2, 0, w, h);
    else this.camera.clearViewOffset();
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(w, h);
    this.composer.setSize(w, h);
    this.lineMat.resolution.set(w, h);
  }
}

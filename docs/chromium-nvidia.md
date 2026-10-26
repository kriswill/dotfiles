# Chromium / Electron hardware video decode on NVIDIA (nebula)

**Verified against:** nebula: RTX 5080, NVIDIA 595.104.02 (open modules),
Hyprland 0.56.2, nvidia-vaapi-driver 0.0.18, libva 2.24.1. Clients: Discord
1.0.161 (Electron 42.11.10 / Chromium 148.0.7778.280), Vesktop 1.6.8
(Electron 44.9.3), Helium 0.20.1.1. Checked 2026-10-25.

## State

- **Discord and Vesktop launch with `--disable-accelerated-video-decode`**
  (`modules/hosts/nebula/configuration.nix`). Discord gets it through
  nixpkgs' `commandLineArgs` override. Vesktop has no such argument, so it
  gets a `symlinkJoin` + `wrapProgram` wrapper (its `.desktop` `Exec` runs
  `vesktop` by name, so the wrapper is what launches). The flag turns off
  Chromium's hardware video decode only. Compositing, WebGL and the rest of
  the GPU work stay on the GPU. Software decode of a 1080p60 stream is a few
  percent of one core.
- **Why:** with hardware decode, every Discord stream's video jumps backward
  and hitches while the audio stays fine. A/B test on 2026-10-25: relaunching
  Discord with the flag fixed it immediately.
- **Every other Chromium/Electron app on Wayland can still end up decoding
  through nvidia-vaapi-driver** (see the chain below). Helium had libva
  loaded but not `nvidia_drv_video.so` when checked, and it was not tested
  with video playing.

## How VA-API ends up on the NVIDIA card

Chromium turns VA-API off on NVIDIA by default. In 148.0.7778.280,
`media/base/media_switches.cc` declares `kVaapiOnNvidiaGPUs` as
`FEATURE_DISABLED_BY_DEFAULT`: *"NVIDIA VA-API drivers do not support
Chromium and can sometimes cause crashes"* ([crbug 1492880][crbug]). No GPU
blocklist entry covers modern NVIDIA drivers; `software_rendering_list.json`
entry 56 only blocks video decode below driver 331.38. So that one feature
is the only gate, and on nebula it never takes effect:

1. **snowglobe installs the driver.** `gpu-vendors = [ "nvidia" ]` puts
   `nvidia-vaapi-driver` in `hardware.graphics.extraPackages`, i.e. in
   `/run/opengl-driver/lib/dri/nvidia_drv_video.so`.
2. **libva finds it without any env var.** libva 2.24.1's
   `va/drm/va_drm_utils.c` maps DRM driver `nvidia-drm` to VA driver
   `nvidia` ("Unofficial NVIDIA"). `LIBVA_DRIVER_NAME` is not set anywhere on
   nebula and is not needed.
3. **On Wayland, Chromium picks a render node itself.**
   `ui/ozone/platform/wayland/host/wayland_zwp_linux_dmabuf.cc` reads the
   compositor's linux-dmabuf "main device". If GBM opens it,
   `WaylandConnection::SetRenderNodePath` appends
   `--render-node-override=/dev/dri/renderD128` to the browser command line.
   `content/browser/gpu/gpu_process_host.cc` copies that switch to the GPU
   process.
4. **That switch skips the NVIDIA gate.** In
   `media/gpu/vaapi/vaapi_wrapper.cc`, `LoadDrmFD` flags an `nvidia-drm` node
   as "should skip" unless `kVaapiOnNvidiaGPUs` is on. But
   `VADisplayStateSingleton::PreSandboxInitialization` uses the
   `--render-node-override` node regardless and only logs
   `Forcibly using value of --render-node-override`. Under X11/XWayland there
   is no override, so the gate does apply.

`NIXOS_OZONE_WL=1` (also from snowglobe) is what puts Electron apps on the
Wayland path. Discord adds a second route: a Discord engineer said on
[#455][i455] that Discord "opt[s] into VA-API where Chromium by default does
not". Its GPU process command line carried no `VaapiOnNvidiaGPUs`, so that
opt-in is somewhere other than the flags.

## The bug

From driver traces in [#455][i455] and [PR #476][pr476]. These were not
re-traced on nebula.

- The driver's `vaEndPicture` only queues the decode. A resolve thread
  copies the decoded frame into the surface's exported backing image
  slightly later.
- Chromium exports a few surfaces once, rotates through them, and never calls
  `vaSyncSurface` again. One trace counted 12 exports and 12 syncs for 2,079
  decoded pictures. Another counted 8 syncs for 2,280 frames.
- When Chromium's read beats the copy, it shows that buffer's previous
  contents, a frame exactly one rotation old. That is the picture jumping
  backward. Decode itself runs at a steady 60 fps, and audio is a separate
  path.
- **0.0.18 exposed it.** The single-buffer export change in 0.0.18 (#443)
  made Chromium's hardware path work at all. On 0.0.17, Discord silently
  fell back to software (its debug overlay shows **Decoder: dav1d**). On
  0.0.18 it uses **Decoder: electron**, and that is when the stutter starts.
- **Whose bug:** elFarto (the maintainer) says `vaEndPicture` "only starts
  the decoding process", so a client that displays without `vaSyncSurface`
  is buggy. Discord calls it "an upstream issue in Chromium in combination
  with libva-nvidia-driver". Reporters reproduced it in plain Chromium on
  vdo.ninja and Fluxer (WebRTC apps), and in a WebCodecs `VideoDecoder`.
  mpv (`--hwdec=vaapi`) syncs every frame and is not affected.

## Upstream status (2026-10-25)

| Where | Status |
| --- | --- |
| Discord | Fixed in its own Electron build: Canary host 1.0.2149 (2026-10-08), confirmed by testers on 1.0.2149 and 1.0.2160. Stable 1.0.161 (nixpkgs) still has it. |
| nvidia-vaapi-driver | [PR #476][pr476] (wait in `vaEndPicture` for exported surfaces) is **open**. [#482][i482] reports a smaller remaining race. No release after 0.0.18. |
| Chromium | No Chromium bug found for this. Reporters say it reproduces in Chromium 152, 153 and 154. |
| Vesktop | Runs stock Electron, so Discord's fix does not reach it. [#399][i399] (open) reports the same symptom. Not tested on nebula. |

## When to drop the flags

- **Discord:** once stable Discord includes the Canary fix, **or** once a
  nvidia-vaapi-driver release with #476 reaches nixpkgs.
- **Vesktop:** only once the driver fix (or a Chromium fix) ships, because
  Discord's Electron patch does not apply to it.

To test, quit the wrapped client first, because Discord is single-instance
and a second launch only focuses the running one. Then run the stock nixpkgs
package from this flake, without the flag:

```sh
nix run .#nixosConfigurations.nebula.pkgs.discord   # or …pkgs.vesktop
nix eval --raw .#nixosConfigurations.nebula.pkgs.nvidia-vaapi-driver.version
```

Watch a stream with motion and confirm hardware decode is actually in use
(below). Smooth playback with `dec` above 0 means the flag can go.

## Diagnosing

```sh
# Is anything decoding on NVDEC? `dec` column, `C+G` row for the GPU process
nvidia-smi pmon -c 1

# Did the GPU process load the VA-API driver? (find it by --type=gpu-process)
grep -oE '/nix/store/[^ ]*(libva|nvidia_drv_video)[^ ]*' /proc/<gpu-pid>/maps | sort -u

# Which flags/features did it get?
tr '\0' ' ' < /proc/<gpu-pid>/cmdline | tr ' ' '\n' | \
  grep -E '^--(enable|disable)-features|render-node-override|accelerated'
```

In Discord, the stream debug overlay's **Decoder** field shows `electron`
(Chromium hardware path) or `dav1d`/`openh264` (software).

## Workaround options

- **Per app, `--disable-accelerated-video-decode`** (chosen). Scoped and
  declarative, and it leaves VA-API alone for everything else.
- **Per app, `LIBVA_DRIVER_NAME=none`.** What the #455 reporters used. It
  makes libva fail to load a driver, so it has the same effect, but as an
  env var it is harder to scope with a FHS/bwrap wrapper.
- **Drop nvidia-vaapi-driver system-wide.** It belongs to snowglobe's NVIDIA
  profile, and removing it would also take hardware decode from mpv and
  Firefox, which are not affected by this race. Not worth it.

## Learned behaviours & workarounds

- **Electron overwrites its own `/proc/<pid>/cmdline` and `environ`
  (2026-10-25).** It rewrites the process title, so `environ` reads as
  NUL-padded garbage. Read env vars from Discord's bwrap parent
  (`bubblewrap … discord-…-fhsenv-rootfs`), and split `cmdline` on spaces,
  not NULs.
- **`pgrep -f`/`for d in /proc/*` loops match the probing shell itself**
  when the pattern is in the command line. Match on `readlink /proc/<pid>/exe`
  or use a script file instead.
- **Discord's Chromium warnings are not in the user journal** when it is
  launched from the app launcher, so the `Forcibly using value of
  --render-node-override` line could not be confirmed from logs. The source
  path above is the evidence, plus the driver mapped in the GPU process.
- **An `XID` hit in `journalctl -k` was the Realtek NIC** (`r8169 … XID 64a`),
  not an NVIDIA Xid. Grep for `NVRM: Xid`.

## Sources

- [nvidia-vaapi-driver #455: Electron decoder stuttering after 0.0.17 → 0.0.18][i455]
- [nvidia-vaapi-driver PR #476: finish resolving exported surfaces before vaEndPicture returns][pr476]
- [nvidia-vaapi-driver #482: resolving flag cleared before the CUDA copy finishes][i482]
- [nvidia-vaapi-driver #399: Vesktop video playback bug][i399]
- [nvidia-vaapi-driver README (Chrome section)](https://github.com/elFarto/nvidia-vaapi-driver#chrome)
- Chromium 148.0.7778.280:
  [vaapi_wrapper.cc](https://github.com/chromium/chromium/blob/148.0.7778.280/media/gpu/vaapi/vaapi_wrapper.cc),
  [media_switches.cc](https://github.com/chromium/chromium/blob/148.0.7778.280/media/base/media_switches.cc),
  [wayland_zwp_linux_dmabuf.cc](https://github.com/chromium/chromium/blob/148.0.7778.280/ui/ozone/platform/wayland/host/wayland_zwp_linux_dmabuf.cc),
  [wayland_connection.cc](https://github.com/chromium/chromium/blob/148.0.7778.280/ui/ozone/platform/wayland/host/wayland_connection.cc),
  [gpu_process_host.cc](https://github.com/chromium/chromium/blob/148.0.7778.280/content/browser/gpu/gpu_process_host.cc),
  [software_rendering_list.json](https://github.com/chromium/chromium/blob/148.0.7778.280/gpu/config/software_rendering_list.json)
- [libva 2.24.1 va_drm_utils.c](https://github.com/intel/libva/blob/2.24.1/va/drm/va_drm_utils.c)

[crbug]: https://crbug.com/1492880
[i455]: https://github.com/elFarto/nvidia-vaapi-driver/issues/455
[pr476]: https://github.com/elFarto/nvidia-vaapi-driver/pull/476
[i482]: https://github.com/elFarto/nvidia-vaapi-driver/issues/482
[i399]: https://github.com/elFarto/nvidia-vaapi-driver/issues/399

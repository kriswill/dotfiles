// Renders an SF Symbol (external drive + network) onto a rounded-rect tile
// at every size an .iconset needs. Run: swift make-icon.swift <outdir>
import AppKit

let args = CommandLine.arguments
guard args.count == 2 else { fputs("usage: make-icon.swift <outdir>\n", stderr); exit(1) }
let outDir = URL(fileURLWithPath: args[1], isDirectory: true)
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let sizes: [(name: String, px: Int)] = [
  ("icon_16x16", 16), ("icon_16x16@2x", 32),
  ("icon_32x32", 32), ("icon_32x32@2x", 64),
  ("icon_128x128", 128), ("icon_128x128@2x", 256),
  ("icon_256x256", 256), ("icon_256x256@2x", 512),
  ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

func render(px: Int) -> NSImage {
  let s = CGFloat(px)
  let img = NSImage(size: NSSize(width: s, height: s))
  img.lockFocus()
  defer { img.unlockFocus() }

  // Rounded-rect tile, macOS-style inset (~10% margin), kanagawa-ish deep blue
  let inset = s * 0.05
  let tile = NSBezierPath(
    roundedRect: NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset),
    xRadius: s * 0.22, yRadius: s * 0.22)
  let top = NSColor(calibratedRed: 0.14, green: 0.16, blue: 0.23, alpha: 1)      // #242938-ish
  let bottom = NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.16, alpha: 1)
  NSGradient(starting: top, ending: bottom)?.draw(in: tile, angle: -90)

  // SF Symbol glyph centered, light foreground
  let cfg = NSImage.SymbolConfiguration(pointSize: s * 0.52, weight: .medium)
  guard
    let sym = NSImage(systemSymbolName: "externaldrive.connected.to.line.below",
                      accessibilityDescription: nil)?
      .withSymbolConfiguration(cfg)
  else { fputs("symbol not found\n", stderr); exit(2) }

  let tinted = NSImage(size: sym.size)
  tinted.lockFocus()
  NSColor(calibratedRed: 0.85, green: 0.87, blue: 0.91, alpha: 1).set()
  let r = NSRect(origin: .zero, size: sym.size)
  sym.draw(in: r)
  r.fill(using: .sourceAtop)
  tinted.unlockFocus()

  let g = tinted.size
  let scale = (s * 0.62) / max(g.width, g.height)
  let w = g.width * scale, h = g.height * scale
  tinted.draw(
    in: NSRect(x: (s - w) / 2, y: (s - h) / 2, width: w, height: h),
    from: .zero, operation: .sourceOver, fraction: 1.0)
  return img
}

for (name, px) in sizes {
  let img = render(px: px)
  guard let tiff = img.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff) else { exit(3) }
  rep.size = NSSize(width: px, height: px)
  guard let png = rep.representation(using: .png, properties: [:]) else { exit(4) }
  try png.write(to: outDir.appendingPathComponent("\(name).png"))
}
print("wrote \(sizes.count) pngs to \(outDir.path)")

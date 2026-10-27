import AppKit
import AVFoundation

@MainActor
final class AssetManager {
    static let shared = AssetManager()

    private(set) var bmp317: CGImage?
    private(set) var bmp342: CGImage?
    private(set) var bmp318: CGImage?
    private(set) var bmp132: CGImage?
    private(set) var bmp124: CGImage?
    private(set) var bmp146: CGImage?
    private(set) var bmp170: CGImage?
    private(set) var bmp229: CGImage?
    private(set) var em2000: CGImage?
    private(set) var gif415: CGImage?
    private(set) var gif419: CGImage?

    enum TabVisualState {
        case normal
        case hover
        case active
    }

    private var cachedTabSprites: [Int: [TabVisualState: CGImage]] = [:]
    private var sounds: [String: NSSound] = [:]
    private var bmp317AlphaMask: [UInt8] = []
    private var bmp317Width: Int = 0
    private var bmp317Height: Int = 0

    let resourceDir: URL

    private init() {
        let candidates: [URL] = [
            Bundle.main.resourceURL?.appendingPathComponent("Resources"),
            Bundle.main.resourceURL,
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources"),
            URL(fileURLWithPath: "/Users/dwjohnston/.gemini/antigravity/scratch/excite-messenger/Resources")
        ].compactMap { $0 }

        var found = URL(fileURLWithPath: "/Users/dwjohnston/.gemini/antigravity/scratch/excite-messenger/Resources")
        for candidate in candidates {
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("bmp317.png").path) {
                found = candidate
                break
            }
        }
        self.resourceDir = found
        loadAllAssets()
    }

    private func loadAllAssets() {
        bmp317 = loadCGImage(named: "bmp317.png")
        bmp342 = loadCGImage(named: "bmp342.png")
        bmp318 = loadCGImage(named: "bmp318.png")
        bmp132 = loadCGImage(named: "bmp132.png")
        bmp124 = loadCGImage(named: "bmp124.png")
        bmp146 = loadCGImage(named: "bmp146.png")
        bmp170 = loadCGImage(named: "bmp170.png")
        bmp229 = loadCGImage(named: "bmp229.png")
        gif415 = loadCGImage(named: "gif_415.png")
        gif419 = loadCGImage(named: "gif_419.png")

        if let rawEm = loadCGImage(named: "em2000.png") {
            em2000 = chromaKeyBlueAndRed(rawEm)
        }

        if let img = bmp317 {
            buildAlphaMask(for: img)
            precomputeTabSprites()
        }

        for wav in ["wav356", "wav357", "wav358", "wav361", "wav416", "wav417", "wav418", "wav419", "wav420"] {
            let url = resourceDir.appendingPathComponent("\(wav).wav")
            if let sound = NSSound(contentsOf: url, byReference: false) {
                sounds[wav] = sound
            }
        }
    }

    private func loadCGImage(named filename: String) -> CGImage? {
        let url = resourceDir.appendingPathComponent(filename)
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    /// Chroma-keys pure blue (#0000FF) and gutter red (#CC0000) in em2000.png
    private func chromaKeyBlueAndRed(_ image: CGImage) -> CGImage? {
        let w = image.width
        let h = image.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &pixels,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = pixels[i]
            let g = pixels[i + 1]
            let b = pixels[i + 2]
            if (r == 0 && g == 0 && b == 255) || (r == 204 && g == 0 && b == 0) {
                pixels[i] = 0
                pixels[i + 1] = 0
                pixels[i + 2] = 0
                pixels[i + 3] = 0
            }
        }
        return ctx.makeImage()
    }

    private func buildAlphaMask(for image: CGImage) {
        let w = image.width
        let h = image.height
        bmp317Width = w
        bmp317Height = h
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &pixels,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        bmp317AlphaMask = [UInt8](repeating: 0, count: w * h)
        for idx in 0..<(w * h) {
            bmp317AlphaMask[idx] = pixels[idx * 4 + 3]
        }
    }

    func isOpaqueInBmp317(x: Int, y: Int) -> Bool {
        guard x >= 0, y >= 0, x < bmp317Width, y < bmp317Height else { return false }
        return bmp317AlphaMask[y * bmp317Width + x] > 16
    }

    /// Slices a sub-rectangle using Win32 top-left coordinates (0,0 = top-left of sprite sheet)
    func slice(_ image: CGImage?, x: Int, y: Int, w: Int, h: Int) -> CGImage? {
        guard let image = image, w > 0, h > 0 else { return nil }
        let rect = CGRect(x: x, y: y, width: w, height: h)
        return image.cropping(to: rect)
    }

    func tabSprite(id: Int, state: TabVisualState) -> CGImage? {
        return cachedTabSprites[id]?[state]
    }

    private func precomputeTabSprites() {
        guard let bmp317 = bmp317 else { return }

        struct TabSpec {
            let id: Int
            let normSx: Int
            let normSy: Int
            let stripSy: Int
        }
        let specs: [TabSpec] = [
            TabSpec(id: 0, normSx: 221, normSy: 58,  stripSy: 31),
            TabSpec(id: 1, normSx: 283, normSy: 28,  stripSy: 51),
            TabSpec(id: 2, normSx: 221, normSy: 148, stripSy: 70),
            TabSpec(id: 3, normSx: 283, normSy: 58,  stripSy: 88),
            TabSpec(id: 4, normSx: 283, normSy: 118, stripSy: 108),
            TabSpec(id: 5, normSx: 221, normSy: 118, stripSy: 127),
            TabSpec(id: 6, normSx: 283, normSy: 88,  stripSy: 146),
            TabSpec(id: 7, normSx: 221, normSy: 88,  stripSy: 165),
            TabSpec(id: 8, normSx: 221, normSy: 28,  stripSy: 184)
        ]

        let colorSpace = CGColorSpaceCreateDeviceRGB()

        for s in specs {
            guard let normImg = slice(bmp317, x: s.normSx, y: s.normSy, w: 61, h: 30) else { continue }
            var dict: [TabVisualState: CGImage] = [.normal: normImg]

            // Mask hover tab using normal tab alpha silhouette
            if let rawHover = slice(bmp317, x: 97, y: s.stripSy, w: 61, h: 30),
               let maskedHover = maskTabImage(content: rawHover, mask: normImg, colorSpace: colorSpace) {
                dict[.hover] = maskedHover
            } else {
                dict[.hover] = normImg
            }

            // Mask active tab using normal tab alpha silhouette
            if let rawActive = slice(bmp317, x: 159, y: s.stripSy, w: 61, h: 30),
               let maskedActive = maskTabImage(content: rawActive, mask: normImg, colorSpace: colorSpace) {
                dict[.active] = maskedActive
            } else {
                dict[.active] = normImg
            }

            cachedTabSprites[s.id] = dict
        }
    }

    private func maskTabImage(content: CGImage, mask: CGImage, colorSpace: CGColorSpace) -> CGImage? {
        let w = 61
        let h = 30
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // 1. Draw normal tab (sets alpha mask)
        ctx.draw(mask, in: CGRect(x: 0, y: 0, width: w, height: h))
        // 2. Set blend mode to .sourceIn
        ctx.setBlendMode(.sourceIn)
        // 3. Draw content (hover or active)
        ctx.draw(content, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }

    func playSound(_ name: String, enabled: Bool = true) {
        guard enabled, let sound = sounds[name] else { return }
        sound.stop()
        sound.play()
    }
}

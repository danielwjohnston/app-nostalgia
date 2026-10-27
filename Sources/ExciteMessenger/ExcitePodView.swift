import AppKit
import AVFoundation

@MainActor
final class ExcitePodView: NSView {

    // MARK: - Navigation Tab Definitions (9 Scalloped Tabs)
    struct TabDef {
        let id: Int
        let key: String
        let name: String
        let dy: CGFloat
    }

    static let tabs: [TabDef] = [
        TabDef(id: 0, key: "Email",      name: "Email",        dy: 56),
        TabDef(id: 1, key: "Search",     name: "Search",       dy: 75),
        TabDef(id: 2, key: "News",       name: "News",         dy: 94),
        TabDef(id: 3, key: "TV",         name: "TV Listings",  dy: 113),
        TabDef(id: 4, key: "TuneIn",     name: "TuneIn",       dy: 132),
        TabDef(id: 5, key: "Stocks",     name: "Stocks",       dy: 151),
        TabDef(id: 6, key: "Weather",    name: "Weather",      dy: 170),
        TabDef(id: 7, key: "Horoscopes", name: "Horoscopes",   dy: 189),
        TabDef(id: 8, key: "Deals",      name: "Deals",        dy: 208)
    ]

    // Logical dimensions
    static let podWidth: CGFloat = 330
    static let flyoutWidth: CGFloat = 475
    static let baseHeight: CGFloat = 290
    private static let drawerFullWidth: Int = 234

    // Interactive State
    private(set) var activeTab: Int = 2 // Start on News
    private(set) var hoverTab: Int = -1
    private(set) var pressedTab: Int = -1
    private(set) var hoverZone: String?
    private(set) var activeNewsSubtab: Int = 0
    private(set) var isDockedEdge: Bool = false
    private(set) var showHRGNXRay: Bool = false
    private(set) var useSlate2000Tint: Bool = false
    private(set) var pixelScale: CGFloat = 1.0
    private(set) var soundEnabled: Bool = true
    private(set) var showFlyoutControls: Bool = false

    var currentLogicalWidth: CGFloat {
        showFlyoutControls ? Self.flyoutWidth : Self.podWidth
    }

    // TSlidingWins Physics State (0x00439D89: sar ecx, 3)
    private var drawerWidth: Int = 234
    private var targetDrawerWidth: Int = 234
    private var switchingToTab: Int = -1
    private var physicsTimer: Timer?
    private var tick: Int = 0

    // Volume Slider dragging
    private var isDraggingVolume = false

    // Window Dragging State
    private var isDraggingWindow = false
    private var dragStartScreenPt: NSPoint = .zero
    private var dragStartWinOrigin: NSPoint = .zero
    private var savedUndockedOrigin: NSPoint?

    // Clickable rows in Content Well
    private var clickableRows: [(rect: NSRect, action: () -> Void)] = []

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)

        LiveServices.shared.onUpdate = { [weak self] in
            self?.needsDisplay = true
            ExciteChatWindowController.shared.refreshAll()
        }
        ExciteChatWindowController.shared.updateScale(self.pixelScale)

        physicsTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stepPhysics()
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func toLogical(_ pt: NSPoint) -> NSPoint {
        NSPoint(x: pt.x / pixelScale, y: pt.y / pixelScale)
    }

    // MARK: - TSlidingWins Physics (0x00439D89: sar ecx, 3)

    private func stepPhysics() {
        tick = (tick + 1) % 10000
        var dirty = false

        LiveServices.shared.updateMeterBallistics()
        if LiveServices.shared.radioPlaying || LiveServices.shared.currentRMSLevel > 0 {
            dirty = true
        }

        if drawerWidth != targetDrawerWidth {
            let diff = drawerWidth - targetDrawerWidth
            // sar ecx, 3 (divide remaining distance by 8)
            var step = diff >> 3
            if step == 0 {
                step = diff > 0 ? 1 : -1
            }
            drawerWidth -= step
            if abs(drawerWidth - targetDrawerWidth) <= 1 {
                drawerWidth = targetDrawerWidth
                if switchingToTab >= 0 {
                    activeTab = switchingToTab
                    switchingToTab = -1
                    targetDrawerWidth = Self.drawerFullWidth
                    AssetManager.shared.playSound("wav358", enabled: soundEnabled)
                }
            }
            dirty = true
        }

        if dirty {
            needsDisplay = true
        }
    }

    func selectTab(_ idx: Int) {
        guard idx >= 0, idx < Self.tabs.count else { return }
        if isDockedEdge {
            toggleDockEdge()
        }
        AssetManager.shared.playSound("wav356", enabled: soundEnabled)
        if targetDrawerWidth == 0 && drawerWidth == 0 {
            activeTab = idx
            targetDrawerWidth = Self.drawerFullWidth
            AssetManager.shared.playSound("wav358", enabled: soundEnabled)
        } else if activeTab == idx && switchingToTab == -1 {
            targetDrawerWidth = (targetDrawerWidth == 0) ? Self.drawerFullWidth : 0
            AssetManager.shared.playSound("wav358", enabled: soundEnabled)
        } else {
            switchingToTab = idx
            targetDrawerWidth = 36
            AssetManager.shared.playSound("wav358", enabled: soundEnabled)
        }
        needsDisplay = true
    }

    func toggleDrawerCollapse() {
        AssetManager.shared.playSound("wav356", enabled: soundEnabled)
        targetDrawerWidth = (targetDrawerWidth == 0) ? Self.drawerFullWidth : 0
        AssetManager.shared.playSound("wav358", enabled: soundEnabled)
        needsDisplay = true
    }

    func toggleDockEdge() {
        guard let win = window, let screen = win.screen ?? NSScreen.main else { return }
        AssetManager.shared.playSound("wav357", enabled: soundEnabled)
        isDockedEdge.toggle()
        if isDockedEdge {
            savedUndockedOrigin = win.frame.origin
            let vis = screen.visibleFrame
            let dockedX = vis.maxX - (32.0 * pixelScale)
            win.setFrameOrigin(NSPoint(x: dockedX, y: win.frame.origin.y))
        } else if let saved = savedUndockedOrigin {
            win.setFrameOrigin(saved)
        }
        needsDisplay = true
    }

    func toggleFlyoutControls() {
        showFlyoutControls.toggle()
        updateWindowFrame()
    }

    func toggleHRGNXRay() {
        showHRGNXRay.toggle()
        needsDisplay = true
    }

    func toggleSkin() {
        useSlate2000Tint.toggle()
        needsDisplay = true
    }

    func toggleSound() {
        soundEnabled.toggle()
    }

    func setScale(_ newScale: CGFloat) {
        pixelScale = newScale
        updateWindowFrame()
        ExciteChatWindowController.shared.updateScale(newScale)
    }

    func cyclePixelScale() {
        let scales: [CGFloat] = [1.0, 1.25, 1.5, 2.0]
        let next = scales.first(where: { $0 > pixelScale }) ?? 1.0
        setScale(next)
    }

    func updateWindowFrame() {
        guard let win = window else { return }
        let newW = currentLogicalWidth * pixelScale
        let newH = Self.baseHeight * pixelScale
        var f = win.frame
        let topY = f.maxY
        let leftX = f.minX
        f.size = NSSize(width: newW, height: newH)
        f.origin.x = leftX
        f.origin.y = topY - newH
        win.setFrame(f, display: true, animate: false)
        self.frame = NSRect(x: 0, y: 0, width: newW, height: newH)
        needsDisplay = true
    }

    // MARK: - Drawing Engine

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        ctx.scaleBy(x: pixelScale, y: pixelScale)
        ctx.interpolationQuality = .none
        ctx.setShouldAntialias(true)

        clickableRows.removeAll()
        let assets = AssetManager.shared
        guard let bmp317 = assets.bmp317, let bmp342 = assets.bmp342 else {
            ctx.restoreGState()
            return
        }

        if isDockedEdge {
            // 25x87 collapsed vertical edge tab
            drawSprite(ctx, image: bmp317, sx: 575, sy: 0, sw: 25, sh: 87, dx: 4, dy: 16)
            ctx.restoreGState()
            return
        }

        let dw = CGFloat(drawerWidth)

        // 1. RIGHT SLIDING DRAWER (Clipped to x: 76 .. 76 + dw + 19)
        if drawerWidth > 0 {
            ctx.saveGState()
            ctx.clip(to: CGRect(x: 76, y: 0, width: dw + 22, height: 286))

            // Background Fill: #B5B49C warm putty
            ctx.setFillColor(red: 181/255.0, green: 180/255.0, blue: 156/255.0, alpha: 1.0)
            ctx.fill(CGRect(x: 76, y: 38, width: 234, height: 216))

            // Top Header: bmp342 ("eXcite ASSISTANT") at (76, 5, 234, 33)
            drawSprite(ctx, image: bmp342, sx: 0, sy: 0, sw: 234, sh: 33, dx: 76, dy: 5)

            // Bottom 4-Button Toolbar at (76, 254, 234, 23)
            drawSprite(ctx, image: bmp317, sx: 157, sy: 216, sw: 234, sh: 23, dx: 76, dy: 254)
            // Hover states for footer buttons
            let footerBtns: [(id: String, dx: CGFloat, sx: Int, w: Int)] = [
                ("footer_tell", 76,       157, 80),
                ("footer_pers", 76 + 80,  237, 67),
                ("footer_sign", 76 + 147, 304, 47),
                ("footer_pref", 76 + 194, 351, 40)
            ]
            for fb in footerBtns {
                if hoverZone == fb.id {
                    drawSprite(ctx, image: bmp317, sx: fb.sx, sy: 240, sw: fb.w, sh: 23, dx: fb.dx, dy: 254)
                }
            }

            // Render Active Tab Content inside Drawer
            renderActiveTabContent(ctx, bmp317: bmp317)

            // Right Bezel End-Cap at (76 + dw, 8, 19, 265)
            let bezelX = 76 + dw
            drawSprite(ctx, image: bmp317, sx: 77, sy: 28, sw: 19, sh: 265, dx: bezelX, dy: 8)
            // Close [X] button hover on bezel
            if hoverZone == "bezel_close" {
                drawSprite(ctx, image: bmp317, sx: 397, sy: 72, sw: 10, sh: 10, dx: bezelX + 4, dy: 28)
            }

            ctx.restoreGState()
        }

        // 2. LEFT CAPSULE SPINE (x = 0..76, y = 0..282)
        drawSprite(ctx, image: bmp317, sx: 0, sy: 28, sw: 76, sh: 282, dx: 0, dy: 0)

        // Top Excite Orb hover / pulse state
        if hoverZone == "orb_excite" || (LiveServices.shared.buddies.reduce(0) { $0 + $1.unreadCount } > 0 && (tick / 8) % 2 == 0) {
            drawSprite(ctx, image: bmp317, sx: 371, sy: 28, sw: 25, sh: 25, dx: 24, dy: 28)
        }

        // 9 Scalloped Navigation Tabs
        for t in Self.tabs {
            let state: AssetManager.TabVisualState
            if t.id == activeTab {
                state = .active
            } else if t.id == hoverTab {
                state = .hover
            } else {
                state = .normal
            }
            if let tabImg = assets.tabSprite(id: t.id, state: state) {
                drawDirectCGImage(ctx, image: tabImg, dx: 0, dy: t.dy, dw: 61, dh: 30)
            }
        }

        // Unread Notification Pill on Email tab
        let unread = LiveServices.shared.buddies.reduce(0) { $0 + $1.unreadCount }
        if unread > 0 {
            let pill = NSBezierPath(roundedRect: NSRect(x: 52, y: 62, width: 14, height: 12), xRadius: 4, yRadius: 4)
            NSColor(calibratedRed: 0.85, green: 0.0, blue: 0.0, alpha: 1.0).setFill()
            pill.fill()
            let pStyle = NSMutableParagraphStyle()
            pStyle.alignment = .center
            ("\(unread)" as NSString).draw(in: NSRect(x: 52, y: 63, width: 14, height: 11), withAttributes: [
                .font: NSFont.boldSystemFont(ofSize: 8.5),
                .foregroundColor: NSColor.white,
                .paragraphStyle: pStyle
            ])
        }

        // Bottom Help '?' Orb hover state
        if hoverZone == "orb_help" {
            drawSprite(ctx, image: bmp317, sx: 369, sy: 106, sw: 23, sh: 23, dx: 24, dy: 236)
        }

        // Optional 2000 Slate Tint Overlay
        if useSlate2000Tint {
            ctx.saveGState()
            ctx.setBlendMode(.color)
            NSColor(calibratedRed: 0.38, green: 0.42, blue: 0.72, alpha: 0.55).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 76, height: 282))
            if drawerWidth > 0 {
                ctx.fill(CGRect(x: 76, y: 0, width: dw + 19, height: 286))
            }
            ctx.restoreGState()
        }

        // 3. RIGHT DIAGNOSTIC HARDWARE PILLS (Only shown when toggled on)
        if showFlyoutControls {
            drawDiagnosticHardwarePanel(ctx)
        }

        // 4. CSG HRGN X-RAY OVERLAY
        if showHRGNXRay {
            drawHRGNXRayOverlay(ctx, dw: dw)
        }

        ctx.restoreGState()
    }

    // MARK: - Tab Content Renderers

    private func renderActiveTabContent(_ ctx: CGContext, bmp317: CGImage) {
        let assets = AssetManager.shared
        let srv = LiveServices.shared
        let t = Self.tabs[activeTab]

        switch t.key {
        case "TuneIn":
            // TuneIn Header Bar at (76, 38, 234, 27)
            drawSprite(ctx, image: bmp317, sx: 235, sy: 0, sw: 234, sh: 27, dx: 76, dy: 38)
            // "< Networks" button
            let netSx = (hoverZone == "tunein_net") ? 78 : 0
            drawSprite(ctx, image: bmp317, sx: netSx, sy: 0, sw: 77, sh: 26, dx: 76 + 80, dy: 38)
            // "< Channel" button
            let chSy = (hoverZone == "tunein_ch") ? 428 : 455
            drawSprite(ctx, image: bmp317, sx: 235, sy: chSy, sw: 77, sh: 26, dx: 76 + 157, dy: 38)

            // Station Banner: bmp132 (234x60) at (76, 71) - clean, no obscuring badge!
            if let bmp132 = assets.bmp132 {
                drawSprite(ctx, image: bmp132, sx: 0, sy: 0, sw: 234, sh: 60, dx: 76, dy: 71)
            }

            // TuneIn Player Deck: (0, 368, 234, 113) at (76, 141)
            drawSprite(ctx, image: bmp317, sx: 0, sy: 368, sw: 234, sh: 113, dx: 76, dy: 141)

            // Live Artist / Song / Station strings
            let st = srv.currentStation
            let trackAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont(name: "Tahoma", size: 10.0) ?? NSFont.systemFont(ofSize: 10.0),
                .foregroundColor: NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.04, alpha: 1.0)
            ]
            (st.currentArtist as NSString).draw(at: NSPoint(x: 126, y: 154), withAttributes: trackAttrs)
            (st.currentSong as NSString).draw(at: NSPoint(x: 126, y: 173), withAttributes: trackAttrs)
            ("\(st.name) (\(st.genre))" as NSString).draw(at: NSPoint(x: 126, y: 191), withAttributes: trackAttrs)

            // Volume Wedge Fill ("psst." to "Yikes!")
            let rampX: CGFloat = 114
            let rampY: CGFloat = 205
            let rampW: CGFloat = 148
            let fillW = rampW * CGFloat(srv.radioVolume)
            ctx.saveGState()
            let rampPath = CGMutablePath()
            rampPath.move(to: CGPoint(x: rampX, y: rampY + 7))
            rampPath.addLine(to: CGPoint(x: rampX + fillW, y: rampY + 7 - 6 * CGFloat(srv.radioVolume)))
            rampPath.addLine(to: CGPoint(x: rampX + fillW, y: rampY + 7 + 6 * CGFloat(srv.radioVolume)))
            rampPath.closeSubpath()
            ctx.setFillColor(red: 99/255.0, green: 96/255.0, blue: 51/255.0, alpha: 1.0)
            ctx.addPath(rampPath)
            ctx.fillPath()
            ctx.restoreGState()

            // Volume Thumb (584, 36, 7, 23)
            let thumbX = rampX + fillW - 3
            drawSprite(ctx, image: bmp317, sx: 584, sy: 36, sw: 7, sh: 23, dx: thumbX, dy: 200)

            // Transport Buttons: Play, Pause, Stop
            if srv.radioPlaying && !srv.radioPaused {
                drawSprite(ctx, image: bmp317, sx: 60, sy: 338, sw: 36, sh: 26, dx: 77, dy: 226) // Active Play
            } else if hoverZone == "btn_play" {
                drawSprite(ctx, image: bmp317, sx: 1, sy: 311, sw: 36, sh: 26, dx: 77, dy: 226)  // Hover Play
            }
            if srv.radioPaused {
                drawSprite(ctx, image: bmp317, sx: 97, sy: 338, sw: 36, sh: 26, dx: 114, dy: 226) // Active Pause
            } else if hoverZone == "btn_pause" {
                drawSprite(ctx, image: bmp317, sx: 38, sy: 311, sw: 36, sh: 26, dx: 114, dy: 226) // Hover Pause
            }
            if !srv.radioPlaying && !srv.radioPaused {
                drawSprite(ctx, image: bmp317, sx: 134, sy: 338, sw: 36, sh: 26, dx: 151, dy: 226) // Active Stop
            } else if hoverZone == "btn_stop" {
                drawSprite(ctx, image: bmp317, sx: 75, sy: 311, sw: 36, sh: 26, dx: 151, dy: 226)  // Hover Stop
            }

            // 14-Segment Authentic 1999 Hardware LED VU Meter
            let activeLeds = Int(srv.currentRMSLevel * 14.0)
            let peakLed = Int(srv.peakHoldLevel * 14.0)

            for i in 0..<14 {
                let slotX: CGFloat = 194 + CGFloat(i * 8)
                let slotY: CGFloat = 230
                let isLit = (i < activeLeds) || (i == peakLed && peakLed > 0)

                if isLit {
                    let fillColor: NSColor
                    let hiColor: NSColor
                    let strokeColor: NSColor

                    if i >= 12 {
                        fillColor = NSColor(calibratedRed: 0.95, green: 0.12, blue: 0.12, alpha: 1.0)
                        hiColor = NSColor(calibratedRed: 1.0, green: 0.65, blue: 0.65, alpha: 1.0)
                        strokeColor = NSColor(calibratedRed: 0.55, green: 0.0, blue: 0.0, alpha: 1.0)
                    } else if i >= 9 {
                        fillColor = NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.0, alpha: 1.0)
                        hiColor = NSColor(calibratedRed: 1.0, green: 0.92, blue: 0.55, alpha: 1.0)
                        strokeColor = NSColor(calibratedRed: 0.60, green: 0.40, blue: 0.0, alpha: 1.0)
                    } else {
                        fillColor = NSColor(calibratedRed: 0.15, green: 0.92, blue: 0.18, alpha: 1.0)
                        hiColor = NSColor(calibratedRed: 0.68, green: 1.0, blue: 0.72, alpha: 1.0)
                        strokeColor = NSColor(calibratedRed: 0.05, green: 0.50, blue: 0.08, alpha: 1.0)
                    }

                    let ledRect = NSRect(x: slotX, y: slotY, width: 5, height: 9)
                    fillColor.setFill()
                    ledRect.fill()

                    hiColor.setFill()
                    NSRect(x: slotX, y: slotY, width: 5, height: 1).fill()
                    NSRect(x: slotX, y: slotY, width: 1, height: 9).fill()

                    strokeColor.setStroke()
                    NSBezierPath(rect: ledRect).stroke()
                }
            }

        case "News":
            // 6-Button News Sub-Tab Bar at (76, 38, 234, 30)
            if let bmp124 = assets.bmp124 {
                drawSprite(ctx, image: bmp124, sx: 0, sy: 0, sw: 234, sh: 30, dx: 76, dy: 38)
            }
            for i in 0..<6 {
                let col = i % 3, row = i / 3
                let bx = col * 78, by = row * 15
                if activeNewsSubtab == i, let bmp170 = assets.bmp170 {
                    drawSprite(ctx, image: bmp170, sx: bx, sy: by, sw: 78, sh: 15, dx: 76 + CGFloat(bx), dy: 38 + CGFloat(by))
                } else if hoverZone == "subtab_\(i)", let bmp146 = assets.bmp146 {
                    drawSprite(ctx, image: bmp146, sx: bx, sy: by, sw: 78, sh: 15, dx: 76 + CGFloat(bx), dy: 38 + CGFloat(by))
                }
            }

            // White Sunken Content Well at (82, 73, 222, 175)
            let well = NSRect(x: 82, y: 73, width: 222, height: 175)
            drawSunkenWhiteWell(ctx, rect: well)

            let items = srv.newsBySubtab[activeNewsSubtab]
            let sectionTitles = ["EXCITE WIRE — TOP STORIES", "WALL STREET & BUSINESS", "TECHNOLOGY & SCI-TECH", "ODD NEWS & OFFBEAT", "SPORTS SCORES & HEADLINES", "PHOTO OF THE DAY & ARTS"]
            drawContentWellHeader(title: sectionTitles[activeNewsSubtab], in: well)

            var curY: CGFloat = 98
            for (idx, item) in items.prefix(4).enumerated() {
                let rowRect = NSRect(x: 84, y: curY, width: 218, height: 34)
                let isHover = (hoverZone == "news_row_\(idx)")
                drawArticleRow(ctx, title: item.title, subtitle: item.subtitle, source: item.source, isHover: isHover, dx: 86, dy: curY)
                if let url = item.url {
                    clickableRows.append((rowRect, { NSWorkspace.shared.open(url) }))
                }
                curY += 36
            }

        case "Weather":
            let well = NSRect(x: 82, y: 44, width: 222, height: 204)
            drawSunkenWhiteWell(ctx, rect: well)
            drawContentWellHeader(title: "FIVE-DAY LOCAL WEATHER", in: well)

            // Clickable City header button
            let cityRect = NSRect(x: 86, y: 60, width: 214, height: 18)
            let isCityHover = (hoverZone == "weather_city")
            if isCityHover {
                NSColor(calibratedRed: 0.92, green: 0.94, blue: 1.0, alpha: 1.0).setFill()
                cityRect.fill()
            }
            let cityAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 10.5),
                .foregroundColor: isCityHover ? NSColor.systemBlue : NSColor(calibratedRed: 0.1, green: 0.2, blue: 0.5, alpha: 1.0)
            ]
            ("\(srv.weatherCity) — \(srv.currentTempF)°F (Click to change)" as NSString).draw(at: NSPoint(x: 88, y: 62), withAttributes: cityAttrs)
            clickableRows.append((cityRect, { [weak self] in
                self?.showWeatherCityPrompt()
            }))

            var wy: CGFloat = 82
            for day in srv.weatherDays {
                if let bmp318 = assets.bmp318 {
                    let spriteIdx = min(10, max(0, day.spriteIndex))
                    drawSprite(ctx, image: bmp318, sx: spriteIdx * 40, sy: 0, sw: 40, sh: 31, dx: 86, dy: wy - 2, dw: 30, dh: 23)
                }
                let dayAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.boldSystemFont(ofSize: 10),
                    .foregroundColor: NSColor.black
                ]
                (day.dayName as NSString).draw(at: NSPoint(x: 122, y: wy + 2), withAttributes: dayAttrs)
                let condAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 9.5),
                    .foregroundColor: NSColor(calibratedRed: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
                ]
                ("\(day.condition)  •  High: \(day.highF)° Low: \(day.lowF)°" as NSString).draw(at: NSPoint(x: 156, y: wy + 2), withAttributes: condAttrs)
                wy += 25
            }

        case "Stocks":
            let well = NSRect(x: 82, y: 44, width: 222, height: 204)
            drawSunkenWhiteWell(ctx, rect: well)
            drawContentWellHeader(title: "LIVE MARKET QUOTES", in: well)

            let thAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 9.5),
                .foregroundColor: NSColor(calibratedRed: 0.3, green: 0.3, blue: 0.4, alpha: 1.0)
            ]
            ("SYMBOL" as NSString).draw(at: NSPoint(x: 86, y: 64), withAttributes: thAttrs)
            ("PRICE (USD)" as NSString).draw(at: NSPoint(x: 154, y: 64), withAttributes: thAttrs)
            ("CHANGE" as NSString).draw(at: NSPoint(x: 236, y: 64), withAttributes: thAttrs)

            let sy: CGFloat = 78
            for (idx, q) in srv.stocks.prefix(5).enumerated() {
                let ry = sy + CGFloat(idx * 24)
                let rowRect = NSRect(x: 84, y: ry, width: 218, height: 22)
                let isHov = (hoverZone == "stock_\(idx)")
                if isHov {
                    NSColor(calibratedRed: 0.92, green: 0.94, blue: 1.0, alpha: 1.0).setFill()
                    rowRect.fill()
                }
                let symAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.boldSystemFont(ofSize: 10),
                    .foregroundColor: NSColor.black
                ]
                let prAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont(name: "Tahoma", size: 10) ?? NSFont.systemFont(ofSize: 10),
                    .foregroundColor: NSColor(calibratedRed: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
                ]
                let chgColor = q.isPositive
                    ? NSColor(calibratedRed: 0.0, green: 0.55, blue: 0.1, alpha: 1.0)
                    : NSColor(calibratedRed: 0.75, green: 0.0, blue: 0.0, alpha: 1.0)
                let chgAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.boldSystemFont(ofSize: 9.5),
                    .foregroundColor: chgColor
                ]
                (q.symbol as NSString).draw(at: NSPoint(x: 86, y: ry + 6), withAttributes: symAttrs)
                (q.price as NSString).draw(at: NSPoint(x: 154, y: ry + 6), withAttributes: prAttrs)
                (q.change as NSString).draw(at: NSPoint(x: 236, y: ry + 6), withAttributes: chgAttrs)
                if let url = q.url {
                    clickableRows.append((rowRect, { NSWorkspace.shared.open(url) }))
                }
            }

        case "TV":
            let well = NSRect(x: 82, y: 44, width: 222, height: 204)
            drawSunkenWhiteWell(ctx, rect: well)
            drawContentWellHeader(title: "PRIME TIME TV SCHEDULE", in: well)

            var ty: CGFloat = 64
            for (idx, tv) in srv.tvListings.prefix(4).enumerated() {
                let rowRect = NSRect(x: 84, y: ty, width: 218, height: 34)
                let isHov = (hoverZone == "tv_\(idx)")
                if isHov {
                    NSColor(calibratedRed: 0.94, green: 0.96, blue: 1.0, alpha: 1.0).setFill()
                    rowRect.fill()
                }
                let timeAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.boldSystemFont(ofSize: 9.5),
                    .foregroundColor: NSColor(calibratedRed: 0.1, green: 0.3, blue: 0.7, alpha: 1.0)
                ]
                let showAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.boldSystemFont(ofSize: 10),
                    .foregroundColor: NSColor.black
                ]
                let epAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 9),
                    .foregroundColor: NSColor(calibratedRed: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
                ]
                ("\(tv.time) [\(tv.network)]" as NSString).draw(at: NSPoint(x: 86, y: ty + 2), withAttributes: timeAttrs)
                (tv.showTitle as NSString).draw(at: NSPoint(x: 144, y: ty + 2), withAttributes: showAttrs)
                ("\(tv.episodeTitle) • \(tv.rating)" as NSString).draw(at: NSPoint(x: 86, y: ty + 16), withAttributes: epAttrs)
                if let url = tv.url {
                    clickableRows.append((rowRect, { NSWorkspace.shared.open(url) }))
                }
                ty += 34
            }

        case "Deals":
            let well = NSRect(x: 82, y: 44, width: 222, height: 204)
            drawSunkenWhiteWell(ctx, rect: well)
            drawContentWellHeader(title: "TODAY'S TOP SOFTWARE DEALS", in: well)

            var dy: CGFloat = 64
            for (idx, d) in srv.deals.prefix(4).enumerated() {
                let rowRect = NSRect(x: 84, y: dy, width: 218, height: 34)
                let isHov = (hoverZone == "deal_\(idx)")
                if isHov {
                    NSColor(calibratedRed: 0.94, green: 0.98, blue: 0.94, alpha: 1.0).setFill()
                    rowRect.fill()
                }
                let tAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.boldSystemFont(ofSize: 10),
                    .foregroundColor: NSColor.black
                ]
                let prAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.boldSystemFont(ofSize: 9.5),
                    .foregroundColor: NSColor(calibratedRed: 0.0, green: 0.55, blue: 0.1, alpha: 1.0)
                ]
                (d.title as NSString).draw(at: NSPoint(x: 86, y: dy + 2), withAttributes: tAttrs)
                ("\(d.salePrice) (Reg \(d.normalPrice), \(d.savingsPct))" as NSString).draw(at: NSPoint(x: 86, y: dy + 16), withAttributes: prAttrs)
                if let url = d.url {
                    clickableRows.append((rowRect, { NSWorkspace.shared.open(url) }))
                }
                dy += 34
            }

        case "Horoscopes":
            let well = NSRect(x: 82, y: 44, width: 222, height: 204)
            drawSunkenWhiteWell(ctx, rect: well)
            drawContentWellHeader(title: "DAILY ZODIAC HOROSCOPES", in: well)

            // Clickable Zodiac Sign strip
            let signRect = NSRect(x: 86, y: 62, width: 214, height: 38)
            let isSignHover = (hoverZone == "horoscope_sign")
            if isSignHover {
                NSColor(calibratedRed: 0.95, green: 0.92, blue: 0.98, alpha: 1.0).setFill()
                signRect.fill()
            }
            let hInfo = srv.currentHoroscopeText()
            if let bmp229 = assets.bmp229 {
                drawSprite(ctx, image: bmp229, sx: srv.selectedZodiacIndex * 50, sy: 0, sw: 50, sh: 48, dx: 86, dy: 64, dw: 36, dh: 35)
            }
            let zAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 11),
                .foregroundColor: isSignHover ? NSColor.systemPurple : NSColor(calibratedRed: 0.45, green: 0.1, blue: 0.5, alpha: 1.0)
            ]
            ("\(hInfo.sign) (Click to switch)" as NSString).draw(at: NSPoint(x: 128, y: 66), withAttributes: zAttrs)
            clickableRows.append((signRect, { [weak self] in
                AssetManager.shared.playSound("wav356", enabled: self?.soundEnabled ?? true)
                LiveServices.shared.cycleZodiacSign()
                self?.needsDisplay = true
            }))

            let predAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont(name: "Tahoma", size: 10) ?? NSFont.systemFont(ofSize: 10),
                .foregroundColor: NSColor(calibratedRed: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
            ]
            (hInfo.forecast as NSString).draw(in: NSRect(x: 88, y: 106, width: 210, height: 80), withAttributes: predAttrs)

            let luckyAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 9.5),
                .foregroundColor: NSColor(calibratedRed: 0.2, green: 0.4, blue: 0.2, alpha: 1.0)
            ]
            (hInfo.lucky as NSString).draw(at: NSPoint(x: 88, y: 194), withAttributes: luckyAttrs)

        case "Search":
            let well = NSRect(x: 82, y: 44, width: 222, height: 204)
            drawSunkenWhiteWell(ctx, rect: well)
            drawContentWellHeader(title: "EXCITE LIVE SEARCH", in: well)

            // Interactive Search Query Box at (86, 58, 168, 20)
            let searchBox = NSRect(x: 86, y: 58, width: 168, height: 20)
            NSColor(calibratedRed: 0.96, green: 0.96, blue: 0.92, alpha: 1.0).setFill()
            searchBox.fill()
            NSColor(calibratedRed: 0.40, green: 0.40, blue: 0.35, alpha: 1.0).setStroke()
            NSBezierPath(rect: searchBox).stroke()

            let qAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont(name: "Tahoma", size: 9.5) ?? NSFont.systemFont(ofSize: 9.5),
                .foregroundColor: NSColor(calibratedRed: 0.1, green: 0.2, blue: 0.6, alpha: 1.0)
            ]
            let qText = srv.searchQuery.isEmpty ? "Click here to search..." : srv.searchQuery
            (qText as NSString).draw(at: NSPoint(x: 90, y: 62), withAttributes: qAttrs)

            // "Search" Button at (256, 58, 44, 20)
            let btnRect = NSRect(x: 256, y: 58, width: 44, height: 20)
            let isBtnHot = (hoverZone == "btn_search")
            let btnBg = isBtnHot ? NSColor(calibratedRed: 0.85, green: 0.20, blue: 0.15, alpha: 1.0) : NSColor(calibratedRed: 0.75, green: 0.10, blue: 0.05, alpha: 1.0)
            btnBg.setFill()
            btnRect.fill()
            let bAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 9.0),
                .foregroundColor: NSColor.white
            ]
            ("Search" as NSString).draw(at: NSPoint(x: 262, y: 62), withAttributes: bAttrs)

            clickableRows.append((searchBox, { [weak self] in
                self?.showSearchPrompt()
            }))
            clickableRows.append((btnRect, { [weak self] in
                self?.showSearchPrompt()
            }))

            var sy: CGFloat = 84
            for (idx, r) in srv.searchResults.prefix(4).enumerated() {
                let rowRect = NSRect(x: 84, y: sy, width: 218, height: 32)
                let isHov = (hoverZone == "search_\(idx)")
                if isHov {
                    NSColor(calibratedRed: 0.95, green: 0.95, blue: 1.0, alpha: 1.0).setFill()
                    rowRect.fill()
                }
                let tAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.boldSystemFont(ofSize: 10),
                    .foregroundColor: NSColor(calibratedRed: 0.0, green: 0.2, blue: 0.7, alpha: 1.0)
                ]
                let snipAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 9),
                    .foregroundColor: NSColor(calibratedRed: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
                ]
                (r.title as NSString).draw(at: NSPoint(x: 86, y: sy + 2), withAttributes: tAttrs)
                let cleanSnip = String(r.subtitle.prefix(42)) + (r.subtitle.count > 42 ? "..." : "")
                (cleanSnip as NSString).draw(at: NSPoint(x: 86, y: sy + 15), withAttributes: snipAttrs)
                if let url = r.url {
                    clickableRows.append((rowRect, { NSWorkspace.shared.open(url) }))
                }
                sy += 34
            }

        case "Email":
            let well = NSRect(x: 82, y: 44, width: 222, height: 204)
            drawSunkenWhiteWell(ctx, rect: well)
            drawContentWellHeader(title: "EXCITE MESSENGER BUDDY LIST", in: well)

            var by: CGFloat = 64
            for (idx, b) in srv.buddies.enumerated() {
                let rowRect = NSRect(x: 84, y: by, width: 218, height: 32)
                let isHov = (hoverZone == "buddy_\(idx)")
                if isHov {
                    NSColor(calibratedRed: 0.92, green: 0.94, blue: 1.0, alpha: 1.0).setFill()
                    rowRect.fill()
                }
                let dotRect = NSRect(x: 88, y: by + 6, width: 7, height: 7)
                NSColor(calibratedRed: 0.2, green: 0.85, blue: 0.2, alpha: 1.0).setFill()
                NSBezierPath(ovalIn: dotRect).fill()

                let nameAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.boldSystemFont(ofSize: 10),
                    .foregroundColor: NSColor.black
                ]
                let statusAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 8.5),
                    .foregroundColor: NSColor(calibratedRed: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
                ]
                (b.displayName as NSString).draw(at: NSPoint(x: 100, y: by + 3), withAttributes: nameAttrs)
                (b.statusMessage as NSString).draw(at: NSPoint(x: 100, y: by + 16), withAttributes: statusAttrs)

                clickableRows.append((rowRect, { [weak self] in
                    ExciteChatWindowController.shared.openChat(forHandle: b.handle, relativeTo: self?.window)
                }))
                by += 33
            }

        default:
            break
        }
    }

    private func drawSunkenWhiteWell(_ ctx: CGContext, rect: NSRect) {
        NSColor.white.setFill()
        rect.fill()
        NSColor(calibratedRed: 0.40, green: 0.40, blue: 0.35, alpha: 1.0).setFill()
        NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: 1.5).fill()
        NSRect(x: rect.minX, y: rect.minY, width: 1.5, height: rect.height).fill()
        NSColor(calibratedRed: 0.92, green: 0.92, blue: 0.88, alpha: 1.0).setFill()
        NSRect(x: rect.minX, y: rect.maxY - 1, width: rect.width, height: 1).fill()
        NSRect(x: rect.maxX - 1, y: rect.minY, width: 1, height: rect.height).fill()
    }

    private func drawContentWellHeader(title: String, in well: NSRect) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 9.5),
            .foregroundColor: NSColor(calibratedRed: 0.42, green: 0.42, blue: 0.22, alpha: 1.0)
        ]
        (title as NSString).draw(at: NSPoint(x: well.minX + 4, y: well.minY + 4), withAttributes: attrs)
        NSColor(calibratedRed: 0.80, green: 0.80, blue: 0.65, alpha: 1.0).setFill()
        NSRect(x: well.minX + 4, y: well.minY + 18, width: well.width - 8, height: 1).fill()
    }

    private func drawArticleRow(
        _ ctx: CGContext,
        title: String,
        subtitle: String,
        source: String,
        isHover: Bool,
        dx: CGFloat,
        dy: CGFloat
    ) {
        if isHover {
            NSColor(calibratedRed: 0.94, green: 0.96, blue: 1.0, alpha: 1.0).setFill()
            NSRect(x: dx - 2, y: dy, width: 216, height: 34).fill()
        }
        let dotAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 10),
            .foregroundColor: NSColor(calibratedRed: 0.80, green: 0.0, blue: 0.0, alpha: 1.0)
        ]
        let tAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 10),
            .foregroundColor: isHover
                ? NSColor(calibratedRed: 0.85, green: 0.0, blue: 0.0, alpha: 1.0)
                : NSColor(calibratedRed: 0.0, green: 0.15, blue: 0.65, alpha: 1.0)
        ]
        let sAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9.0),
            .foregroundColor: NSColor(calibratedRed: 0.35, green: 0.35, blue: 0.35, alpha: 1.0)
        ]
        ("▪" as NSString).draw(at: NSPoint(x: dx, y: dy + 2), withAttributes: dotAttrs)
        let cleanT = String(title.prefix(32))
        (cleanT as NSString).draw(at: NSPoint(x: dx + 10, y: dy + 2), withAttributes: tAttrs)
        let cleanS = String(subtitle.prefix(38))
        (cleanS as NSString).draw(at: NSPoint(x: dx + 10, y: dy + 15), withAttributes: sAttrs)
    }

    private func drawDiagnosticHardwarePanel(_ ctx: CGContext) {
        let pills: [(id: String, label: String, active: Bool, y: CGFloat)] = [
            ("skin", useSlate2000Tint ? "Skin: 2000 Slate" : "Skin: 1999 Tan", useSlate2000Tint, 12),
            ("xray", showHRGNXRay ? "HRGN X-Ray: ON" : "HRGN X-Ray: OFF", showHRGNXRay, 36),
            ("scale", String(format: "Scale: %.1fx", pixelScale), false, 60),
            ("im", "Open IM Chat Window", false, 84),
            ("refresh", "Refresh Live APIs", false, 108)
        ]
        for p in pills {
            let rect = NSRect(x: 345, y: p.y, width: 120, height: 20)
            let bg = p.active
                ? NSColor(calibratedRed: 0.72, green: 0.12, blue: 0.08, alpha: 0.94)
                : NSColor(calibratedRed: 0.22, green: 0.22, blue: 0.16, alpha: 0.90)
            let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
            bg.setFill()
            path.fill()
            NSColor(calibratedRed: 0.88, green: 0.88, blue: 0.72, alpha: 0.8).setStroke()
            path.lineWidth = 1
            path.stroke()

            let pStyle = NSMutableParagraphStyle()
            pStyle.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 9.0),
                .foregroundColor: NSColor.white,
                .paragraphStyle: pStyle
            ]
            (p.label as NSString).draw(in: rect.offsetBy(dx: 0, dy: 4), withAttributes: attrs)
        }
    }

    private func drawHRGNXRayOverlay(_ ctx: CGContext, dw: CGFloat) {
        drawDashedRect(ctx, rect: CGRect(x: 1, y: 1, width: 75, height: 280), color: .red)
        for t in Self.tabs {
            drawDashedRect(ctx, rect: CGRect(x: 0, y: t.dy, width: 61, height: 30), color: .cyan)
        }
        if dw > 0 {
            drawDashedRect(ctx, rect: CGRect(x: 76, y: 5, width: dw, height: 275), color: .green)
            drawDashedRect(ctx, rect: CGRect(x: 76 + dw, y: 8, width: 19, height: 265), color: .yellow)
        }
    }

    private func drawDashedRect(_ ctx: CGContext, rect: CGRect, color: NSColor) {
        ctx.saveGState()
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(1.2)
        ctx.setLineDash(phase: 0, lengths: [3, 2])
        ctx.stroke(rect)
        ctx.restoreGState()
    }

    private func drawDirectCGImage(_ ctx: CGContext, image: CGImage, dx: CGFloat, dy: CGFloat, dw: CGFloat, dh: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: dx, y: dy + dh)
        ctx.scaleBy(x: 1.0, y: -1.0)
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: dw, height: dh))
        ctx.restoreGState()
    }

    private func drawSprite(
        _ ctx: CGContext,
        image: CGImage,
        sx: Int,
        sy: Int,
        sw: Int,
        sh: Int,
        dx: CGFloat,
        dy: CGFloat,
        dw: CGFloat? = nil,
        dh: CGFloat? = nil
    ) {
        guard let slice = AssetManager.shared.slice(image, x: sx, y: sy, w: sw, h: sh) else { return }
        let destW = dw ?? CGFloat(sw)
        let destH = dh ?? CGFloat(sh)
        ctx.saveGState()
        ctx.translateBy(x: dx, y: dy + destH)
        ctx.scaleBy(x: 1.0, y: -1.0)
        ctx.draw(slice, in: CGRect(x: 0, y: 0, width: destW, height: destH))
        ctx.restoreGState()
    }

    // MARK: - Mouse Interaction

    override func mouseMoved(with event: NSEvent) {
        let pt = toLogical(convert(event.locationInWindow, from: nil))
        var newZone: String?

        if isDockedEdge {
            needsDisplay = true
            return
        }

        // Left Scalloped Tabs
        if pt.x >= 0 && pt.x <= 64 {
            for t in Self.tabs.reversed() {
                if pt.y >= t.dy && pt.y <= t.dy + 30 {
                    newZone = "tab_\(t.id)"
                    break
                }
            }
            if pt.y >= 28 && pt.y <= 53 && pt.x >= 24 && pt.x <= 49 {
                newZone = "orb_excite"
            } else if pt.y >= 236 && pt.y <= 259 && pt.x >= 24 && pt.x <= 47 {
                newZone = "orb_help"
            }
        }

        // Drawer Close Button on Right Bezel (X: bezelX + 3..16, Y: 26..40)
        let bezelX = CGFloat(76 + drawerWidth)
        if pt.x >= bezelX + 3 && pt.x <= bezelX + 16 && pt.y >= 26 && pt.y <= 40 {
            newZone = "bezel_close"
        }

        // TuneIn Radio buttons
        if activeTab == 4 && pt.x >= 76 && pt.x <= 310 {
            if pt.y >= 38 && pt.y <= 64 {
                if pt.x >= 156 && pt.x <= 233 { newZone = "tunein_net" }
                else if pt.x >= 233 && pt.x <= 310 { newZone = "tunein_ch" }
            } else if pt.y >= 226 && pt.y <= 252 {
                if pt.x >= 77 && pt.x <= 113 { newZone = "btn_play" }
                else if pt.x >= 114 && pt.x <= 150 { newZone = "btn_pause" }
                else if pt.x >= 151 && pt.x <= 187 { newZone = "btn_stop" }
            }
        }

        // News subtabs & row hovers
        if activeTab == 2 && pt.x >= 76 && pt.x <= 310 {
            if pt.y >= 38 && pt.y <= 68 {
                let relX = Int(pt.x - 76)
                let relY = Int(pt.y - 38)
                let col = min(2, max(0, relX / 78))
                let row = min(1, max(0, relY / 15))
                newZone = "subtab_\(row * 3 + col)"
            } else if pt.x >= 84 && pt.x <= 302 && pt.y >= 98 && pt.y <= 242 {
                let rowIdx = min(3, max(0, Int(pt.y - 98) / 36))
                newZone = "news_row_\(rowIdx)"
            }
        }

        // Weather city hover
        if activeTab == 6 && pt.x >= 86 && pt.x <= 300 && pt.y >= 58 && pt.y <= 78 {
            newZone = "weather_city"
        }

        // Horoscopes sign hover
        if activeTab == 7 && pt.x >= 86 && pt.x <= 300 && pt.y >= 58 && pt.y <= 100 {
            newZone = "horoscope_sign"
        }

        // Search bar & results hover
        if activeTab == 1 && pt.x >= 84 && pt.x <= 302 {
            if pt.x >= 256 && pt.x <= 300 && pt.y >= 58 && pt.y <= 78 {
                newZone = "btn_search"
            } else if pt.y >= 84 && pt.y <= 220 {
                let rowIdx = min(3, max(0, Int(pt.y - 84) / 34))
                newZone = "search_\(rowIdx)"
            }
        }

        // Stocks row hover
        if activeTab == 5 && pt.x >= 84 && pt.x <= 302 && pt.y >= 78 && pt.y <= 198 {
            let rowIdx = min(4, max(0, Int(pt.y - 78) / 24))
            newZone = "stock_\(rowIdx)"
        }

        // TV row hover
        if activeTab == 3 && pt.x >= 84 && pt.x <= 302 && pt.y >= 64 && pt.y <= 200 {
            let rowIdx = min(3, max(0, Int(pt.y - 64) / 34))
            newZone = "tv_\(rowIdx)"
        }

        // Deals row hover
        if activeTab == 8 && pt.x >= 84 && pt.x <= 302 && pt.y >= 64 && pt.y <= 200 {
            let rowIdx = min(3, max(0, Int(pt.y - 64) / 34))
            newZone = "deal_\(rowIdx)"
        }

        // Buddies row hover
        if activeTab == 0 && pt.x >= 84 && pt.x <= 302 && pt.y >= 64 && pt.y <= 196 {
            let rowIdx = min(3, max(0, Int(pt.y - 64) / 33))
            newZone = "buddy_\(rowIdx)"
        }

        // Bottom toolbar buttons
        if pt.x >= 76 && pt.x <= 310 && pt.y >= 254 && pt.y <= 277 {
            if pt.x < 156 { newZone = "footer_tell" }
            else if pt.x < 223 { newZone = "footer_pers" }
            else if pt.x < 270 { newZone = "footer_sign" }
            else { newZone = "footer_pref" }
        }

        // Flyout Diagnostic Pills (only when visible)
        if showFlyoutControls && pt.x >= 345 && pt.x <= 465 {
            if pt.y >= 12 && pt.y <= 32 { newZone = "pill_skin" }
            else if pt.y >= 36 && pt.y <= 56 { newZone = "pill_xray" }
            else if pt.y >= 60 && pt.y <= 80 { newZone = "pill_scale" }
            else if pt.y >= 84 && pt.y <= 104 { newZone = "pill_im" }
            else if pt.y >= 108 && pt.y <= 128 { newZone = "pill_refresh" }
        }

        let newHoverTab = newZone?.hasPrefix("tab_") == true ? Int(newZone!.replacingOccurrences(of: "tab_", with: "")) ?? -1 : -1
        if newHoverTab != hoverTab || newZone != hoverZone {
            if newHoverTab != -1 && newHoverTab != hoverTab {
                AssetManager.shared.playSound("wav356", enabled: soundEnabled)
            }
            hoverTab = newHoverTab
            hoverZone = newZone
            needsDisplay = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        let pt = toLogical(convert(event.locationInWindow, from: nil))

        if isDockedEdge {
            if NSRect(x: 4, y: 16, width: 25, height: 87).contains(pt) {
                toggleDockEdge()
            }
            return
        }

        // Flyout pills (when visible)
        if showFlyoutControls && pt.x >= 345 && pt.x <= 465 {
            if pt.y >= 12 && pt.y <= 32 {
                useSlate2000Tint.toggle()
                AssetManager.shared.playSound("wav356", enabled: soundEnabled)
                needsDisplay = true
                return
            } else if pt.y >= 36 && pt.y <= 56 {
                showHRGNXRay.toggle()
                AssetManager.shared.playSound("wav356", enabled: soundEnabled)
                needsDisplay = true
                return
            } else if pt.y >= 60 && pt.y <= 80 {
                cyclePixelScale()
                AssetManager.shared.playSound("wav356", enabled: soundEnabled)
                return
            } else if pt.y >= 84 && pt.y <= 104 {
                let first = LiveServices.shared.buddies.first?.handle ?? "swerndorfer@excite.com"
                ExciteChatWindowController.shared.openChat(forHandle: first, relativeTo: window)
                return
            } else if pt.y >= 108 && pt.y <= 128 {
                AssetManager.shared.playSound("wav361", enabled: soundEnabled)
                LiveServices.shared.refreshAllLiveFeeds()
                return
            }
        }

        // Left Navigation Tabs
        if pt.x >= 0 && pt.x <= 64 {
            for t in Self.tabs.reversed() {
                if pt.y >= t.dy && pt.y <= t.dy + 30 {
                    selectTab(t.id)
                    return
                }
            }
            if pt.y >= 28 && pt.y <= 53 && pt.x >= 24 && pt.x <= 49 {
                // Click top orb: refresh live feeds
                AssetManager.shared.playSound("wav356", enabled: soundEnabled)
                LiveServices.shared.refreshAllLiveFeeds()
                return
            } else if pt.y >= 236 && pt.y <= 259 && pt.x >= 24 && pt.x <= 47 {
                // Click bottom help orb: open Help / About dialog!
                AssetManager.shared.playSound("wav356", enabled: soundEnabled)
                showHelpDialog()
                return
            }
        }

        // Right Bezel [X] Close Button (dx: bezelX + 3..16, dy: 26..40)
        let bezelX = CGFloat(76 + drawerWidth)
        if pt.x >= bezelX + 3 && pt.x <= bezelX + 16 && pt.y >= 26 && pt.y <= 40 {
            AssetManager.shared.playSound("wav356", enabled: soundEnabled)
            if targetDrawerWidth > 0 {
                targetDrawerWidth = 0
                AssetManager.shared.playSound("wav358", enabled: soundEnabled)
            } else {
                window?.orderOut(nil)
            }
            needsDisplay = true
            return
        }

        // TuneIn Radio Controls
        if activeTab == 4 {
            if pt.y >= 38 && pt.y <= 64 {
                if pt.x >= 156 && pt.x <= 233 {
                    // "< Networks" popup menu
                    AssetManager.shared.playSound("wav356", enabled: soundEnabled)
                    showNetworksMenu(at: NSPoint(x: pt.x * pixelScale, y: pt.y * pixelScale))
                    return
                } else if pt.x >= 233 && pt.x <= 310 {
                    // "< Channel" next station
                    AssetManager.shared.playSound("wav356", enabled: soundEnabled)
                    LiveServices.shared.nextRadioChannel()
                    return
                }
            } else if pt.y >= 200 && pt.y <= 224 && pt.x >= 110 && pt.x <= 265 {
                isDraggingVolume = true
                let vol = Float((pt.x - 114) / 148.0)
                LiveServices.shared.setVolume(vol)
                needsDisplay = true
                return
            } else if pt.y >= 226 && pt.y <= 252 {
                if pt.x >= 77 && pt.x <= 113 {
                    LiveServices.shared.playRadio()
                    AssetManager.shared.playSound("wav361", enabled: soundEnabled)
                    return
                } else if pt.x >= 114 && pt.x <= 150 {
                    LiveServices.shared.pauseRadio()
                    AssetManager.shared.playSound("wav356", enabled: soundEnabled)
                    return
                } else if pt.x >= 151 && pt.x <= 187 {
                    LiveServices.shared.stopRadio()
                    AssetManager.shared.playSound("wav356", enabled: soundEnabled)
                    return
                }
            }
        }

        // News Subtabs
        if activeTab == 2 && pt.x >= 76 && pt.x <= 310 && pt.y >= 38 && pt.y <= 68 {
            let relX = Int(pt.x - 76)
            let relY = Int(pt.y - 38)
            let col = min(2, max(0, relX / 78))
            let row = min(1, max(0, relY / 15))
            activeNewsSubtab = row * 3 + col
            AssetManager.shared.playSound("wav356", enabled: soundEnabled)
            needsDisplay = true
            return
        }

        // Bottom toolbar
        if pt.x >= 76 && pt.x <= 310 && pt.y >= 254 && pt.y <= 277 {
            if pt.x >= 270 {
                // Prefs button: Ollama & 1Password Settings!
                AssetManager.shared.playSound("wav356", enabled: soundEnabled)
                showOllamaSettingsDialog()
                return
            } else if pt.x >= 223 {
                // Sign In button: Excite Member Sign-In & Status dialog!
                AssetManager.shared.playSound("wav356", enabled: soundEnabled)
                showSignInDialog()
                return
            } else if pt.x >= 156 {
                // Personalize: toggle skin
                useSlate2000Tint.toggle()
                AssetManager.shared.playSound("wav356", enabled: soundEnabled)
                needsDisplay = true
                return
            } else {
                // Tell a Friend: open IM Chat
                let first = LiveServices.shared.buddies.first?.handle ?? "swerndorfer@excite.com"
                ExciteChatWindowController.shared.openChat(forHandle: first, relativeTo: window)
                return
            }
        }

        // Clickable rows in Content Well
        for row in clickableRows {
            if row.rect.contains(pt) {
                AssetManager.shared.playSound("wav361", enabled: soundEnabled)
                row.action()
                return
            }
        }

        // Check for double click on bezel to toggle flyout controls
        if event.clickCount == 2 && pt.x >= bezelX {
            toggleFlyoutControls()
            return
        }

        // Window Dragging on Spine or Header
        isDraggingWindow = true
        dragStartScreenPt = NSEvent.mouseLocation
        dragStartWinOrigin = window?.frame.origin ?? .zero
    }

    override func mouseDragged(with event: NSEvent) {
        if isDraggingVolume {
            let pt = toLogical(convert(event.locationInWindow, from: nil))
            let vol = Float((pt.x - 114) / 148.0)
            LiveServices.shared.setVolume(vol)
            needsDisplay = true
            return
        }

        if isDraggingWindow, let win = window {
            let cur = NSEvent.mouseLocation
            win.setFrameOrigin(NSPoint(
                x: dragStartWinOrigin.x + (cur.x - dragStartScreenPt.x),
                y: dragStartWinOrigin.y + (cur.y - dragStartScreenPt.y)
            ))
        }
    }

    override func mouseUp(with event: NSEvent) {
        isDraggingWindow = false
        isDraggingVolume = false
        pressedTab = -1
        needsDisplay = true
    }

    // MARK: - Interactive Dialogs & Popups

    func showNetworksMenu(at screenPt: NSPoint) {
        let menu = NSMenu(title: "SomaFM Stations")
        for (idx, st) in LiveServices.shared.stations.enumerated() {
            let item = NSMenuItem(title: "\(st.network): \(st.name) (\(st.genre))", action: #selector(onStationSelected(_:)), keyEquivalent: "")
            item.tag = idx
            item.target = self
            if idx == LiveServices.shared.currentStationIndex {
                item.state = .on
            }
            menu.addItem(item)
        }
        menu.popUp(positioning: menu.item(at: LiveServices.shared.currentStationIndex), at: screenPt, in: self)
    }

    @objc private func onStationSelected(_ sender: NSMenuItem) {
        let idx = sender.tag
        if idx >= 0 && idx < LiveServices.shared.stations.count {
            while LiveServices.shared.currentStationIndex != idx {
                LiveServices.shared.nextRadioChannel()
            }
            if !LiveServices.shared.radioPlaying {
                LiveServices.shared.playRadio()
            }
            needsDisplay = true
        }
    }

    func showSearchPrompt() {
        let alert = NSAlert()
        alert.messageText = "Excite Live Web Search"
        alert.informativeText = "Enter keyword to search across Wikipedia & Web:"
        alert.addButton(withTitle: "Search Excite")
        alert.addButton(withTitle: "Cancel")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.stringValue = LiveServices.shared.searchQuery
        alert.accessoryView = input
        if alert.runModal() == .alertFirstButtonReturn {
            let q = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !q.isEmpty {
                AssetManager.shared.playSound("wav361", enabled: soundEnabled)
                LiveServices.shared.performLiveSearch(query: q)
                needsDisplay = true
            }
        }
    }

    func showWeatherCityPrompt() {
        let alert = NSAlert()
        alert.messageText = "Change Weather City"
        alert.informativeText = "Enter city name (e.g. Seattle, Austin, New York, London, Tokyo):"
        alert.addButton(withTitle: "Update Forecast")
        alert.addButton(withTitle: "Cancel")
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.stringValue = LiveServices.shared.weatherCity
        alert.accessoryView = input
        if alert.runModal() == .alertFirstButtonReturn {
            let city = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !city.isEmpty {
                AssetManager.shared.playSound("wav361", enabled: soundEnabled)
                LiveServices.shared.updateWeatherLocation(cityQuery: city)
                needsDisplay = true
            }
        }
    }

    func showSignInDialog() {
        let alert = NSAlert()
        alert.messageText = "Excite Member Sign In"
        alert.informativeText = "Connect to Excite Instant Messenger & Live Services:"
        alert.addButton(withTitle: "Sign In / Update")
        alert.addButton(withTitle: "Cancel")

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 110))

        let userLabel = NSTextField(labelWithString: "Member Name:")
        userLabel.frame = NSRect(x: 0, y: 82, width: 100, height: 20)
        let userField = NSTextField(frame: NSRect(x: 105, y: 80, width: 230, height: 22))
        userField.stringValue = NSUserName()

        let passLabel = NSTextField(labelWithString: "Password:")
        passLabel.frame = NSRect(x: 0, y: 52, width: 100, height: 20)
        let passField = NSSecureTextField(frame: NSRect(x: 105, y: 50, width: 230, height: 22))
        passField.placeholderString = "Saved in 1Password / Keychain"
        passField.stringValue = "••••••••••••"

        let statusLabel = NSTextField(labelWithString: "Online Status:")
        statusLabel.frame = NSRect(x: 0, y: 22, width: 100, height: 20)
        let statusPopup = NSPopUpButton(frame: NSRect(x: 103, y: 18, width: 234, height: 24), pullsDown: false)
        statusPopup.addItems(withTitles: ["Online", "Away", "Be Right Back", "Busy", "Invisible"])

        container.addSubview(userLabel)
        container.addSubview(userField)
        container.addSubview(passLabel)
        container.addSubview(passField)
        container.addSubview(statusLabel)
        container.addSubview(statusPopup)

        alert.accessoryView = container

        if alert.runModal() == .alertFirstButtonReturn {
            AssetManager.shared.playSound("wav357", enabled: soundEnabled)
            let chosenStatus = statusPopup.titleOfSelectedItem ?? "Online"
            let notify = NSAlert()
            notify.messageText = "Signed In as \(userField.stringValue)"
            notify.informativeText = "Status set to '\(chosenStatus)'. Connected to Excite Live Mesh & Ollama Engine."
            notify.runModal()
            needsDisplay = true
        }
    }

    func showHelpDialog() {
        let alert = NSAlert()
        alert.messageText = "Excite Assistant & Messenger Help"
        alert.informativeText = """
        Excite Assistant v2.0 (1999/2026)

        Tactile Appliance Navigation:
        • 9 Scalloped Tabs: Click any tab to slide out the motorized drawer.
        • Click Active Tab or [X] Bezel: Collapses drawer into the spine.
        • Top Red Orb: Refreshes all live feeds and checks messages.
        • Bottom '?' Orb: Opens this help guide.
        • Bottom Toolbar:
          - Tell a Friend: Opens IM chat sessions.
          - Personalize: Toggles 1999 Tan / 2000 Slate skin.
          - Sign In: Configures member name and online presence.
          - Prefs: Configures Ollama AI Chatbot & 1Password.

        Interactive Tab Features:
        • Search Tab: Click the search box or 'Search' to search Wikipedia live.
        • Weather Tab: Click the city name to change your location worldwide.
        • Horoscopes Tab: Click the Zodiac medallion to cycle all 12 signs.
        • TuneIn Tab: Click '< Networks' for station picker, '< Channel' to cycle.

        Keyboard Shortcuts:
        • Cmd+Q: Quit Excite Assistant
        • Cmd+W: Close active window
        • Cmd+1..4: Switch pod scale (1.0x, 1.25x, 1.5x, 2.0x)
        • Cmd+D: Show / hide flyout debug controls
        • Cmd+K: Collapse / expand sliding drawer
        • Cmd+P: Play / pause TuneIn radio
        • Cmd+]: Next radio channel
        • Cmd+R: Refresh live news and feeds
        • Cmd+,: Ollama AI & 1Password settings
        """
        alert.runModal()
    }

    func showOllamaSettingsDialog() {
        let alert = NSAlert()
        alert.messageText = "Excite Messenger AI / Ollama Settings"
        alert.informativeText = "Configure Ollama AI Chatbot & 1Password Integration:"
        alert.addButton(withTitle: "Save Settings")
        alert.addButton(withTitle: "Import from 1Password ('op')")
        alert.addButton(withTitle: "Cancel")

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 350, height: 130))

        let hostLabel = NSTextField(labelWithString: "Ollama Host:")
        hostLabel.frame = NSRect(x: 0, y: 102, width: 100, height: 20)
        let hostField = NSTextField(frame: NSRect(x: 105, y: 100, width: 240, height: 22))
        hostField.stringValue = OllamaService.shared.config.host

        let keyLabel = NSTextField(labelWithString: "API Key:")
        keyLabel.frame = NSRect(x: 0, y: 72, width: 100, height: 20)
        let keyField = NSSecureTextField(frame: NSRect(x: 105, y: 70, width: 240, height: 22))
        keyField.placeholderString = "Paste key from 1Password or leave blank"
        keyField.stringValue = OllamaService.shared.config.apiKey

        let modelLabel = NSTextField(labelWithString: "Model Name:")
        modelLabel.frame = NSRect(x: 0, y: 42, width: 100, height: 20)
        let modelField = NSTextField(frame: NSRect(x: 105, y: 40, width: 240, height: 22))
        modelField.stringValue = OllamaService.shared.config.model

        let opLabel = NSTextField(labelWithString: "1Password Item:")
        opLabel.frame = NSRect(x: 0, y: 12, width: 100, height: 20)
        let opField = NSTextField(frame: NSRect(x: 105, y: 10, width: 240, height: 22))
        opField.placeholderString = "e.g. Ollama or op://vault/item/secret"
        opField.stringValue = OllamaService.shared.config.opItem

        container.addSubview(hostLabel)
        container.addSubview(hostField)
        container.addSubview(keyLabel)
        container.addSubview(keyField)
        container.addSubview(modelLabel)
        container.addSubview(modelField)
        container.addSubview(opLabel)
        container.addSubview(opField)

        alert.accessoryView = container

        let resp = alert.runModal()
        if resp == .alertFirstButtonReturn {
            OllamaService.shared.updateSettings(
                host: hostField.stringValue,
                apiKey: keyField.stringValue,
                model: modelField.stringValue,
                opItem: opField.stringValue
            )
            AssetManager.shared.playSound("wav361", enabled: soundEnabled)
        } else if resp == .alertSecondButtonReturn {
            let itemName = opField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if let key = OllamaService.shared.fetchKeyFrom1Password(itemName: itemName.isEmpty ? nil : itemName) {
                OllamaService.shared.updateSettings(
                    host: hostField.stringValue,
                    apiKey: key,
                    model: modelField.stringValue,
                    opItem: itemName.isEmpty ? nil : itemName
                )
                let info = NSAlert()
                info.messageText = "1Password Import Succeeded"
                info.informativeText = "Successfully retrieved Ollama API key from 1Password! Chat sessions are now authenticated."
                info.runModal()
            } else {
                let err = NSAlert()
                err.messageText = "1Password CLI Not Ready"
                err.informativeText = """
                Could not read item '\(itemName.isEmpty ? "Ollama" : itemName)' via 1Password CLI ('op').

                Tips:
                • If using the 1Password desktop app: In 1Password Settings > Developer, check 'Integrate with 1Password CLI'.
                • Or sign in via Terminal: op signin
                • Or simply copy the key from 1Password and paste it directly into the 'API Key' field above (or type '/key <your_key>' in any chat window)!
                """
                err.runModal()
            }
        }
    }
}

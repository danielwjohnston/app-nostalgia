import AppKit

@MainActor
final class ExciteChatWindowController {
    static let shared = ExciteChatWindowController()

    private var windowsByHandle: [String: NSWindow] = [:]
    private var viewsByHandle: [String: ExciteChatView] = [:]

    func openChat(forHandle handle: String, relativeTo parentWindow: NSWindow?) {
        LiveServices.shared.clearUnread(forHandle: handle)

        if let existing = windowsByHandle[handle] {
            existing.makeKeyAndOrderFront(nil)
            viewsByHandle[handle]?.needsDisplay = true
            return
        }

        let w: CGFloat = 260
        let h: CGFloat = 290
        var origin = CGPoint(x: 240, y: 360)
        if let parentFrame = parentWindow?.frame {
            origin = CGPoint(
                x: max(20, parentFrame.minX - w - 14),
                y: parentFrame.maxY - h
            )
        }

        let win = FlippableBorderlessWindow(
            contentRect: NSRect(origin: origin, size: NSSize(width: w, height: h)),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = .floating
        win.isReleasedWhenClosed = false

        let chatView = ExciteChatView(frame: NSRect(x: 0, y: 0, width: w, height: h), handle: handle)
        win.contentView = chatView
        win.makeKeyAndOrderFront(nil)
        win.makeFirstResponder(chatView.inputField)

        windowsByHandle[handle] = win
        viewsByHandle[handle] = chatView
        AssetManager.shared.playSound("wav416")
    }

    func refreshAll() {
        for (_, view) in viewsByHandle {
            view.needsDisplay = true
        }
    }
}

final class FlippableBorderlessWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class ExciteChatView: NSView, NSTextFieldDelegate {
    let handle: String
    let inputField = NSTextField()
    private var dragStartMouse: NSPoint = .zero
    private var dragStartOrigin: NSPoint = .zero
    private var isDraggingWindow = false
    private var hoverSend = false
    private var hoverClose = false

    override var isFlipped: Bool { true }

    init(frame frameRect: NSRect, handle: String) {
        self.handle = handle
        super.init(frame: frameRect)
        setupInputField()
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupInputField() {
        inputField.frame = NSRect(x: 14, y: 224, width: 176, height: 22)
        inputField.placeholderAttributedString = NSAttributedString(
            string: "Type instant message...",
            attributes: [
                .foregroundColor: NSColor(calibratedRed: 0.38, green: 0.38, blue: 0.48, alpha: 1.0),
                .font: NSFont(name: "Tahoma", size: 11) ?? NSFont.systemFont(ofSize: 11)
            ]
        )
        inputField.font = NSFont(name: "Tahoma", size: 11) ?? NSFont.systemFont(ofSize: 11)
        inputField.textColor = NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.12, alpha: 1.0)
        inputField.backgroundColor = NSColor(calibratedRed: 0.99, green: 0.99, blue: 0.96, alpha: 1.0)
        inputField.drawsBackground = true
        inputField.isBezeled = true
        inputField.bezelStyle = .squareBezel
        inputField.focusRingType = .none
        inputField.delegate = self
        inputField.target = self
        inputField.action = #selector(onSendTriggered)
        addSubview(inputField)
    }

    @objc private func onSendTriggered() {
        let text = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputField.stringValue = ""
        LiveServices.shared.sendInstantMessage(toHandle: handle, text: text)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.interpolationQuality = .none

        let buddy = LiveServices.shared.buddies.first { $0.handle == handle }
        let displayName = buddy?.displayName ?? handle
        let status = buddy?.status ?? "Online"

        // Non-rectangular Excite Messenger 2000 Slate-Titanium Capsule Shell
        let outerPath = NSBezierPath()
        outerPath.move(to: NSPoint(x: 16, y: 0))
        outerPath.line(to: NSPoint(x: 138, y: 0))
        outerPath.curve(to: NSPoint(x: 152, y: 10), controlPoint1: NSPoint(x: 146, y: 0), controlPoint2: NSPoint(x: 148, y: 6))
        outerPath.line(to: NSPoint(x: bounds.width - 14, y: 10))
        outerPath.appendArc(withCenter: NSPoint(x: bounds.width - 14, y: 24), radius: 14, startAngle: 270, endAngle: 0, clockwise: false)
        outerPath.line(to: NSPoint(x: bounds.width, y: bounds.height - 14))
        outerPath.appendArc(withCenter: NSPoint(x: bounds.width - 14, y: bounds.height - 14), radius: 14, startAngle: 0, endAngle: 90, clockwise: false)
        outerPath.line(to: NSPoint(x: 14, y: bounds.height))
        outerPath.appendArc(withCenter: NSPoint(x: 14, y: bounds.height - 14), radius: 14, startAngle: 90, endAngle: 180, clockwise: false)
        outerPath.line(to: NSPoint(x: 0, y: 16))
        outerPath.appendArc(withCenter: NSPoint(x: 16, y: 16), radius: 16, startAngle: 180, endAngle: 270, clockwise: false)
        outerPath.close()

        // Chassis fill (#666699 Slate-Blue from em.exe 2000)
        NSColor(calibratedRed: 0.40, green: 0.40, blue: 0.60, alpha: 1.0).setFill()
        outerPath.fill()

        // Top-left specular highlight & dark cutout outline
        NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.24, alpha: 1.0).setStroke()
        outerPath.lineWidth = 2.0
        outerPath.stroke()

        // Draw authentic 2000 Excite Messenger header badge slice from em2000.png (538, 0, 227, 28) if loaded
        if let emImg = AssetManager.shared.em2000,
           let headerSlice = AssetManager.shared.slice(emImg, x: 538, y: 0, w: 227, h: 26) {
            ctx.saveGState()
            ctx.translateBy(x: 8, y: 30)
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(headerSlice, in: CGRect(x: 0, y: 0, width: 227, height: 26))
            ctx.restoreGState()
        } else {
            // Fallback brand pill
            let pill = NSBezierPath(roundedRect: NSRect(x: 8, y: 4, width: 132, height: 22), xRadius: 8, yRadius: 8)
            NSColor(calibratedRed: 0.80, green: 0.0, blue: 0.0, alpha: 1.0).setFill()
            pill.fill()
        }

        // Close [X] button at top right
        let closeRect = NSRect(x: bounds.width - 24, y: 14, width: 16, height: 14)
        drawBeveledButton(in: closeRect, label: "×", hot: hoverClose, pressed: false)

        // Buddy Header Strip (y: 32..52)
        let buddyStrip = NSRect(x: 12, y: 34, width: bounds.width - 24, height: 20)
        NSColor(calibratedRed: 0.30, green: 0.30, blue: 0.48, alpha: 1.0).setFill()
        buddyStrip.fill()

        // Online green dot
        let dotRect = NSRect(x: 18, y: 40, width: 8, height: 8)
        NSColor(calibratedRed: 0.2, green: 0.95, blue: 0.3, alpha: 1.0).setFill()
        NSBezierPath(ovalIn: dotRect).fill()

        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 11),
            .foregroundColor: NSColor.white
        ]
        ("\(displayName) (\(status))" as NSString).draw(at: NSPoint(x: 30, y: 37), withAttributes: headerAttrs)

        // Sunken Transcript Well (y: 58..214)
        let wellRect = NSRect(x: 12, y: 58, width: bounds.width - 24, height: 158)
        drawSunkenWell(in: wellRect, fill: NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.95, alpha: 1.0))

        // Render chat messages inside the well with dynamic bottom-pinned wrapping
        ctx.saveGState()
        let clipRect = wellRect.insetBy(dx: 4, dy: 4)
        ctx.clip(to: clipRect)

        let allMessages = buddy?.messages ?? []
        let availableWidth = clipRect.width - 12

        struct LayoutItem {
            let msg: ChatMessage
            let senderLine: String
            let textHeight: CGFloat
            let totalHeight: CGFloat
        }

        var items: [LayoutItem] = []
        var totalStackHeight: CGFloat = 0

        // Traverse backwards from newest to fit as many messages as possible
        for msg in allMessages.suffix(16).reversed() {
            let senderLine = "\(msg.sender) [\(msg.timestamp)]:"
            let bounded = (msg.text as NSString).boundingRect(
                with: NSSize(width: availableWidth, height: 1000),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [
                    .font: NSFont(name: "Tahoma", size: 10.5) ?? NSFont.systemFont(ofSize: 10.5)
                ]
            )
            let h = max(13, ceil(bounded.height) + 2)
            let itemTotal = 13 + h + 5
            if totalStackHeight + itemTotal > clipRect.height && !items.isEmpty {
                break
            }
            totalStackHeight += itemTotal
            items.append(LayoutItem(msg: msg, senderLine: senderLine, textHeight: h, totalHeight: itemTotal))
        }

        // Draw in chronological order (oldest to newest)
        var curY = clipRect.maxY - totalStackHeight - 2
        if curY < clipRect.minY + 2 {
            curY = clipRect.minY + 2
        }

        for item in items.reversed() {
            let msg = item.msg
            let senderColor = msg.isFromUser
                ? NSColor(calibratedRed: 0.0, green: 0.20, blue: 0.65, alpha: 1.0)
                : NSColor(calibratedRed: 0.65, green: 0.0, blue: 0.0, alpha: 1.0)
            let senderAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 10),
                .foregroundColor: senderColor
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont(name: "Tahoma", size: 10.5) ?? NSFont.systemFont(ofSize: 10.5),
                .foregroundColor: NSColor(calibratedRed: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
            ]

            (item.senderLine as NSString).draw(at: NSPoint(x: clipRect.minX + 4, y: curY), withAttributes: senderAttrs)
            curY += 13

            let drawRect = NSRect(x: clipRect.minX + 6, y: curY, width: availableWidth, height: item.textHeight)
            (msg.text as NSString).draw(in: drawRect, withAttributes: bodyAttrs)
            curY += item.textHeight + 5
        }
        ctx.restoreGState()

        // Send button next to inputField
        let sendRect = NSRect(x: 196, y: 224, width: 52, height: 22)
        drawBeveledButton(in: sendRect, label: "Send", hot: hoverSend, pressed: false)

        // Bottom status footer
        let footAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9.5),
            .foregroundColor: NSColor(calibratedRed: 0.85, green: 0.85, blue: 0.96, alpha: 1.0)
        ]
        let statusLine = buddy?.statusMessage ?? "Excite Instant Messenger Protocol v2.0"
        (statusLine as NSString).draw(at: NSPoint(x: 14, y: 256), withAttributes: footAttrs)
    }

    private func drawSunkenWell(in rect: NSRect, fill: NSColor) {
        fill.setFill()
        rect.fill()
        // Top-left dark inset shadow
        NSColor(calibratedRed: 0.20, green: 0.20, blue: 0.35, alpha: 1.0).setFill()
        NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: 2).fill()
        NSRect(x: rect.minX, y: rect.minY, width: 2, height: rect.height).fill()
        // Bottom-right light highlight
        NSColor(calibratedRed: 0.78, green: 0.78, blue: 0.92, alpha: 1.0).setFill()
        NSRect(x: rect.minX, y: rect.maxY - 1, width: rect.width, height: 1).fill()
        NSRect(x: rect.maxX - 1, y: rect.minY, width: 1, height: rect.height).fill()
    }

    private func drawBeveledButton(in rect: NSRect, label: String, hot: Bool, pressed: Bool) {
        let base = hot
            ? NSColor(calibratedRed: 0.52, green: 0.52, blue: 0.75, alpha: 1.0)
            : NSColor(calibratedRed: 0.44, green: 0.44, blue: 0.66, alpha: 1.0)
        base.setFill()
        rect.fill()
        let hi = NSColor(calibratedRed: 0.82, green: 0.82, blue: 0.98, alpha: 1.0)
        let lo = NSColor(calibratedRed: 0.18, green: 0.18, blue: 0.32, alpha: 1.0)
        (pressed ? lo : hi).setFill()
        NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: 1).fill()
        NSRect(x: rect.minX, y: rect.minY, width: 1, height: rect.height).fill()
        (pressed ? hi : lo).setFill()
        NSRect(x: rect.minX, y: rect.maxY - 1, width: rect.width, height: 1).fill()
        NSRect(x: rect.maxX - 1, y: rect.minY, width: 1, height: rect.height).fill()

        let pStyle = NSMutableParagraphStyle()
        pStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 10.5),
            .foregroundColor: NSColor.white,
            .paragraphStyle: pStyle
        ]
        (label as NSString).draw(in: rect.offsetBy(dx: 0, dy: 4), withAttributes: attrs)
    }

    override func mouseMoved(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        let sendRect = NSRect(x: 196, y: 224, width: 52, height: 22)
        let closeRect = NSRect(x: bounds.width - 24, y: 14, width: 16, height: 14)
        let newSend = sendRect.contains(pt)
        let newClose = closeRect.contains(pt)
        if newSend != hoverSend || newClose != hoverClose {
            hoverSend = newSend
            hoverClose = newClose
            needsDisplay = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        let sendRect = NSRect(x: 196, y: 224, width: 52, height: 22)
        let closeRect = NSRect(x: bounds.width - 24, y: 14, width: 16, height: 14)

        if closeRect.contains(pt) {
            AssetManager.shared.playSound("wav356")
            window?.orderOut(nil)
            return
        }
        if sendRect.contains(pt) {
            onSendTriggered()
            return
        }
        if pt.y < 54 {
            isDraggingWindow = true
            dragStartMouse = NSEvent.mouseLocation
            dragStartOrigin = window?.frame.origin ?? .zero
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDraggingWindow, let win = window else { return }
        let cur = NSEvent.mouseLocation
        let dx = cur.x - dragStartMouse.x
        let dy = cur.y - dragStartMouse.y
        win.setFrameOrigin(NSPoint(x: dragStartOrigin.x + dx, y: dragStartOrigin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        isDraggingWindow = false
    }
}

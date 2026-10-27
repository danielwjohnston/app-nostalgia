import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindow: FlippableBorderlessWindow?
    var podView: ExcitePodView?
    var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        setupMainMenu()

        let scale: CGFloat = 1.0 // Start at crisp 1.0x original 1999 size
        let w = ExcitePodView.podWidth * scale
        let h = ExcitePodView.baseHeight * scale

        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = NSPoint(
            x: screenRect.maxX - w - 40,
            y: screenRect.midY - (h / 2)
        )

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
        win.title = "Excite Assistant & Messenger (1999/2000)"

        let view = ExcitePodView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        win.contentView = view
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.mainWindow = win
        self.podView = view

        setupStatusBarItem()
        AssetManager.shared.playSound("wav358")
        LiveServices.shared.refreshAllLiveFeeds()
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // 1. Application Menu ("Excite Assistant")
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Excite Assistant")
        appMenu.addItem(withTitle: "About Excite Assistant & Messenger", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Preferences / AI Settings...", action: #selector(showPreferences), keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide Excite Assistant", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Excite Assistant", action: #selector(quitApp), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // 2. File Menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New IM Chat Session...", action: #selector(openIM), keyEquivalent: "n")
        fileMenu.addItem(withTitle: "Close Window", action: #selector(closeFrontWindow), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // 3. Edit Menu (Standard text editing shortcuts: Cmd+C, Cmd+V, Cmd+A, Cmd+X)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // 4. View Menu (Scaling, Flyouts, Skins, Drawer)
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        let scaleMenu = NSMenu(title: "Scale")
        scaleMenu.addItem(withTitle: "1.0x (Original 1999 72dpi)", action: #selector(setScale10), keyEquivalent: "1")
        scaleMenu.addItem(withTitle: "1.25x (Medium)", action: #selector(setScale125), keyEquivalent: "2")
        scaleMenu.addItem(withTitle: "1.5x (Large Default)", action: #selector(setScale150), keyEquivalent: "3")
        scaleMenu.addItem(withTitle: "2.0x (Retina HiDPI)", action: #selector(setScale200), keyEquivalent: "4")
        let scaleSub = NSMenuItem(title: "Pod Scale", action: nil, keyEquivalent: "")
        scaleSub.submenu = scaleMenu
        viewMenu.addItem(scaleSub)

        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "Toggle Flyout Controls", action: #selector(toggleFlyouts), keyEquivalent: "d")
        viewMenu.addItem(withTitle: "Toggle HRGN X-Ray Wireframe", action: #selector(toggleXRay), keyEquivalent: "x")
        viewMenu.addItem(withTitle: "Switch Skin (1999 Tan / 2000 Slate)", action: #selector(toggleSkin), keyEquivalent: "t")
        viewMenu.addItem(withTitle: "Collapse / Expand Drawer", action: #selector(toggleDrawer), keyEquivalent: "k")
        viewMenu.addItem(withTitle: "Toggle Sound Effects", action: #selector(toggleSound), keyEquivalent: "s")
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // 5. TuneIn Audio Menu
        let audioMenuItem = NSMenuItem()
        let audioMenu = NSMenu(title: "TuneIn Audio")
        audioMenu.addItem(withTitle: "Play / Pause", action: #selector(toggleRadio), keyEquivalent: "p")
        audioMenu.addItem(withTitle: "Stop", action: #selector(stopRadio), keyEquivalent: ".")
        audioMenu.addItem(withTitle: "Next Radio Station", action: #selector(nextStation), keyEquivalent: "]")
        audioMenu.addItem(withTitle: "Previous Radio Station", action: #selector(prevStation), keyEquivalent: "[")
        audioMenu.addItem(NSMenuItem.separator())
        let stationsMenu = NSMenu(title: "Stations")
        for (idx, st) in LiveServices.shared.stations.enumerated() {
            let item = NSMenuItem(title: "\(st.network): \(st.name) (\(st.genre))", action: #selector(selectStationByIndex(_:)), keyEquivalent: "")
            item.tag = idx
            stationsMenu.addItem(item)
        }
        let stSub = NSMenuItem(title: "Stations", action: nil, keyEquivalent: "")
        stSub.submenu = stationsMenu
        audioMenu.addItem(stSub)
        audioMenuItem.submenu = audioMenu
        mainMenu.addItem(audioMenuItem)

        // 6. Messenger & AI Menu
        let aiMenuItem = NSMenuItem()
        let aiMenu = NSMenu(title: "Messenger & AI")
        aiMenu.addItem(withTitle: "Chat with Scott Werndorfer", action: #selector(chatWithScott), keyEquivalent: "")
        aiMenu.addItem(withTitle: "Chat with Kevin Kurtz", action: #selector(chatWithKevin), keyEquivalent: "")
        aiMenu.addItem(withTitle: "Chat with C.J. klug", action: #selector(chatWithCJ), keyEquivalent: "")
        aiMenu.addItem(withTitle: "Chat with Excite Live Bot", action: #selector(chatWithBot), keyEquivalent: "")
        aiMenu.addItem(NSMenuItem.separator())
        aiMenu.addItem(withTitle: "Refresh All Live Feeds", action: #selector(refreshFeeds), keyEquivalent: "r")
        aiMenu.addItem(withTitle: "Tell a Friend (Copy GitHub Project Link)", action: #selector(tellAFriend), keyEquivalent: "")
        aiMenu.addItem(withTitle: "Ollama & 1Password Configuration...", action: #selector(showPreferences), keyEquivalent: "")
        aiMenuItem.submenu = aiMenu
        mainMenu.addItem(aiMenuItem)

        // 7. Window Menu
        let winMenuItem = NSMenuItem()
        let winMenu = NSMenu(title: "Window")
        winMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        winMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        winMenuItem.submenu = winMenu
        mainMenu.addItem(winMenuItem)

        // 8. Help Menu
        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(withTitle: "Excite Assistant Help Topics", action: #selector(showHelp), keyEquivalent: "?")
        helpMenu.addItem(withTitle: "Decompilation & Region Specs", action: #selector(showDecompDoc), keyEquivalent: "")
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func setupStatusBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "eXcite"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Excite Pod", action: #selector(showPod), keyEquivalent: "e"))
        menu.addItem(NSMenuItem(title: "Open Excite Messenger IM Window", action: #selector(openIM), keyEquivalent: "m"))
        menu.addItem(NSMenuItem(title: "Toggle Flyout Controls", action: #selector(toggleFlyouts), keyEquivalent: "d"))
        menu.addItem(NSMenuItem(title: "Play / Pause TuneIn SomaFM Radio", action: #selector(toggleRadio), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Refresh All Live Feeds", action: #selector(refreshFeeds), keyEquivalent: "u"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Excite Assistant", action: #selector(quitApp), keyEquivalent: "q"))
        for m in menu.items { m.target = self }
        item.menu = menu
        self.statusItem = item
    }

    @objc func showPod() {
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openIM() {
        let first = LiveServices.shared.buddies.first?.handle ?? "swerndorfer@excite.com"
        ExciteChatWindowController.shared.openChat(forHandle: first, relativeTo: mainWindow)
    }

    @objc func closeFrontWindow() {
        if let keyWin = NSApp.keyWindow {
            keyWin.orderOut(nil)
        } else {
            mainWindow?.orderOut(nil)
        }
    }

    @objc func toggleFlyouts() {
        podView?.toggleFlyoutControls()
    }

    @objc func toggleXRay() {
        podView?.toggleHRGNXRay()
    }

    @objc func toggleSkin() {
        podView?.toggleSkin()
    }

    @objc func toggleDrawer() {
        podView?.toggleDrawerCollapse()
    }

    @objc func toggleSound() {
        podView?.toggleSound()
    }

    @objc func setScale10() { podView?.setScale(1.0) }
    @objc func setScale125() { podView?.setScale(1.25) }
    @objc func setScale150() { podView?.setScale(1.5) }
    @objc func setScale200() { podView?.setScale(2.0) }

    @objc func toggleRadio() {
        if LiveServices.shared.radioPlaying {
            LiveServices.shared.pauseRadio()
        } else {
            LiveServices.shared.playRadio()
        }
    }

    @objc func stopRadio() {
        LiveServices.shared.stopRadio()
    }

    @objc func nextStation() {
        LiveServices.shared.nextRadioChannel()
    }

    @objc func prevStation() {
        LiveServices.shared.prevRadioChannel()
    }

    @objc func selectStationByIndex(_ sender: NSMenuItem) {
        let idx = sender.tag
        if idx >= 0 && idx < LiveServices.shared.stations.count {
            while LiveServices.shared.currentStationIndex != idx {
                LiveServices.shared.nextRadioChannel()
            }
        }
    }

    @objc func chatWithScott() {
        ExciteChatWindowController.shared.openChat(forHandle: "swerndorfer@excite.com", relativeTo: mainWindow)
    }

    @objc func chatWithKevin() {
        ExciteChatWindowController.shared.openChat(forHandle: "kkurtz@excite.com", relativeTo: mainWindow)
    }

    @objc func chatWithCJ() {
        ExciteChatWindowController.shared.openChat(forHandle: "cjklug@excite.com", relativeTo: mainWindow)
    }

    @objc func chatWithBot() {
        ExciteChatWindowController.shared.openChat(forHandle: "livebot@excite.com", relativeTo: mainWindow)
    }

    @objc func refreshFeeds() {
        LiveServices.shared.refreshAllLiveFeeds()
        AssetManager.shared.playSound("wav361")
    }

    @objc func showPreferences() {
        podView?.showOllamaSettingsDialog()
    }

    @objc func tellAFriend() {
        podView?.showTellAFriendDialog()
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Excite Assistant & Messenger v2.0"
        alert.informativeText = """
        Faithful Y2K tactile appliance recreation based on x86 decompilation of Excite Assistant (1999) and Excite Messenger (2000).

        • Constructive Solid Geometry (CSG) scalloped tab math
        • TSlidingWins integer shift-right ease-out physics (sar ecx, 3)
        • SomaFM live streaming with dual-ballistic 14-LED VU meter
        • Ollama & 1Password AI buddy personas
        • macOS Native AppKit implementation

        Engineers: Scott Werndorfer, Kevin Kurtz, C.J.klug
        """
        alert.runModal()
    }

    @objc func showHelp() {
        let alert = NSAlert()
        alert.messageText = "Excite Assistant Help"
        alert.informativeText = """
        Keyboard Shortcuts & Controls:
        • Cmd+Q: Quit Excite Assistant
        • Cmd+W: Close active window
        • Cmd+1..4: Switch pod scale (1.0x, 1.25x, 1.5x, 2.0x)
        • Cmd+D: Show / hide debug flyout buttons
        • Cmd+K: Collapse / expand sliding drawer
        • Cmd+P: Play / pause TuneIn SomaFM radio
        • Cmd+]: Next radio channel
        • Cmd+R: Refresh all live news and feeds
        • Cmd+,: Ollama & 1Password AI settings
        • Double-click right bezel to toggle flyouts
        • Click [X] on right bezel to slide drawer closed
        """
        alert.runModal()
    }

    @objc func showDecompDoc() {
        let docURL = URL(fileURLWithPath: "/Users/dwjohnston/.gemini/antigravity/brain/422273d3-dd11-490e-94e2-75cc47bbc6cc/excite_gui_decompilation.md")
        NSWorkspace.shared.open(docURL)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

@main
struct MainApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

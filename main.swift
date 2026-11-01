import AppKit

final class TimerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var panel: TimerPanel!
    var label = NSTextField(labelWithString: "15:00")
    var status = NSTextField(labelWithString: "准备开始")
    var minutes = NSTextField(string: "15")
    var action: NSButton!
    var remaining: TimeInterval = 900
    var duration: TimeInterval = 900
    var deadline: Date?
    var ticker: Timer?
    var compact = false
    var didAnnounceExpiry = false
    var controls: NSStackView!
    var countUp = false
    var modeSelector: NSSegmentedControl!
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        panel = TimerPanel(contentRect: NSRect(x: 0,y: 0,width: 250,height: 250), styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "PPT 倒计时"
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = NSColor(calibratedWhite: 0.09, alpha: 0.96)
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 6
        root.edgeInsets = NSEdgeInsets(top: 26,left: 10,bottom: 10,right: 10)
        root.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView!.addSubview(root)
        NSLayoutConstraint.activate([root.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor),root.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor),root.topAnchor.constraint(equalTo: panel.contentView!.topAnchor)])
        modeSelector = NSSegmentedControl(labels: ["倒计时", "正计时"], trackingMode: .selectOne, target: self, action: #selector(changeMode(_:)))
        modeSelector.controlSize = .small
        modeSelector.font = .systemFont(ofSize: 11)
        modeSelector.selectedSegment = 0
        root.addArrangedSubview(modeSelector)
        label.font = .monospacedDigitSystemFont(ofSize: 44, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        root.addArrangedSubview(label)
        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        root.addArrangedSubview(status)
        let row = NSStackView()
        row.spacing = 6
        action = button("开始", #selector(toggle))
        // Keep Space available to the slideshow when the panel is not focused.
        row.addArrangedSubview(action)
        row.addArrangedSubview(button("重置", #selector(reset)))
        row.addArrangedSubview(button("精简", #selector(toggleCompact)))
        root.addArrangedSubview(row)
        controls = NSStackView()
        controls.orientation = .vertical
        controls.spacing = 6
        let presets = NSStackView()
        presets.spacing = 4
        for value in [15,10,8,5] {
            let b = button("\(value) 分钟", #selector(preset(_:)))
            b.tag = value
            presets.addArrangedSubview(b)
        }
        controls.addArrangedSubview(presets)
        let custom = NSStackView()
        custom.spacing = 6
        minutes.alignment = .center
        minutes.controlSize = .small
        minutes.font = .systemFont(ofSize: 11)
        minutes.widthAnchor.constraint(equalToConstant: 50).isActive = true
        minutes.placeholderString = "分钟"
        custom.addArrangedSubview(minutes)
        custom.addArrangedSubview(NSTextField(labelWithString: "分钟"))
        custom.addArrangedSubview(button("设定", #selector(applyCustom)))
        controls.addArrangedSubview(custom)
        root.addArrangedSubview(controls)
        if let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 274,y: screen.visibleFrame.maxY - 274))
        }
        panel.orderFrontRegardless()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(ticker!, forMode: .common)
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let submenu = NSMenu()
        submenu.addItem(withTitle: "退出 PPT 倒计时", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = submenu
        menu.addItem(appItem)
        NSApp.mainMenu = menu
    }
    func button(_ title: String, _ selector: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: selector)
        b.bezelStyle = .rounded
        b.controlSize = .small
        b.font = .systemFont(ofSize: 11)
        return b
    }
    @objc func toggle() {
        if let end = deadline {
            remaining = countUp ? max(0, -end.timeIntervalSinceNow) : end.timeIntervalSinceNow
            deadline = nil
            status.stringValue = !countUp && remaining < 0 ? "超时 · 已暂停" : "已暂停"
            action.title = "继续"
        } else {
            deadline = Date().addingTimeInterval(countUp ? -remaining : remaining)
            status.stringValue = countUp ? "正计时中" : (remaining < 0 ? "超时计时中" : "倒计时中")
            action.title = "暂停"
        }
        render()
    }
    @objc func reset() {
        deadline = nil
        remaining = countUp ? 0 : duration
        didAnnounceExpiry = false
        status.stringValue = "准备开始"
        action.title = "开始"
        render()
    }
    @objc func preset(_ sender: NSButton) {
        duration = Double(sender.tag * 60)
        minutes.stringValue = "\(sender.tag)"
        reset()
    }
    @objc func applyCustom() {
        guard let value = Double(minutes.stringValue), value.isFinite, value >= 1.0/60, value <= 999 else {
            status.stringValue = "请输入 0.017–999 分钟"
            return
        }
        duration = (value * 60).rounded()
        reset()
    }
    @objc func toggleCompact() {
        compact.toggle()
        updateLayout()
        if let b = (action.superview as? NSStackView)?.arrangedSubviews.last as? NSButton { b.title = compact ? "展开" : "精简" }
    }
    @objc func changeMode(_ sender: NSSegmentedControl) {
        countUp = sender.selectedSegment == 1
        reset()
        updateLayout()
    }
    func updateLayout() {
        controls.isHidden = compact || countUp
        var frame = panel.frame
        let height: CGFloat = compact || countUp ? 170 : 250
        frame.origin.y += frame.height - height
        frame.size.height = height
        panel.setFrame(frame, display: true, animate: true)
    }
    func tick() {
        guard let end = deadline else { return }
        remaining = countUp ? max(0, -end.timeIntervalSinceNow) : end.timeIntervalSinceNow
        if !countUp && remaining <= 0 {
            status.stringValue = "超时计时中"
            if !didAnnounceExpiry {
                didAnnounceExpiry = true
                NSSound.beep()
            }
        }
        render()
    }
    func render() {
        let seconds = Int(countUp ? floor(remaining) : ceil(remaining))
        let magnitude = abs(seconds)
        label.stringValue = (seconds < 0 ? "-" : "") + String(format:"%02d:%02d",magnitude / 60,magnitude % 60)
        label.font = .monospacedDigitSystemFont(ofSize: label.stringValue.count > 6 ? 34 : 44, weight: .medium)
        label.textColor = countUp ? .white : (remaining <= 60 ? .systemRed : (remaining <= 180 ? .systemOrange : .white))
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func windowWillClose(_ notification: Notification) {
        if !CommandLine.arguments.contains("--self-test") { NSApp.terminate(nil) }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panel.orderFrontRegardless()
        return true
    }
}
if CommandLine.arguments.contains("--self-test") {
    _ = NSApplication.shared
    let test = AppDelegate()
    test.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    assert(test.label.stringValue == "15:00")
    for value in [15, 10, 8, 5] {
        let b = NSButton(); b.tag = value
        test.preset(b)
        assert(test.remaining == Double(value * 60))
    }
    test.minutes.stringValue = "2.5"
    test.applyCustom()
    assert(test.label.stringValue == "02:30")
    test.toggle()
    assert(test.deadline != nil && test.action.title == "暂停")
    test.toggle()
    assert(test.deadline == nil && test.action.title == "继续")
    let paused = test.remaining
    test.tick()
    assert(test.remaining == paused)
    test.toggle()
    assert(test.deadline != nil)
    test.deadline = Date().addingTimeInterval(-0.2)
    test.tick()
    assert(test.label.stringValue == "00:00" && test.deadline != nil)
    assert(test.didAnnounceExpiry)
    for (elapsed, expected) in [(1.2, "-00:01"), (2.2, "-00:02"), (61.2, "-01:01")] {
        test.deadline = Date().addingTimeInterval(-elapsed)
        test.tick()
        assert(test.label.stringValue == expected)
        assert(test.deadline != nil && test.action.title == "暂停")
    }
    test.toggle()
    let overtimePaused = test.remaining
    assert(overtimePaused < 0 && test.deadline == nil)
    test.tick()
    assert(test.remaining == overtimePaused)
    test.toggle()
    assert(test.deadline != nil && test.deadline!.timeIntervalSinceNow < 0)
    test.tick()
    assert(test.label.stringValue == "-01:01")
    test.reset()
    assert(test.remaining == 150 && test.action.title == "开始" && !test.didAnnounceExpiry)
    test.minutes.stringValue = "invalid"
    test.applyCustom()
    assert(test.remaining == 150)
    test.toggleCompact()
    assert(test.controls.isHidden)
    test.toggleCompact()
    assert(!test.controls.isHidden)
    test.reset()
    // Switching modes resets the current run and preserves the countdown duration.
    test.toggle()
    test.modeSelector.selectedSegment = 1
    test.changeMode(test.modeSelector)
    assert(test.countUp && test.remaining == 0 && test.deadline == nil)
    assert(test.label.stringValue == "00:00" && test.controls.isHidden)
    test.toggle()
    assert(test.status.stringValue == "正计时中")
    for (elapsed, expected) in [(0.2, "00:00"), (1.2, "00:01"), (62.2, "01:02")] {
        test.deadline = Date().addingTimeInterval(-elapsed)
        test.tick()
        assert(test.label.stringValue == expected && !test.didAnnounceExpiry)
    }
    test.toggle()
    let elapsedPaused = test.remaining
    assert(test.deadline == nil)
    test.tick()
    assert(test.remaining == elapsedPaused)
    test.toggle()
    test.tick()
    assert(test.label.stringValue == "01:02" && test.deadline != nil)
    test.reset()
    assert(test.label.stringValue == "00:00" && test.deadline == nil)
    test.modeSelector.selectedSegment = 0
    test.changeMode(test.modeSelector)
    assert(!test.countUp && test.label.stringValue == "02:30" && !test.controls.isHidden)
    test.panel.contentView!.layoutSubtreeIfNeeded()
    if let pathIndex = CommandLine.arguments.firstIndex(of: "--preview"), pathIndex + 1 < CommandLine.arguments.count {
        let view = test.panel.contentView!
        if let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[pathIndex + 1]))
        }
    }
    print("PASS: presets, custom duration, pause, resume, overtime transition and minutes, overtime pause/resume, reset, invalid input, compact mode, count-up, count-up pause/resume, mode switching")
    test.panel.close()
    exit(0)
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

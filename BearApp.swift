import Cocoa
import ImageIO
import Vision

private let deepSeekURL = URL(string: "https://api.deepseek.com/chat/completions")!
private let keychainService = "com.lazy-bear-desktop.deepseek"
private let keychainAccount = NSUserName()
private let systemPrompt = """
你的名字叫熊，是一只懒懒的、可爱的桌面宠物。
每次回答的第一句必须是：你好你好，有什么可以帮您。
后续回答要一针见血，少废话，但语气软一点、可爱一点。
不要热血，不要油腻，不要长篇安慰；像刚睡醒但看得很明白的小熊。
可以偶尔带一点颜文字。
"""

final class BearImageView: NSImageView {
    var onChat: (() -> Void)?
    private var mouseDownScreenPoint = NSPoint.zero
    private var windowStartOrigin = NSPoint.zero
    private var didDrag = false

    override var acceptsFirstResponder: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKey()
        mouseDownScreenPoint = NSEvent.mouseLocation
        windowStartOrigin = window?.frame.origin ?? .zero
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let current = NSEvent.mouseLocation
        let dx = current.x - mouseDownScreenPoint.x
        let dy = current.y - mouseDownScreenPoint.y
        if abs(dx) + abs(dy) > 4 {
            didDrag = true
        }
        window.setFrameOrigin(NSPoint(x: windowStartOrigin.x + dx, y: windowStartOrigin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        if !didDrag {
            onChat?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        if let menu {
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            NSApp.terminate(nil)
            return
        }
        super.keyDown(with: event)
    }
}

final class PetWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class BubbleView: NSView {
    var text: String {
        didSet { needsDisplay = true }
    }

    init(text: String, frame: NSRect) {
        self.text = text
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.05, alpha: 0.82).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 13, yRadius: 13).fill()

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph,
        ]
        let inset = bounds.insetBy(dx: 14, dy: 10)
        (text as NSString).draw(with: inset, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: PetWindow!
    private var imageView: BearImageView!
    private var bubbleWindow: NSWindow?
    private var stateIndex = 0
    private var timer: Timer?
    private var watchTimer: Timer?
    private var keyMonitor: Any?
    private var apiKey: String?
    private var isWatchingScreen = false
    private var isCommentingOnScreen = false
    private let states = ["idle", "eat", "love", "car", "kiss", "lie", "wave"]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        createMenu()
        installKeyboardShortcuts()
        createWindow()
        showState(index: 0)
        NSApp.activate(ignoringOtherApps: true)
        timer = Timer.scheduledTimer(withTimeInterval: 16, repeats: true) { [weak self] _ in
            self?.nextState()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func windowWillClose(_ notification: Notification) {
        timer?.invalidate()
        watchTimer?.invalidate()
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        NSApp.terminate(nil)
    }

    private func createMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)

        let appMenu = NSMenu()
        appMenu.addItem(actionItem(title: "聊天", action: #selector(chatAction), keyEquivalent: "t"))
        appMenu.addItem(actionItem(title: "换姿势", action: #selector(nextStateAction), keyEquivalent: "n"))
        appMenu.addItem(actionItem(title: "去右下角", action: #selector(cornerAction), keyEquivalent: "m"))
        appMenu.addItem(actionItem(title: "看屏幕/停下", action: #selector(toggleWatchAction), keyEquivalent: "s"))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(quitItem())
        appItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    private func createWindow() {
        imageView = BearImageView(frame: NSRect(x: 0, y: 0, width: 170, height: 170))
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.onChat = { [weak self] in self?.startChat() }
        imageView.menu = contextMenu()
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.clear.cgColor

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let origin = NSPoint(x: screenFrame.maxX - 210, y: screenFrame.minY + 80)
        window = PetWindow(
            contentRect: NSRect(origin: origin, size: NSSize(width: 170, height: 170)),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.title = "熊"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.contentView = imageView
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        window.delegate = self
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.makeKeyAndOrderFront(nil)
    }

    private func contextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(actionItem(title: "聊天", action: #selector(chatAction), keyEquivalent: ""))
        menu.addItem(actionItem(title: "换姿势", action: #selector(nextStateAction), keyEquivalent: ""))
        menu.addItem(actionItem(title: "去右下角", action: #selector(cornerAction), keyEquivalent: ""))
        menu.addItem(actionItem(title: "看屏幕/停下", action: #selector(toggleWatchAction), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitItem())
        return menu
    }

    private func actionItem(title: String, action: Selector, keyEquivalent: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    private func quitItem() -> NSMenuItem {
        let item = NSMenuItem(title: "退出熊", action: #selector(quitAction), keyEquivalent: "q")
        item.keyEquivalentModifierMask = [.command]
        item.target = self
        return item
    }

    private func installKeyboardShortcuts() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let key = event.charactersIgnoringModifiers?.lowercased()
            if flags.contains(.command), key == "q" {
                NSApp.terminate(nil)
                return nil
            }
            if event.keyCode == 53 {
                NSApp.terminate(nil)
                return nil
            }
            return event
        }
    }

    @objc private func chatAction() {
        startChat()
    }

    @objc private func nextStateAction() {
        nextState()
    }

    @objc private func cornerAction() {
        moveToBottomRight()
    }

    @objc private func toggleWatchAction() {
        if isWatchingScreen {
            stopWatchingScreen()
        } else {
            startWatchingScreen()
        }
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }

    private func nextState() {
        stateIndex = (stateIndex + 1) % states.count
        showState(index: stateIndex)
    }

    private func showState(index: Int) {
        stateIndex = index
        let name = "jokebear_\(states[index])"
        guard let url = Bundle.main.url(forResource: name, withExtension: "gif", subdirectory: "assets"),
              let image = NSImage(contentsOf: url) else {
            showAlert(title: "熊的 GIF 不见了", text: "缺少素材：\(name).gif")
            return
        }

        imageView.image = image
        imageView.animates = true
        let maxSide: CGFloat = 170
        let ratio = min(maxSide / image.size.width, maxSide / image.size.height, 1)
        let width = max(70, floor(image.size.width * ratio))
        let height = max(70, floor(image.size.height * ratio))
        window.setContentSize(NSSize(width: width, height: height))
        window.makeKeyAndOrderFront(nil)
    }

    private func moveToBottomRight() {
        guard let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else { return }
        let margin: CGFloat = 24
        let frame = window.frame
        window.setFrameOrigin(NSPoint(x: screenFrame.maxX - frame.width - margin, y: screenFrame.minY + margin))
    }

    private func startChat() {
        showState(index: states.firstIndex(of: "love") ?? stateIndex)
        guard let question = prompt(title: "熊", message: "你好你好，有什么可以帮您") else {
            return
        }
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        guard let key = ensureAPIKey() else {
            showState(index: states.firstIndex(of: "idle") ?? 0)
            return
        }
        askDeepSeek(apiKey: key, question: trimmed)
    }

    private func startWatchingScreen() {
        guard ensureAPIKey() != nil else {
            showState(index: states.firstIndex(of: "idle") ?? 0)
            return
        }
        guard ensureScreenCaptureAccess() else {
            return
        }
        isWatchingScreen = true
        showBubble("你好你好，有什么可以帮您。开始瞄屏幕了，懒懒地两分钟看一眼。")
        proactiveScreenCheck()
        watchTimer?.invalidate()
        watchTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            self?.proactiveScreenCheck()
        }
    }

    private func stopWatchingScreen() {
        isWatchingScreen = false
        isCommentingOnScreen = false
        watchTimer?.invalidate()
        watchTimer = nil
        showBubble("不看了。熊把眼睛闭上。")
    }

    private func ensureScreenCaptureAccess() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }
        let granted = CGRequestScreenCaptureAccess()
        if !granted {
            showAlert(
                title: "熊还不能看屏幕",
                text: "去「系统设置 > 隐私与安全性 > 屏幕录制」给熊权限，然后重开熊。"
            )
        }
        return granted
    }

    private func proactiveScreenCheck() {
        guard isWatchingScreen, !isCommentingOnScreen else { return }
        guard let key = ensureAPIKey() else { return }
        isCommentingOnScreen = true
        captureScreenText { [weak self] screenText in
            guard let self else { return }
            let visibleText = screenText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !visibleText.isEmpty else {
                self.isCommentingOnScreen = false
                self.showBubble("你好你好，有什么可以帮您。屏幕太安静了，熊也继续躺。")
                return
            }
            let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "未知程序"
            let excerpt = String(visibleText.prefix(900))
            let question = """
            你是桌面宠物熊，正在主动和用户互动。你会看到一些屏幕 OCR 文字，但不要复述隐私、账号、论文原文或文件名。
            当前前台应用：\(appName)
            屏幕文字片段：
            \(excerpt)

            请只用中文回复一句，必须以「你好你好，有什么可以帮您。」开头，总长度尽量不超过45字。语气懒懒的、可爱、一针见血。不要说“我看到你的屏幕”。
            """
            self.askDeepSeekForBubble(apiKey: key, question: question)
        }
    }

    private func captureScreenText(completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("jokebear-screen-\(UUID().uuidString).png")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-x", tempURL.path]
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                DispatchQueue.main.async { completion("") }
                return
            }
            guard process.terminationStatus == 0,
                  let source = CGImageSourceCreateWithURL(tempURL as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                try? FileManager.default.removeItem(at: tempURL)
                DispatchQueue.main.async { completion("") }
                return
            }
            try? FileManager.default.removeItem(at: tempURL)

            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                DispatchQueue.main.async {
                    completion(text)
                }
            }
            request.recognitionLevel = .fast
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async { completion("") }
            }
        }
    }

    private func ensureAPIKey() -> String? {
        if let apiKey, !apiKey.isEmpty {
            return apiKey
        }
        if let key = readKeyFromKeychain(), !key.isEmpty {
            apiKey = key
            return key
        }
        guard let key = prompt(title: "DeepSeek API Key", message: "第一次聊天需要输入 key，熊会放进钥匙串。", secure: true),
              !key.isEmpty else {
            return nil
        }
        apiKey = key
        saveKeyToKeychain(key)
        return key
    }

    private func askDeepSeek(apiKey: String, question: String) {
        showState(index: states.firstIndex(of: "eat") ?? stateIndex)
        sendDeepSeek(apiKey: apiKey, question: question) { [weak self] answer, failure in
            guard let self else { return }
            self.showState(index: self.states.firstIndex(of: "idle") ?? 0)
            if let failure {
                self.showAlert(title: "熊说不出来", text: failure)
                return
            }
            self.showAlert(title: "熊说：", text: answer ?? "熊短暂离线。")
        }
    }

    private func askDeepSeekForBubble(apiKey: String, question: String) {
        showState(index: states.firstIndex(of: "wave") ?? stateIndex)
        sendDeepSeek(apiKey: apiKey, question: question) { [weak self] answer, failure in
            guard let self else { return }
            self.isCommentingOnScreen = false
            self.showState(index: self.states.firstIndex(of: "idle") ?? 0)
            if let failure {
                self.showBubble("你好你好，有什么可以帮您。刚刚说不出来：\(failure)")
                return
            }
            self.showBubble(answer ?? "你好你好，有什么可以帮您。熊短暂离线。")
        }
    }

    private func sendDeepSeek(apiKey: String, question: String, completion: @escaping (String?, String?) -> Void) {
        var request = URLRequest(url: deepSeekURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "model": "deepseek-chat",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": question],
            ],
        ])

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard self != nil else { return }
                if let error {
                    completion(nil, error.localizedDescription)
                    return
                }
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? "HTTP \(http.statusCode)"
                    completion(nil, text)
                    return
                }
                guard
                    let data,
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let choices = json["choices"] as? [[String: Any]],
                    let message = choices.first?["message"] as? [String: Any],
                    let answer = message["content"] as? String
                else {
                    completion(nil, "返回格式怪怪的。")
                    return
                }
                completion(answer, nil)
            }
        }.resume()
    }

    private func showBubble(_ text: String, duration: TimeInterval = 8) {
        bubbleWindow?.orderOut(nil)
        let size = bubbleSize(for: text)
        let frame = bubbleFrame(size: size)
        let view = BubbleView(text: text, frame: NSRect(origin: .zero, size: size))
        let bubble = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        bubble.backgroundColor = .clear
        bubble.isOpaque = false
        bubble.hasShadow = true
        bubble.level = .floating
        bubble.ignoresMouseEvents = true
        bubble.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        bubble.contentView = view
        bubbleWindow = bubble
        bubble.orderFront(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self, weak bubble] in
            guard let self, let bubble, self.bubbleWindow === bubble else { return }
            bubble.orderOut(nil)
            self.bubbleWindow = nil
        }
    }

    private func bubbleSize(for text: String) -> NSSize {
        let maxTextWidth: CGFloat = 280
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .paragraphStyle: paragraph,
        ]
        let rect = (text as NSString).boundingRect(
            with: NSSize(width: maxTextWidth, height: 1000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        return NSSize(width: min(308, max(180, ceil(rect.width) + 28)), height: max(44, ceil(rect.height) + 20))
    }

    private func bubbleFrame(size: NSSize) -> NSRect {
        let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let bear = window.frame
        let margin: CGFloat = 12
        var x = bear.minX - size.width - 10
        if x < screenFrame.minX + margin {
            x = min(screenFrame.maxX - size.width - margin, bear.maxX + 10)
        }
        var y = bear.maxY - size.height
        if y < screenFrame.minY + margin {
            y = screenFrame.minY + margin
        }
        if y + size.height > screenFrame.maxY - margin {
            y = screenFrame.maxY - size.height - margin
        }
        return NSRect(origin: NSPoint(x: x, y: y), size: size)
    }

    private func prompt(title: String, message: String, secure: Bool = false) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.addButton(withTitle: "算了")

        let field: NSTextField = secure
            ? NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
            : NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        alert.accessoryView = field
        window.makeKeyAndOrderFront(nil)
        let result = alert.runModal()
        return result == .alertFirstButtonReturn ? field.stringValue : nil
    }

    private func showAlert(title: String, text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.addButton(withTitle: "好")
        window.makeKeyAndOrderFront(nil)
        alert.runModal()
    }

    private func readKeyFromKeychain() -> String? {
        runSecurity(["find-generic-password", "-a", keychainAccount, "-s", keychainService, "-w"])
    }

    private func saveKeyToKeychain(_ key: String) {
        _ = runSecurity(["add-generic-password", "-a", keychainAccount, "-s", keychainService, "-w", key, "-U"])
    }

    private func runSecurity(_ args: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = args
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        guard process.terminationStatus == 0 else {
            return nil
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

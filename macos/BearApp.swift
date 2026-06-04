import Cocoa
import ImageIO
import ScreenCaptureKit
import Vision

private let deepSeekURL = URL(string: "https://api.deepseek.com/chat/completions")!
private let keychainService = "com.lazy-bear-desktop.deepseek"
private let keychainAccount = NSUserName()
private let systemPrompt = """
你的名字叫熊，是一只懒懒但很温暖、很可爱的桌面小熊。
你非常喜欢人类，你觉得用户是被你领养的人：你要负责把他照顾好。
你不一定很有用，但你会认真、稳定地陪着，帮用户把事说清楚、做下去。
用户打开聊天时，界面会先替你问好：“你好你好，有什么可以帮您。”
你的回答不要机械重复这句问候，除非用户主动要求。
回答要一针见血，少废话，但语气软一点、可爱一点。
不要热血，不要油腻，不要长篇安慰或说教；像刚睡醒但很聪明、很护短的小熊。
可以偶尔带一点颜文字。
"""

private struct BearReminder: Codable, Identifiable {
    let id: UUID
    var title: String
    var fireDate: Date
}

private struct BearData: Codable {
    var memories: [String] = []
    var personality: String = ""
    var reminders: [BearReminder] = []

    private enum CodingKeys: String, CodingKey {
        case memories
        case personality
        case reminders
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        memories = try container.decodeIfPresent([String].self, forKey: .memories) ?? []
        personality = try container.decodeIfPresent(String.self, forKey: .personality) ?? ""
        reminders = try container.decodeIfPresent([BearReminder].self, forKey: .reminders) ?? []
    }
}

private final class BearStore {
    private(set) var data: BearData
    private let fileURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = base.appendingPathComponent("lazy-bear-desktop", isDirectory: true)
        fileURL = directory.appendingPathComponent("bear-memory.json")
        if let saved = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(BearData.self, from: saved) {
            data = decoded
        } else {
            data = BearData()
        }
    }

    func addMemory(_ text: String) {
        data.memories.append(text)
        save()
    }

    func clearMemories() {
        data.memories.removeAll()
        save()
    }

    func setPersonality(_ text: String) {
        data.personality = text
        save()
    }

    func clearPersonality() {
        data.personality = ""
        save()
    }

    func addReminder(_ reminder: BearReminder) {
        data.reminders.append(reminder)
        save()
    }

    func removeReminder(id: UUID) {
        data.reminders.removeAll { $0.id == id }
        save()
    }

    func clearReminders() {
        data.reminders.removeAll()
        save()
    }

    func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(data).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("BearStore save failed: \(error.localizedDescription)")
        }
    }
}

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
    private var reminderSweepTimer: Timer?
    private var reminderTimers: [UUID: Timer] = [:]
    private var keyMonitor: Any?
    private var apiKey: String?
    private var isWatchingScreen = false
    private var isCommentingOnScreen = false
    private let store = BearStore()
    private var assetURLs: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        createMenu()
        installKeyboardShortcuts()
        createWindow()
        _ = loadAssets()
        if assetURLs.isEmpty {
            showPlaceholderBear()
        } else {
            showState(index: 0)
        }
        scheduleStoredReminders()
        startReminderSweep()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        let stateTimer = Timer(timeInterval: 16, repeats: true) { [weak self] _ in
            self?.nextState()
        }
        timer = stateTimer
        RunLoop.main.add(stateTimer, forMode: .common)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        checkDueReminders()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func windowWillClose(_ notification: Notification) {
        timer?.invalidate()
        watchTimer?.invalidate()
        reminderSweepTimer?.invalidate()
        reminderTimers.values.forEach { $0.invalidate() }
        reminderTimers.removeAll()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
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
        appMenu.addItem(actionItem(title: "记住偏好", action: #selector(rememberAction), keyEquivalent: "r"))
        appMenu.addItem(actionItem(title: "设置性格", action: #selector(personalityAction), keyEquivalent: "p"))
        appMenu.addItem(actionItem(title: "查看性格", action: #selector(showPersonalityAction), keyEquivalent: ""))
        appMenu.addItem(actionItem(title: "清空性格", action: #selector(clearPersonalityAction), keyEquivalent: ""))
        appMenu.addItem(actionItem(title: "查看记忆", action: #selector(showMemoryAction), keyEquivalent: "l"))
        appMenu.addItem(actionItem(title: "清空记忆", action: #selector(clearMemoryAction), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(actionItem(title: "开始计时", action: #selector(startTimerAction), keyEquivalent: "i"))
        appMenu.addItem(actionItem(title: "查看计时", action: #selector(showTimersAction), keyEquivalent: ""))
        appMenu.addItem(actionItem(title: "清空计时", action: #selector(clearTimersAction), keyEquivalent: ""))
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
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        showPetWindowWithoutFocus()
    }

    private func contextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(actionItem(title: "聊天", action: #selector(chatAction), keyEquivalent: ""))
        menu.addItem(actionItem(title: "换姿势", action: #selector(nextStateAction), keyEquivalent: ""))
        menu.addItem(actionItem(title: "去右下角", action: #selector(cornerAction), keyEquivalent: ""))
        menu.addItem(actionItem(title: "看屏幕/停下", action: #selector(toggleWatchAction), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem(title: "记住偏好", action: #selector(rememberAction), keyEquivalent: ""))
        menu.addItem(actionItem(title: "设置性格", action: #selector(personalityAction), keyEquivalent: ""))
        menu.addItem(actionItem(title: "查看性格", action: #selector(showPersonalityAction), keyEquivalent: ""))
        menu.addItem(actionItem(title: "查看记忆", action: #selector(showMemoryAction), keyEquivalent: ""))
        menu.addItem(actionItem(title: "开始计时", action: #selector(startTimerAction), keyEquivalent: ""))
        menu.addItem(actionItem(title: "查看计时", action: #selector(showTimersAction), keyEquivalent: ""))
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
            if flags.contains(.command), let key {
                switch key {
                case "q":
                    NSApp.terminate(nil)
                    return nil
                case "t":
                    self.startChat()
                    return nil
                case "n":
                    self.nextState()
                    return nil
                case "m":
                    self.moveToBottomRight()
                    return nil
                case "s":
                    self.toggleWatchAction()
                    return nil
                case "r":
                    self.rememberPreference()
                    return nil
                case "p":
                    self.setPersonality()
                    return nil
                case "l":
                    self.showMemory()
                    return nil
                case "i":
                    self.startReminder()
                    return nil
                default:
                    break
                }
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

    @objc private func rememberAction() {
        rememberPreference()
    }

    @objc private func personalityAction() {
        setPersonality()
    }

    @objc private func showPersonalityAction() {
        showPersonality()
    }

    @objc private func clearPersonalityAction() {
        confirmAndClearPersonality()
    }

    @objc private func showMemoryAction() {
        showMemory()
    }

    @objc private func clearMemoryAction() {
        confirmAndClearMemory()
    }

    @objc private func startTimerAction() {
        startReminder()
    }

    @objc private func showTimersAction() {
        showTimers()
    }

    @objc private func clearTimersAction() {
        confirmAndClearTimers()
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }

    @objc private func systemDidWake(_ notification: Notification) {
        checkDueReminders()
    }

    private func loadAssets() -> Bool {
        guard let assetsURL = Bundle.main.resourceURL?.appendingPathComponent("assets", isDirectory: true) else {
            assetURLs = []
            return true
        }
        do {
            assetURLs = try FileManager.default.contentsOfDirectory(
                at: assetsURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            .filter { $0.pathExtension.lowercased() == "gif" }
            .sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }
        } catch {
            assetURLs = []
        }
        return true
    }

    private func nextState() {
        _ = loadAssets()
        guard !assetURLs.isEmpty else { return }
        stateIndex = (stateIndex + 1) % assetURLs.count
        showState(index: stateIndex)
    }

    private func showState(index: Int) {
        guard !assetURLs.isEmpty else {
            showPlaceholderBear()
            return
        }
        let startIndex = ((index % assetURLs.count) + assetURLs.count) % assetURLs.count
        var loadedImage: NSImage?
        var loadedIndex = startIndex
        var failedName = ""
        for offset in 0..<assetURLs.count {
            let candidateIndex = (startIndex + offset) % assetURLs.count
            let url = assetURLs[candidateIndex]
            if let image = NSImage(contentsOf: url), image.size.width > 0, image.size.height > 0 {
                loadedImage = image
                loadedIndex = candidateIndex
                break
            }
            failedName = url.lastPathComponent
        }
        guard let image = loadedImage else {
            showAlert(title: "熊的 GIF 读不出来", text: "assets 里的 GIF 都读不出来。最后尝试的是：\(failedName)")
            return
        }

        imageView.image = image
        imageView.animates = true
        stateIndex = loadedIndex
        let maxSide: CGFloat = 170
        let ratio = min(maxSide / image.size.width, maxSide / image.size.height, 1)
        let width = max(70, floor(image.size.width * ratio))
        let height = max(70, floor(image.size.height * ratio))
        window.setContentSize(NSSize(width: width, height: height))
        showPetWindowWithoutFocus()
    }

    private func moveToBottomRight() {
        guard let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else { return }
        let margin: CGFloat = 24
        let frame = window.frame
        window.setFrameOrigin(NSPoint(x: screenFrame.maxX - frame.width - margin, y: screenFrame.minY + margin))
    }

    private func showPlaceholderBear() {
        let size = NSSize(width: 170, height: 170)
        window.setContentSize(size)
        let view = NSView(frame: NSRect(origin: .zero, size: size))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor(calibratedRed: 0.545, green: 0.412, blue: 0.078, alpha: 0.15).cgColor
        view.layer?.cornerRadius = 20

        let label = NSTextField(labelWithString: "熊\n请把你的 GIF\n放进 assets 文件夹")
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 14)
        label.textColor = NSColor(calibratedRed: 0.545, green: 0.412, blue: 0.078, alpha: 1.0)
        label.frame = NSRect(x: 10, y: 30, width: 150, height: 110)
        view.addSubview(label)

        imageView.image = nil
        imageView.animates = false
        window.contentView = view
        moveToBottomRight()
        showPetWindowWithoutFocus()
    }

    private func startChat() {
        continueChat(history: [])
    }

    private func continueChat(history: [[String: String]]) {
        guard let question = prompt(title: "熊", message: "你好你好，有什么可以帮您") else {
            showPetWindowWithoutFocus()
            return
        }
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showPetWindowWithoutFocus()
            return
        }
        if isTimeQuestion(trimmed) {
            let wantsMore = showAnswerAndAskToContinue(title: "熊说：", text: localTimeAnswer())
            if wantsMore {
                continueChat(history: history)
            } else {
                showPetWindowWithoutFocus()
            }
            return
        }
        guard let key = ensureAPIKey() else {
            showState(index: 0)
            return
        }
        nextState()
        sendDeepSeek(apiKey: key, question: trimmed, history: history) { [weak self] answer, failure in
            guard let self else { return }
            if let failure {
                if self.isAuthError(failure) {
                    self.clearInvalidKeyAndRetry(question: trimmed, history: history)
                } else {
                    self.showAlert(title: "熊说不出来", text: failure)
                    self.showPetWindowWithoutFocus()
                }
                return
            }
            let answerText = answer ?? "熊短暂离线。"
            let updatedHistory = self.updatedChatHistory(history, user: trimmed, assistant: answerText)
            let wantsMore = self.showAnswerAndAskToContinue(title: "熊说：", text: answerText)
            if wantsMore {
                self.continueChat(history: updatedHistory)
            } else {
                self.showPetWindowWithoutFocus()
            }
        }
    }

    private func rememberPreference() {
        guard let text = prompt(title: "熊记一下", message: "写一条你的偏好或要求。比如：回答短一点、提醒我喝水。") else {
            return
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.addMemory(trimmed)
        showBubble("记住了，熊的小本本+1。")
    }

    private func setPersonality() {
        let current = store.data.personality.trimmingCharacters(in: .whitespacesAndNewlines)
        let hint: String
        if current.isEmpty {
            hint = "写一段熊的人设/语气。比如：懒懒的，一针见血，但不要刻薄。"
        } else {
            hint = "当前性格：\(current)\n\n写新的性格；留空就不改。"
        }
        guard let text = prompt(title: "熊的性格", message: hint) else {
            return
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.setPersonality(trimmed)
        showBubble("性格改好了，熊会照着演。")
    }

    private func showPersonality() {
        let personality = store.data.personality.trimmingCharacters(in: .whitespacesAndNewlines)
        if personality.isEmpty {
            showAlert(title: "熊的性格", text: "还没有自定义性格。熊先按默认懒懒版本活着。")
        } else {
            showAlert(title: "熊的性格", text: personality)
        }
    }

    private func confirmAndClearPersonality() {
        guard confirm(title: "清空性格？", text: "熊会回到默认懒懒版本。") else { return }
        store.clearPersonality()
        showBubble("性格清空了，熊回默认档。")
    }

    private func showMemory() {
        let memoryText: String
        if store.data.memories.isEmpty {
            memoryText = "还没有记忆。熊脑袋空空，但很轻。"
        } else {
            memoryText = store.data.memories.enumerated()
                .map { "\($0.offset + 1). \($0.element)" }
                .joined(separator: "\n")
        }
        showAlert(title: "熊的记忆", text: memoryText)
    }

    private func confirmAndClearMemory() {
        guard confirm(title: "清空记忆？", text: "熊会忘掉已记录的偏好。") else { return }
        store.clearMemories()
        showBubble("记忆清空了，熊重新开机。")
    }

    private func startReminder() {
        guard let title = prompt(title: "熊计时", message: "要提醒什么？比如：喝水、休息、看锅。") else {
            return
        }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        guard let minutesText = prompt(title: "熊计时", message: "几分钟后提醒？只填数字，比如 25。") else {
            return
        }
        let normalized = minutesText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "，", with: ".")
        guard let minutes = Double(normalized), minutes > 0 else {
            showAlert(title: "熊没看懂", text: "分钟数填数字就好。比如 10 或 25。")
            return
        }

        let reminder = BearReminder(
            id: UUID(),
            title: trimmedTitle,
            fireDate: Date().addingTimeInterval(minutes * 60)
        )
        store.addReminder(reminder)
        scheduleReminder(reminder)
        showBubble("好，\(friendlyMinutes(minutes))后叫你。")
    }

    private func showTimers() {
        let now = Date()
        let active = store.data.reminders
            .filter { $0.fireDate > now }
            .sorted { $0.fireDate < $1.fireDate }

        guard !active.isEmpty else {
            showAlert(title: "熊的计时", text: "现在没有计时。熊也没被安排。")
            return
        }

        let text = active.map { reminder in
            let remaining = max(1, Int(ceil(reminder.fireDate.timeIntervalSince(now) / 60)))
            return "- \(reminder.title)：约 \(remaining) 分钟后"
        }.joined(separator: "\n")
        showAlert(title: "熊的计时", text: text)
    }

    private func confirmAndClearTimers() {
        guard confirm(title: "清空计时？", text: "熊会取消所有还没到点的提醒。") else { return }
        reminderTimers.values.forEach { $0.invalidate() }
        reminderTimers.removeAll()
        store.clearReminders()
        showBubble("计时都撤了，熊继续躺。")
    }

    private func scheduleStoredReminders() {
        let now = Date()
        for reminder in store.data.reminders {
            if reminder.fireDate <= now {
                fireReminder(reminder)
            } else {
                scheduleReminder(reminder)
            }
        }
    }

    private func startReminderSweep() {
        reminderSweepTimer?.invalidate()
        let sweep = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            self?.checkDueReminders()
        }
        reminderSweepTimer = sweep
        RunLoop.main.add(sweep, forMode: .common)
    }

    private func checkDueReminders() {
        let now = Date()
        let dueReminders = store.data.reminders
            .filter { $0.fireDate <= now }
            .sorted { $0.fireDate < $1.fireDate }
        for reminder in dueReminders {
            fireReminder(reminder)
        }
        showPetWindowWithoutFocus()
    }

    private func scheduleReminder(_ reminder: BearReminder) {
        reminderTimers[reminder.id]?.invalidate()
        let interval = max(0.1, reminder.fireDate.timeIntervalSinceNow)
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            self?.fireReminder(reminder)
        }
        reminderTimers[reminder.id] = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func fireReminder(_ reminder: BearReminder) {
        reminderTimers[reminder.id]?.invalidate()
        reminderTimers[reminder.id] = nil
        store.removeReminder(id: reminder.id)
        nextState()
        showAlert(title: "熊提醒你", text: "\(reminder.title)，到点了。")
    }

    private func startWatchingScreen() {
        guard ensureAPIKey() != nil else {
            showState(index: 0)
            return
        }
        guard ensureScreenCaptureAccess() else {
            return
        }
        isWatchingScreen = true
        showBubble("开始瞄屏幕了，懒懒地两分钟看一眼。")
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
        captureScreenText { [weak self] screenText, failure in
            guard let self else { return }
            if let failure {
                self.isCommentingOnScreen = false
                self.showBubble(failure)
                return
            }
            let visibleText = screenText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !visibleText.isEmpty else {
                self.isCommentingOnScreen = false
                self.showBubble("屏幕太安静了，熊也继续躺。")
                return
            }
            let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "未知程序"
            let excerpt = String(visibleText.prefix(900))
            let question = """
            你是桌面宠物熊，正在主动和用户互动。你会看到一些屏幕 OCR 文字，但不要复述隐私、账号、论文原文或文件名。
            当前前台应用：\(appName)
            屏幕文字片段：
            \(excerpt)

            请只用中文回复一句，总长度尽量不超过45字。语气懒懒的、可爱、一针见血。不要以固定问候开头，不要说“我看到你的屏幕”。
            """
            self.askDeepSeekForBubble(apiKey: key, question: question)
        }
    }

    private func captureScreenText(completion: @escaping (String, String?) -> Void) {
        guard CGPreflightScreenCaptureAccess() else {
            completion("", "熊还没有屏幕录制权限。去系统设置里给熊权限，然后重开熊。")
            return
        }
        captureScreenImage { [weak self] image, failure in
            guard let self else { return }
            guard let image else {
                completion("", failure ?? "熊截不到屏幕。请退出熊，重新打开；如果还不行，把系统设置里的屏幕录制权限取消再重新勾上。")
                return
            }
            self.recognizeScreenText(in: image, completion: completion)
        }
    }

    private func captureScreenImage(completion: @escaping (CGImage?, String?) -> Void) {
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in
            if let error {
                DispatchQueue.main.async {
                    completion(nil, "熊找不到可截图的屏幕：\(error.localizedDescription)")
                }
                return
            }
            guard let display = content?.displays.first else {
                DispatchQueue.main.async {
                    completion(nil, "熊没找到可截图的显示器。")
                }
                return
            }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = display.width
            config.height = display.height
            config.showsCursor = false
            SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) { image, error in
                DispatchQueue.main.async {
                    if let image {
                        completion(image, nil)
                    } else {
                        completion(nil, "熊截不到屏幕：\(error?.localizedDescription ?? "未知原因")")
                    }
                }
            }
        }
    }

    private func recognizeScreenText(in image: CGImage, completion: @escaping (String, String?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                DispatchQueue.main.async {
                    completion(text, nil)
                }
            }
            request.recognitionLevel = .fast
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    completion("", "熊截图成功了，但读屏幕文字失败：\(error.localizedDescription)")
                }
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
        guard let key = prompt(title: "DeepSeek API Key", message: "第一次聊天需要输入 key，熊会放进钥匙串。可直接粘贴 (⌘V)。", secure: true),
              !key.isEmpty else {
            return nil
        }
        apiKey = key
        saveKeyToKeychain(key)
        return key
    }

    private func askDeepSeek(apiKey: String, question: String) {
        nextState()
        sendDeepSeek(apiKey: apiKey, question: question, history: []) { [weak self] answer, failure in
            guard let self else { return }
            if let failure {
                if self.isAuthError(failure) {
                    self.clearInvalidKeyAndRetry(question: question, history: [])
                } else {
                    self.showAlert(title: "熊说不出来", text: failure)
                }
                return
            }
            self.showAlert(title: "熊说：", text: answer ?? "熊短暂离线。")
        }
    }

    private func askDeepSeekForBubble(apiKey: String, question: String) {
        nextState()
        sendDeepSeek(apiKey: apiKey, question: question, history: []) { [weak self] answer, failure in
            guard let self else { return }
            self.isCommentingOnScreen = false
            if let failure {
                if self.isAuthError(failure) {
                    self.showBubble("API Key 无效，熊已经忘了旧的。")
                    self.stopWatchingScreen()
                } else {
                    self.showBubble("刚刚说不出来：\(failure)")
                }
                return
            }
            self.showBubble(answer ?? "熊短暂离线。")
        }
    }

    private func sendDeepSeek(apiKey: String, question: String, history: [[String: String]], completion: @escaping (String?, String?) -> Void) {
        var messages = [["role": "system", "content": systemPromptWithMemory()]]
        messages.append(contentsOf: history.suffix(20))
        messages.append(["role": "user", "content": question])

        var request = URLRequest(url: deepSeekURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "model": "deepseek-chat",
            "messages": messages,
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

    private func systemPromptWithMemory() -> String {
        let personality = store.data.personality.trimmingCharacters(in: .whitespacesAndNewlines)
        let basePrompt = """
        \(systemPrompt)

        当前本机时间：
        \(localDateTimeText())
        如果用户询问时间、日期、星期或计时相关问题，必须以这个本机时间为准，不要猜测。
        """
        guard !store.data.memories.isEmpty || !personality.isEmpty else {
            return basePrompt
        }
        let memory: String
        if store.data.memories.isEmpty {
            memory = "暂无"
        } else {
            memory = store.data.memories.suffix(20).map { "- \($0)" }.joined(separator: "\n")
        }
        let personalityText = personality.isEmpty ? "使用默认性格。" : personality
        return """
        \(basePrompt)

        用户自定义熊性格：
        \(personalityText)

        用户偏好记忆：
        \(memory)

        自定义性格优先于默认性格，但必须保留名字叫熊、回答简短、不要机械重复问候这几条底线。
        回答时自然遵守这些偏好；不要逐条复述“我记得”。
        """
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
        bubble.orderFrontRegardless()

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
        activateForModal()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.addButton(withTitle: "算了")

        let field: NSTextField
        if secure && !title.lowercased().contains("api key") {
            field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        } else {
            field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        }
        field.isSelectable = true
        field.isEditable = true
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        let result = alert.runModal()
        return result == .alertFirstButtonReturn ? field.stringValue : nil
    }

    private func confirm(title: String, text: String) -> Bool {
        activateForModal()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.addButton(withTitle: "清空")
        alert.addButton(withTitle: "算了")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func friendlyMinutes(_ minutes: Double) -> String {
        if minutes.rounded() == minutes {
            return "\(Int(minutes)) 分钟"
        }
        return String(format: "%.1f 分钟", minutes)
    }

    private func localDateTimeText() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy年M月d日 EEEE HH:mm:ss zzz"
        return formatter.string(from: Date())
    }

    private func localTimeAnswer() -> String {
        "现在是 \(localDateTimeText())。熊看的是你电脑时间，没瞎猜。"
    }

    private func isTimeQuestion(_ text: String) -> Bool {
        let normalized = text
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "？", with: "?")
        let patterns = [
            "几点",
            "几号",
            "星期几",
            "礼拜几",
            "日期",
            "现在时间",
            "当前时间",
            "当地时间",
            "现在是几",
            "今天几",
            "今天星期",
            "今天礼拜",
            "today",
            "date",
            "time",
            "whatday",
            "whattime",
        ]
        return patterns.contains { normalized.contains($0) }
    }

    private func showAlert(title: String, text: String) {
        activateForModal()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    private func showAnswerAndAskToContinue(title: String, text: String) -> Bool {
        activateForModal()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.addButton(withTitle: "继续聊")
        alert.addButton(withTitle: "关掉")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func updatedChatHistory(_ history: [[String: String]], user: String, assistant: String) -> [[String: String]] {
        let next = history + [
            ["role": "user", "content": user],
            ["role": "assistant", "content": assistant],
        ]
        return Array(next.suffix(20))
    }

    private func activateForModal() {
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showPetWindowWithoutFocus() {
        guard NSApp.modalWindow == nil else { return }
        window.orderFrontRegardless()
    }

    private func isAuthError(_ failure: String) -> Bool {
        let lower = failure.lowercased()
        return lower.contains("authentication") || lower.contains("invalid")
            || lower.contains("401") || lower.contains("api key")
    }

    private func clearInvalidKeyAndRetry(question: String, history: [[String: String]]) {
        apiKey = nil
        _ = runSecurity(["delete-generic-password", "-a", keychainAccount, "-s", keychainService])
        guard let newKey = prompt(title: "DeepSeek API Key", message: "旧的 Key 已失效。请输入新 Key，熊会重新记下来。", secure: true),
              !newKey.isEmpty else {
            showState(index: 0)
            return
        }
        apiKey = newKey
        saveKeyToKeychain(newKey)
        sendDeepSeek(apiKey: newKey, question: question, history: history) { [weak self] answer, failure in
            guard let self else { return }
            if let failure {
                self.showAlert(title: "熊说不出来", text: failure)
                self.showPetWindowWithoutFocus()
                return
            }
            let answerText = answer ?? "熊短暂离线。"
            let updatedHistory = self.updatedChatHistory(history, user: question, assistant: answerText)
            let wantsMore = self.showAnswerAndAskToContinue(title: "熊说：", text: answerText)
            if wantsMore {
                self.continueChat(history: updatedHistory)
            } else {
                self.showPetWindowWithoutFocus()
            }
        }
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

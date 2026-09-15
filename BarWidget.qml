pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Omarchy bar inbox for Tether by Zack Bartel — https://github.com/zackb/tether
BarWidget {
  id: root
  moduleName: "io.github.charleschao.omamessage"

  property bool daemonOk: false
  property int reconnectAttempt: 0
  property var status: ({ present: false, paired: false, map: false, pbap: false, classic: false, le: false, ancs: false, mapError: "", note: "", linkReason: "", profileReason: "", ancsReason: "" })
  property var devices: []
  property var threads: []
  property var messages: []
  property var contacts: []
  property var calls: []
  property var notifications: []
  property var drafts: Model.emptyDict()
  property var markedRead: Model.emptyDict()
  property string sockBuf: ""
  property string pendingCopy: ""
  property string contactQuery: ""
  property string page: "inbox"
  property string tab: "messages"
  property var selectedThread: null
  property string replyDraft: ""
  property string composeTo: ""
  property string composeBody: ""
  property bool sending: false
  property bool sendFailed: false
  property bool messagesLoading: false
  property string pendingBody: ""
  property string pendingThread: ""
  property var readWatermarks: Model.emptyDict()
  property var markAllQueue: []
  property string actionNote: ""

  readonly property string socketPath: {
    var runtime = Quickshell.env("XDG_RUNTIME_DIR")
    if (!runtime) return ""
    return String(runtime) + "/tether/tetherd.sock"
  }
  readonly property bool socketUp: !!(socketLoader.item && socketLoader.item.connected)
  readonly property bool mapUp: status && status.map === true
  readonly property bool ancsUp: status && status.ancs === true
  readonly property int unreadCount: Model.unreadTotal(threads)
  readonly property int noticeCount: Model.noticeCount(notifications)
  readonly property var ringingCall: Model.liveCall(calls)
  readonly property string displayText: Model.barLabel(root.unreadCount, root.mapUp, root.daemonOk, root.noticeCount, root.ancsUp, !!root.ringingCall)
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function setNote(msg) {
    root.actionNote = Model.neutralizeUi(msg)
  }

  function sendCmd(obj) {
    var sock = socketLoader.item
    if (!sock || !sock.connected) return false
    var line = JSON.stringify(obj)
    if (Model.utf8Len(line) > Model.MAX_JSON) return false
    sock.write(line + "\n")
    sock.flush()
    return true
  }

  function dropSocket() {
    root.sockBuf = ""
    var sock = socketLoader.item
    if (sock) sock.connected = false
  }

  function handleChunk(chunk) {
    var r = Model.takeSocketLines(root.sockBuf, chunk, Model.MAX_JSON)
    root.sockBuf = r.buf
    var lines = r.lines || []
    var i
    for (i = 0; i < lines.length; i++) root.handleLine(lines[i])
    if (r.overflow) root.dropSocket()
  }

  function pullState() {
    root.sendCmd({ command: "bt_connection" })
    root.sendCmd({ command: "bt_list_devices" })
    root.sendCmd({ command: "bt_list_threads" })
    root.sendCmd({ command: "bt_list_calls" })
    root.sendCmd({ command: "bt_list_notifications" })
  }

  function onSocketUp() {
    root.daemonOk = true
    root.reconnectAttempt = 0
    root.sendCmd({ command: "subscribe" })
    root.pullState()
  }

  function onSocketDown() {
    root.daemonOk = false
    root.sockBuf = ""
    sendWatchdog.stop()
    if (root.sending) root.failSend("Tether is not running.")
    else {
      root.sending = false
      root.pendingBody = ""
      root.pendingThread = ""
    }
  }

  function failSend(reason) {
    root.sending = false
    sendWatchdog.stop()
    if (root.pendingBody)
      root.messages = Model.dropLocalOutgoing(root.messages, root.pendingBody)
    if (root.pendingBody && !String(root.replyDraft || "") && !String(root.composeBody || "")) {
      if (root.page === "compose") root.composeBody = root.pendingBody
      else root.replyDraft = root.pendingBody
    }
    root.sendFailed = true
    root.pendingBody = ""
    root.pendingThread = ""
    root.setNote(reason || "The message was not sent.")
  }

  function handleLine(line) {
    var ev = Model.parseEvent(line)
    if (!ev) return
    var cmd = ev.command
    if (cmd === "bt_connection_changed") {
      root.daemonOk = true
      root.status = Model.parseConnection(ev)
      return
    }
    if (cmd === "bt_threads") {
      root.threads = Model.applyReadWatermarks(Model.parseThreads(ev), root.readWatermarks)
      if (root.selectedThread) {
        var listed = Model.threadByHandle(root.threads, root.selectedThread.handle)
        if (listed) root.selectedThread = Model.mergeSelectedThread(root.selectedThread, listed)
      }
      return
    }
    if (cmd === "bt_messages") {
      var key = String(ev.thread || "")
      var msgs = Model.parseMessages(ev)
      var queue = root.markAllQueue || []
      if (queue.length) root.markRead(msgs)
      if (root.selectedThread && Model.sameThread(root.selectedThread.handle, key)) {
        root.adoptThreadKey(key)
        root.messages = Model.mergeMessages(msgs, root.messages, key)
        root.messagesLoading = false
        if (!queue.length) root.markRead(root.messages)
      }
      if (queue.length && Model.sameThread(queue[0], key)) {
        var rest = []
        var i
        for (i = 1; i < queue.length; i++) rest.push(queue[i])
        root.markAllQueue = rest
        root.pumpMarkAll()
      }
      return
    }
    if (cmd === "bt_contacts") {
      root.contacts = Model.parseContacts(ev)
      return
    }
    if (cmd === "bt_devices") {
      root.devices = Model.parseDevices(ev)
      return
    }
    if (cmd === "bt_calls") {
      root.calls = Model.parseCalls(ev)
      return
    }
    if (cmd === "bt_notifications") {
      root.notifications = Model.parseNotifications(ev)
      return
    }
    if (cmd === "bt_notification" || cmd === "bt_notification_removed") {
      root.sendCmd({ command: "bt_list_notifications" })
      return
    }
    if (cmd === "bt_notification_action_result") {
      if (ev.success !== true)
        root.setNote(ev.message || "The iPhone would not take the dismissal.")
      root.sendCmd({ command: "bt_list_notifications" })
      return
    }
    if (cmd === "bt_message") {
      root.sendCmd({ command: "bt_list_threads" })
      if (root.selectedThread && Model.sameThread(ev.thread, root.selectedThread.handle)) {
        root.adoptThreadKey(ev.thread)
        root.loadMessages(root.selectedThread.handle)
      }
      return
    }
    if (cmd === "bt_send_result") {
      if (ev.success === true) {
        root.sending = false
        sendWatchdog.stop()
        root.sendFailed = false
        if (root.replyDraft === root.pendingBody) root.replyDraft = ""
        if (root.composeBody === root.pendingBody) root.composeBody = ""
        if (root.pendingBody)
          root.messages = Model.setOutgoingFlags(root.messages, root.pendingBody, false, false)
        root.pendingBody = ""
        root.pendingThread = ""
        root.sendCmd({ command: "bt_list_threads" })
      } else {
        root.failSend(ev.message || "The message was not sent.")
      }
      return
    }
    if (cmd === "bt_message_read") {
      root.sendCmd({ command: "bt_list_threads" })
      return
    }
    if (cmd === "bt_solicit_result") {
      root.setNote(ev.message || "Asked the iPhone to show its Bluetooth permissions.")
      return
    }
    if (cmd === "bt_call_result") {
      if (ev.success !== true)
        root.setNote(ev.message || "The call could not be placed.")
      root.sendCmd({ command: "bt_list_calls" })
    }
  }

  function open() {
    if (panelLoader.item) panelLoader.item.open()
    root.pullState()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
    if (!root.opened) root.pullState()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function refresh() {
    root.pullState()
  }

  function openApp() {
    Quickshell.execDetached(["/usr/bin/uwsm-app", "--", "tether-gtk"])
  }

  function backToList() {
    if (root.page === "thread" && root.selectedThread)
      root.stashDraft(root.selectedThread.handle, root.replyDraft)
    root.page = "inbox"
    root.selectedThread = null
    root.messages = []
    root.messagesLoading = false
    root.sendFailed = false
    root.replyDraft = ""
    root.composeTo = ""
    root.composeBody = ""
    root.contacts = []
    root.actionNote = ""
  }

  function showInbox() {
    root.tab = "messages"
    root.backToList()
  }

  function showNotifications() {
    root.tab = "notifications"
    root.backToList()
    root.sendCmd({ command: "bt_list_notifications" })
    if (panelLoader.item && !root.opened) panelLoader.item.open()
  }

  function setTab(name) {
    var t = String(name || "")
    if (t !== "messages" && t !== "notifications") return
    if (root.page !== "inbox") root.backToList()
    root.tab = t
    root.actionNote = ""
    if (t === "notifications")
      root.sendCmd({ command: "bt_list_notifications" })
  }

  function showCompose() {
    root.tab = "messages"
    root.stashDraft(root.selectedThread ? root.selectedThread.handle : "", root.replyDraft)
    root.page = "compose"
    root.selectedThread = null
    root.messages = []
    root.messagesLoading = false
    root.sendFailed = false
    root.replyDraft = ""
    root.composeTo = ""
    root.composeBody = ""
    root.actionNote = ""
    root.searchContacts("")
    if (panelLoader.item && !root.opened) panelLoader.item.open()
  }

  function stashDraft(handle, text) {
    if (!handle) return
    root.drafts = Model.putDraft(root.drafts, handle, text)
  }

  function adoptThreadKey(key) {
    var k = String(key || "")
    if (!k || !root.selectedThread) return
    if (root.selectedThread.handle === k) return
    if (!Model.sameThread(root.selectedThread.handle, k)) return
    root.selectedThread = Model.mergeSelectedThread(root.selectedThread, Model.copyThread(root.selectedThread, { handle: k }))
  }

  function openThread(thread) {
    if (!thread || !thread.handle) return
    if (root.page === "thread" && root.selectedThread)
      root.stashDraft(root.selectedThread.handle, root.replyDraft)
    var same = root.selectedThread && Model.sameThread(root.selectedThread.handle, thread.handle)
    root.selectedThread = thread
    root.page = "thread"
    root.replyDraft = Model.getDraft(root.drafts, thread.handle)
    root.actionNote = ""
    root.sendFailed = false
    root.readWatermarks = Model.markReadAt(root.readWatermarks, thread.handle, thread.timestamp)
    root.threads = Model.applyReadWatermarks(Model.zeroUnread(root.threads, thread.handle), root.readWatermarks)
    if (!same) {
      root.messages = []
      root.messagesLoading = true
    }
    root.loadMessages(thread.handle)
    if (panelLoader.item && !root.opened) panelLoader.item.open()
  }

  function loadMessages(handle) {
    if (!handle) {
      root.messages = []
      root.messagesLoading = false
      return
    }
    root.sendCmd({ command: "bt_list_messages", thread: handle })
  }

  function markRead(msgs) {
    var handles = Model.unreadHandles(msgs)
    var pending = []
    var seen = Model.emptyDict()
    var old = root.markedRead || Model.emptyDict()
    for (var k in old) seen[k] = old[k]
    for (var i = 0; i < handles.length; i++) {
      if (seen[handles[i]]) continue
      pending.push(handles[i])
    }
    if (!pending.length) return
    // tetherd accepts one MAP message handle per bt_mark_read command. Sending
    // an array under "handles" is silently ignored by the daemon, leaving the
    // phone's unread state unchanged.
    for (i = 0; i < pending.length; i++) {
      if (!root.sendCmd({ command: "bt_mark_read", handle: pending[i], read: true }))
        break
      seen[pending[i]] = true
    }
    root.markedRead = seen
  }

  function markAllRead() {
    if (!root.mapUp) {
      root.setNote("Tether is not running.")
      return
    }
    var queue = Model.unreadThreadHandles(root.threads)
    var now = Date.now() / 1000
    var i
    for (i = 0; i < queue.length; i++)
      root.readWatermarks = Model.markReadAt(root.readWatermarks, queue[i], now)
    root.threads = Model.applyReadWatermarks(Model.zeroAllUnread(root.threads), root.readWatermarks)
    root.markRead(root.messages)
    if (!queue.length) {
      root.setNote("No unread messages.")
      return
    }
    root.markAllQueue = queue
    root.pumpMarkAll()
  }

  function pumpMarkAll() {
    var q = root.markAllQueue || []
    if (!q.length) return
    root.sendCmd({ command: "bt_list_messages", thread: q[0] })
  }

  function sendTo(handle, text) {
    var h = Model.normalizeHandle(handle)
    var t = String(text || "").replace(/^\s+|\s+$/g, "")
    if (!h) {
      root.setNote("Need a name or number.")
      return false
    }
    if (!t) {
      root.setNote("Type a message.")
      return false
    }
    if (t.length > Model.MAX_BODY) {
      root.setNote("Message is too long.")
      return false
    }
    if (root.sending) {
      root.setNote("Still sending the previous message.")
      return false
    }
    if (!root.sendCmd({ command: "bt_send_message", thread: h, body: t })) {
      root.setNote("Tether is not running.")
      return false
    }
    var now = Date.now() / 1000
    root.pendingBody = t
    root.pendingThread = h
    root.sending = true
    root.sendFailed = false
    root.actionNote = ""
    if (root.selectedThread && Model.sameThread(root.selectedThread.handle, h))
      root.messages = Model.appendOutgoing(root.messages, root.selectedThread.handle, t, now)
    root.threads = Model.patchThread(root.threads, h, t, now)
    root.readWatermarks = Model.markReadAt(root.readWatermarks, h, now)
    sendWatchdog.restart()
    return true
  }

  function sendReply() {
    if (!root.selectedThread) return false
    return root.sendTo(root.selectedThread.handle, root.replyDraft)
  }

  function sendNew() {
    var h = Model.normalizeHandle(root.composeTo)
    var body = root.composeBody
    if (!root.sendTo(h, body)) return false
    var match = Model.threadByHandle(root.threads, h)
    if (match) {
      root.openThread(match)
    } else {
      root.openThread({
        handle: h,
        name: root.composeTo.replace(/^\s+|\s+$/g, "") || h,
        address: h,
        preview: "",
        timestamp: 0,
        unread: 0,
        count: 0,
        group: false,
        repliable: true,
        replyReason: ""
      })
    }
    root.messages = Model.appendOutgoing(root.messages, h, root.pendingBody, Date.now() / 1000)
    root.messagesLoading = root.messages.length === 0
    root.threads = Model.patchThread(root.threads, h, root.pendingBody, Date.now() / 1000)
    return true
  }

  function retrySend() {
    if (root.page === "compose") return root.sendNew()
    return root.sendReply()
  }

  function searchContacts(q) {
    var s = String(q || "")
    if (s.length > Model.MAX_NAME) s = s.slice(0, Model.MAX_NAME)
    root.contactQuery = s
    contactTimer.restart()
  }

  function loadContacts() {
    root.sendCmd({ command: "bt_list_contacts", query: root.contactQuery })
  }

  function openContactHandle(c, handle) {
    var h = Model.normalizeHandle(handle)
    if (!h) {
      root.setNote("No phone or email for that contact.")
      return
    }
    var match = Model.threadByHandle(root.threads, h)
    if (match) {
      root.openThread(match)
      return
    }
    root.composeTo = h
    root.openThread({
      handle: h,
      name: (c && c.name) || h,
      address: h,
      preview: "",
      timestamp: 0,
      unread: 0,
      count: 0,
      group: false,
      repliable: true,
      replyReason: ""
    })
  }

  function solicit() {
    if (!root.sendCmd({ command: "bt_solicit" }))
      root.setNote("Tether is not running.")
  }

  function dismissNotice(notice) {
    if (!notice || notice.uid == null) return
    if (!notice.negative) {
      root.setNote("That notification cannot be dismissed from here.")
      return
    }
    if (!root.sendCmd({ command: "bt_notification_action", uid: notice.uid, action: "negative" })) {
      root.setNote("Tether is not running.")
      return
    }
    root.notifications = Model.dropNotice(root.notifications, notice.uid)
  }

  function dismissAllNotices() {
    var list = root.notifications || []
    var remaining = list
    var dismissed = 0
    var i
    for (i = 0; i < list.length; i++) {
      var notice = list[i]
      if (!notice || !notice.negative || notice.uid == null) continue
      if (!root.sendCmd({ command: "bt_notification_action", uid: notice.uid, action: "negative" })) {
        root.setNote(dismissed ? "Stopped after dismissing " + dismissed + " notifications." : "Tether is not running.")
        break
      }
      remaining = Model.dropNotice(remaining, notice.uid)
      dismissed += 1
    }
    if (!dismissed) {
      root.setNote("No notifications can be dismissed from here.")
      return
    }
    root.notifications = remaining
    root.setNote("Dismissing " + dismissed + " notification" + (dismissed === 1 ? "." : "s."))
  }

  function activateNotice(notice) {
    if (!notice) return
    var match = Model.threadForNotice(root.threads, notice)
    if (match) {
      root.openThread(match)
      return
    }
    if (notice.webUrl) {
      Qt.openUrlExternally(notice.webUrl)
      return
    }
    if (notice.otp) {
      root.copyText(notice.otp)
      return
    }
    var blob = String(notice.primary || "")
    if (notice.secondary && notice.secondary !== blob) {
      if (blob) blob += "\n"
      blob += notice.secondary
    }
    if (blob) root.copyText(blob)
    if (blob) root.setNote("No complete web link in this notification; copied.")
    else root.setNote("No conversation or web link for that notification.")
  }

  function answerCall() {
    var c = root.ringingCall
    var msg = { command: "bt_call_action", action: "answer" }
    if (c && c.path) msg.path = c.path
    if (!root.sendCmd(msg))
      root.setNote("Tether is not running.")
  }

  function hangupCall() {
    var c = root.ringingCall
    var msg = { command: "bt_call_action", action: "hangup" }
    if (c && c.path) msg.path = c.path
    if (!root.sendCmd(msg))
      root.setNote("Tether is not running.")
  }

  function copyText(text) {
    var t = String(text || "")
    if (!t || t.length > Model.MAX_BODY) return
    root.pendingCopy = t
    clipWatchdog.stop()
    clipKill.stop()
    clipProc.running = false
    clipProc.stdinEnabled = true
    clipProc.running = true
    root.setNote("Copied.")
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  Component.onCompleted: {
    if (root.socketPath) socketLoader.active = true
    injectPanel()
  }

  Timer {
    id: contactTimer
    interval: 280
    repeat: false
    onTriggered: root.loadContacts()
  }

  Timer {
    id: sendWatchdog
    interval: 60000
    repeat: false
    onTriggered: root.failSend("Send timed out.")
  }

  Component {
    id: socketComponent
    Socket {
      path: root.socketPath
      connected: true
      parser: SplitParser {
        splitMarker: ""
        onRead: function(chunk) { root.handleChunk(chunk) }
      }
      onConnectionStateChanged: {
        if (connected) root.onSocketUp()
        else root.onSocketDown()
      }
    }
  }

  Loader {
    id: socketLoader
    active: false
    sourceComponent: socketComponent
  }

  Timer {
    id: reconnectTimer
    interval: 1500
    repeat: true
    running: !!root.socketPath && !root.socketUp
    onTriggered: {
      if (!root.socketPath) return
      root.reconnectAttempt = Math.min(12, root.reconnectAttempt + 1)
      socketLoader.active = false
      socketLoader.active = true
    }
  }

  Process {
    id: clipProc
    command: ["/usr/bin/wl-copy"]
    stdinEnabled: true
    onStarted: {
      write(root.pendingCopy)
      root.pendingCopy = ""
      stdinEnabled = false
      clipWatchdog.restart()
    }
    onExited: {
      clipWatchdog.stop()
      clipKill.stop()
      stdinEnabled = true
    }
  }

  Timer {
    id: clipWatchdog
    interval: 3000
    repeat: false
    onTriggered: {
      clipProc.signal(15)
      clipKill.restart()
    }
  }

  Timer {
    id: clipKill
    interval: 1000
    repeat: false
    onTriggered: clipProc.signal(9)
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "io.github.charleschao.omamessage"
    function refresh(): void { root.broadcast("refresh") }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function inbox(): void { root.showInbox() }
    function contacts(): void { root.showCompose() }
    function notifications(): void { root.showNotifications() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.displayText
    fontSize: Style.bar.iconFont
    tooltipText: {
      var status = Model.statusTitle(root.status, root.daemonOk)
      var bits = []
      if (root.ringingCall)
        bits.push(Model.callTitle(root.ringingCall) + " · " + Model.callParty(root.ringingCall))
      if (root.mapUp && root.unreadCount > 0)
        bits.push(root.unreadCount + " unread")
      if (root.ancsUp && root.noticeCount > 0)
        bits.push(root.noticeCount + " notifications")
      if (bits.length)
        return Model.neutralizeUi(bits.join(" · ") + " · " + status)
      return Model.neutralizeUi(status)
    }
    active: !!(root.ringingCall) || (root.mapUp && root.unreadCount > 0)
    dimmed: !root.mapUp && !root.ancsUp && !root.ringingCall
    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.openApp()
      else if (b === Qt.RightButton) {
        var unread = Model.firstUnreadThread(root.threads)
        if (unread) root.openThread(unread)
        else root.showInbox()
      } else root.togglePanel()
    }
  }
}

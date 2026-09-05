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
  property bool spawnAttempted: false
  property var status: ({ present: false, paired: false, map: false, pbap: false, classic: false, le: false, mapError: "", note: "", linkReason: "", profileReason: "" })
  property var devices: []
  property var threads: []
  property var messages: []
  property var contacts: []
  property var calls: []
  property var drafts: ({})
  property var markedRead: ({})
  property string contactQuery: ""
  property string page: "inbox"
  property var selectedThread: null
  property string replyDraft: ""
  property string composeTo: ""
  property string composeBody: ""
  property bool sending: false
  property string actionNote: ""

  readonly property string socketPath: {
    var runtime = Quickshell.env("XDG_RUNTIME_DIR")
    return String(runtime || "/tmp") + "/tether/tetherd.sock"
  }
  readonly property bool socketUp: !!(socketLoader.item && socketLoader.item.connected)
  readonly property bool mapUp: status && status.map === true
  readonly property int unreadCount: Model.unreadTotal(threads)
  readonly property var ringingCall: Model.liveCall(calls)
  readonly property string displayText: Model.barLabel(root.unreadCount, root.mapUp, root.daemonOk)
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function setNote(msg) {
    root.actionNote = Model.neutralizeUi(msg)
  }

  function sendCmd(obj) {
    var sock = socketLoader.item
    if (!sock || !sock.connected) return false
    sock.write(JSON.stringify(obj) + "\n")
    sock.flush()
    return true
  }

  function pullState() {
    root.sendCmd({ command: "bt_connection" })
    root.sendCmd({ command: "bt_list_devices" })
    root.sendCmd({ command: "bt_list_threads" })
    root.sendCmd({ command: "bt_list_calls" })
  }

  function onSocketUp() {
    root.daemonOk = true
    root.reconnectAttempt = 0
    root.sendCmd({ command: "subscribe" })
    root.pullState()
  }

  function onSocketDown() {
    root.daemonOk = false
    root.sending = false
    sendWatchdog.stop()
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
      root.threads = Model.parseThreads(ev)
      return
    }
    if (cmd === "bt_messages") {
      var key = String(ev.thread || "")
      if (!root.selectedThread || root.selectedThread.handle !== key) return
      var msgs = Model.parseMessages(ev)
      root.messages = msgs
      root.markRead(msgs)
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
    if (cmd === "bt_message") {
      root.sendCmd({ command: "bt_list_threads" })
      if (root.selectedThread && ev.thread === root.selectedThread.handle)
        root.loadMessages(root.selectedThread.handle)
      return
    }
    if (cmd === "bt_send_result") {
      root.sending = false
      sendWatchdog.stop()
      if (ev.success === true) {
        root.replyDraft = ""
        root.composeBody = ""
        if (root.selectedThread) root.loadMessages(root.selectedThread.handle)
        root.sendCmd({ command: "bt_list_threads" })
      } else {
        root.setNote(ev.message || "The message was not sent.")
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
    Quickshell.execDetached(["uwsm-app", "--", "tether-gtk"])
  }

  function showInbox() {
    if (root.page === "thread" && root.selectedThread)
      root.stashDraft(root.selectedThread.handle, root.replyDraft)
    root.page = "inbox"
    root.selectedThread = null
    root.messages = []
    root.replyDraft = ""
    root.composeTo = ""
    root.composeBody = ""
    root.contacts = []
    root.actionNote = ""
  }

  function showCompose() {
    root.stashDraft(root.selectedThread ? root.selectedThread.handle : "", root.replyDraft)
    root.page = "compose"
    root.selectedThread = null
    root.messages = []
    root.replyDraft = ""
    root.composeTo = ""
    root.composeBody = ""
    root.actionNote = ""
    root.searchContacts("")
    if (panelLoader.item && !root.opened) panelLoader.item.open()
  }

  function stashDraft(handle, text) {
    if (!handle) return
    var next = {}
    var old = root.drafts || {}
    for (var k in old) next[k] = old[k]
    var t = String(text || "")
    if (t) next[handle] = t
    else delete next[handle]
    root.drafts = next
  }

  function openThread(thread) {
    if (!thread || !thread.handle) return
    if (root.page === "thread" && root.selectedThread)
      root.stashDraft(root.selectedThread.handle, root.replyDraft)
    root.selectedThread = thread
    root.page = "thread"
    root.replyDraft = (root.drafts && root.drafts[thread.handle]) || ""
    root.actionNote = ""
    root.threads = Model.zeroUnread(root.threads, thread.handle)
    root.loadMessages(thread.handle)
    if (panelLoader.item && !root.opened) panelLoader.item.open()
  }

  function loadMessages(handle) {
    if (!handle) {
      root.messages = []
      return
    }
    root.sendCmd({ command: "bt_list_messages", thread: handle })
  }

  function markRead(msgs) {
    var handles = Model.unreadHandles(msgs)
    var pending = []
    var seen = {}
    var old = root.markedRead || {}
    for (var k in old) seen[k] = old[k]
    for (var i = 0; i < handles.length; i++) {
      if (seen[handles[i]]) continue
      pending.push(handles[i])
      seen[handles[i]] = true
    }
    if (!pending.length) return
    root.markedRead = seen
    root.sendCmd({ command: "bt_mark_read", handles: pending, read: true })
  }

  function sendTo(handle, text) {
    var h = Model.normalizeHandle(handle)
    var t = String(text || "").replace(/^\s+|\s+$/g, "")
    if (!h || !t) return false
    if (root.sending) {
      root.setNote("Still sending the previous message.")
      return false
    }
    if (!root.sendCmd({ command: "bt_send_message", thread: h, body: t })) {
      root.setNote("Tether is not running.")
      return false
    }
    root.sending = true
    sendWatchdog.restart()
    return true
  }

  function sendReply() {
    if (!root.selectedThread) return false
    return root.sendTo(root.selectedThread.handle, root.replyDraft)
  }

  function sendNew() {
    var h = Model.normalizeHandle(root.composeTo)
    if (!root.sendTo(h, root.composeBody)) return false
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
    return true
  }

  function searchContacts(q) {
    root.contactQuery = String(q || "")
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
    if (!t) return
    Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(t) + " | wl-copy"])
    root.setNote("Copied.")
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  Component.onCompleted: {
    socketLoader.active = true
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
    onTriggered: {
      root.sending = false
      root.setNote("Send timed out.")
    }
  }

  Component {
    id: socketComponent
    Socket {
      path: root.socketPath
      connected: true
      parser: SplitParser {
        splitMarker: "\n"
        onRead: function(line) { root.handleLine(line) }
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
    running: !root.socketUp
    onTriggered: {
      if (!root.spawnAttempted) {
        root.spawnAttempted = true
        Quickshell.execDetached(["tether", "--bt-connection"])
      }
      root.reconnectAttempt = Math.min(12, root.reconnectAttempt + 1)
      socketLoader.active = false
      socketLoader.active = true
    }
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
    function app(): void { root.openApp() }
    function inbox(): void { root.showInbox() }
    function settings(): void { root.openApp() }
    function contacts(): void { root.showCompose() }
    function calls(): void { root.open() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.displayText
    fontSize: Style.bar.iconFont
    tooltipText: {
      var status = Model.statusTitle(root.status, root.daemonOk)
      if (root.mapUp && root.unreadCount > 0)
        return Model.neutralizeUi(root.unreadCount + " unread · " + status)
      return Model.neutralizeUi(status)
    }
    active: root.mapUp && root.unreadCount > 0
    dimmed: !root.mapUp
    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.openApp()
      else if (b === Qt.RightButton) root.showInbox()
      else root.togglePanel()
    }
  }
}

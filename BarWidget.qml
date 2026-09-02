import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Omarchy bar widget for Tether by Zack Bartel — https://github.com/zackb/tether
BarWidget {
  id: root
  moduleName: "io.github.charleschao.omamessage"

  property var status: ({ present: false, map: false, pbap: false, ancs: false, bredr: false, le: false, note: "", raw: "" })
  property var devices: []
  property var threads: []
  property var notifications: []
  property var messages: []
  property bool cliOk: false
  property bool busy: false
  property int refreshStep: 0
  property string page: "inbox"
  property string tab: "messages"
  property var selectedThread: null
  property var selectedNotice: null
  property string replyDraft: ""
  property bool wifiUp: false
  property var lanDevices: []
  property var lanPeers: []
  property var pendingPair: null
  property string clipPreview: ""
  property string clipDraft: ""
  property string filePath: ""
  property var recentDownloads: []
  property var btFlags: ({ enabled: false, ancs: false, ancsContent: true })
  property var btStatus: ({ mode: "", bond: "", tether: "", classOk: false, raw: "" })
  property var btSetup: ({ complete: true, text: "" })
  property string acceptDraft: ""
  property string actionNote: ""

  readonly property string displayText: Model.barLabel(status)
  readonly property bool mapUp: status && status.map === true
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
    root.refresh()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
    if (!root.opened) root.refresh()
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

  function nextStep() {
    root.refreshStep += 1
    if (root.refreshStep === 1) {
      if (!devProc.running) devProc.running = true
    } else if (root.refreshStep === 2) {
      if (!threadProc.running) threadProc.running = true
    } else if (root.refreshStep === 3) {
      if (!notifProc.running) notifProc.running = true
    } else if (root.refreshStep === 4) {
      if (!wifiProc.running) wifiProc.running = true
    } else if (root.refreshStep === 5) {
      if (root.wifiUp) {
        if (!lanProc.running) lanProc.running = true
      } else {
        root.lanDevices = []
        root.lanPeers = []
        root.pendingPair = null
        root.recentDownloads = []
        root.busy = false
        root.refreshStep = 0
        if (root.opened && root.tab === "settings")
          root.loadSettings()
        if (root.page === "thread" && root.selectedThread && root.selectedThread.handle)
          root.loadMessages(root.selectedThread.handle)
      }
    } else if (root.refreshStep === 6) {
      if (!dlProc.running) dlProc.running = true
    } else {
      root.busy = false
      root.refreshStep = 0
      if (root.opened && root.tab === "settings")
        root.loadSettings()
      if (root.opened && root.tab === "link")
        root.loadLink()
      if (root.page === "thread" && root.selectedThread && root.selectedThread.handle)
        root.loadMessages(root.selectedThread.handle)
    }
  }

  function refresh() {
    if (root.busy) return
    root.busy = true
    root.refreshStep = 0
    if (!connProc.running) connProc.running = true
  }

  function openApp() {
    if (!launchProc.running) launchProc.running = true
  }

  function showInbox() {
    root.page = "inbox"
    root.selectedThread = null
    root.selectedNotice = null
    root.messages = []
    root.replyDraft = ""
  }

  function openThread(thread) {
    if (!thread) return
    root.selectedThread = thread
    root.page = "thread"
    root.tab = "messages"
    root.replyDraft = ""
    root.loadMessages(thread.handle)
    if (panelLoader.item && !root.opened) panelLoader.item.open()
  }

  function openNotice(notice) {
    if (!notice) return
    var match = Model.threadByName(root.threads, notice.app)
    if (!match) match = Model.threadByName(root.threads, notice.title)
    if (match && match.handle) {
      root.openThread(match)
      return
    }
    root.selectedNotice = notice
    root.page = "notice"
    if (panelLoader.item && !root.opened) panelLoader.item.open()
  }

  function loadMessages(handle) {
    if (!handle) {
      root.messages = []
      return
    }
    msgProc.command = ["tether", "--bt-messages", handle]
    if (!msgProc.running) msgProc.running = true
  }

  function normalizeHandle(value) {
    var h = String(value || "").trim()
    if (!h) return ""
    if (h.indexOf("tel:") === 0 || h.indexOf("mailto:") === 0) return h
    if (h.indexOf("@") >= 0) return "mailto:" + h
    return "tel:" + h.replace(/[^+\d]/g, "")
  }

  function sendTo(handle, text) {
    var h = root.normalizeHandle(handle)
    var t = String(text || "").trim()
    if (!h || !t) return false
    if (sendProc.running) {
      root.actionNote = "Still sending the previous message."
      return false
    }
    sendProc.command = ["tether", "--bt-send", h, t]
    sendProc.running = true
    return true
  }

  function sendReply() {
    var thread = root.selectedThread
    if (!thread) return
    root.sendTo(thread.handle, root.replyDraft)
  }

  function solicit() {
    if (!solicitProc.running) solicitProc.running = true
  }

  function sendFile() {
    var p = String(root.filePath || "").trim()
    if (!p || !root.wifiUp) return
    fileProc.command = ["tether", "-f", p]
    if (!fileProc.running) fileProc.running = true
  }

  function pullClipboard() {
    if (!root.wifiUp) return
    if (!clipProc.running) clipProc.running = true
  }

  function loadLink() {
    if (!root.wifiUp) {
      root.lanPeers = []
      root.pendingPair = null
      return
    }
    if (!lanProc.running) lanProc.running = true
    if (!discProc.running) discProc.running = true
    if (!pairLogProc.running) pairLogProc.running = true
    root.pullClipboard()
  }

  function pairLan(peer) {
    root.acceptPending()
  }

  function acceptPending() {
    var p = root.pendingPair
    var fp = p && p.fingerprint ? String(p.fingerprint).trim() : ""
    if (!fp) {
      root.actionNote = "Open Tether on the iPhone first. When it asks to pair with this PC, Accept here."
      return
    }
    root.acceptDraft = fp
    root.acceptPair()
  }

  function pushClipboard() {
    var t = String(root.clipDraft !== "" ? root.clipDraft : root.clipPreview)
    if (!t || !root.wifiUp) return
    pushProc.command = ["bash", "-c", "printf '%s' \"$1\" | tether -s", "omamessage-clip", t]
    if (!pushProc.running) pushProc.running = true
  }

  function sendDropped(url) {
    var p = Model.fileFromUrl(url)
    if (!p || !root.wifiUp) return
    root.filePath = p
    root.sendFile()
  }

  function pairBt(addr, explicit) {
    var a = String(addr || "").trim()
    if (!a) return
    root.actionNote = explicit ? "Pairing with explicit-pair…" : "Pairing over Bluetooth…"
    pairProc.command = explicit
      ? ["tether", "--bt-pair", a, "--explicit-pair"]
      : ["tether", "--bt-pair", a]
    if (!pairProc.running) pairProc.running = true
  }

  function unpairBt(addr) {
    var a = String(addr || "").trim()
    if (!a) return
    root.actionNote = "Removing Bluetooth bond…"
    unpairProc.command = ["tether", "--bt-unpair", a]
    if (!unpairProc.running) unpairProc.running = true
  }

  function setBtFlag(which, on) {
    var next = {
      enabled: root.btFlags.enabled,
      ancs: root.btFlags.ancs,
      ancsContent: root.btFlags.ancsContent
    }
    if (which === "enabled") next.enabled = on
    else if (which === "ancs") next.ancs = on
    else if (which === "ancsContent") next.ancsContent = on
    else return
    root.btFlags = next
    var flag = which === "enabled" ? "--bt-enable" : (which === "ancs" ? "--bt-ancs" : "--bt-ancs-content")
    root.actionNote = "Updating Tether…"
    flagProc.command = ["tether", flag, on ? "on" : "off"]
    if (!flagProc.running) flagProc.running = true
  }

  function acceptPair() {
    var fp = String(root.acceptDraft || "").trim()
    if (!fp || !root.wifiUp) return
    root.actionNote = "Accepting iOS pairing…"
    acceptProc.command = ["tether", "--accept", fp]
    if (!acceptProc.running) acceptProc.running = true
  }

  function loadSettings() {
    if (!statusProc.running) statusProc.running = true
    if (!setupProc.running) setupProc.running = true
    if (!diagProc.running) diagProc.running = true
  }

  onWifiUpChanged: {
    // Keep Link visible; Wi-Fi-only actions disable themselves.
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  Component.onCompleted: refresh()

  Timer {
    interval: 8000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: connProc
    command: ["tether", "--bt-connection"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.status = Model.parseConnection(text)
        root.cliOk = true
      }
    }
    onExited: function(code) {
      if (code !== 0) {
        root.cliOk = false
        root.status = Model.parseConnection("")
      }
      root.nextStep()
    }
  }

  Process {
    id: devProc
    command: ["tether", "--bt-devices"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.devices = Model.parseDevices(text)
    }
    onExited: root.nextStep()
  }

  Process {
    id: threadProc
    command: ["tether", "--bt-threads"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.threads = Model.parseThreads(text)
    }
    onExited: root.nextStep()
  }

  Process {
    id: notifProc
    command: ["tether", "--bt-notifications"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.notifications = Model.parseNotifications(text)
    }
    onExited: root.nextStep()
  }

  Process {
    id: msgProc
    command: ["tether", "--bt-messages", ""]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.messages = Model.parseMessages(text)
    }
  }

  Process {
    id: sendProc
    command: ["tether", "--bt-send", "", ""]
    onExited: function(code) {
      if (code === 0) {
        root.replyDraft = ""
        if (root.selectedThread) root.loadMessages(root.selectedThread.handle)
        root.refresh()
      }
    }
  }

  Process {
    id: wifiProc
    command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.wifiUp = Model.lanConnected(text)
    }
    onExited: function(code) {
      if (code !== 0) root.wifiUp = false
      root.nextStep()
    }
  }

  Process {
    id: lanProc
    command: ["tether", "--list-devices"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.lanDevices = Model.parseLanDevices(text)
    }
    onExited: function() {
      if (root.busy) root.nextStep()
    }
  }

  Process {
    id: discProc
    command: ["tether", "--discover", "--timeout", "2000"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.lanPeers = Model.remoteLanPeers(Model.parseDiscover(text))
    }
  }

  Process {
    id: pairLogProc
    command: ["bash", "-lc", "grep -E 'Pairing Request Pending|Pairing Accepted|Pairing Rejected' -- \"$HOME/.local/state/tether/tetherd.log\" 2>/dev/null | tail -n 30"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.pendingPair = Model.parsePendingPair(text)
    }
  }

  Process {
    id: clipProc
    command: ["tether", "-g"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.clipPreview = Model.clipPreview(text)
        root.clipDraft = root.clipPreview
      }
    }
  }

  Process {
    id: fileProc
    command: ["tether", "-f", ""]
    onExited: function(code) {
      if (code === 0) root.filePath = ""
    }
  }

  Process {
    id: pushProc
    command: ["tether", "-s"]
    onExited: function(code) {
      root.actionNote = code === 0
        ? (root.lanDevices.length > 0 ? "Clipboard pushed to Tether." : "Copied on this PC. Pair the iOS app on Link to sync to the phone.")
        : "Clipboard push failed."
    }
  }

  Process {
    id: pairProc
    command: ["tether", "--bt-pair", ""]
    onExited: function(code) {
      root.actionNote = code === 0
        ? "Pairing started. Confirm the code on the iPhone. Prefer Open Tether if no dialog appears."
        : "Pairing failed. Open Tether to confirm the code, or try explicit-pair in Settings."
      root.refresh()
    }
  }

  Process {
    id: unpairProc
    command: ["tether", "--bt-unpair", ""]
    onExited: function(code) {
      root.actionNote = code === 0 ? "Bluetooth bond removed." : "Could not unpair."
      root.refresh()
    }
  }

  Process {
    id: flagProc
    command: ["tether", "--bt-enable", "on"]
    onExited: function(code) {
      root.actionNote = code === 0 ? "Tether Bluetooth setting updated." : "Could not update that Tether setting."
      root.refresh()
      root.loadSettings()
    }
  }

  Process {
    id: acceptProc
    command: ["tether", "--accept", ""]
    onExited: function(code) {
      if (code === 0) {
        root.acceptDraft = ""
        root.pendingPair = null
        root.actionNote = "Accepted iOS pairing."
      } else {
        root.actionNote = "Accept failed. Open Tether on the iPhone so it can ask this PC to pair."
      }
      root.refresh()
      root.loadLink()
    }
  }

  Process {
    id: statusProc
    command: ["tether", "--bt-status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.btStatus = Model.parseBtStatus(text)
    }
  }

  Process {
    id: setupProc
    command: ["tether", "--bt-setup"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.btSetup = Model.parseBtSetup(text)
    }
  }

  Process {
    id: diagProc
    command: ["tether", "--bt-diagnostics"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.btFlags = Model.parseDiagnostics(text)
    }
  }

  Process {
    id: dlProc
    command: ["bash", "-lc", "ls -1t -- \"$HOME/Downloads\" 2>/dev/null | head -n 6"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.recentDownloads = Model.parseDownloads(text)
    }
    onExited: root.nextStep()
  }

  FileView {
    id: hostsFile
    path: Quickshell.env("HOME") + "/.config/tether/known_hosts.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var parsed = Model.parseLanDevices(text())
      if (parsed.length > 0) root.lanDevices = parsed
    }
  }

  Process {
    id: solicitProc
    command: ["tether", "--bt-solicit"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var msg = Model.clipPreview(text)
        if (msg) root.actionNote = msg
      }
    }
    onExited: function(code) {
      if (!root.actionNote) {
        root.actionNote = code === 0
          ? "Asked the iPhone to re-offer notification access. If Notify stays dark, turn Bluetooth off and on on the iPhone."
          : "Could not re-advertise permissions."
      }
      root.refresh()
    }
  }

  Process {
    id: launchProc
    command: ["uwsm-app", "--", "tether-gtk"]
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
    function refresh(): void { root.refresh() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function app(): void { root.openApp() }
    function inbox(): void { root.showInbox() }
    function settings(): void {
      root.showInbox()
      root.tab = "settings"
      root.open()
      root.loadSettings()
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.displayText
    tooltipText: "Omamessage — Tether by Zack Bartel — " + Model.statusTitle(root.status)
    dimmed: !root.mapUp
    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.openApp()
      else if (b === Qt.RightButton) root.showInbox()
      else root.togglePanel()
    }
  }
}

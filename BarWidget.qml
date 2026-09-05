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
  property var unreadSeen: ({})
  property var notifications: []
  property var contacts: []
  property string contactQuery: ""
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
  property var btFlags: ({ enabled: false, ancs: false, ancsContent: true, retention: "", retentionReady: false, groupMessages: false, callsEnabled: false, adapterPinned: "", adapterId: "", version: "" })
  property var btStatus: ({ mode: "", bond: "", tether: "", classOk: false, adapters: [], adapterId: "", adapterPinned: "", raw: "" })
  property var btSetup: ({ complete: true, text: "" })
  property var cliCaps: ({ calls: false, adapter: true, forget: true })
  property var calls: []
  property string dialDraft: ""
  property string diagnosticsText: ""
  property string copyOkNote: "Copied."
  property string acceptDraft: ""
  property string actionNote: ""

  readonly property string displayText: Model.barLabel(status)
  readonly property bool mapUp: status && status.map === true
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property int readMaxBytes: 65536
  readonly property int readTermSecs: 8
  readonly property int readKillAfterSecs: 2
  readonly property string boundCmd: Model.fileFromUrl("" + Qt.resolvedUrl("scripts/bounded-cmd.sh"))
  readonly property string pickFileCmd: Model.fileFromUrl("" + Qt.resolvedUrl("scripts/pick-file.sh"))
  readonly property var readWrap: [root.boundCmd, String(root.readMaxBytes), String(root.readTermSecs), String(root.readKillAfterSecs), "--"]

  function boundCommand(argv) {
    var c = root.readWrap.slice()
    for (var i = 0; i < argv.length; i++) c.push(argv[i])
    return c
  }

  function setNote(msg) {
    root.actionNote = Model.neutralizeUi(msg)
  }

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
        root.busy = false
        root.refreshStep = 0
        if (root.opened && root.tab === "settings")
          root.loadSettings()
        if (root.opened && root.tab === "calls")
          root.loadCalls()
        if (root.page === "thread" && root.selectedThread && root.selectedThread.handle)
          root.loadMessages(root.selectedThread.handle)
      }
    } else {
      root.busy = false
      root.refreshStep = 0
      if (root.opened && root.tab === "settings")
        root.loadSettings()
      if (root.opened && root.tab === "calls")
        root.loadCalls()
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
    if (thread.handle) {
      var seen = {}
      var old = root.unreadSeen || {}
      for (var k in old) seen[k] = old[k]
      var n = thread.unread || 0
      if (old[thread.handle] !== undefined && old[thread.handle] > n)
        n = old[thread.handle]
      seen[thread.handle] = n
      root.unreadSeen = seen
    }
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
    msgProc.command = root.boundCommand(["tether", "--bt-messages", handle])
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
      root.setNote("Still sending the previous message.")
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
    var t = Model.pairTarget(peer)
    if (!t || !t.ip) {
      root.acceptPending()
      return
    }
    if (!root.wifiUp) {
      root.setNote("Needs LAN.")
      return
    }
    root.setNote("Sending pair request to " + (peer.name || t.ip) + "…")
    lanPairProc.command = ["tether", "--pair", "--host", String(t.ip), "--port", String(t.port || 5134)]
    if (!lanPairProc.running) lanPairProc.running = true
  }

  function forgetLan(fp) {
    var f = String(fp || "").trim()
    if (!f || !root.wifiUp) return
    root.setNote("Forgetting Wi-Fi pairing…")
    forgetProc.command = ["tether", "--forget", f]
    if (!forgetProc.running) forgetProc.running = true
  }

  function acceptPending() {
    var p = root.pendingPair
    var fp = p && p.fingerprint ? String(p.fingerprint).trim() : ""
    if (!fp) {
      root.setNote("Open Tether on the iPhone first. When it asks to pair with this PC, Accept here.")
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

  function browseFile() {
    if (!root.wifiUp || browseProc.running || pickTimer.running) return
    root.tab = "link"
    root.showInbox()
    root.close()
    pickTimer.restart()
  }

  function pairBt(addr, explicit) {
    var a = String(addr || "").trim()
    if (!a) return
    root.setNote(explicit ? "Pairing with explicit-pair…" : "Pairing over Bluetooth…")
    pairProc.command = explicit
      ? ["tether", "--bt-pair", a, "--explicit-pair"]
      : ["tether", "--bt-pair", a]
    if (!pairProc.running) pairProc.running = true
  }

  function unpairBt(addr) {
    var a = String(addr || "").trim()
    if (!a) return
    root.setNote("Removing Bluetooth bond…")
    unpairProc.command = ["tether", "--bt-unpair", a]
    if (!unpairProc.running) unpairProc.running = true
  }

  function setBtFlag(which, on) {
    var next = {
      enabled: root.btFlags.enabled,
      ancs: root.btFlags.ancs,
      ancsContent: root.btFlags.ancsContent,
      retention: root.btFlags.retention || "",
      retentionReady: root.btFlags.retentionReady === true,
      groupMessages: root.btFlags.groupMessages === true,
      callsEnabled: root.btFlags.callsEnabled === true,
      adapterPinned: root.btFlags.adapterPinned || "",
      adapterId: root.btFlags.adapterId || "",
      version: root.btFlags.version || ""
    }
    if (which === "enabled") next.enabled = on
    else if (which === "ancs") next.ancs = on
    else if (which === "ancsContent") next.ancsContent = on
    else if (which === "callsEnabled") next.callsEnabled = on
    else return
    root.btFlags = next
    var flag = which === "enabled" ? "--bt-enable"
      : (which === "ancs" ? "--bt-ancs"
        : (which === "ancsContent" ? "--bt-ancs-content" : "--bt-calls-enable"))
    root.setNote("Updating Tether…")
    flagProc.command = ["tether", flag, on ? "on" : "off"]
    if (!flagProc.running) flagProc.running = true
  }

  function setAdapter(id) {
    var a = String(id || "auto").trim()
    if (!a) a = "auto"
    root.setNote(a === "auto" ? "Using the first powered Bluetooth controller…" : ("Using " + a + "…"))
    adapterProc.command = ["tether", "--bt-adapter", a]
    if (!adapterProc.running) adapterProc.running = true
  }

  function copyText(text, okNote) {
    var t = String(text || "")
    if (!t) {
      root.setNote("Nothing to copy.")
      return
    }
    copyProc.command = ["bash", "-c", "printf '%s' \"$1\" | wl-copy 2>/dev/null || printf '%s' \"$1\" | tether -s", "omamessage-copy", t]
    root.copyOkNote = okNote || "Copied."
    if (!copyProc.running) copyProc.running = true
  }

  function copySetup() {
    root.copyText(root.btSetup && root.btSetup.text ? root.btSetup.text : "", "Setup commands copied.")
  }

  function copyDiagnostics() {
    root.copyText(root.diagnosticsText, "Diagnostics copied. Safe to paste into a Tether bug report.")
  }

  function loadCalls() {
    if (!(root.cliCaps && root.cliCaps.calls)) {
      root.calls = []
      return
    }
    if (!callsProc.running) callsProc.running = true
  }

  function dialNumber(number) {
    var n = String(number || root.dialDraft || "").replace(/[^\d+]/g, "")
    if (!n) return
    root.setNote("Dialing…")
    dialProc.command = ["tether", "--bt-call", n]
    if (!dialProc.running) dialProc.running = true
  }

  function answerCall() {
    root.setNote("Answering…")
    answerProc.command = ["tether", "--bt-answer"]
    if (!answerProc.running) answerProc.running = true
  }

  function hangupCall() {
    root.setNote("Hanging up…")
    hangupProc.command = ["tether", "--bt-hangup"]
    if (!hangupProc.running) hangupProc.running = true
  }

  function acceptPair() {
    var fp = String(root.acceptDraft || "").trim()
    if (!fp || !root.wifiUp) return
    root.setNote("Accepting iOS pairing…")
    acceptProc.command = ["tether", "--accept", fp]
    if (!acceptProc.running) acceptProc.running = true
  }

  function loadSettings() {
    if (!statusProc.running) statusProc.running = true
    if (!setupProc.running) setupProc.running = true
    if (!diagProc.running) diagProc.running = true
    if (!helpProc.running) helpProc.running = true
  }

  function searchContacts(q) {
    root.contactQuery = String(q || "")
    contactTimer.restart()
  }

  function loadContacts() {
    var q = Model.contactQueryArg(root.contactQuery)
    contactProc.command = q
      ? root.boundCommand(["tether", "--bt-contacts", q])
      : root.boundCommand(["tether", "--bt-contacts"])
    if (!contactProc.running) contactProc.running = true
  }

  function openContact(c) {
    if (!c) return
    root.openContactHandle(c, c.handle)
  }

  function openContactHandle(c, handle) {
    var h = String(handle || "").trim()
    if (!h) {
      root.setNote("No phone or email for that contact.")
      return
    }
    var match = Model.threadByHandle(root.threads, h)
    if (match) {
      root.openThread(match)
      return
    }
    root.openThread({
      name: (c && c.name) || h,
      handle: h,
      time: "",
      preview: "",
      unread: 0
    })
  }

  function setRetention(mode) {
    var m = Model.parseRetention(mode)
    if (!m) return
    root.setNote("Updating how messages and contacts are kept on disk…")
    retentionProc.command = ["tether", "--bt-retention", m]
    if (!retentionProc.running) retentionProc.running = true
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

  Timer {
    id: contactTimer
    interval: 280
    repeat: false
    onTriggered: root.loadContacts()
  }

  Timer {
    id: pickTimer
    interval: 200
    repeat: false
    onTriggered: {
      browseProc.command = [root.pickFileCmd]
      if (!browseProc.running) browseProc.running = true
    }
  }

  Process {
    id: connProc
    command: root.readWrap.concat(["tether", "--bt-connection"])
    stdout: StdioCollector {
      id: connOut
      waitForEnd: true
    }
    onExited: function(code) {
      if (Model.readRejected(code)) {
        root.nextStep()
        return
      }
      if (code === 0) {
        root.status = Model.parseConnection(connOut.text)
        root.cliOk = true
      } else {
        root.cliOk = false
        root.status = Model.parseConnection("")
      }
      root.nextStep()
    }
  }

  Process {
    id: devProc
    command: root.readWrap.concat(["tether", "--bt-devices"])
    stdout: StdioCollector {
      id: devOut
      waitForEnd: true
    }
    onExited: function(code) {
      if (!Model.readRejected(code))
        root.devices = Model.parseDevices(devOut.text)
      root.nextStep()
    }
  }

  Process {
    id: threadProc
    command: root.readWrap.concat(["tether", "--bt-threads"])
    stdout: StdioCollector {
      id: threadOut
      waitForEnd: true
    }
    onExited: function(code) {
      if (!Model.readRejected(code))
        root.threads = Model.parseThreads(threadOut.text)
      root.nextStep()
    }
  }

  Process {
    id: notifProc
    command: root.readWrap.concat(["tether", "--bt-notifications"])
    stdout: StdioCollector {
      id: notifOut
      waitForEnd: true
    }
    onExited: function(code) {
      if (!Model.readRejected(code))
        root.notifications = Model.parseNotifications(notifOut.text)
      root.nextStep()
    }
  }

  Process {
    id: contactProc
    command: root.readWrap.concat(["tether", "--bt-contacts"])
    stdout: StdioCollector {
      id: contactOut
      waitForEnd: true
    }
    onExited: function(code) {
      if (!Model.readRejected(code))
        root.contacts = Model.parseContacts(contactOut.text)
      var q = Model.contactQueryArg(root.contactQuery)
      var asked = ""
      var cmd = contactProc.command || []
      var last = cmd.length ? String(cmd[cmd.length - 1]) : ""
      if (last && last !== "--bt-contacts") asked = last
      if (q !== asked && !contactProc.running)
        root.loadContacts()
    }
  }

  Process {
    id: msgProc
    command: root.readWrap.concat(["tether", "--bt-messages", ""])
    stdout: StdioCollector {
      id: msgOut
      waitForEnd: true
    }
    onExited: function(code) {
      if (!Model.readRejected(code))
        root.messages = Model.parseMessages(msgOut.text)
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
    command: root.readWrap.concat(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device"])
    stdout: StdioCollector {
      id: wifiOut
      waitForEnd: true
    }
    onExited: function(code) {
      if (Model.readRejected(code)) {
        root.nextStep()
        return
      }
      root.wifiUp = code === 0 && Model.lanConnected(wifiOut.text)
      root.nextStep()
    }
  }

  Process {
    id: lanProc
    command: root.readWrap.concat(["tether", "--list-devices"])
    stdout: StdioCollector {
      id: lanOut
      waitForEnd: true
    }
    onExited: function(code) {
      if (!Model.readRejected(code))
        root.lanDevices = Model.parseLanDevices(lanOut.text)
      if (root.busy) root.nextStep()
    }
  }

  Process {
    id: discProc
    command: root.readWrap.concat(["tether", "--discover", "--timeout", "2000"])
    stdout: StdioCollector {
      id: discOut
      waitForEnd: true
    }
    onExited: function(code) {
      if (!Model.readRejected(code))
        root.lanPeers = Model.remoteLanPeers(Model.parseDiscover(discOut.text))
    }
  }

  Process {
    id: pairLogProc
    command: root.readWrap.concat(["bash", "-c", "tail -c 65536 -- \"$HOME/.local/state/tether/tetherd.log\" 2>/dev/null | grep -E 'Pairing Request Pending|Pairing Accepted|Pairing Rejected' | tail -n 30"])
    stdout: StdioCollector {
      id: pairLogOut
      waitForEnd: true
    }
    onExited: function(code) {
      if (!Model.readRejected(code))
        root.pendingPair = Model.parsePendingPair(pairLogOut.text)
    }
  }

  Process {
    id: clipProc
    command: root.readWrap.concat(["tether", "-g"])
    stdout: StdioCollector {
      id: clipOut
      waitForEnd: true
    }
    onExited: function(code) {
      if (Model.readRejected(code)) return
      root.clipPreview = Model.clipPreview(clipOut.text)
      root.clipDraft = root.clipPreview
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
      root.setNote(code === 0
        ? (root.lanDevices.length > 0 ? "Clipboard pushed to Tether." : "Copied on this PC. Pair the iOS app on Link to sync to the phone.")
        : "Clipboard push failed.")
    }
  }

  Process {
    id: pairProc
    command: ["tether", "--bt-pair", ""]
    onExited: function(code) {
      root.setNote(code === 0
        ? "Pairing started. Confirm the code on the iPhone. Prefer Open Tether if no dialog appears."
        : "Pairing failed. Open Tether to confirm the code, or try explicit-pair in Settings.")
      root.refresh()
    }
  }

  Process {
    id: unpairProc
    command: ["tether", "--bt-unpair", ""]
    onExited: function(code) {
      root.setNote(code === 0 ? "Bluetooth bond removed." : "Could not unpair.")
      root.refresh()
    }
  }

  Process {
    id: flagProc
    command: ["tether", "--bt-enable", "on"]
    onExited: function(code) {
      root.setNote(code === 0 ? "Tether Bluetooth setting updated." : "Could not update that Tether setting.")
      root.refresh()
      root.loadSettings()
    }
  }

  Process {
    id: retentionProc
    command: ["tether", "--bt-retention", "encrypted"]
    stdout: StdioCollector {
      id: retentionOut
      waitForEnd: true
    }
    onExited: function(code) {
      var msg = Model.clipPreview(retentionOut.text)
      if (code === 0)
        root.setNote(msg || "On-disk retention updated.")
      else
        root.setNote(msg || "Could not update on-disk retention.")
      root.loadSettings()
    }
  }

  Process {
    id: lanPairProc
    command: ["tether", "--pair", "--host", "127.0.0.1", "--port", "5134"]
    onExited: function(code) {
      root.setNote(code === 0
        ? "Pair request sent. Approve on the iPhone."
        : "Pair request failed. Open Tether on the iPhone and Accept here.")
      root.loadLink()
    }
  }

  Process {
    id: forgetProc
    command: ["tether", "--forget", ""]
    onExited: function(code) {
      root.setNote(code === 0 ? "Forgot that Wi-Fi pairing." : "Could not forget that pairing.")
      root.refresh()
      root.loadLink()
    }
  }

  Process {
    id: adapterProc
    command: ["tether", "--bt-adapter", "auto"]
    stdout: StdioCollector {
      id: adapterOut
      waitForEnd: true
    }
    onExited: function(code) {
      var msg = Model.clipPreview(adapterOut.text)
      root.setNote(code === 0 ? (msg || "Bluetooth controller updated.") : (msg || "Could not change controller."))
      root.loadSettings()
      root.refresh()
    }
  }

  Process {
    id: copyProc
    command: ["bash", "-c", "true"]
    onExited: function(code) {
      root.setNote(code === 0 ? root.copyOkNote : "Could not copy.")
    }
  }

  Process {
    id: helpProc
    command: root.readWrap.concat(["tether", "--help"])
    stdout: StdioCollector {
      id: helpOut
      waitForEnd: true
    }
    onExited: function(code) {
      if (!Model.readRejected(code))
        root.cliCaps = Model.parseCliCaps(helpOut.text)
    }
  }

  Process {
    id: callsProc
    command: root.readWrap.concat(["tether", "--bt-calls"])
    stdout: StdioCollector {
      id: callsOut
      waitForEnd: true
    }
    onExited: function(code) {
      if (!Model.readRejected(code))
        root.calls = Model.parseCalls(callsOut.text)
    }
  }

  Process {
    id: dialProc
    command: ["tether", "--bt-call", ""]
    onExited: function(code) {
      root.setNote(code === 0 ? "Dialing." : "Could not place the call. Call control may be off.")
      root.loadCalls()
    }
  }

  Process {
    id: answerProc
    command: ["tether", "--bt-answer"]
    onExited: function(code) {
      root.setNote(code === 0 ? "Answering." : "Could not answer.")
      root.loadCalls()
    }
  }

  Process {
    id: hangupProc
    command: ["tether", "--bt-hangup"]
    onExited: function(code) {
      root.setNote(code === 0 ? "Hanging up." : "Could not hang up.")
      root.loadCalls()
    }
  }

  Process {
    id: acceptProc
    command: ["tether", "--accept", ""]
    onExited: function(code) {
      if (code === 0) {
        root.acceptDraft = ""
        root.pendingPair = null
        root.setNote("Accepted iOS pairing.")
      } else {
        root.setNote("Accept failed. Open Tether on the iPhone so it can ask this PC to pair.")
      }
      root.refresh()
      root.loadLink()
    }
  }

  Process {
    id: statusProc
    command: root.readWrap.concat(["tether", "--bt-status"])
    stdout: StdioCollector {
      id: statusOut
      waitForEnd: true
    }
    onExited: function(code) {
      if (Model.readRejected(code)) return
      var st = Model.parseBtStatus(statusOut.text)
      st.adapterPinned = (root.btFlags && root.btFlags.adapterPinned) || (root.btStatus && root.btStatus.adapterPinned) || ""
      root.btStatus = st
    }
  }

  Process {
    id: setupProc
    command: root.readWrap.concat(["tether", "--bt-setup"])
    stdout: StdioCollector {
      id: setupOut
      waitForEnd: true
    }
    onExited: function(code) {
      if (!Model.readRejected(code))
        root.btSetup = Model.parseBtSetup(setupOut.text)
    }
  }

  Process {
    id: diagProc
    command: root.readWrap.concat(["tether", "--bt-diagnostics"])
    stdout: StdioCollector {
      id: diagOut
      waitForEnd: true
    }
    onExited: function(code) {
      if (Model.readRejected(code)) return
      var d = Model.parseDiagnostics(diagOut.text)
      root.btFlags = d
      root.diagnosticsText = String(diagOut.text || "")
      var st = Model.parseBtStatus(root.btStatus && root.btStatus.raw ? root.btStatus.raw : "")
      if (root.btStatus && root.btStatus.adapters)
        st = root.btStatus
      st.adapterPinned = d.adapterPinned
      if (d.adapterId) st.adapterId = d.adapterId
      root.btStatus = {
        mode: st.mode,
        bond: st.bond,
        tether: st.tether,
        classOk: st.classOk,
        adapters: st.adapters || [],
        adapterId: st.adapterId || d.adapterId,
        adapterPinned: d.adapterPinned,
        raw: st.raw
      }
    }
  }

  Process {
    id: browseProc
    command: ["true"]
    stdout: StdioCollector {
      id: browseOut
      waitForEnd: true
    }
    onExited: function(code) {
      if (code === 0) {
        var p = String(browseOut.text || "").trim()
        if (p) {
          root.filePath = p
          var slash = p.lastIndexOf("/")
          root.setNote("Selected " + (slash >= 0 ? p.slice(slash + 1) : p))
        }
      }
      root.tab = "link"
      root.showInbox()
      root.open()
    }
  }

  FileView {
    id: hostsFile
    path: Quickshell.env("HOME") + "/.config/tether/known_hosts.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var raw = text()
      if (!raw || raw.length > root.readMaxBytes) return
      var parsed = Model.parseLanDevices(raw)
      if (parsed.length > 0) root.lanDevices = parsed
    }
  }

  Process {
    id: solicitProc
    command: root.readWrap.concat(["tether", "--bt-solicit"])
    stdout: StdioCollector {
      id: solicitOut
      waitForEnd: true
    }
    onExited: function(code) {
      if (Model.readRejected(code)) {
        root.refresh()
        return
      }
      var msg = Model.clipPreview(solicitOut.text)
      if (msg) root.setNote(msg)
      else {
        root.setNote(code === 0
          ? "Asked the iPhone to re-offer notification access. If Notify stays dark, turn Bluetooth off and on on the iPhone."
          : "Could not re-advertise permissions.")
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
    function contacts(): void {
      root.showInbox()
      root.tab = "contacts"
      root.open()
      root.loadContacts()
    }
    function calls(): void {
      root.showInbox()
      root.tab = "calls"
      root.open()
      root.loadCalls()
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.displayText
    tooltipText: Model.neutralizeUi(Model.statusTitle(root.status))
    dimmed: !root.mapUp
    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.openApp()
      else if (b === Qt.RightButton) root.showInbox()
      else root.togglePanel()
    }
  }
}

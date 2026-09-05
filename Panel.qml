import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Inbox popout. Messaging is Tether by Zack Bartel: https://github.com/zackb/tether
Panel {
  id: root
  moduleName: "io.github.charleschao.omamessage"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property var hw: hostWidget
  readonly property var status: hw ? hw.status : ({})
  readonly property var devices: hw && hw.devices ? hw.devices : []
  readonly property var threads: hw && hw.threads ? hw.threads : []
  readonly property var unreadSeen: hw && hw.unreadSeen ? hw.unreadSeen : ({})
  readonly property var notifications: hw && hw.notifications ? hw.notifications : []
  readonly property var contacts: hw && hw.contacts ? hw.contacts : []
  readonly property string contactQuery: hw ? hw.contactQuery : ""
  readonly property var messages: hw && hw.messages ? hw.messages : []
  readonly property string page: hw ? hw.page : "inbox"
  readonly property string tab: hw ? hw.tab : "messages"
  readonly property var selectedThread: hw ? hw.selectedThread : null
  readonly property var selectedNotice: hw ? hw.selectedNotice : null
  readonly property bool cliOk: hw ? hw.cliOk : false
  readonly property bool wifiUp: hw ? hw.wifiUp : false
  readonly property var lanDevices: hw && hw.lanDevices ? hw.lanDevices : []
  readonly property var lanPeers: hw && hw.lanPeers ? hw.lanPeers : []
  readonly property var pendingPair: hw ? hw.pendingPair : null
  readonly property string clipPreview: hw ? hw.clipPreview : ""

  readonly property var btFlags: hw && hw.btFlags ? hw.btFlags : ({ enabled: false, ancs: false, ancsContent: true, retention: "", retentionReady: false, groupMessages: false, callsEnabled: false })
  readonly property var btStatus: hw && hw.btStatus ? hw.btStatus : ({})
  readonly property var btSetup: hw && hw.btSetup ? hw.btSetup : ({ complete: true, text: "" })
  readonly property var cliCaps: hw && hw.cliCaps ? hw.cliCaps : ({ calls: false })
  readonly property var calls: hw && hw.calls ? hw.calls : []
  readonly property string actionNote: hw ? hw.actionNote : ""
  readonly property var tabs: {
    var t = [
      { value: "messages", label: "Messages" },
      { value: "notifications", label: "Notify" }
    ]
    if (root.cliCaps && root.cliCaps.calls)
      t.push({ value: "calls", label: "Calls" })
    t.push({ value: "link", label: "Link" })
    t.push({ value: "settings", label: "Settings" })
    return t
  }
  readonly property var adapterOptions: {
    var o = [{ value: "auto", label: "Auto" }]
    var ads = (root.btStatus && root.btStatus.adapters) ? root.btStatus.adapters : []
    var i
    for (i = 0; i < ads.length; i++) {
      o.push({
        value: ads[i].id,
        label: ads[i].inUse ? (ads[i].id + " in use") : ads[i].id
      })
    }
    return o
  }
  readonly property string adapterValue: (root.btStatus && root.btStatus.adapterPinned) ? root.btStatus.adapterPinned : "auto"
  readonly property var retentionOptions: [
    { value: "encrypted", label: "Encrypted" },
    { value: "plaintext", label: "Plaintext" },
    { value: "none", label: "None" }
  ]
  property bool unpairOpen: false
  property bool retentionOpen: false
  property bool forgetOpen: false
  property var forgetDevice: null

  readonly property color fg: bar ? bar.foreground : Color.popups.text
  readonly property color muted: Color.muted
  readonly property color accent: Color.accent
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color hoverFill: Style.hoverFillFor(root.fg, root.accent)
  readonly property color selectedFill: Style.selectedFillFor(root.fg, root.accent)
  readonly property color normalFill: Style.normalFillFor(root.fg, root.accent)
  readonly property int paneWidth: Style.space(420)
  readonly property int panelBodyHeight: Style.space(540)
  readonly property int composeHeight: Style.space(48)
  readonly property bool inboxFooter: root.page === "inbox" && (root.tab === "messages" || root.tab === "contacts")
  readonly property int inboxFooterH: root.inboxFooter ? Style.space(28) : 0
  readonly property int composeH: {
    if (root.page === "thread") return root.composeHeight
    if (root.page === "inbox" && root.tab === "messages") return root.composeHeight
    if (root.page === "inbox" && root.tab === "contacts") return root.composeHeight
    if (root.page === "inbox" && root.tab === "calls") return root.composeHeight
    return 0
  }
  readonly property int bodyListHeight: {
    var h = root.panelBodyHeight - headerCol.implicitHeight - Style.space(2)
    if (root.inboxFooterH > 0)
      h -= root.inboxFooterH + Style.space(2)
    h -= root.composeH
    if (h < Style.space(200)) h = Style.space(200)
    return h
  }

  function lastInRun(index) {
    var msgs = root.messages
    if (!msgs || index < 0 || index >= msgs.length - 1) return true
    return !!msgs[index].mine !== !!msgs[index + 1].mine
  }

  function threadHasUnread(thread) {
    if (!thread) return false
    var n = thread.unread || 0
    if (n <= 0) return false
    var w = 0
    if (thread.handle && root.unreadSeen && root.unreadSeen[thread.handle] !== undefined)
      w = root.unreadSeen[thread.handle]
    return n > w
  }

  function sendNew() {
    if (!hw) return
    if (hw.sendTo(newTo.text, newBody.text))
      newBody.text = ""
  }

  function sendReplyNow() {
    if (!hw || !replyField.text.trim() || !root.selectedThread) return
    hw.replyDraft = replyField.text
    if (hw.sendTo(root.selectedThread.handle, replyField.text))
      replyField.text = ""
  }

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() {
    if (root.opened) root.close()
    else {
      if (hw && hw.refresh) hw.refresh()
      root.open()
    }
  }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  Connections {
    target: hw
    function onPageChanged() {
      if (root.page === "thread")
        Qt.callLater(function() { replyField.forceActiveFocus() })
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(root.paneWidth)
    contentHeight: panel.fittedContentHeight(root.panelBodyHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: replyField.activeFocus || newTo.activeFocus || newBody.activeFocus || contactSearch.activeFocus || clipField.activeFocus || fileField.activeFocus || acceptField.activeFocus || dialField.activeFocus
      onCloseRequested: {
        if (root.unpairOpen) {
          root.unpairOpen = false
          return
        }
        if (root.retentionOpen) {
          root.retentionOpen = false
          return
        }
        if (root.forgetOpen) {
          root.forgetOpen = false
          return
        }
        if (root.page !== "inbox" && hw) hw.showInbox()
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: shell
        width: parent.width
        spacing: 0

        // ---- header ----
        Item {
          width: parent.width
          height: headerCol.implicitHeight

          Column {
            id: headerCol
            width: parent.width
            leftPadding: Style.space(16)
            rightPadding: Style.space(16)
            topPadding: Style.space(10)
            bottomPadding: Style.space(8)
            spacing: Style.space(6)

            Item {
              width: parent.width - Style.space(32)
              height: heroTitle.implicitHeight

              Text {
                id: backLink
                visible: root.page === "thread" || root.page === "notice"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: "←"
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                MouseArea {
                  anchors.fill: parent
                  anchors.margins: -Style.space(6)
                  cursorShape: Qt.PointingHandCursor
                  onClicked: if (hw) hw.showInbox()
                }
              }

              Text {
                id: heroTitle
                anchors.left: backLink.visible ? backLink.right : parent.left
                anchors.leftMargin: backLink.visible ? Style.space(8) : 0
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: root.page === "thread" && root.selectedThread
                  ? root.selectedThread.name
                  : (root.page === "notice" ? "Notification" : "Omamessage")
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
              }
            }

            Text {
              id: heroMeta
              visible: root.page === "inbox"
              width: parent.width - Style.space(32)
              textFormat: Text.PlainText
              text: {
                var line = Model.statusTitle(root.status)
                var p = Model.firstPhone(root.devices)
                if (p && p.name) line += " · " + p.name
                return line
              }
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            ButtonGroup {
              visible: root.page === "inbox"
              width: parent.width - Style.space(32)
              options: root.tabs
              value: root.tab
              foreground: root.fg
              background: "transparent"
              accent: root.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              focusable: false
              onChanged: function(v) {
                if (!hw) return
                if (hw.page !== "inbox") hw.showInbox()
                hw.tab = v
                if (v === "settings" && hw.loadSettings)
                  hw.loadSettings()
                if (v === "calls" && hw.loadCalls)
                  hw.loadCalls()
                if (v === "link" && hw.loadLink)
                  hw.loadLink()
              }
            }
          }
        }

        PanelSeparator { foreground: root.fg }

        // ---- inbox: messages ----
        ListView {
          id: threadList
          visible: root.page === "inbox" && root.tab === "messages"
          width: parent.width
          height: root.bodyListHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          spacing: 0
          model: root.threads

          delegate: Item {
            required property var modelData
            width: threadList.width
            height: Style.space(52)

            Rectangle {
              anchors.fill: parent
              color: rowHover.containsMouse ? root.hoverFill : "transparent"
            }

            Item {
              anchors.fill: parent
              anchors.leftMargin: Style.space(16)
              anchors.rightMargin: Style.space(16)

              Column {
                anchors.left: parent.left
                anchors.right: threadMeta.left
                anchors.rightMargin: Style.space(12)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: modelData.name
                  elide: Text.ElideRight
                  color: root.fg
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: root.threadHasUnread(modelData)
                }
                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: modelData.preview
                  elide: Text.ElideRight
                  color: root.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }

              Column {
                id: threadMeta
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text {
                  anchors.right: parent.right
                  textFormat: Text.PlainText
                  text: Model.threadTime(modelData.time)
                  color: root.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
                Rectangle {
                  visible: root.threadHasUnread(modelData)
                  anchors.right: parent.right
                  width: 6
                  height: 6
                  radius: 3
                  color: root.accent
                }
              }
            }

            MouseArea {
              id: rowHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: if (hw) hw.openThread(modelData)
            }
          }

          Text {
            visible: root.threads.length === 0
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: root.status && root.status.map ? "No conversations yet" : "Messages not connected"
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        Item {
          visible: root.page === "inbox" && root.tab === "messages"
          width: parent.width
          height: root.composeHeight

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(12)
            anchors.topMargin: Style.space(6)
            anchors.bottomMargin: Style.space(6)
            spacing: Style.space(8)

            TextField {
              id: newTo
              width: Style.space(152)
              anchors.verticalCenter: parent.verticalCenter
              placeholderText: "To"
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              foreground: root.fg
              accent: root.accent
            }

            TextField {
              id: newBody
              width: parent.width - newTo.width - newSend.width - Style.space(16)
              anchors.verticalCenter: parent.verticalCenter
              placeholderText: "New message"
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              foreground: root.fg
              accent: root.accent
              onAccepted: root.sendNew()
            }

            Button {
              id: newSend
              text: "Send"
              bordered: true
              foreground: root.fg
              accent: root.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              anchors.verticalCenter: parent.verticalCenter
              enabled: newTo.text.trim().length > 0 && newBody.text.trim().length > 0
              onClicked: root.sendNew()
            }
          }
        }

        Item {
          visible: root.page === "inbox" && root.tab === "contacts"
          width: parent.width
          height: root.composeHeight

          TextField {
            id: contactSearch
            anchors.fill: parent
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(12)
            anchors.topMargin: Style.space(6)
            anchors.bottomMargin: Style.space(6)
            placeholderText: "Search contacts"
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            foreground: root.fg
            accent: root.accent
            text: root.contactQuery
            onTextChanged: if (hw && text !== hw.contactQuery) hw.searchContacts(text)
          }
        }

        ListView {
          id: contactList
          visible: root.page === "inbox" && root.tab === "contacts"
          width: parent.width
          height: root.bodyListHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          spacing: 0
          model: root.contacts

          delegate: Item {
            required property var modelData
            property var contact: modelData
            width: contactList.width
            height: contactCol.implicitHeight + Style.space(16)

            Rectangle {
              anchors.fill: parent
              color: cHover.containsMouse ? root.hoverFill : "transparent"
            }

            MouseArea {
              id: cHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: if (hw) hw.openContact(contact)
            }

            Column {
              id: contactCol
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: Style.space(16)
              anchors.rightMargin: Style.space(16)
              anchors.top: parent.top
              anchors.topMargin: Style.space(8)
              spacing: 2
              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: contact.name
                elide: Text.ElideRight
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
              Repeater {
                model: contact.entries || []
                delegate: Text {
                  required property var modelData
                  width: contactCol.width
                  textFormat: Text.PlainText
                  text: modelData.label
                  wrapMode: Text.Wrap
                  color: root.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  MouseArea {
                    anchors.fill: parent
                    enabled: !!modelData.handle
                    cursorShape: modelData.handle ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (hw && modelData.handle) hw.openContactHandle(contact, modelData.handle)
                  }
                }
              }
            }
          }

          Text {
            visible: root.contacts.length === 0
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: {
              if (!(root.status && root.status.pbap))
                return "Contacts not connected"
              if (root.contactQuery)
                return "No matches"
              return "No contacts yet"
            }
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        // ---- inbox: notifications ----
        ListView {
          id: noticeList
          visible: root.page === "inbox" && root.tab === "notifications"
          width: parent.width
          height: root.bodyListHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          model: root.notifications

          delegate: Item {
            required property var modelData
            width: noticeList.width
            height: Style.space(56)

            Rectangle {
              anchors.fill: parent
              color: nHover.containsMouse ? root.hoverFill : "transparent"
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: Style.space(14)
              anchors.rightMargin: Style.space(14)
              spacing: 2
              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: modelData.app || "Notification"
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: modelData.title || modelData.body
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
              }
            }

            MouseArea {
              id: nHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: if (hw) hw.openNotice(modelData)
            }
          }

          Column {
            visible: root.notifications.length === 0
            anchors.centerIn: parent
            spacing: Style.space(10)
            width: parent.width - Style.space(40)
            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              text: root.status && root.status.ancs
                ? "No notifications"
                : "Needs Bluetooth LE"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            Text {
              visible: root.actionNote !== ""
              width: parent.width
              wrapMode: Text.WordWrap
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              text: root.actionNote
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Button {
              visible: !(root.status && root.status.ancs)
              anchors.horizontalCenter: parent.horizontalCenter
              text: "Re-advertise"
              bordered: true
              foreground: root.fg
              accent: root.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              onClicked: if (hw) hw.solicit()
            }
          }
        }

        Item {
          visible: root.page === "inbox" && root.tab === "calls"
          width: parent.width
          height: root.composeHeight

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(12)
            anchors.topMargin: Style.space(6)
            anchors.bottomMargin: Style.space(6)
            spacing: Style.space(8)

            TextField {
              id: dialField
              width: parent.width - dialBtn.width - Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              placeholderText: "Number"
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              foreground: root.fg
              accent: root.accent
              text: hw ? hw.dialDraft : ""
              onTextChanged: if (hw && text !== hw.dialDraft) hw.dialDraft = text
              onAccepted: if (hw) hw.dialNumber(text)
            }
            Button {
              id: dialBtn
              text: "Call"
              bordered: true
              foreground: root.fg
              accent: root.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              anchors.verticalCenter: parent.verticalCenter
              enabled: dialField.text.replace(/[^\d+]/g, "").length > 0
              onClicked: if (hw) hw.dialNumber(dialField.text)
            }
          }
        }

        ListView {
          id: callList
          visible: root.page === "inbox" && root.tab === "calls"
          width: parent.width
          height: root.bodyListHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          model: root.calls
          footer: Item {
            width: callList.width
            height: Style.space(40)
            Row {
              anchors.centerIn: parent
              spacing: Style.space(8)
              Button {
                text: "Answer"
                bordered: true
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: if (hw) hw.answerCall()
              }
              Button {
                text: "Hang up"
                bordered: true
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: if (hw) hw.hangupCall()
              }
            }
          }

          delegate: Item {
            required property var modelData
            width: callList.width
            height: Style.space(56)

            Column {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: Style.space(16)
              anchors.rightMargin: Style.space(16)
              spacing: 2
              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: modelData.state
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: (modelData.name ? modelData.name + " · " : "") + modelData.number
                elide: Text.ElideRight
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
            }
          }

          Column {
            visible: root.calls.length === 0
            anchors.centerIn: parent
            spacing: Style.space(10)
            width: parent.width - Style.space(40)
            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              text: root.btFlags.callsEnabled ? "No calls" : "Call control is off"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            Text {
              visible: root.actionNote !== ""
              width: parent.width
              wrapMode: Text.WordWrap
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              text: root.actionNote
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(8)
              Button {
                text: "Answer"
                bordered: true
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: if (hw) hw.answerCall()
              }
              Button {
                text: "Hang up"
                bordered: true
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: if (hw) hw.hangupCall()
              }
            }
          }
        }

        Flickable {
          visible: root.page === "inbox" && root.tab === "link"
          width: parent.width
          height: root.bodyListHeight
          clip: true
          contentWidth: width
          contentHeight: linkCol.implicitHeight
          boundsBehavior: Flickable.StopAtBounds

          Column {
            id: linkCol
            width: parent.width
            leftPadding: Style.space(14)
            rightPadding: Style.space(14)
            topPadding: Style.space(10)
            spacing: Style.space(10)

            Text {
              textFormat: Text.PlainText
              text: "BLUETOOTH"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }
            Text {
              width: parent.width - Style.space(28)
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              text: {
                var p = Model.firstPhone(root.devices)
                if (!p) return "No iPhone on Bluetooth."
                var bits = [p.name]
                if (p.connected) bits.push("connected")
                if (root.status && root.status.map) bits.push("messages live")
                else bits.push("messages not ready")
                return bits.join(" · ")
              }
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            Text {
              visible: {
                var p = Model.firstPhone(root.devices)
                return !!(p && p.address && !p.connected)
              }
              textFormat: Text.PlainText
              text: "Pair iPhone"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  var p = Model.firstPhone(root.devices)
                  if (hw && p) hw.pairBt(p.address)
                }
              }
            }

            Text {
              textFormat: Text.PlainText
              text: "iOS APP"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }
            Text {
              width: parent.width - Style.space(28)
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              text: {
                if (!root.wifiUp)
                  return "Needs LAN."
                if (root.lanDevices.length > 0)
                  return "Paired: " + root.lanDevices.map(function(d) { return d.name }).join(", ")
                if (root.pendingPair && root.pendingPair.fingerprint)
                  return "Pairing request from " + (root.pendingPair.name || "iPhone") + "."
                if (root.lanPeers.length > 0)
                  return "iOS app on the network. Tap this PC in the app."
                return "Open the Tether iOS app."
              }
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            Text {
              visible: root.actionNote !== ""
              width: parent.width - Style.space(28)
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              text: root.actionNote
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Button {
              visible: !!(root.pendingPair && root.pendingPair.fingerprint) && root.lanDevices.length === 0
              text: "Accept iPhone"
              bordered: true
              foreground: root.fg
              accent: root.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              onClicked: if (hw) hw.acceptPending()
            }
            Repeater {
              model: root.lanPeers
              Button {
                required property var modelData
                visible: root.wifiUp
                text: "Pair " + modelData.name
                bordered: true
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: if (hw) hw.pairLan(modelData)
              }
            }
            Repeater {
              model: root.lanDevices
              Button {
                required property var modelData
                visible: root.wifiUp
                text: "Forget " + modelData.name
                bordered: true
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: {
                  root.forgetDevice = modelData
                  root.forgetOpen = true
                }
              }
            }

            Text {
              textFormat: Text.PlainText
              text: "CLIPBOARD"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }
            Row {
              visible: root.wifiUp
              width: parent.width - Style.space(28)
              spacing: Style.space(8)
              TextField {
                id: clipField
                width: parent.width - clipPush.width - Style.space(8)
                placeholderText: "clipboard text"
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                foreground: root.fg
                accent: root.accent
                text: hw ? hw.clipDraft : ""
                onTextChanged: if (hw && text !== hw.clipDraft) hw.clipDraft = text
                onAccepted: if (hw) hw.pushClipboard()
              }
              Button {
                id: clipPush
                text: "Push"
                bordered: true
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: if (hw) hw.pushClipboard()
              }
            }
            Button {
              visible: root.wifiUp
              text: "Pull clipboard"
              bordered: true
              foreground: root.fg
              accent: root.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              onClicked: if (hw) hw.pullClipboard()
            }

            Text {
              textFormat: Text.PlainText
              text: "FILES"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }
            DropArea {
              visible: root.wifiUp
              width: parent.width - Style.space(28)
              height: Style.space(64)
              onDropped: function(drop) {
                if (!hw) return
                var urls = drop.urls || []
                for (var i = 0; i < urls.length; i++) hw.sendDropped(urls[i])
              }
              BorderSurface {
                anchors.fill: parent
                radius: Style.cornerRadius
                color: parent.containsDrag ? root.hoverFill : "transparent"
                borderSpec: Border.controlSpec(parent.containsDrag ? "hover-cursor" : "normal", root.fg, root.accent)
                Text {
                  anchors.centerIn: parent
                  width: parent.width - Style.space(16)
                  wrapMode: Text.WordWrap
                  horizontalAlignment: Text.AlignHCenter
                  textFormat: Text.PlainText
                  text: "Drop files here to send to the iPhone"
                  color: root.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }
            Row {
              visible: root.wifiUp
              width: parent.width - Style.space(28)
              spacing: Style.space(8)
              TextField {
                id: fileField
                width: parent.width - fileBrowse.width - fileSend.width - Style.space(16)
                placeholderText: "~/Downloads"
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                foreground: root.fg
                accent: root.accent
                text: hw ? hw.filePath : ""
                onTextChanged: if (hw && text !== hw.filePath) hw.filePath = text
                onAccepted: if (hw) hw.sendFile()
              }
              Button {
                id: fileBrowse
                text: "Browse"
                bordered: true
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: if (hw) hw.browseFile()
              }
              Button {
                id: fileSend
                text: "Send"
                bordered: true
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                enabled: fileField.text.trim().length > 0
                onClicked: if (hw) hw.sendFile()
              }
            }
          }
        }

        Flickable {
          visible: root.page === "inbox" && root.tab === "settings"
          width: parent.width
          height: root.bodyListHeight
          clip: true
          contentWidth: width
          contentHeight: settingsCol.implicitHeight
          boundsBehavior: Flickable.StopAtBounds

          Column {
            id: settingsCol
            width: parent.width
            leftPadding: Style.space(14)
            rightPadding: Style.space(14)
            topPadding: Style.space(10)
            spacing: Style.space(8)

            Text {
              visible: root.actionNote !== ""
              width: parent.width - Style.space(28)
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              text: root.actionNote
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              textFormat: Text.PlainText
              text: "BLUETOOTH"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }
            Text {
              width: parent.width - Style.space(28)
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              text: {
                var parts = []
                if (root.btStatus && root.btStatus.mode) parts.push("Mode " + root.btStatus.mode)
                if (root.btStatus && root.btStatus.bond) parts.push("bond " + root.btStatus.bond)
                if (root.btStatus && root.btStatus.classOk) parts.push("class ok")
                if (root.btStatus && root.btStatus.tether) parts.push(root.btStatus.tether)
                return parts.length ? parts.join(" · ") : "Loading adapter status…"
              }
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Toggle {
              width: parent.width - Style.space(28)
              label: "Messages (MAP)"
              checked: root.btFlags.enabled
              foreground: root.fg
              accent: root.accent
              fontFamily: root.fontFamily
              titleSize: Style.font.bodySmall
              onClicked: if (hw) hw.setBtFlag("enabled", !root.btFlags.enabled)
            }

            Toggle {
              width: parent.width - Style.space(28)
              label: "Notification mirroring"
              checked: root.btFlags.ancs
              foreground: root.fg
              accent: root.accent
              fontFamily: root.fontFamily
              titleSize: Style.font.bodySmall
              onClicked: if (hw) hw.setBtFlag("ancs", !root.btFlags.ancs)
            }

            Toggle {
              width: parent.width - Style.space(28)
              label: "Notification titles and bodies"
              checked: root.btFlags.ancsContent
              enabled: root.btFlags.ancs
              foreground: root.fg
              accent: root.accent
              fontFamily: root.fontFamily
              titleSize: Style.font.bodySmall
              onClicked: if (hw) hw.setBtFlag("ancsContent", !root.btFlags.ancsContent)
            }

            Toggle {
              visible: !!(root.cliCaps && root.cliCaps.calls)
              width: parent.width - Style.space(28)
              label: "Call control (audio stays on the iPhone)"
              checked: root.btFlags.callsEnabled
              foreground: root.fg
              accent: root.accent
              fontFamily: root.fontFamily
              titleSize: Style.font.bodySmall
              onClicked: if (hw) hw.setBtFlag("callsEnabled", !root.btFlags.callsEnabled)
            }

            Text {
              width: parent.width - Style.space(28)
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              text: root.btFlags.groupMessages
                ? "Group replies are on in Tether."
                : "Group replies stay off until enabled in Tether (MAP has no group thread id)."
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              textFormat: Text.PlainText
              text: "CONTROLLER"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }
            ButtonGroup {
              visible: root.adapterOptions.length > 1
              width: parent.width - Style.space(28)
              options: root.adapterOptions
              value: root.adapterValue
              foreground: root.fg
              background: "transparent"
              accent: root.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              focusable: false
              onChanged: function(v) {
                if (!hw) return
                if (v === root.adapterValue) return
                hw.setAdapter(v)
              }
            }
            Text {
              visible: root.adapterOptions.length <= 1
              width: parent.width - Style.space(28)
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              text: root.btStatus && root.btStatus.adapterId
                ? ("Using " + root.btStatus.adapterId)
                : "No Bluetooth controller reported."
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              visible: root.devices.length > 0
              textFormat: Text.PlainText
              text: "DEVICES"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }
            Repeater {
              model: root.devices
              Column {
                required property var modelData
                width: settingsCol.width - Style.space(28)
                spacing: Style.space(4)
                Text {
                  width: parent.width
                  wrapMode: Text.WordWrap
                  textFormat: Text.PlainText
                  text: (modelData.name || modelData.address) + (modelData.iphone ? " · iPhone" : "")
                  color: root.fg
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
                Text {
                  width: parent.width
                  wrapMode: Text.WordWrap
                  textFormat: Text.PlainText
                  text: Model.deviceSubtitle(modelData)
                  color: root.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
                Row {
                  spacing: Style.space(8)
                  Button {
                    text: "Pair"
                    bordered: true
                    foreground: root.fg
                    accent: root.accent
                    fontFamily: root.fontFamily
                    fontSize: Style.font.caption
                    onClicked: if (hw) hw.pairBt(modelData.address, false)
                  }
                  Button {
                    text: "Explicit"
                    bordered: true
                    foreground: root.fg
                    accent: root.accent
                    fontFamily: root.fontFamily
                    fontSize: Style.font.caption
                    onClicked: if (hw) hw.pairBt(modelData.address, true)
                  }
                }
              }
            }

            Text {
              textFormat: Text.PlainText
              text: "ON DISK"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }
            Text {
              width: parent.width - Style.space(28)
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              text: root.btFlags.retentionReady
                ? "Message history and contacts. Encrypted uses the desktop keyring."
                : "Message history and contacts. Encrypted needs a desktop keyring."
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            ButtonGroup {
              width: parent.width - Style.space(28)
              options: root.retentionOptions
              value: root.btFlags.retention || "encrypted"
              foreground: root.fg
              background: "transparent"
              accent: root.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              focusable: false
              onChanged: function(v) {
                if (!hw) return
                if (v === root.btFlags.retention) return
                if (v === "none") {
                  root.retentionOpen = true
                  return
                }
                hw.setRetention(v)
              }
            }

            Text {
              width: parent.width - Style.space(28)
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              text: "Pairing shows a code on the iPhone. Explicit pair skips connect-first."
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Row {
              spacing: Style.space(8)
              Button {
                text: "Re-advertise"
                bordered: true
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: if (hw) hw.solicit()
              }
              Button {
                text: "Unpair iPhone"
                bordered: true
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: root.unpairOpen = true
              }
            }

            Text {
              textFormat: Text.PlainText
              text: "SETUP"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }
            Text {
              width: parent.width - Style.space(28)
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              text: root.btSetup && root.btSetup.complete
                ? "Bluetooth system setup is complete."
                : (root.btSetup && root.btSetup.text ? root.btSetup.text : "Checking tether --bt-setup…")
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            Row {
              spacing: Style.space(8)
              Button {
                visible: !!(root.btSetup && root.btSetup.text)
                text: "Copy commands"
                bordered: true
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: if (hw) hw.copySetup()
              }
              Button {
                visible: !!(hw && hw.diagnosticsText)
                text: "Copy diagnostics"
                bordered: true
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: if (hw) hw.copyDiagnostics()
              }
            }

            Text {
              textFormat: Text.PlainText
              text: "iOS APP"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }
            Text {
              width: parent.width - Style.space(28)
              wrapMode: Text.WordWrap
              textFormat: Text.PlainText
              text: !root.wifiUp
                ? "Needs LAN."
                : "Paste a pending fingerprint if Accept is not on Link."
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            Row {
              visible: root.wifiUp
              width: parent.width - Style.space(28)
              spacing: Style.space(8)
              TextField {
                id: acceptField
                width: parent.width - acceptBtn.width - Style.space(8)
                placeholderText: "fingerprint"
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                foreground: root.fg
                accent: root.accent
                text: hw ? hw.acceptDraft : ""
                onTextChanged: if (hw && text !== hw.acceptDraft) hw.acceptDraft = text
                onAccepted: if (hw) hw.acceptPair()
              }
              Button {
                id: acceptBtn
                text: "Accept"
                bordered: true
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                enabled: acceptField.text.trim().length > 0
                onClicked: if (hw) hw.acceptPair()
              }
            }
          }
        }

        // ---- thread ----
        Column {
          visible: root.page === "thread"
          width: parent.width
          spacing: 0

          ListView {
            id: msgList
            width: parent.width
            height: root.bodyListHeight
            clip: true
            spacing: Style.space(4)
            boundsBehavior: Flickable.StopAtBounds
            model: root.messages
            onCountChanged: if (count > 0) positionViewAtEnd()

            delegate: Item {
              required property var modelData
              required property int index
              width: msgList.width
              height: bubble.implicitHeight + (stamp.visible ? stamp.implicitHeight + Style.space(2) : 0)

              Rectangle {
                id: bubble
                anchors.left: modelData.mine ? undefined : parent.left
                anchors.right: modelData.mine ? parent.right : undefined
                anchors.leftMargin: Style.space(14)
                anchors.rightMargin: Style.space(14)
                width: Math.min(msgList.width * 0.78, msgBody.implicitWidth + Style.space(20))
                implicitHeight: msgBody.implicitHeight + Style.space(14)
                radius: 10
                color: modelData.mine ? root.selectedFill : root.normalFill

                Text {
                  id: msgBody
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(10)
                  width: msgList.width * 0.72
                  textFormat: Text.PlainText
                  text: modelData.body
                  wrapMode: Text.Wrap
                  color: root.fg
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }
              }

              Text {
                id: stamp
                visible: root.lastInRun(index)
                anchors.top: bubble.bottom
                anchors.topMargin: Style.space(2)
                anchors.left: modelData.mine ? undefined : bubble.left
                anchors.right: modelData.mine ? bubble.right : undefined
                textFormat: Text.PlainText
                text: Model.threadTime(modelData.time)
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }

          Item {
            width: parent.width
            height: root.composeHeight

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)
              anchors.topMargin: Style.space(6)
              anchors.bottomMargin: Style.space(6)
              spacing: Style.space(8)

              TextField {
                id: replyField
                width: parent.width - sendBtn.width - Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                placeholderText: "Message"
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                foreground: root.fg
                accent: root.accent
                enabled: !!(root.selectedThread && root.selectedThread.handle)
                onAccepted: root.sendReplyNow()
              }

              Button {
                id: sendBtn
                text: "Send"
                bordered: true
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                anchors.verticalCenter: parent.verticalCenter
                enabled: replyField.text.trim().length > 0
                onClicked: root.sendReplyNow()
              }
            }
          }
        }

        // ---- notice detail ----
        Column {
          visible: root.page === "notice" && root.selectedNotice
          width: parent.width
          leftPadding: Style.space(14)
          rightPadding: Style.space(14)
          topPadding: Style.space(10)
          bottomPadding: Style.space(12)
          spacing: Style.space(8)

          Text {
            width: parent.width - Style.space(28)
            textFormat: Text.PlainText
            text: root.selectedNotice ? (root.selectedNotice.app || "") : ""
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
          Text {
            width: parent.width - Style.space(28)
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: root.selectedNotice ? (root.selectedNotice.title || "") : ""
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
          Text {
            width: parent.width - Style.space(28)
            wrapMode: Text.Wrap
            visible: !!(root.selectedNotice && root.selectedNotice.body)
            textFormat: Text.PlainText
            text: root.selectedNotice ? (root.selectedNotice.body || "") : ""
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        PanelSeparator {
          visible: root.inboxFooter
          foreground: root.fg
        }

        Item {
          visible: root.inboxFooter
          width: parent.width
          height: visible ? root.inboxFooterH : 0

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(16)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "Contacts"
            color: root.tab === "contacts" ? root.fg : root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (!hw) return
                hw.tab = "contacts"
                if (hw.loadContacts) hw.loadContacts()
              }
            }
          }

          Text {
            anchors.right: parent.right
            anchors.rightMargin: Style.space(16)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "Open Tether"
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: if (hw) hw.openApp()
            }
          }
        }
      }

      ConfirmDialog {
        anchors.fill: parent
        opened: root.unpairOpen
        z: 10
        message: "Remove the Bluetooth bond with this iPhone? Messages will stop until you pair again."
        confirmText: "Unpair"
        cancelText: "Cancel"
        background: Color.popups.background
        foreground: root.fg
        selectedText: root.accent
        fontFamily: root.fontFamily
        onCanceled: root.unpairOpen = false
        onConfirmed: {
          root.unpairOpen = false
          var p = Model.firstPhone(root.devices)
          if (hw && p) hw.unpairBt(p.address)
        }
      }

      ConfirmDialog {
        anchors.fill: parent
        opened: root.retentionOpen
        z: 11
        message: "Delete stored messages and contacts on this PC and keep nothing further?"
        confirmText: "Keep nothing"
        cancelText: "Cancel"
        background: Color.popups.background
        foreground: root.fg
        selectedText: root.accent
        fontFamily: root.fontFamily
        onCanceled: root.retentionOpen = false
        onConfirmed: {
          root.retentionOpen = false
          if (hw) hw.setRetention("none")
        }
      }

      ConfirmDialog {
        anchors.fill: parent
        opened: root.forgetOpen
        z: 12
        message: "Forget this Wi-Fi pairing? Clipboard and files will stop until you pair again."
        confirmText: "Forget"
        cancelText: "Cancel"
        background: Color.popups.background
        foreground: root.fg
        selectedText: root.accent
        fontFamily: root.fontFamily
        onCanceled: {
          root.forgetOpen = false
          root.forgetDevice = null
        }
        onConfirmed: {
          var d = root.forgetDevice
          root.forgetOpen = false
          root.forgetDevice = null
          if (hw && d && d.fingerprint) hw.forgetLan(d.fingerprint)
        }
      }
    }
  }
}

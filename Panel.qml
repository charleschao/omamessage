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
  readonly property var notifications: hw && hw.notifications ? hw.notifications : []
  readonly property var messages: hw && hw.messages ? hw.messages : []
  readonly property string page: hw ? hw.page : "inbox"
  readonly property string tab: hw ? hw.tab : "messages"
  readonly property var selectedThread: hw ? hw.selectedThread : null
  readonly property var selectedNotice: hw ? hw.selectedNotice : null
  readonly property bool cliOk: hw ? hw.cliOk : false
  readonly property bool wifiUp: hw ? hw.wifiUp : false
  readonly property var lanDevices: hw && hw.lanDevices ? hw.lanDevices : []
  readonly property var lanPeers: hw && hw.lanPeers ? hw.lanPeers : []
  readonly property string clipPreview: hw ? hw.clipPreview : ""
  readonly property var recentDownloads: hw && hw.recentDownloads ? hw.recentDownloads : []
  readonly property var btFlags: hw && hw.btFlags ? hw.btFlags : ({ enabled: false, ancs: false, ancsContent: true })
  readonly property var btStatus: hw && hw.btStatus ? hw.btStatus : ({})
  readonly property var btSetup: hw && hw.btSetup ? hw.btSetup : ({ complete: true, text: "" })
  readonly property string actionNote: hw ? hw.actionNote : ""
  readonly property var tabs: [
    { value: "messages", label: "Messages" },
    { value: "notifications", label: "Notify" },
    { value: "link", label: "Link" },
    { value: "settings", label: "Settings" }
  ]
  property bool unpairOpen: false

  readonly property color fg: bar ? bar.foreground : Color.popups.text
  readonly property color muted: Color.muted
  readonly property color accent: Color.accent
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color hoverFill: Style.hoverFillFor(root.fg, root.accent)
  readonly property color selectedFill: Style.selectedFillFor(root.fg, root.accent)
  readonly property color normalFill: Style.normalFillFor(root.fg, root.accent)
  readonly property int paneWidth: Style.space(420)
  readonly property int listHeight: Style.space(360)

  function sendNew() {
    if (!hw) return
    hw.sendTo(newTo.text, newBody.text)
    newBody.text = ""
  }

  function sendReplyNow() {
    if (!hw || !replyField.text.trim()) return
    hw.replyDraft = replyField.text
    hw.sendReply()
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
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(root.paneWidth)
    contentHeight: panel.fittedContentHeight(Style.space(540))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: replyField.activeFocus || newTo.activeFocus || newBody.activeFocus || fileField.activeFocus || clipField.activeFocus || acceptField.activeFocus
      onCloseRequested: {
        if (root.unpairOpen) {
          root.unpairOpen = false
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
          height: headerCol.implicitHeight + Style.space(20)

          Column {
            id: headerCol
            width: parent.width
            leftPadding: Style.space(16)
            rightPadding: Style.space(16)
            topPadding: Style.space(14)
            bottomPadding: Style.space(12)
            spacing: Style.space(10)

            Item {
              width: parent.width - Style.space(32)
              height: Math.max(heroTitle.implicitHeight + heroMeta.implicitHeight + Style.space(2), phoneName.implicitHeight)

              Column {
                anchors.left: parent.left
                anchors.right: phoneName.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                Text {
                  id: heroTitle
                  width: parent.width
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
                Text {
                  id: heroMeta
                  visible: root.page === "inbox"
                  width: parent.width
                  textFormat: Text.PlainText
                  text: Model.heroStatus(root.status)
                  color: root.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1.2
                  elide: Text.ElideRight
                }
              }

              Text {
                id: phoneName
                visible: root.page === "inbox" && !!(Model.firstPhone(root.devices))
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: {
                  var p = Model.firstPhone(root.devices)
                  return p ? p.name : ""
                }
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
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
              fontSize: Style.font.bodySmall
              focusable: false
              onChanged: function(v) {
                if (!hw) return
                if (hw.page !== "inbox") hw.showInbox()
                hw.tab = v
                if (v === "settings" && hw.loadSettings)
                  hw.loadSettings()
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
          height: Style.space(340)
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
                  font.bold: !!(modelData.unread && modelData.unread > 0)
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
                  visible: !!(modelData.unread && modelData.unread > 0)
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
          height: Style.space(56)

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(12)
            anchors.topMargin: Style.space(8)
            anchors.bottomMargin: Style.space(8)
            spacing: Style.space(8)

            TextField {
              id: newTo
              width: Style.space(110)
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

        // ---- inbox: notifications ----
        ListView {
        id: noticeList
        visible: root.page === "inbox" && root.tab === "notifications"
        width: parent.width
        height: Style.space(320)
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
                text: modelData.app || "Notification"
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
              Text {
                width: parent.width
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
            spacing: Style.space(8)
            width: parent.width - Style.space(40)
            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              horizontalAlignment: Text.AlignHCenter
              text: root.status && root.status.ancs
                ? "No mirrored notifications yet"
                : "Notifications need Bluetooth LE. Toggle Bluetooth off/on on the iPhone, or ask Tether to re-advertise."
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            Text {
              visible: !(root.status && root.status.ancs)
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: "Re-advertise permissions"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (hw) hw.solicit()
              }
            }
          }
        }

        Flickable {
          visible: root.page === "inbox" && root.tab === "link"
          width: parent.width
          height: Style.space(360)
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
              width: parent.width - Style.space(28)
              wrapMode: Text.WordWrap
              text: "Bluetooth: messages. Wi-Fi: clipboard, files, iOS app. Tether by Zack Bartel."
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              text: "BLUETOOTH"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }
            Text {
              width: parent.width - Style.space(28)
              wrapMode: Text.WordWrap
              text: {
                var p = Model.firstPhone(root.devices)
                if (!p) return "No iPhone on Bluetooth. Pair in the iPhone Bluetooth menu, then Pair here."
                return p.name + (p.connected ? " — connected" : " — not connected")
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
              text: "iOS APP"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }
            Text {
              width: parent.width - Style.space(28)
              wrapMode: Text.WordWrap
              text: {
                if (!root.wifiUp)
                  return "Connect this PC to the same Wi-Fi or ethernet as the iPhone."
                if (root.lanDevices.length > 0)
                  return "Paired: " + root.lanDevices.map(function(d) { return d.name }).join(", ")
                if (root.lanPeers.length > 0)
                  return root.lanPeers[0].name + " is on the network, not paired yet. Pair, then accept on the iPhone."
                return "Open Tether on the iPhone. This PC is advertising; the app should see it."
              }
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            Button {
              visible: root.wifiUp && root.lanPeers.length > 0 && root.lanDevices.length === 0
              text: "Pair iOS app"
              bordered: true
              foreground: root.fg
              accent: root.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              onClicked: if (hw) hw.pairLan(root.lanPeers[0])
            }

            Text {
              text: "CLIPBOARD"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }
            Text {
              width: parent.width - Style.space(28)
              wrapMode: Text.WordWrap
              text: !root.wifiUp
                ? "Needs a LAN connection."
                : (root.lanDevices.length > 0
                  ? "Pull this PC’s clipboard, or push text to sync it to the iOS app."
                  : "Pull and Push work on this PC. Pair the iOS app above to sync to the phone.")
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
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
                width: parent.width - fileSend.width - Style.space(8)
                placeholderText: "/path/to/file"
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                foreground: root.fg
                accent: root.accent
                text: hw ? hw.filePath : ""
                onTextChanged: if (hw && text !== hw.filePath) hw.filePath = text
                onAccepted: if (hw) hw.sendFile()
              }
              Button {
                id: fileSend
                text: "Send"
                bordered: true
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: if (hw) hw.sendFile()
              }
            }
            Text {
              width: parent.width - Style.space(28)
              wrapMode: Text.WordWrap
              text: "Incoming files land in ~/Downloads."
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Repeater {
              model: root.recentDownloads
              Text {
                required property string modelData
                width: linkCol.width - Style.space(28)
                elide: Text.ElideMiddle
                text: modelData
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }
        }

        Flickable {
          visible: root.page === "inbox" && root.tab === "settings"
          width: parent.width
          height: Style.space(360)
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
              width: parent.width - Style.space(28)
              wrapMode: Text.WordWrap
              text: "Tether by Zack Bartel — this bar only calls the local CLI. OTP, Firefox, and Thunderbird stay in Tether."
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              visible: root.actionNote !== ""
              width: parent.width - Style.space(28)
              wrapMode: Text.WordWrap
              text: root.actionNote
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              text: "BLUETOOTH"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }
            Text {
              width: parent.width - Style.space(28)
              wrapMode: Text.WordWrap
              text: "Toggles are Tether settings. The chips above are the live link (Notify needs Bluetooth LE)."
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              width: parent.width - Style.space(28)
              wrapMode: Text.WordWrap
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

            Row {
              spacing: Style.space(8)
              Button {
                text: "Pair iPhone"
                bordered: true
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: {
                  var p = Model.firstPhone(root.devices)
                  if (hw && p) hw.pairBt(p.address, false)
                }
              }
              Button {
                text: "Explicit pair"
                bordered: true
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: {
                  var p = Model.firstPhone(root.devices)
                  if (hw && p) hw.pairBt(p.address, true)
                }
              }
            }

            Text {
              width: parent.width - Style.space(28)
              wrapMode: Text.WordWrap
              text: "Pairing shows a code on the iPhone. If no dialog appears here, use Open app (tether-gtk). Explicit pair skips connect-first; notifications may not work on that bond."
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
              text: "SETUP"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }
            Text {
              width: parent.width - Style.space(28)
              wrapMode: Text.WordWrap
              text: root.btSetup && root.btSetup.complete
                ? "Bluetooth system setup is complete."
                : (root.btSetup && root.btSetup.text ? root.btSetup.text : "Checking tether --bt-setup…")
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              text: "iOS APP (WIFI)"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }
            Text {
              width: parent.width - Style.space(28)
              wrapMode: Text.WordWrap
              text: !root.wifiUp
                ? "Turn Wi-Fi on this PC, then open Tether on the iPhone on the same LAN."
                : "Paste the fingerprint from the iPhone app to accept a pending pair. Clipboard and files need this pairing."
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

          Item {
            width: parent.width
            height: Style.space(28)
            Text {
              anchors.left: parent.left
              anchors.leftMargin: Style.space(14)
              anchors.verticalCenter: parent.verticalCenter
              text: "← Inbox"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (hw) hw.showInbox()
              }
            }
          }

          ListView {
            id: msgList
            width: parent.width
            height: Style.space(300)
            clip: true
            spacing: Style.space(6)
            boundsBehavior: Flickable.StopAtBounds
            model: root.messages
            onCountChanged: if (count > 0) positionViewAtEnd()

            delegate: Item {
              required property var modelData
              width: msgList.width
              height: bubble.implicitHeight

              Rectangle {
                id: bubble
                anchors.left: modelData.mine ? undefined : parent.left
                anchors.right: modelData.mine ? parent.right : undefined
                anchors.leftMargin: Style.space(14)
                anchors.rightMargin: Style.space(14)
                width: Math.min(msgList.width * 0.78, msgBody.implicitWidth + Style.space(20))
                implicitHeight: msgCol.implicitHeight + Style.space(12)
                radius: 12
                color: modelData.mine ? root.selectedFill : root.normalFill

                Column {
                  id: msgCol
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(10)
                  spacing: 2
                  Text {
                    id: msgBody
                    width: msgList.width * 0.72
                    text: modelData.body
                    wrapMode: Text.Wrap
                    color: root.fg
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                  Text {
                    text: modelData.time
                    color: root.muted
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }
            }
          }

          Rectangle {
            width: parent.width
            height: Style.space(56)
            color: root.normalFill

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)
              anchors.topMargin: Style.space(8)
              anchors.bottomMargin: Style.space(8)
              spacing: Style.space(8)

              TextField {
                id: replyField
                width: parent.width - sendBtn.width - Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                placeholderText: "Type a message"
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
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
            text: "← Inbox"
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: if (hw) hw.showInbox()
            }
          }
          Text {
            width: parent.width - Style.space(28)
            text: root.selectedNotice ? (root.selectedNotice.app || "") : ""
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
          Text {
            width: parent.width - Style.space(28)
            wrapMode: Text.Wrap
            text: root.selectedNotice ? (root.selectedNotice.title || "") : ""
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
          Text {
            width: parent.width - Style.space(28)
            wrapMode: Text.Wrap
            visible: !!(root.selectedNotice && root.selectedNotice.body)
            text: root.selectedNotice ? (root.selectedNotice.body || "") : ""
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        PanelSeparator { foreground: root.fg }

        Item {
          width: parent.width
          height: Style.space(32)
          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(16)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "Tether by Zack Bartel"
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
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
    }
  }
}

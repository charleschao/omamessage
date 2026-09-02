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
  readonly property string clipPreview: hw ? hw.clipPreview : ""
  readonly property var recentDownloads: hw && hw.recentDownloads ? hw.recentDownloads : []
  readonly property var tabs: [
    { id: "messages", label: "Messages" },
    { id: "notifications", label: "Notifications" },
    { id: "link", label: "Link" }
  ]

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
    contentHeight: panel.fittedContentHeight(Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: replyField.activeFocus || newTo.activeFocus || newBody.activeFocus || fileField.activeFocus || clipField.activeFocus
      onCloseRequested: {
        if (root.page !== "inbox" && hw) hw.showInbox()
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: shell
        width: parent.width
        spacing: 0

        // ---- header: devices ----
        Column {
          width: parent.width
          leftPadding: Style.space(14)
          rightPadding: Style.space(14)
          topPadding: Style.space(12)
          bottomPadding: Style.space(10)
          spacing: Style.space(8)

          Row {
            spacing: Style.space(8)
            Text {
              text: root.page === "thread" && root.selectedThread
                ? root.selectedThread.name
                : (root.page === "notice" ? "Notification" : "Omamessage")
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
            }
            Text {
              visible: root.page === "inbox"
              text: Model.statusTitle(root.status)
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 0.8
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Flow {
            width: parent.width - Style.space(28)
            spacing: Style.space(6)
            visible: root.page === "inbox"
            Repeater {
              model: root.devices
              BorderSurface {
                required property var modelData
                height: Style.space(22)
                implicitWidth: chipLabel.implicitWidth + Style.space(16)
                radius: height / 2
                color: modelData.connected ? root.selectedFill : "transparent"
                borderSpec: Border.controlSpec(modelData.connected ? "selected" : "normal", root.fg, root.accent)

                Row {
                  id: chipLabel
                  anchors.centerIn: parent
                  spacing: Style.space(6)
                  Rectangle {
                    width: 7
                    height: 7
                    radius: 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: modelData.connected ? root.accent : root.muted
                  }
                  Text {
                    text: modelData.name
                    color: modelData.connected ? root.fg : root.muted
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }
            }
            Text {
              visible: root.devices.length === 0
              text: root.cliOk ? "No Bluetooth devices yet" : "tether CLI not running"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Text {
            visible: root.page === "inbox" && !root.wifiUp
            width: parent.width - Style.space(28)
            wrapMode: Text.WordWrap
            text: "Wi-Fi is off — clipboard, files, and iOS pairing stay disabled. Bluetooth messages still work."
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
          Row {
            visible: root.page === "inbox"
            spacing: Style.space(6)
            Repeater {
              model: root.tabs
              Button {
                required property var modelData
                text: modelData.label
                selected: root.tab === modelData.id
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: {
                  if (!hw) return
                  hw.tab = modelData.id
                  if (hw.page !== "inbox") hw.showInbox()
                  hw.tab = modelData.id
                }
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
        height: Style.space(280)
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          spacing: 0
          model: root.threads

          delegate: Item {
            required property var modelData
            width: threadList.width
            height: Style.space(56)

            Rectangle {
              anchors.fill: parent
              color: rowHover.containsMouse ? root.hoverFill : "transparent"
            }

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(14)
              anchors.rightMargin: Style.space(14)
              spacing: Style.space(10)

              Rectangle {
                width: Style.space(32)
                height: Style.space(32)
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: root.hoverFill
                Text {
                  anchors.centerIn: parent
                  text: Model.initials(modelData.name)
                  color: root.fg
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              Column {
                width: parent.width - Style.space(90)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                  width: parent.width
                  text: modelData.name
                  elide: Text.ElideRight
                  color: root.fg
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }
                Text {
                  width: parent.width
                  text: modelData.preview
                  elide: Text.ElideRight
                  color: root.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: String(modelData.time).slice(11)
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
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
            text: root.status && root.status.map ? "No conversations yet" : "Messages not connected"
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        Rectangle {
        visible: root.page === "inbox" && root.tab === "messages"
        width: parent.width
        height: Style.space(92)
        color: root.normalFill

          Column {
            anchors.fill: parent
            anchors.margins: Style.space(10)
            spacing: Style.space(6)

            Text {
              text: "New message"
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              TextField {
                id: newTo
                width: Math.round(parent.width * 0.34)
                placeholderText: "Number or email"
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                foreground: root.fg
                accent: root.accent
              }

              TextField {
                id: newBody
                width: parent.width - newTo.width - newSend.width - Style.space(16)
                placeholderText: "Type a new message"
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
                : (root.lanDevices.length > 0
                  ? root.lanDevices.map(function(d) { return d.name }).join(", ")
                  : "No iOS app paired. Open Tether on the iPhone while this PC is on Wi-Fi.")
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
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
              text: root.wifiUp
                ? "Pull this PC’s clipboard, or push text so Tether can sync it to the iOS app."
                : "Needs Wi-Fi + iOS app."
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
          height: Style.space(36)
          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(14)
            anchors.verticalCenter: parent.verticalCenter
            text: "Zack Bartel · github.com/zackb/tether"
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
          Text {
            anchors.right: parent.right
            anchors.rightMargin: Style.space(14)
            anchors.verticalCenter: parent.verticalCenter
            text: "Open app"
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
    }
  }
}

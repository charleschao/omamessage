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
  readonly property var messages: hw && hw.messages ? hw.messages : []
  readonly property var contacts: hw && hw.contacts ? hw.contacts : []
  readonly property var calls: hw && hw.calls ? hw.calls : []
  readonly property var notifications: hw && hw.notifications ? hw.notifications : []
  readonly property var ringingCall: hw ? hw.ringingCall : null
  readonly property string page: hw ? hw.page : "inbox"
  readonly property string tab: hw ? hw.tab : "messages"
  readonly property var selectedThread: hw ? hw.selectedThread : null
  readonly property bool daemonOk: hw ? hw.daemonOk : false
  readonly property bool mapUp: hw ? hw.mapUp : false
  readonly property bool ancsUp: hw ? hw.ancsUp : false
  readonly property bool sending: hw ? hw.sending : false
  readonly property bool sendFailed: hw ? hw.sendFailed : false
  readonly property bool messagesLoading: hw ? hw.messagesLoading : false
  readonly property string actionNote: hw ? hw.actionNote : ""
  readonly property bool repliable: !!(root.selectedThread && root.selectedThread.repliable)
  readonly property bool inboxMode: root.page === "inbox"
  readonly property bool messagesTab: root.inboxMode && root.tab === "messages"
  readonly property bool noticesTab: root.inboxMode && root.tab === "notifications"

  property string searchQuery: ""
  property int cursorIndex: 0
  property bool cursorActive: false

  readonly property var visibleThreads: Model.filterThreads(root.threads, root.searchQuery)
  readonly property var visibleNotices: Model.filterNotifications(root.notifications, root.searchQuery)
  readonly property var contactSuggestions: Model.flattenContactSuggestions(root.contacts)
  readonly property var transcript: Model.decorateTranscript(root.messages, Date.now() / 1000, !!(root.selectedThread && root.selectedThread.group))
  readonly property bool showSetup: root.messagesTab && !root.mapUp && root.threads.length === 0
  readonly property var phone: Model.firstPhone(root.devices)
  readonly property var tabOptions: [
    {
      value: "messages",
      label: root.unreadCountLabel
    },
    {
      value: "notifications",
      label: root.noticeCountLabel
    }
  ]
  readonly property string unreadCountLabel: {
    var n = hw ? hw.unreadCount : 0
    return n > 0 ? "Messages " + (n > 99 ? "99+" : String(n)) : "Messages"
  }
  readonly property string noticeCountLabel: {
    var n = hw ? hw.noticeCount : 0
    return n > 0 ? "Notifications " + (n > 99 ? "99+" : String(n)) : "Notifications"
  }
  readonly property var inboxList: root.noticesTab ? root.visibleNotices : root.visibleThreads

  readonly property color fg: bar ? bar.foreground : Color.popups.text
  readonly property color muted: Color.muted
  readonly property color accent: Color.accent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color hoverFill: Style.hoverFillFor(root.fg, root.accent)
  readonly property color inFill: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.10)
  readonly property color outFill: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.40)
  readonly property int paneWidth: Style.space(420)
  readonly property int panelBodyHeight: Style.space(540)
  readonly property int composeHeight: Style.space(48)
  readonly property int composeH: {
    if (root.page === "thread") return root.composeHeight
    if (root.page === "compose") return root.composeHeight
    return 0
  }
  readonly property int bannerH: {
    var h = 0
    if (root.ringingCall) h += Style.space(44)
    else if (!root.mapUp && !root.showSetup && !root.noticesTab) h += Style.space(36)
    return h
  }
  readonly property int tabRowH: root.inboxMode ? Style.space(48) : 0
  readonly property int searchRowH: {
    if (root.page === "thread" || root.page === "compose") return Style.space(52)
    if (root.inboxMode) return Style.space(52)
    return 0
  }
  readonly property int headerH: root.tabRowH + root.searchRowH
  readonly property int noteH: {
    if (root.actionNote === "") return 0
    if (root.page !== "thread" && root.page !== "compose" && !root.noticesTab) return 0
    if (root.sendFailed && (root.page === "thread" || root.page === "compose")) return Style.space(36)
    return Style.space(28)
  }
  readonly property int bodyListHeight: {
    var h = root.panelBodyHeight - root.headerH - root.bannerH - Style.space(2)
    h -= root.composeH
    h -= root.noteH
    if (h < Style.space(200)) h = Style.space(200)
    return h
  }

  function clampCursor() {
    var n = root.inboxList.length
    if (n <= 0) {
      root.cursorIndex = 0
      return
    }
    if (root.cursorIndex < 0) root.cursorIndex = 0
    if (root.cursorIndex >= n) root.cursorIndex = n - 1
  }

  function openCursor() {
    if (root.page !== "inbox") return
    var list = root.inboxList
    if (!list.length) return
    root.clampCursor()
    if (!hw) return
    if (root.noticesTab) hw.activateNotice(list[root.cursorIndex])
    else hw.openThread(list[root.cursorIndex])
  }

  function dismissCursor() {
    if (!root.noticesTab || !hw) return
    var list = root.visibleNotices
    if (!list.length) return
    root.clampCursor()
    hw.dismissNotice(list[root.cursorIndex])
  }

  function switchTab(delta) {
    if (!hw || root.page !== "inbox") return
    hw.setTab(delta > 0 ? "notifications" : "messages")
    root.cursorIndex = 0
    root.cursorActive = false
    root.searchQuery = ""
  }

  function focusComposer() {
    if (root.page === "thread" && replyField.enabled)
      replyField.forceActiveFocus()
    else if (root.page === "compose") {
      if (composeField.enabled && toField.text.replace(/^\s+|\s+$/g, ""))
        composeField.forceActiveFocus()
      else
        toField.forceActiveFocus()
    }
  }

  function sendReplyNow() {
    if (!hw || !replyField.text.replace(/^\s+|\s+$/g, "") || !root.selectedThread) return
    if (!hw.sendTo(root.selectedThread.handle, replyField.text)) return
    // Keep the binding. Assigning replyField.text breaks it and the field
    // stops taking clicks after the send-disable cycle.
    hw.replyDraft = ""
    msgList.pinToEnd = true
    Qt.callLater(function() {
      root.focusComposer()
      if (msgList.count > 0) msgList.positionViewAtEnd()
    })
  }

  function sendComposeNow() {
    if (!hw) return
    hw.composeTo = toField.text
    hw.composeBody = composeField.text
    if (!hw.sendNew()) return
    hw.composeBody = ""
    Qt.callLater(root.focusComposer)
  }

  function open() {
    root.cursorActive = false
    root.controller.show()
  }
  function close() { root.controller.hide() }
  function toggle() {
    if (root.opened) root.close()
    else {
      if (hw && hw.pullState) hw.pullState()
      root.open()
    }
  }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  onInboxListChanged: root.clampCursor()
  onSearchQueryChanged: root.cursorIndex = 0
  onTabChanged: {
    root.cursorIndex = 0
    root.cursorActive = false
  }

  Connections {
    target: hw
    function onPageChanged() {
      if (root.page === "thread") {
        msgList.pinToEnd = true
        Qt.callLater(root.focusComposer)
      } else if (root.page === "compose")
        Qt.callLater(root.focusComposer)
      else
        Qt.callLater(function() { keyCatcher.forceActiveFocus() })
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
      blocked: searchField.activeFocus || replyField.activeFocus || toField.activeFocus || composeField.activeFocus
      onCloseRequested: {
        if (root.page !== "inbox" && hw) hw.backToList()
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (dx !== 0 && root.page !== "inbox" && hw) {
          if (dx < 0) hw.backToList()
          return
        }
        if (dx !== 0 && root.page === "inbox") {
          root.switchTab(dx)
          return
        }
        if (root.page !== "inbox") return
        root.cursorActive = true
        root.cursorIndex += dy
        root.clampCursor()
        if (root.noticesTab) {
          noticeList.currentIndex = root.cursorIndex
          noticeList.positionViewAtIndex(root.cursorIndex, ListView.Contain)
        } else {
          threadList.currentIndex = root.cursorIndex
          threadList.positionViewAtIndex(root.cursorIndex, ListView.Contain)
        }
      }
      onActivateRequested: root.openCursor()
      onDeleteRequested: root.dismissCursor()
      onTextKey: function(t) {
        if (t === "/") {
          searchField.forceActiveFocus()
          return
        }
        if (t === "n" && hw) hw.showCompose()
      }

      Column {
        id: shell
        width: parent.width
        spacing: 0

        // Incoming / live call
        Item {
          visible: !!root.ringingCall
          width: parent.width
          height: visible ? Style.space(44) : 0

          Rectangle {
            anchors.fill: parent
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16)
          }

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(16)
            anchors.right: callBtns.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: Model.callTitle(root.ringingCall) + " · " + Model.callParty(root.ringingCall)
            elide: Text.ElideRight
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }

          Row {
            id: callBtns
            anchors.right: parent.right
            anchors.rightMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)
            Button {
              visible: !!(root.ringingCall && root.ringingCall.ringing)
              text: "Answer"
              bordered: true
              foreground: root.fg
              accent: root.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              onClicked: if (hw) hw.answerCall()
            }
            Button {
              text: root.ringingCall && root.ringingCall.ringing ? "Decline" : "Hang up"
              bordered: true
              foreground: root.fg
              accent: root.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              onClicked: if (hw) hw.hangupCall()
            }
          }
        }

        // Quiet status while the inbox is still usable
        Item {
          visible: !root.mapUp && !root.showSetup && !root.ringingCall
          width: parent.width
          height: visible ? Style.space(36) : 0

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(16)
            anchors.right: bannerAction.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: Model.statusTitle(root.status, root.daemonOk)
            elide: Text.ElideRight
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            id: bannerAction
            anchors.right: parent.right
            anchors.rightMargin: Style.space(16)
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: "Tether…"
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            MouseArea {
              anchors.fill: parent
              anchors.margins: -Style.space(4)
              cursorShape: Qt.PointingHandCursor
              onClicked: if (hw) hw.openApp()
            }
          }
        }

        // Header
        Column {
          width: parent.width
          spacing: 0

          Item {
            visible: root.inboxMode
            width: parent.width
            height: visible ? root.tabRowH : 0

            ButtonGroup {
              id: tabGroup
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)
              anchors.verticalCenter: parent.verticalCenter
              options: root.tabOptions
              value: root.tab
              foreground: root.fg
              background: "transparent"
              accent: root.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              focusable: false
              onChanged: function(v) {
                if (!hw || v === root.tab) return
                hw.setTab(v)
                root.searchQuery = ""
              }
            }
          }

          Item {
            visible: root.inboxMode
            width: parent.width
            height: visible ? root.searchRowH : 0

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)
              anchors.topMargin: Style.space(8)
              anchors.bottomMargin: Style.space(8)
              spacing: Style.space(8)

              TextField {
                id: searchField
                width: parent.width - (newBtn.visible ? newBtn.width + Style.space(8) : 0)
                anchors.verticalCenter: parent.verticalCenter
                placeholderText: root.noticesTab ? "Search notifications" : "Search"
                maximumLength: Model.MAX_NAME
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                foreground: root.fg
                accent: root.accent
                text: root.searchQuery
                onTextChanged: if (text !== root.searchQuery) root.searchQuery = text
                Keys.onEscapePressed: function(event) {
                  if (root.searchQuery) {
                    root.searchQuery = ""
                    event.accepted = true
                  } else {
                    keyCatcher.forceActiveFocus()
                    event.accepted = true
                  }
                }
              }

              Button {
                id: newBtn
                visible: root.messagesTab
                text: "New"
                bordered: true
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                anchors.verticalCenter: parent.verticalCenter
                enabled: root.mapUp
                onClicked: if (hw) hw.showCompose()
              }
            }
          }

          Item {
            visible: root.page !== "inbox"
            width: parent.width
            height: visible ? root.searchRowH : 0

            Text {
              id: backLink
              anchors.left: parent.left
              anchors.leftMargin: Style.space(16)
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
                onClicked: if (hw) hw.backToList()
              }
            }

            Column {
              anchors.left: backLink.right
              anchors.leftMargin: Style.space(8)
              anchors.right: parent.right
              anchors.rightMargin: Style.space(16)
              anchors.verticalCenter: parent.verticalCenter
              spacing: 0
              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: root.page === "compose"
                  ? "New message"
                  : (root.selectedThread ? root.selectedThread.name : "")
                elide: Text.ElideRight
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }
              Text {
                visible: root.page === "thread" && !!root.selectedThread && !root.repliable && !!root.selectedThread.replyReason
                width: parent.width
                textFormat: Text.PlainText
                text: root.selectedThread ? root.selectedThread.replyReason : ""
                elide: Text.ElideRight
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }
        }

        PanelSeparator { foreground: root.fg }

        // Setup empty
        Item {
          visible: root.showSetup
          width: parent.width
          height: root.bodyListHeight

          Column {
            anchors.centerIn: parent
            width: parent.width - Style.space(48)
            spacing: Style.space(12)
            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              text: Model.statusTitle(root.status, root.daemonOk)
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }
            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              text: Model.setupHint(root.status, root.daemonOk)
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            Text {
              visible: !!(root.phone && root.phone.name)
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              text: root.phone ? root.phone.name : ""
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(8)
              Button {
                text: "Open Tether"
                bordered: true
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: if (hw) hw.openApp()
              }
              Button {
                visible: Model.needsSolicit(root.status)
                text: "Ask iPhone"
                bordered: true
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: if (hw) hw.solicit()
              }
            }
          }
        }

        // Conversation list
        ListView {
          id: threadList
          visible: root.messagesTab && !root.showSetup
          width: parent.width
          height: root.bodyListHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          spacing: 0
          model: root.visibleThreads
          currentIndex: root.cursorIndex

          delegate: Item {
            id: threadRow
            required property var modelData
            required property int index
            width: threadList.width
            height: Style.space(56)
            readonly property bool current: index === root.cursorIndex
            readonly property bool unread: (modelData.unread || 0) > 0

            Rectangle {
              anchors.fill: parent
              color: rowHover.containsMouse || (threadRow.current && root.cursorActive) ? root.hoverFill : "transparent"
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
                  font.bold: threadRow.unread
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
                  text: Model.formatThreadTime(modelData.timestamp)
                  color: root.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
                Rectangle {
                  visible: threadRow.unread
                  anchors.right: parent.right
                  height: Style.space(16)
                  width: Math.max(height, unreadLbl.implicitWidth + Style.space(8))
                  radius: height / 2
                  color: root.accent
                  Text {
                    id: unreadLbl
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: modelData.unread > 99 ? "99+" : String(modelData.unread)
                    color: Color.popups.background
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }
            }

            MouseArea {
              id: rowHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.cursorActive = false
                root.cursorIndex = index
                if (hw) hw.openThread(modelData)
              }
            }
          }

          Text {
            visible: root.visibleThreads.length === 0
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: root.searchQuery ? "No matches" : "No conversations yet"
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        // Notifications
        ListView {
          id: noticeList
          visible: root.noticesTab
          width: parent.width
          height: root.bodyListHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          spacing: 0
          model: root.visibleNotices
          currentIndex: root.cursorIndex

          delegate: Item {
            id: noticeRow
            required property var modelData
            required property int index
            width: noticeList.width
            height: noticeBody.implicitHeight + Style.space(16)
            readonly property bool current: index === root.cursorIndex

            HoverHandler {
              id: nHover
              cursorShape: Qt.PointingHandCursor
            }

            MouseArea {
              z: -1
              anchors.fill: parent
              onClicked: {
                root.cursorActive = false
                root.cursorIndex = index
                if (hw) hw.activateNotice(modelData)
              }
            }

            Rectangle {
              anchors.fill: parent
              color: nHover.hovered || (noticeRow.current && root.cursorActive) ? root.hoverFill : "transparent"
            }

            Column {
              id: noticeBody
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: Style.space(16)
              anchors.rightMargin: Style.space(16)
              anchors.verticalCenter: parent.verticalCenter
              spacing: 2

              Item {
                width: parent.width
                height: Math.max(noticeApp.implicitHeight, noticeMeta.height)

                Text {
                  id: noticeApp
                  anchors.left: parent.left
                  anchors.right: noticeMeta.left
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: modelData.app || "Notification"
                  elide: Text.ElideRight
                  color: root.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Row {
                  id: noticeMeta
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(2)

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: Model.formatThreadTime(modelData.timestamp)
                    color: root.muted
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }

                  PanelActionButton {
                    visible: !!modelData.negative
                    iconText: "󰅖"
                    tooltipText: "Dismiss"
                    foreground: root.muted
                    hoverColor: root.fg
                    fontFamily: root.fontFamily
                    fontSize: Style.font.caption
                    onClicked: if (hw) hw.dismissNotice(modelData)
                  }
                }
              }

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: modelData.primary || ""
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
              Text {
                visible: !!modelData.secondary
                width: parent.width
                textFormat: Text.PlainText
                text: modelData.secondary || ""
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
              Button {
                visible: !!modelData.otp
                text: "Copy " + modelData.otp
                bordered: true
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                onClicked: if (hw) hw.copyText(modelData.otp)
              }
            }
          }

          Column {
            visible: root.visibleNotices.length === 0
            anchors.centerIn: parent
            width: parent.width - Style.space(48)
            spacing: Style.space(12)
            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              text: {
                if (root.searchQuery) return "No matches"
                if (root.ancsUp) return "No notifications yet"
                return Model.statusTitle(root.status, root.daemonOk)
              }
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }
            Text {
              visible: !root.searchQuery && !root.ancsUp
              width: parent.width
              wrapMode: Text.WordWrap
              horizontalAlignment: Text.AlignHCenter
              textFormat: Text.PlainText
              text: Model.ancsHint(root.status, root.daemonOk)
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
            Row {
              visible: !root.ancsUp && !root.searchQuery
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(8)
              Button {
                text: "Open Tether"
                bordered: true
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: if (hw) hw.openApp()
              }
              Button {
                visible: Model.needsSolicit(root.status)
                text: "Ask iPhone"
                bordered: true
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: if (hw) hw.solicit()
              }
            }
          }
        }

        // Transcript
        ListView {
          id: msgList
          visible: root.page === "thread"
          width: parent.width
          height: root.bodyListHeight
          clip: true
          spacing: Style.space(2)
          boundsBehavior: Flickable.StopAtBounds
          model: root.transcript
          property bool pinToEnd: true
          onMovementEnded: pinToEnd = atYEnd
          onCountChanged: if (pinToEnd && count > 0) positionViewAtEnd()

          Text {
            visible: root.messagesLoading && root.messages.length === 0
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "Loading…"
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          delegate: Item {
            required property var modelData
            width: msgList.width
            height: modelData.kind === "day" ? dayLbl.implicitHeight + Style.space(16) : bubbleCol.implicitHeight

            Text {
              id: dayLbl
              visible: modelData.kind === "day"
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: modelData.label || ""
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Column {
              id: bubbleCol
              visible: modelData.kind === "msg"
              anchors.left: modelData.mine ? undefined : parent.left
              anchors.right: modelData.mine ? parent.right : undefined
              anchors.leftMargin: Style.space(14)
              anchors.rightMargin: Style.space(14)
              spacing: Style.space(4)
              opacity: modelData.pending ? 0.65 : 1

              Text {
                visible: !!modelData.showName
                anchors.left: parent.left
                textFormat: Text.PlainText
                text: modelData.name || ""
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              Rectangle {
                id: bubble
                width: msgBody.width + Style.space(24)
                implicitHeight: msgBody.implicitHeight + Style.space(16)
                radius: 14
                color: modelData.failed
                  ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                  : (modelData.mine ? root.outFill : root.inFill)

                Text {
                  id: msgBody
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(12)
                  width: Math.min(msgList.width * 0.70, implicitWidth)
                  textFormat: Text.StyledText
                  text: modelData.html || ""
                  wrapMode: Text.Wrap
                  color: root.fg
                  linkColor: root.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  onLinkActivated: function(link) {
                    var href = Model.parseHttpsUrl(link)
                    if (href) Qt.openUrlExternally(href)
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  acceptedButtons: Qt.LeftButton | Qt.RightButton
                  propagateComposedEvents: true
                  onClicked: function(mouse) {
                    if (mouse.button === Qt.RightButton) {
                      if (hw && modelData.body) hw.copyText(modelData.body)
                      mouse.accepted = true
                    } else {
                      mouse.accepted = false
                    }
                  }
                  onPressAndHold: if (hw && modelData.body) hw.copyText(modelData.body)
                }
              }

              Text {
                visible: !!modelData.showStamp && !!modelData.stamp
                anchors.left: modelData.mine ? undefined : parent.left
                anchors.right: modelData.mine ? parent.right : undefined
                textFormat: Text.PlainText
                text: modelData.stamp || ""
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              Button {
                visible: !!modelData.otp
                text: "Copy " + modelData.otp
                bordered: true
                foreground: root.fg
                accent: root.accent
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                onClicked: if (hw) hw.copyText(modelData.otp)
              }
            }
          }
        }

        // Compose new: To + suggestions
        Column {
          visible: root.page === "compose"
          width: parent.width
          height: root.bodyListHeight
          spacing: 0

          Item {
            width: parent.width
            height: root.composeHeight
            TextField {
              id: toField
              anchors.fill: parent
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)
              anchors.topMargin: Style.space(6)
              anchors.bottomMargin: Style.space(6)
              placeholderText: "To"
              maximumLength: Model.MAX_HANDLE
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              foreground: root.fg
              accent: root.accent
              text: hw ? hw.composeTo : ""
              onTextChanged: {
                if (hw && text !== hw.composeTo) hw.composeTo = text
                if (hw) hw.searchContacts(text)
              }
              onAccepted: composeField.forceActiveFocus()
              Keys.onEscapePressed: function(event) {
                if (hw) hw.backToList()
                event.accepted = true
              }
            }
          }

          ListView {
            id: suggestList
            width: parent.width
            height: parent.height - root.composeHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.contactSuggestions

            delegate: Item {
              required property var modelData
              width: suggestList.width
              height: Style.space(48)

              Rectangle {
                anchors.fill: parent
                color: sHover.containsMouse ? root.hoverFill : "transparent"
              }

              Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Style.space(16)
                anchors.rightMargin: Style.space(16)
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
                }
                Text {
                  width: parent.width
                  textFormat: Text.PlainText
                  text: modelData.label
                  elide: Text.ElideRight
                  color: root.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              MouseArea {
                id: sHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (hw) hw.openContactHandle({ name: modelData.name }, modelData.handle)
              }
            }

            Text {
              visible: root.contactSuggestions.length === 0
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: {
                if (!(root.status && root.status.pbap)) return "Contacts not connected"
                if (toField.text.replace(/^\s+|\s+$/g, "")) return "No matches. Send will message this address."
                return "Type a name or number"
              }
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }

        // Thread compose
        Item {
          visible: root.page === "thread"
          width: parent.width
          height: root.composeHeight
          z: 1

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
              placeholderText: root.repliable ? "Message" : "Can't reply here"
              maximumLength: Model.MAX_BODY
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              foreground: root.fg
              accent: root.accent
              // Do not bind enabled to sending. A disabled QQC TextField in this
              // panel drops mouse hits to the card MouseArea, then never takes
              // them back after the Bluetooth send finishes.
              enabled: root.repliable && root.mapUp
              text: hw ? hw.replyDraft : ""
              onTextChanged: if (hw && text !== hw.replyDraft) hw.replyDraft = text
              onAccepted: root.sendReplyNow()
              Keys.onEscapePressed: function(event) {
                if (hw) hw.backToList()
                event.accepted = true
              }
            }

            Button {
              id: sendBtn
              text: root.sending ? "Sending…" : "Send"
              bordered: true
              foreground: root.fg
              accent: root.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              anchors.verticalCenter: parent.verticalCenter
              enabled: root.repliable && root.mapUp && !root.sending && replyField.text.replace(/^\s+|\s+$/g, "").length > 0
              onClicked: root.sendReplyNow()
            }
          }
        }

        // New-message compose
        Item {
          visible: root.page === "compose"
          width: parent.width
          height: root.composeHeight
          z: 1

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(12)
            anchors.topMargin: Style.space(6)
            anchors.bottomMargin: Style.space(6)
            spacing: Style.space(8)

            TextField {
              id: composeField
              width: parent.width - composeSend.width - Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              placeholderText: "Message"
              maximumLength: Model.MAX_BODY
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              foreground: root.fg
              accent: root.accent
              enabled: root.mapUp
              text: hw ? hw.composeBody : ""
              onTextChanged: if (hw && text !== hw.composeBody) hw.composeBody = text
              onAccepted: root.sendComposeNow()
              Keys.onEscapePressed: function(event) {
                if (hw) hw.backToList()
                event.accepted = true
              }
            }

            Button {
              id: composeSend
              text: root.sending ? "Sending…" : "Send"
              bordered: true
              foreground: root.fg
              accent: root.accent
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              anchors.verticalCenter: parent.verticalCenter
              enabled: root.mapUp && !root.sending && toField.text.replace(/^\s+|\s+$/g, "").length > 0 && composeField.text.replace(/^\s+|\s+$/g, "").length > 0
              onClicked: root.sendComposeNow()
            }
          }
        }

        Item {
          visible: root.actionNote !== "" && (root.page === "thread" || root.page === "compose" || root.noticesTab)
          width: parent.width
          height: visible ? root.noteH : 0

          Text {
            anchors.left: parent.left
            anchors.right: retryBtn.visible ? retryBtn.left : parent.right
            anchors.leftMargin: Style.space(16)
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: root.actionNote
            color: root.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Button {
            id: retryBtn
            visible: root.sendFailed && (root.page === "thread" || root.page === "compose")
            anchors.right: parent.right
            anchors.rightMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            text: "Retry"
            bordered: true
            foreground: root.fg
            accent: root.accent
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            onClicked: if (hw) hw.retrySend()
          }
        }
      }
    }
  }
}

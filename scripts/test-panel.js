#!/usr/bin/env node
"use strict"

const assert = require("node:assert/strict")
const fs = require("node:fs")
const os = require("node:os")
const path = require("node:path")
const vm = require("node:vm")
const { spawnSync } = require("node:child_process")

const qml = fs.readFileSync(path.join(__dirname, "..", "Panel.qml"), "utf8")
const textKeys = qml.match(/onTextKey: function\(t\) \{([^]*?)^      }/m)
assert(textKeys, "panel text-key handler found")
let back = 0
let searches = 0
let tab = ""
const root = { page: "thread", get inboxMode() { return this.page === "inbox" } }
const context = vm.createContext({ root,
  hw: { backToList() { back++ }, setTab(value) { tab = value } },
  searchField: { forceActiveFocus() { searches++ } }
})
vm.runInContext(`function key(t) { ${textKeys[1]} }`, context)
context.key("b")
assert.equal(back, 1)
context.key("/")
assert.equal(searches, 0, "thread shortcut must not focus hidden search")
root.page = "inbox"
context.key("/")
assert.equal(searches, 1)
context.key("n")
assert.equal(tab, "notifications")

// Run the actual transcript layout handlers in Qt, with a focused composer.
// This reproduces the off-screen-reply bug and verifies model resets whose
// count stays the same, without connecting to Tether or opening a desktop pane.
const start = qml.indexOf("          property bool pinToEnd: true", qml.indexOf("// Transcript"))
const end = qml.indexOf("\n\n          Text {", start)
assert(start >= 0 && end > start, "transcript layout handlers found")
const runner = fs.existsSync("/usr/lib/qt6/bin/qmltestrunner")
  ? "/usr/lib/qt6/bin/qmltestrunner" : "qmltestrunner"
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "omamessage-panel-test-"))
try {
  const file = path.join(tmp, "tst_transcript.qml")
  fs.writeFileSync(file, `import QtQuick
import QtTest
Item {
  width: 420; height: 540
  ListView {
    id: msgList
    width: 400; height: 300
    clip: true
    model: []
${qml.slice(start, end)}
    delegate: Rectangle {
      required property var modelData
      width: 380
      height: modelData
    }
  }
  TextInput { id: reply; y: 320; text: "keep typing"; focus: true }
  TestCase {
    name: "LiveReplyScroll"
    when: windowShown
    function rows(n, height) {
      var out = []
      for (var i = 0; i < n; i++) out.push(height)
      return out
    }
    function test_liveReply() {
      msgList.model = rows(30, 50)
      wait(50)
      tryCompare(msgList, "atYEnd", true)
      reply.forceActiveFocus()
      verify(reply.activeFocus)
      msgList.model = rows(31, 50)
      wait(50)
      tryCompare(msgList, "atYEnd", true)
      verify(reply.activeFocus)
      compare(reply.text, "keep typing")
      var capped = rows(31, 50)
      capped[30] = 180
      msgList.model = capped
      wait(50)
      tryCompare(msgList, "atYEnd", true)
      msgList.pinToEnd = false
      msgList.positionViewAtBeginning()
      msgList.model = rows(32, 50)
      wait(50)
      verify(!msgList.atYEnd)
      verify(reply.activeFocus)
    }
  }
}
`)
  const result = spawnSync(runner, ["-input", file], { encoding: "utf8", timeout: 15000,
    env: { ...process.env, QT_QPA_PLATFORM: "offscreen", QT_QPA_PLATFORMTHEME: "", QT_QUICK_BACKEND: "software" } })
  if (result.error && result.error.code === "ENOENT") {
    console.log("panel keyboard ok; Qt scroll test skipped (qmltestrunner unavailable)")
  } else {
    process.stdout.write(result.stdout || "")
    process.stderr.write(result.stderr || "")
    assert.equal(result.status, 0, "Qt transcript layout test passed")
    console.log("panel keyboard and transcript layout ok")
  }
} finally {
  fs.rmSync(tmp, { recursive: true, force: true })
}

#!/usr/bin/env node
"use strict"

const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const repo = path.join(__dirname, "..")
const qml = fs.readFileSync(path.join(repo, "BarWidget.qml"), "utf8")
const Model = vm.createContext({})
vm.runInContext(fs.readFileSync(path.join(repo, "Model.js"), "utf8"), Model)

// Exercise the widget's actual controller functions with a fake socket/timer.
// Top-level QML functions all end at the same two-space indentation.
const functions = [...qml.matchAll(/^  function (\w+)\([^]*?^  }/gm)]
const alice = { handle: "tel:+15555550123", name: "Alice", repliable: true }
const bob = { handle: "tel:+15555550999", name: "Bob", repliable: true }

function widget() {
  const sent = []
  const timer = { running: false, restart() { this.running = true }, stop() { this.running = false } }
  const root = {
    socketUp: true, status: { map: true }, daemonOk: true, sockBuf: "",
    outbox: [], sendQueue: [], activeSend: null, sendSession: "local-test", sendSerial: 0,
    serverMessages: [], selectedThread: alice, threads: [alice, bob],
    replyDraft: "", composeBody: "", composeTo: "", page: "thread", tab: "messages",
    drafts: Model.emptyDict(), readWatermarks: Model.emptyDict(), markedRead: Model.emptyDict(),
    markAllQueue: [], actionNote: "", messagesLoading: false,
    sendCmd(command) { sent.push(command); return root.socketUp }
  }
  Object.defineProperties(root, {
    mapUp: { get: () => root.status.map === true },
    messages: { get: () => root.selectedThread
      ? Model.mergeMessages(root.serverMessages, root.outbox, root.selectedThread.handle) : [] },
    failedSend: { get: () => [...root.outbox].reverse().find(row => row.failed && root.selectedThread
      && Model.sameThread(row.thread, root.selectedThread.handle)) || null }
  })
  const ctx = vm.createContext({ root, Model, sendWatchdog: timer, panelLoader: { item: null } })
  for (const [source, name] of functions) {
    if (name === "sendCmd") continue
    vm.runInContext(source, ctx)
    root[name] = ctx[name]
  }
  root.sentMessages = () => sent.filter(command => command.command === "bt_send_message")
  root.result = (item, success = true, extra = {}) => root.handleLine(JSON.stringify({
    command: "bt_send_result", thread: item.thread, operation_id: item.handle, success, ...extra
  }))
  root.timer = timer
  return root
}

{
  const w = widget()
  w.replyDraft = "first"
  assert(w.sendReply())
  const first = w.activeSend
  assert.equal(w.replyDraft, "")
  w.replyDraft = "second"
  assert(w.sendReply())
  assert(w.sendTo(alice.handle, "third"))
  assert.equal(w.sentMessages().length, 1)
  assert.deepEqual(Array.from(w.sendQueue, row => row.body), ["second", "third"])
  assert.deepEqual(Array.from(w.messages, row => row.queued), [false, true, true])
  w.replyDraft = "first" // even identical new typing must survive the old result
  w.result(first)
  assert.equal(w.activeSend.body, "second")
  assert.equal(w.replyDraft, "first")
  w.result(first) // duplicate acknowledgment must not release the second send
  assert.equal(w.sentMessages().length, 2)
  w.result(w.activeSend)
  w.result(w.activeSend)
  assert.deepEqual(w.sentMessages().map(row => row.body), ["first", "second", "third"])
  assert.equal(w.activeSend, null)
  assert.equal(w.timer.running, false)
}

{
  const w = widget()
  w.sendTo(alice.handle, "same text")
  const first = w.activeSend
  w.sendTo(alice.handle, "same text")
  w.handleLine(JSON.stringify({ command: "bt_send_result", operation_id: "another-client",
    thread: alice.handle, success: true }))
  assert.equal(w.activeSend.handle, first.handle)
  w.unconfirmSend("No answer; it may already have been sent.")
  const second = w.activeSend
  assert.notEqual(second.handle, first.handle)
  assert.equal(w.outbox[0].unconfirmed, true)
  assert.equal(w.replyDraft, "")
  w.result(first) // late result updates only the first bubble
  assert.equal(w.activeSend.handle, second.handle)
  assert.equal(w.outbox[0].unconfirmed, false)
  assert.equal(w.outbox[1].pending, true)
  assert.equal(w.sentMessages().length, 2) // no automatic retry
  assert.equal(w.actionNote, "")
}

{
  const w = widget()
  w.sendTo(alice.handle, "for Alice")
  const first = w.activeSend
  w.sendTo(bob.handle, "for Bob")
  w.backToList()
  assert.equal(w.messages.length, 0)
  w.openThread(bob)
  assert.deepEqual(Array.from(w.messages, row => row.body), ["for Bob"])
  w.replyDraft = "Bob draft"
  w.result(first, false, { message: "Rejected" })
  assert.equal(w.replyDraft, "Bob draft")
  assert.equal(w.actionNote, "") // another recipient's error stays with their bubble
  assert.equal(Model.getDraft(w.drafts, alice.handle), "for Alice")
  assert.equal(w.activeSend.thread, bob.handle)
  w.openThread(alice)
  assert.equal(w.failedSend.body, "for Alice")
  w.replyDraft = "a newer Alice draft"
  assert(w.retrySend())
  assert.equal(w.replyDraft, "a newer Alice draft")
  assert.equal(w.sendQueue[0].thread, alice.handle)
  assert.equal(w.sendQueue[0].body, "for Alice")
  assert.equal(w.failedSend, null)
}

{
  const w = widget()
  w.sendTo(alice.handle, "already submitted")
  const first = w.activeSend
  w.sendTo(bob.handle, "still queued")
  w.socketUp = false
  w.onSocketDown()
  assert.equal(w.activeSend, null)
  assert.equal(w.outbox[0].unconfirmed, true)
  assert.equal(w.sendQueue.length, 1)
  assert.equal(w.sentMessages().length, 1)
  w.replyDraft = "keep this offline draft"
  assert.equal(w.sendReply(), false)
  assert.equal(w.replyDraft, "keep this offline draft")
  w.status = { map: false }
  w.socketUp = true
  w.onSocketUp()
  assert.equal(w.activeSend, null)
  w.handleLine(JSON.stringify({ command: "bt_connection_changed", map_open: true }))
  assert.equal(w.activeSend.thread, bob.handle)
  w.result(first)
  assert.equal(w.activeSend.thread, bob.handle)
  assert.equal(w.sentMessages().length, 2)
}

{
  const w = widget()
  w.sendTo(alice.handle, "first")
  const first = w.activeSend
  w.page = "compose"
  w.selectedThread = null
  w.composeTo = bob.handle
  w.composeBody = "new conversation"
  assert(w.sendNew())
  assert.equal(w.selectedThread.handle, bob.handle)
  assert.equal(w.messages[0].body, "new conversation")
  assert.equal(w.composeBody, "")
  w.result(first, false, { message: "Timed out; it may still be sent." })
  assert.equal(w.outbox[0].unconfirmed, true)
  assert.equal(w.failedSend, null)
  assert.equal(w.activeSend.body, "new conversation")
}

{
  const w = widget()
  for (let i = 0; i < Model.MAX_MESSAGES; i++) assert(w.sendTo(alice.handle, `message ${i}`))
  w.replyDraft = "keep when full"
  assert.equal(w.sendReply(), false)
  assert.equal(w.replyDraft, "keep when full")
  w.result(w.activeSend)
  assert(w.sendReply())
  assert.equal(w.outbox.length, Model.MAX_MESSAGES)
  assert.equal(w.sendQueue.at(-1).body, "keep when full")
}

{
  const w = widget()
  for (let i = 0; i < Model.MAX_MESSAGES; i++) assert(w.sendTo(alice.handle, `message ${i}`))
  w.result(w.activeSend, false, { message: "Rejected" })
  const failed = w.failedSend
  w.replyDraft = "new draft"
  w.socketUp = false
  assert.equal(w.retrySend(), false)
  assert.equal(w.failedSend.handle, failed.handle)
  w.socketUp = true
  assert(w.retrySend()) // retry replaces its failed row even at capacity
  assert.equal(w.outbox.length, Model.MAX_MESSAGES)
  assert.equal(w.replyDraft, "new draft")
  assert.equal(w.sendQueue.at(-1).body, "message 0")
}

console.log("sending ok")

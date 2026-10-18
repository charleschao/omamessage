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
const LocalInbox = vm.createContext({ Model })
vm.runInContext(fs.readFileSync(path.join(repo, "LocalInbox.js"), "utf8").replace(/^\.import[^\n]*\n/, ""), LocalInbox)

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
    markAllQueue: [], actionNote: "", messagesLoading: false, opened: true,
    contactQuery: "", contacts: [],
    settings: {}, moduleName: "io.github.charleschao.omamessage",
    bar: { shell: { updateEntryInline() {} } },
    sendCmd(command) { sent.push(command); return root.socketUp }
  }
  Object.defineProperties(root, {
    removals: { get: () => LocalInbox.parse(root.settings.localRemovals) },
    mapUp: { get: () => root.status.map === true },
    messages: { get: () => root.selectedThread
      ? LocalInbox.messages(Model.mergeMessages(root.serverMessages, root.outbox, root.selectedThread.handle),
                            root.removals, root.selectedThread.handle) : [] },
    failedSend: { get: () => [...root.outbox].reverse().find(row => row.failed && root.selectedThread
      && Model.sameThread(row.thread, root.selectedThread.handle)) || null }
  })
  const ctx = vm.createContext({ root, Model, LocalInbox, sendWatchdog: timer, panelLoader: { item: null },
    contactTimer: { restart() {} } })
  for (const [source, name] of functions) {
    if (name === "sendCmd") continue
    vm.runInContext(source, ctx)
    root[name] = ctx[name]
  }
  root.sentMessages = () => sent.filter(command => command.command === "bt_send_message")
  root.commands = sent
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

{
  const w = widget()
  w.replyDraft = "still typing my reply"
  w.serverMessages = Model.parseMessages({ messages: [
    { handle: "old", thread: alice.handle, body: "earlier", read: true }
  ] })
  // A missed push must recover while the same conversation remains open.
  w.refreshConversation()
  assert.equal(w.commands.length, 1)
  assert.equal(w.commands[0].command, "bt_list_messages")
  assert.equal(w.commands[0].thread, alice.handle)
  w.handleLine(JSON.stringify({ command: "bt_messages", thread: alice.handle, messages: [
    { handle: "old", thread: alice.handle, body: "earlier", read: true },
    { handle: "new", thread: alice.handle, body: "new reply", read: false }
  ] }))
  assert.deepEqual(Array.from(w.messages, row => row.body), ["earlier", "new reply"])
  assert.equal(w.page, "thread")
  assert.equal(w.replyDraft, "still typing my reply")
  assert(w.commands.some(command => command.command === "bt_mark_read" && command.handle === "new"))
  const previousMessages = w.serverMessages
  w.handleLine(JSON.stringify({ command: "bt_messages", thread: alice.handle, messages: [
    { handle: "old", thread: alice.handle, body: "earlier", read: true },
    { handle: "new", thread: alice.handle, body: "new reply", read: false }
  ] }))
  assert.equal(w.serverMessages, previousMessages) // no reset for unchanged polls
  w.handleLine(JSON.stringify({ command: "bt_messages", thread: bob.handle,
    messages: [{ handle: "other", thread: bob.handle, body: "for Bob" }] }))
  assert.equal(w.messages.at(-1).body, "new reply")
}

{
  const w = widget()
  // Existing push refresh supports aliases and preserves current typing.
  w.replyDraft = "draft"
  w.handleLine(JSON.stringify({ command: "bt_message", thread: "tel:5555550123" }))
  assert(w.commands.some(command => command.command === "bt_list_messages" && command.thread === "tel:5555550123"))
  assert.equal(w.replyDraft, "draft")
  w.commands.length = 0
  w.handleLine(JSON.stringify({ command: "bt_message", thread: bob.handle }))
  assert.equal(w.commands.some(command => command.command === "bt_list_messages"), false)
}

for (const state of [{ opened: false }, { socketUp: false }, { status: { map: false } },
  { page: "inbox" }, { selectedThread: null }]) {
  const w = widget()
  Object.assign(w, state)
  w.refreshConversation()
  assert.equal(w.commands.length, 0)
}

{
  const w = widget()
  w.replyDraft = "keep on reconnect"
  w.onSocketUp()
  assert(w.commands.some(command => command.command === "bt_list_messages" && command.thread === alice.handle))
  assert.equal(w.replyDraft, "keep on reconnect")
}

const auditTests = {
  "hidden conversation does not mark new messages read"() {
    const w = widget()
    w.opened = false
    w.handleLine(JSON.stringify({ command: "bt_messages", thread: alice.handle,
      messages: [{ handle: "unseen", thread: alice.handle, body: "new", read: false }] }))
    assert.equal(w.commands.some(command => command.command === "bt_mark_read"), false)
  },
  "mark-all ignores unrelated message responses"() {
    const w = widget()
    w.opened = false
    w.markAllQueue = [alice.handle]
    w.handleLine(JSON.stringify({ command: "bt_messages", thread: bob.handle,
      messages: [{ handle: "unrelated", thread: bob.handle, body: "new", read: false }] }))
    assert.equal(w.commands.some(command => command.command === "bt_mark_read"), false)
    assert.equal(w.markAllQueue[0], alice.handle)
  },
  "contact selection preserves a new-message draft"() {
    for (const recipient of [alice, { handle: "tel:+15555550777", name: "New contact" }]) {
      const w = widget()
      w.page = "compose"
      w.selectedThread = null
      w.composeBody = "already typed this"
      w.openContactHandle({ name: recipient.name }, recipient.handle)
      assert.equal(w.replyDraft, "already typed this")
      assert.equal(w.selectedThread.handle, recipient.handle)
      assert.equal(w.composeBody, "")
      assert.equal(w.sentMessages().length, 0)
    }
  },
  "disconnect clears stale connection and calls"() {
    const w = widget()
    w.calls = [{ ringing: true }]
    w.markedRead = { old: true }
    w.socketUp = false
    w.onSocketDown()
    assert.equal(w.mapUp, false)
    assert.equal(w.calls.length, 0)
    assert.equal(Object.keys(w.markedRead).length, 0)
  },
  "reconnect resumes interrupted mark-all"() {
    const w = widget()
    w.opened = false
    w.markAllQueue = [bob.handle]
    w.onSocketUp()
    assert(w.commands.some(command => command.command === "bt_list_messages" && command.thread === bob.handle))
  },
  "failed mark-read can be retried"() {
    const w = widget()
    const messages = Model.parseMessages({ messages: [{ handle: "retry-read", read: false }] })
    w.markRead(messages)
    w.handleLine(JSON.stringify({ command: "bt_message_read", handles: ["retry-read"], success: false }))
    w.markRead(messages)
    assert.equal(w.commands.filter(command => command.command === "bt_mark_read").length, 2)
  },
  "contact search ignores outdated responses"() {
    const w = widget()
    w.page = "compose"
    w.contacts = [{ name: "old suggestion" }]
    w.searchContacts("Bob")
    assert.equal(w.contacts.length, 0)
    w.handleLine(JSON.stringify({ command: "bt_contacts", query: "Alice",
      contacts: [{ name: "Alice", addresses: [alice.handle] }] }))
    assert.equal(w.contacts.length, 0)
    w.handleLine(JSON.stringify({ command: "bt_contacts", query: "Bob",
      contacts: [{ name: "Bob", addresses: [bob.handle] }] }))
    assert.equal(w.contacts[0].name, "Bob")
    w.backToList()
    w.loadContacts()
    assert.equal(w.commands.some(command => command.command === "bt_list_contacts"), false)
  },
  "mark-all survives a full disconnect and fresh connection status"() {
    const w = widget()
    w.opened = false
    w.markAllQueue = [bob.handle]
    w.socketUp = false
    w.onSocketDown()
    w.socketUp = true
    w.onSocketUp()
    assert.equal(w.commands.some(command => command.command === "bt_list_messages"), false)
    w.handleLine(JSON.stringify({ command: "bt_connection_changed", map_open: true }))
    assert(w.commands.some(command => command.command === "bt_list_messages" && command.thread === bob.handle))
    w.handleLine(JSON.stringify({ command: "bt_messages", thread: bob.handle,
      messages: [{ handle: "bob-read", read: false }] }))
    assert.equal(w.markAllQueue.length, 0)
    assert(w.commands.some(command => command.command === "bt_mark_read" && command.handle === "bob-read"))
  },
  "mixed-case email receives canonical message responses"() {
    const w = widget()
    w.selectedThread = { handle: "email:Alice@Example.COM", name: "Alice", repliable: true }
    w.replyDraft = "email draft"
    w.handleLine(JSON.stringify({ command: "bt_messages", thread: "email:alice@example.com",
      messages: [{ handle: "mail-reply", body: "email reply", read: true }] }))
    assert.equal(w.selectedThread.handle, "email:alice@example.com")
    assert.equal(w.messages[0].body, "email reply")
    assert.equal(w.replyDraft, "email draft")
  }
}
let auditFailures = 0
for (const [name, test] of Object.entries(auditTests)) {
  try { test() } catch (error) {
    auditFailures++
    console.error(`FAIL: ${name}: ${error.message}`)
  }
}
assert.equal(auditFailures, 0, "audit regressions")
console.log("sending and conversation refresh ok")

{
  const w = widget()
  const message = { handle: "remove-me", thread: alice.handle, timestamp: 100, body: "private text", read: true }
  const other = { handle: "keep-me", thread: alice.handle, timestamp: 90, body: "keep", read: true }
  w.serverMessages = Model.parseMessages({ messages: [other, message] })
  w.threads = [{ ...alice, timestamp: 100, preview: message.body, unread: 1 }, bob]
  w.replyDraft = "keep draft"
  assert(w.removeMessage(w.messages[1]))
  assert.equal(w.messages.length, 1)
  assert.equal(w.replyDraft, "keep draft")
  assert.equal(w.threads[0].preview, "Message removed")
  assert.equal(w.commands.length, 0, "local removal must never send phone deletion commands")
  assert(!JSON.stringify(w.settings).includes(message.body), "persist identifiers, never content")
  w.handleLine(JSON.stringify({ command: "bt_messages", thread: "tel:5555550123", messages: [other, message] }))
  assert.equal(w.messages.length, 1, "polls and aliases cannot restore a removed message")
  const restarted = widget()
  restarted.settings = JSON.parse(JSON.stringify(w.settings))
  restarted.handleLine(JSON.stringify({ command: "bt_messages", thread: alice.handle, messages: [other, message] }))
  assert.equal(restarted.messages.length, 1, "removal survives shell restart")
  restarted.selectedThread = bob
  restarted.handleLine(JSON.stringify({ command: "bt_messages", thread: bob.handle,
    messages: [{ ...message, thread: bob.handle }] }))
  assert.equal(restarted.messages.length, 1, "same handle in another conversation is not removed")
}

{
  const w = widget()
  w.threads = [{ ...alice, timestamp: 100, preview: "old" }, bob]
  w.replyDraft = "delete draft"
  w.stashDraft(alice.handle, "stored draft")
  w.outbox = Model.appendOutgoing([], alice.handle, "unsent failure", 90, "local-failed", false)
  w.outbox = Model.updateOutgoing(w.outbox, "local-failed", { pending: false, failed: true })
  w.serverMessages = Model.parseMessages({ messages: [{ handle: "old", thread: alice.handle, body: "old", timestamp: 100 }] })
  assert(w.removeConversation(w.threads[0]))
  const before = w.removals.threads[0].before
  assert.equal(w.page, "inbox")
  assert.equal(w.selectedThread, null)
  assert.equal(w.serverMessages.length, 0)
  assert.equal(w.outbox.length, 0)
  assert.equal(w.replyDraft, "")
  assert.equal(Model.getDraft(w.drafts, alice.handle), "")
  assert.equal(w.threads.length, 1)
  assert.equal(w.threads[0].name, "Bob")
  w.handleLine(JSON.stringify({ command: "bt_threads", threads: [
    { thread: "tel:5555550123", name: "Alice", timestamp: 100, preview: "old" },
    { thread: bob.handle, name: "Bob", timestamp: 100 }
  ] }))
  assert.equal(w.threads.length, 1)
  w.handleLine(JSON.stringify({ command: "bt_threads", threads: [
    { thread: alice.handle, name: "Alice", timestamp: before + 10, preview: "new" }
  ] }))
  assert.equal(w.threads.length, 1, "new messages can bring back the conversation")
  w.openThread(w.threads[0])
  w.handleLine(JSON.stringify({ command: "bt_messages", thread: alice.handle, messages: [
    { handle: "old", timestamp: 100, body: "old" },
    { handle: "new", timestamp: before + 10, body: "new", read: true }
  ] }))
  assert.deepEqual(Array.from(w.messages, row => row.body), ["new"], "old history stays removed")
  w.page = "compose"
  w.handleLine(JSON.stringify({ command: "bt_contacts", contacts: [{ name: "Alice", addresses: [alice.handle] }] }))
  assert.equal(w.contacts[0].name, "Alice", "the address book contact is untouched")
}

{
  const w = widget()
  w.sendTo(alice.handle, "sending")
  assert.equal(w.removeMessage(w.messages[0]), false)
  assert.equal(w.removeConversation(alice), false)
  assert.equal(w.outbox.length, 1)
  assert.equal(w.activeSend.body, "sending")
  w.result(w.activeSend, false, { message: "Rejected" })
  const failed = w.messages[0]
  assert(w.removeMessage(failed))
  assert.equal(w.messages.length, 0)
  assert.equal(w.failedSend, null)
  assert.equal(w.replyDraft, "")
  assert.equal(Model.getDraft(w.drafts, alice.handle), "")
}

{
  const w = widget()
  w.bar = null
  w.serverMessages = Model.parseMessages({ messages: [{ handle: "kept", timestamp: 10, body: "kept" }] })
  assert.equal(w.removeMessage(w.messages[0]), false)
  assert.equal(w.messages.length, 1, "do not pretend removal succeeded without persistence")
  w.bar = { shell: { updateEntryInline() { return false } } }
  assert.equal(w.removeMessage(w.messages[0]), false)
  assert.equal(w.messages.length, 1, "respect a rejected settings update")
}
console.log("local message and conversation removal ok")

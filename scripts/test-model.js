#!/usr/bin/env node
"use strict"

const fs = require("fs")
const path = require("path")
const vm = require("vm")

const src = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8")
const M = {
  JSON, Date, Array, Object, Math, Number, String, parseInt, isNaN, isFinite, Infinity, RegExp
}
vm.createContext(M)
vm.runInContext(src, M)

let failed = 0
function eq(name, got, want) {
  const g = JSON.stringify(got)
  const w = JSON.stringify(want)
  if (g === w) return
  failed++
  console.error("FAIL", name, "\n  got ", g, "\n  want", w)
}

function ok(name, cond) {
  if (cond) return
  failed++
  console.error("FAIL", name)
}

eq("parseEvent ignores OK", M.parseEvent("OK"), null)
eq("parseEvent ignores empty", M.parseEvent(""), null)
ok("parseEvent json", M.parseEvent('{"command":"bt_threads"}').command === "bt_threads")

const threads = M.parseThreads({
  threads: [
    {
      thread: "tel:+15551212",
      name: "Ada",
      address: "+15551212",
      preview: "hello",
      timestamp: 1700000000,
      unread: 2,
      group: false,
      repliable: true
    },
    { thread: "group:abc", name: "Team", preview: "hi", unread: 1, group: true, repliable: false, reply_reason: "needs roster" }
  ]
})
eq("thread count", threads.length, 2)
eq("thread handle", threads[0].handle, "tel:+15551212")
eq("unread total", M.unreadTotal(threads), 3)
eq("bar icon", M.BAR_ICON, "󰍡")
eq("bar with unread", M.barLabel(3, true, true), "󰍡 3")
eq("bar idle", M.barLabel(0, true, true), "󰍡")
eq("bar down", M.barLabel(9, false, true), "󰍡")
eq("filter", M.filterThreads(threads, "ada")[0].name, "Ada")
eq("zero unread", M.zeroUnread(threads, "tel:+15551212")[0].unread, 0)

const noon = Date.UTC(2026, 8, 5, 16, 0, 0) / 1000
const localNoon = new Date(2026, 8, 5, 16, 0, 0).getTime() / 1000
eq("time today", M.formatThreadTime(localNoon, localNoon), "16:00")
const yest = new Date(2026, 8, 4, 9, 5, 0).getTime() / 1000
eq("time yesterday", M.formatThreadTime(yest, localNoon), "Yesterday")
eq("day today", M.formatDayHeading(localNoon, localNoon), "Today")
eq("day yesterday", M.formatDayHeading(yest, localNoon), "Yesterday")

eq("linkify", M.linkify("see https://omarchy.org/docs please"),
  "see <a href=\"https://omarchy.org/docs\">https://omarchy.org/docs</a> please")
eq("escape", M.linkify("a <b> & c"), "a &lt;b&gt; &amp; c")
eq("otp", M.extractOtp("Your verification code is 482193"), "482193")
eq("otp ignores order", M.extractOtp("order 123456 shipped"), "")
eq("otp no cue", M.extractOtp("just 482193"), "")

eq("tel", M.normalizeHandle("+1 (555) 1212"), "tel:+15551212")
eq("email", M.normalizeHandle("ada@example.com"), "email:ada@example.com")
eq("mailto", M.normalizeHandle("mailto:ada@example.com"), "email:ada@example.com")

const conn = M.parseConnection({ device_present: true, map_open: false, map_error: "forbidden", profile_reason: "Enable Messages" })
eq("solicit", M.needsSolicit(conn), true)
eq("status note", M.statusTitle(conn, true), "Enable Messages")
eq("daemon down", M.statusTitle(conn, false), "Tether is not running")

const msgs = M.parseMessages({
  messages: [
    { handle: "a", body: "hi", outgoing: false, timestamp: localNoon - 60, read: false },
    { handle: "b", body: "https://x.test ok", outgoing: true, timestamp: localNoon, read: true }
  ]
})
eq("unread handles", M.unreadHandles(msgs), ["a"])
const decorated = M.decorateTranscript(msgs, localNoon)
ok("day row", decorated[0].kind === "day" && decorated[0].label === "Today")
ok("grouped stamp on first", decorated[1].kind === "msg" && decorated[1].showStamp === true)
ok("second is mine", decorated[2].mine === true)
ok("link in html", decorated[2].html.indexOf("href=") >= 0)

const calls = M.parseCalls({
  calls: [
    { path: "/c1", name: "Ada", number: "+1", state: "incoming", ringing: true },
    { path: "/c2", state: "disconnected" }
  ]
})
eq("calls drop disconnected", calls.length, 1)
eq("live ringing", M.liveCall(calls).path, "/c1")
eq("call title", M.callTitle(calls[0]), "Incoming call")

const contacts = M.parseContacts({
  contacts: [{ name: "Ada Lovelace", addresses: ["tel:+1555", "email:ada@x.test"] }]
})
eq("contact handle", contacts[0].handle, "tel:+1555")
eq("contact entries", contacts[0].entries.length, 2)

if (failed) {
  console.error(failed + " failed")
  process.exit(1)
}
console.log("ok")

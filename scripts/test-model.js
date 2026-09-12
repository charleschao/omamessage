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
eq("bar notices", M.barLabel(0, true, true, 4, true), "󰍡 4")
eq("bar unread beats notices", M.barLabel(2, true, true, 9, true), "󰍡 2")
eq("bar call", M.barLabel(0, true, true, 0, false, true), "󰍡 call")
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
eq("linkify http stays text", M.linkify("see http://evil.example/x"), "see http://evil.example/x")
eq("linkify www becomes https", M.linkify("www.omarchy.org/x"),
  "<a href=\"https://www.omarchy.org/x\">www.omarchy.org/x</a>")
eq("https url ok", M.parseHttpsUrl("https://omarchy.org/docs"), "https://omarchy.org/docs")
eq("reject http", M.parseHttpsUrl("http://omarchy.org/"), "")
eq("reject userinfo", M.parseHttpsUrl("https://user:pass@omarchy.org/"), "")
eq("reject loopback ip", M.parseHttpsUrl("https://127.0.0.1/x"), "")
eq("reject ipv6", M.parseHttpsUrl("https://[::1]/x"), "")
eq("reject localhost tld", M.parseHttpsUrl("https://foo.localhost/"), "")
eq("reject file", M.parseHttpsUrl("file:///etc/passwd"), "")
eq("allow at in path", M.parseHttpsUrl("https://example.com/a@b"), "https://example.com/a@b")
eq("utf8 ascii", M.utf8Len("abc"), 3)
eq("utf8 two byte", M.utf8Len("é"), 2)
ok("emptyDict null proto", Object.getPrototypeOf(M.emptyDict()) === null)
const sock = M.takeSocketLines("", '{"command":"bt_threads"}\n{"command":"x"}', 1048576)
eq("socket two lines", sock.lines, ['{"command":"bt_threads"}'])
eq("socket rest", sock.buf, '{"command":"x"}')
eq("socket no overflow", sock.overflow, false)
const big = M.takeSocketLines("", "x".repeat(20) + "\n", 8)
eq("socket overflow", big.overflow, true)
eq("socket overflow drops", big.buf, "")
eq("socket overflow no line", big.lines, [])
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
eq("ancs down", conn.ancs, false)

const linked = M.parseConnection({
  device_present: true,
  map_open: true,
  pbap_open: true,
  ancs_ready: true,
  ancs_reason: "Notification mirroring is active.",
  profile_reason: "Messages and contacts are connected."
})
eq("ancs up", linked.ancs, true)
eq("ancs reason", linked.ancsReason, "Notification mirroring is active.")
eq("status both", M.statusTitle(linked, true), "Messages and notifications")
eq("ancs hint ready", M.ancsHint(linked, true), "Notification mirroring is active.")

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
const suggestions = M.flattenContactSuggestions(contacts)
eq("suggestions count", suggestions.length, 2)
eq("suggestion phone", suggestions[0].handle, "tel:+1555")
eq("suggestion email", suggestions[1].handle, "email:ada@x.test")
eq("suggestion kinds", [suggestions[0].kind, suggestions[1].kind], ["phone", "email"])

const notices = M.parseNotifications({
  notifications: [
    {
      uid: 134,
      app_id: "ch.protonmail.protonmail",
      app_name: "Proton Mail",
      title: "Chase Credit Journey",
      subtitle: "",
      body: "Here's your latest Credit Summary",
      category: 0,
      timestamp: 1789069358,
      silent: false,
      positive_action: false,
      negative_action: true
    },
    {
      uid: 12,
      app_id: "com.apple.MobileSMS",
      app_name: "Messages",
      title: "Ada",
      body: "Your verification code is 482193",
      category: 4,
      timestamp: localNoon,
      negative_action: true
    },
    { uid: -1, title: "bad" },
    { title: "no uid" }
  ]
})
eq("notice count", notices.length, 2)
eq("notice app", notices[0].app, "Proton Mail")
eq("notice primary", notices[0].primary, "Chase Credit Journey")
eq("notice secondary", notices[0].secondary, "Here's your latest Credit Summary")
eq("notice dismiss", notices[0].negative, true)
eq("sms notice", notices[1].messages, true)
eq("sms otp", notices[1].otp, "482193")
eq("notice cap drop", M.dropNotice(notices, 134).length, 1)
eq("notice filter", M.filterNotifications(notices, "proton")[0].uid, 134)
eq("notice total", M.noticeCount(notices), 2)
eq("sms thread", M.threadForNotice(threads, notices[1]).handle, "tel:+15551212")
eq("mail no thread", M.threadForNotice(threads, notices[0]), null)

eq("bucket short stays distinct", M.threadBucket("tel:+15551212"), "tel:15551212")
eq("bucket us number", M.threadBucket("tel:+15555550123"), "tel:5555550123")
eq("bucket national", M.threadBucket("tel:5555550123"), "tel:5555550123")
eq("same thread us spellings", M.sameThread("tel:+15555550123", "tel:5555550123"), true)
eq("same thread email", M.sameThread("email:Ada@X.test", "email:Ada@X.test"), true)
eq("different people", M.sameThread("tel:+15555550123", "tel:+15555550999"), false)
eq("thread by alias", M.threadByHandle([{ handle: "tel:+15555550123", name: "Ada" }], "5555550123").name, "Ada")

const local = M.appendOutgoing(
  [{ handle: "a", body: "hi", mine: false, timestamp: 1, read: true }],
  "tel:+15555550123",
  "on my way",
  1700000000
)
eq("append keeps history", local.length, 2)
eq("append mine", local[1].mine, true)
eq("append body", local[1].body, "on my way")
ok("append local handle", String(local[1].handle).indexOf("local-") === 0)

const server = [
  { handle: "a", body: "hi", mine: false, timestamp: 1, read: true },
  { handle: "map-9", body: "on my way", mine: true, timestamp: 2, read: true }
]
eq("merge drops echo", M.mergeMessages(server, local, "tel:+15555550123").length, 2)
eq("merge keeps pending", M.mergeMessages(server.slice(0, 1), local, "tel:+15555550123").length, 2)
eq("drop local", M.dropLocalOutgoing(local, "on my way").length, 1)
eq("append pending", local[1].pending, true)
eq("flags sent", M.setOutgoingFlags(local, "on my way", false, false)[1].pending, false)
eq("flags failed", M.setOutgoingFlags(local, "on my way", false, true)[1].failed, true)

const patched = M.patchThread(threads, "tel:+15551212", "on my way", 1700000999)
eq("patch preview", patched[0].preview, "on my way")
eq("patch front", patched[0].handle, "tel:+15551212")
eq("patch unread", patched[0].unread, 0)

const drafts = M.putDraft({}, "tel:+15555550123", "hello")
eq("draft by alias", M.getDraft(drafts, "tel:5555550123"), "hello")
eq("draft overwrite", M.getDraft(M.putDraft(drafts, "5555550123", "later"), "tel:+15555550123"), "later")

const marked = M.markReadAt({}, "tel:+15551212", 1700000000)
eq("watermark zeros stale unread", M.applyReadWatermarks(threads, marked)[0].unread, 0)
const newer = [{ handle: "tel:+15551212", unread: 2, timestamp: 1700000999 }]
eq("watermark keeps new unread", M.applyReadWatermarks(newer, marked)[0].unread, 2)
eq("first unread", M.firstUnreadThread(threads).handle, "tel:+15551212")

const grouped = M.decorateTranscript([
  { handle: "a", name: "Ada", body: "one", mine: false, timestamp: localNoon - 10 },
  { handle: "b", name: "Bea", body: "two", mine: false, timestamp: localNoon }
], localNoon, true)
ok("group name", grouped[1].showName === true && grouped[1].name === "Ada")
eq("pending stamp", M.decorateTranscript([{ handle: "local-1", body: "x", mine: true, pending: true, timestamp: localNoon }], localNoon)[1].stamp, "Sending…")

const mergedName = M.mergeSelectedThread(
  { handle: "tel:5555550123", name: "tel:5555550123", address: "5555550123" },
  { handle: "tel:+15555550123", name: "Ada", address: "+15555550123", repliable: true }
)
eq("adopt contact name", mergedName.name, "Ada")
eq("adopt canonical handle", mergedName.handle, "tel:+15555550123")

if (failed) {
  console.error(failed + " failed")
  process.exit(1)
}
console.log("ok")

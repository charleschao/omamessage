// Parsers and formatters for Tether's daemon JSON.
// Tether is Zack Bartel's project: https://github.com/zackb/tether
// This plugin does not reimplement iMessage; it talks to tetherd.sock.

var MAX_JSON = 1048576
var MAX_DEVICES = 32
var MAX_CALLS = 8
var MAX_THREADS = 100
var MAX_MESSAGES = 200
var MAX_CONTACTS = 40
var MAX_CONTACT_FIELDS = 8
var MAX_NAME = 128
var MAX_PREVIEW = 240
var MAX_BODY = 2048
var MAX_NOTE = 240
var MAX_HANDLE = 256
var MAX_ADDR = 64
var MAX_STATUS = 64
var GROUP_WINDOW_SECONDS = 300

var OTP_CUES = [
  "code", "otp", "one-time", "one time", "verification", "verify",
  "passcode", "password", "authenticate", "login", "log in", "sign in",
  "2fa", "token", "pin", "security", "confirm", "do not share", "expires"
]

var WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
var WEEKDAYS_LONG = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
var MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

function field(s, max) {
  s = String(s == null ? "" : s)
  if (s.length > max) s = s.slice(0, max)
  return s.replace(/[\x00-\x08\x0b\x0c\x0e-\x1f]/g, "")
}

function neutralizeUi(s) {
  return field(s, MAX_NOTE).replace(/[<>&]/g, "")
}

function capList(out, max) {
  if (out.length > max) out.length = max
  return out
}

function isArray(value) {
  return Object.prototype.toString.call(value) === "[object Array]"
}

function asArray(value) {
  return isArray(value) ? value : []
}

function asObject(value) {
  return value && typeof value === "object" && !isArray(value) ? value : null
}

function parseEvent(line) {
  var s = String(line == null ? "" : line)
  if (!s || s === "OK") return null
  if (s.length > MAX_JSON) return null
  try {
    var obj = JSON.parse(s)
    return asObject(obj)
  } catch (e) {
    return null
  }
}

function epochOf(value) {
  var n = Number(value)
  if (!isFinite(n) || n < 0) return 0
  if (n > 1e12) n = Math.floor(n / 1000)
  return Math.floor(n)
}

function parseConnection(obj) {
  obj = asObject(obj) || {}
  return {
    present: obj.device_present === true,
    paired: obj.device_paired === true,
    map: obj.map_open === true,
    pbap: obj.pbap_open === true,
    classic: obj.classic_connected === true,
    le: obj.le_connected === true || obj.le_available === true,
    mapError: field(obj.map_error, MAX_STATUS),
    note: field(obj.profile_reason || obj.link_reason, MAX_NOTE),
    linkReason: field(obj.link_reason, MAX_NOTE),
    profileReason: field(obj.profile_reason, MAX_NOTE)
  }
}

function parseDevices(obj) {
  var rows = asArray(obj && obj.devices)
  var out = []
  var n = Math.min(rows.length, MAX_DEVICES * 2)
  for (var i = 0; i < n && out.length < MAX_DEVICES; i++) {
    var d = asObject(rows[i])
    if (!d) continue
    out.push({
      address: field(d.address, MAX_ADDR),
      name: field(d.name, MAX_NAME),
      connected: d.connected === true || d.classic_connected === true,
      map: d.map === true,
      pbap: d.pbap === true,
      ancs: d.ancs === true,
      iphone: d.iphone === true || d.map === true
    })
  }
  return out
}

function parseThread(row) {
  var t = asObject(row)
  if (!t) return null
  var handle = field(t.thread || t.key, MAX_HANDLE)
  if (!handle) return null
  var unread = parseInt(t.unread, 10)
  if (isNaN(unread) || unread < 0) unread = 0
  if (unread > 9999) unread = 9999
  return {
    handle: handle,
    name: field(t.name || t.address, MAX_NAME) || handle,
    address: field(t.address, MAX_HANDLE),
    preview: field(t.preview, MAX_PREVIEW),
    timestamp: epochOf(t.timestamp),
    unread: unread,
    count: parseInt(t.count, 10) || 0,
    group: t.group === true,
    repliable: t.repliable !== false,
    replyReason: field(t.reply_reason, MAX_NOTE)
  }
}

function parseThreads(obj) {
  var rows = asArray(obj && obj.threads)
  var out = []
  var n = Math.min(rows.length, MAX_THREADS * 2)
  for (var i = 0; i < n && out.length < MAX_THREADS; i++) {
    var thread = parseThread(rows[i])
    if (thread) out.push(thread)
  }
  return out
}

function parseMessage(row) {
  var m = asObject(row)
  if (!m) return null
  var body = field(m.body, MAX_BODY)
  var mine = m.outgoing === true
  return {
    handle: field(m.handle, MAX_HANDLE),
    thread: field(m.thread, MAX_HANDLE),
    address: field(m.address, MAX_HANDLE),
    name: field(m.name, MAX_NAME),
    body: body,
    timestamp: epochOf(m.timestamp),
    mine: mine,
    read: m.read !== false,
    otp: extractOtp(body)
  }
}

function parseMessages(obj) {
  var rows = asArray(obj && obj.messages)
  var out = []
  var n = Math.min(rows.length, MAX_MESSAGES * 2)
  for (var i = 0; i < n && out.length < MAX_MESSAGES; i++) {
    var msg = parseMessage(rows[i])
    if (msg) out.push(msg)
  }
  return out
}

function parseContacts(obj) {
  var rows = asArray(obj && obj.contacts)
  var out = []
  var n = Math.min(rows.length, MAX_CONTACTS * 2)
  for (var i = 0; i < n && out.length < MAX_CONTACTS; i++) {
    var c = asObject(rows[i])
    if (!c) continue
    var name = field(c.name, MAX_NAME)
    var addrs = asArray(c.addresses)
    var entries = []
    var k = Math.min(addrs.length, MAX_CONTACT_FIELDS)
    for (var j = 0; j < k; j++) {
      var handle = normalizeHandle(addrs[j])
      if (!handle) continue
      entries.push({
        handle: handle,
        label: field(String(addrs[j]).replace(/^(tel|email|mailto):/i, ""), MAX_HANDLE)
      })
    }
    if (!name && !entries.length) continue
    out.push({
      name: name || (entries[0] ? entries[0].label : ""),
      handle: entries.length ? entries[0].handle : "",
      entries: entries
    })
  }
  return out
}

function parseCalls(obj) {
  var rows = asArray(obj && obj.calls)
  var out = []
  var n = Math.min(rows.length, MAX_CALLS * 2)
  for (var i = 0; i < n && out.length < MAX_CALLS; i++) {
    var c = asObject(rows[i])
    if (!c) continue
    var state = field(c.state, MAX_STATUS)
    if (state === "disconnected") continue
    out.push({
      path: field(c.path, MAX_HANDLE),
      number: field(c.number, MAX_HANDLE),
      name: field(c.name, MAX_NAME),
      state: state,
      ringing: c.ringing === true || state === "incoming" || state === "waiting",
      outgoing: c.outgoing === true,
      connected: c.connected === true || state === "active" || state === "held"
    })
  }
  return out
}

function liveCall(calls) {
  var list = calls || []
  var n = Math.min(list.length, MAX_CALLS)
  var i
  for (i = 0; i < n; i++) {
    if (list[i] && list[i].ringing) return list[i]
  }
  for (i = 0; i < n; i++) {
    if (list[i]) return list[i]
  }
  return null
}

function callTitle(call) {
  if (!call) return ""
  if (call.ringing) return "Incoming call"
  if (call.outgoing && !call.connected) return "Calling"
  if (call.connected) return "On a call"
  return field(call.state, MAX_STATUS) || "Call"
}

function callParty(call) {
  if (!call) return ""
  return call.name || call.number || "Unknown"
}

function firstPhone(devices) {
  var list = devices || []
  var n = Math.min(list.length, MAX_DEVICES)
  for (var i = 0; i < n; i++) {
    if (list[i] && list[i].iphone) return list[i]
  }
  return null
}

function unreadTotal(threads) {
  var list = threads || []
  var n = Math.min(list.length, MAX_THREADS)
  var sum = 0
  for (var i = 0; i < n; i++) {
    var u = list[i] && list[i].unread ? list[i].unread : 0
    if (u > 0) sum += u
  }
  if (sum > 99) return 99
  return sum
}

function barLabel(unread, mapUp, daemonOk) {
  if (daemonOk && mapUp && unread > 0) return String(unread)
  return "Messages"
}

function statusTitle(status, daemonOk) {
  if (!daemonOk) return "Tether is not running"
  if (!status) return "Not connected"
  if (status.map) return "Messages connected"
  if (status.note) return status.note
  if (status.present) return "Phone linked, Messages not ready"
  return "Pair your iPhone"
}

function setupHint(status, daemonOk) {
  if (!daemonOk) return "Open Tether to start the daemon, then pair your iPhone."
  if (status && status.note) return status.note
  if (status && status.present) return "On the iPhone: Settings → Bluetooth → this PC → Show Message Notifications and Sync Contacts."
  return "Pair the iPhone in Tether, then enable message notifications on the phone."
}

function needsSolicit(status) {
  if (!status) return false
  var err = String(status.mapError || "")
  return err === "forbidden" || err === "no_record"
}

function fold(value) {
  return String(value || "").toLowerCase()
}

function filterThreads(threads, needle) {
  var list = threads || []
  var q = fold(needle).replace(/^\s+|\s+$/g, "")
  if (!q) return list
  var out = []
  var n = Math.min(list.length, MAX_THREADS)
  for (var i = 0; i < n; i++) {
    var t = list[i]
    if (!t) continue
    var hay = fold(t.name) + " " + fold(t.address) + " " + fold(t.preview) + " " + fold(t.handle)
    if (hay.indexOf(q) >= 0) out.push(t)
  }
  return out
}

function zeroUnread(threads, handle) {
  var list = threads || []
  var out = []
  var n = Math.min(list.length, MAX_THREADS)
  for (var i = 0; i < n; i++) {
    var t = list[i]
    if (!t) continue
    if (t.handle === handle) {
      out.push({
        handle: t.handle,
        name: t.name,
        address: t.address,
        preview: t.preview,
        timestamp: t.timestamp,
        unread: 0,
        count: t.count,
        group: t.group,
        repliable: t.repliable,
        replyReason: t.replyReason
      })
    } else {
      out.push(t)
    }
  }
  return out
}

function unreadHandles(messages) {
  var list = messages || []
  var out = []
  var n = Math.min(list.length, MAX_MESSAGES)
  for (var i = 0; i < n; i++) {
    var m = list[i]
    if (!m || m.mine || m.read) continue
    if (m.handle && out.indexOf(m.handle) < 0) out.push(m.handle)
  }
  return out
}

function pad2(n) {
  return n < 10 ? "0" + n : String(n)
}

function daysBetween(then, now) {
  var a = new Date(then.getFullYear(), then.getMonth(), then.getDate()).getTime()
  var b = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
  return Math.round((b - a) / 86400000)
}

function dateFromEpoch(epoch) {
  return new Date(epochOf(epoch) * 1000)
}

function formatThreadTime(epoch, nowEpoch) {
  var e = epochOf(epoch)
  if (!e) return ""
  var then = dateFromEpoch(e)
  var now = dateFromEpoch(nowEpoch || Date.now() / 1000)
  var days = daysBetween(then, now)
  if (days <= 0) return pad2(then.getHours()) + ":" + pad2(then.getMinutes())
  if (days === 1) return "Yesterday"
  if (days < 7) return WEEKDAYS[then.getDay()]
  return MONTHS[then.getMonth()] + " " + then.getDate()
}

function formatDayHeading(epoch, nowEpoch) {
  var e = epochOf(epoch)
  if (!e) return ""
  var then = dateFromEpoch(e)
  var now = dateFromEpoch(nowEpoch || Date.now() / 1000)
  var days = daysBetween(then, now)
  if (days <= 0) return "Today"
  if (days === 1) return "Yesterday"
  if (days < 7) return WEEKDAYS_LONG[then.getDay()]
  return WEEKDAYS_LONG[then.getDay()] + ", " + MONTHS[then.getMonth()] + " " + then.getDate()
}

function formatStamp(epoch) {
  var e = epochOf(epoch)
  if (!e) return ""
  var d = dateFromEpoch(e)
  return pad2(d.getHours()) + ":" + pad2(d.getMinutes())
}

function sameLocalDay(a, b) {
  var x = dateFromEpoch(a)
  var y = dateFromEpoch(b)
  return x.getFullYear() === y.getFullYear() && x.getMonth() === y.getMonth() && x.getDate() === y.getDate()
}

function escapeHtml(s) {
  return String(s == null ? "" : s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
}

function trimUrl(url) {
  while (url.length) {
    var c = url.charAt(url.length - 1)
    if (c === "." || c === "," || c === "!" || c === "?" || c === ";" || c === ":") {
      url = url.slice(0, -1)
      continue
    }
    if (c === ")" && url.indexOf("(") < 0) {
      url = url.slice(0, -1)
      continue
    }
    break
  }
  return url
}

function linkify(body) {
  var raw = String(body == null ? "" : body)
  var re = /(https?:\/\/|www\.)[^\s<>"']+/gi
  var out = ""
  var cursor = 0
  var m
  while ((m = re.exec(raw))) {
    var url = trimUrl(m[0])
    if (!url) continue
    out += escapeHtml(raw.slice(cursor, m.index))
    var href = url.slice(0, 4).toLowerCase() === "www." ? "http://" + url : url
    out += "<a href=\"" + escapeHtml(href) + "\">" + escapeHtml(url) + "</a>"
    cursor = m.index + url.length
    re.lastIndex = cursor
  }
  out += escapeHtml(raw.slice(cursor))
  return out
}

function extractOtp(text) {
  var raw = String(text || "")
  if (!raw || raw.length > 4096) return ""
  var lower = raw.toLowerCase()
  var i
  var cued = false
  for (i = 0; i < OTP_CUES.length; i++) {
    if (lower.indexOf(OTP_CUES[i]) >= 0) {
      cued = true
      break
    }
  }
  if (!cued) return ""
  var best = ""
  var re = /\b(\d{3}[- ]\d{3}|\d{4,8})\b/g
  var m
  while ((m = re.exec(raw))) {
    var code = m[1].replace(/[- ]/g, "")
    if (code.length >= 7 && code.charAt(0) === "0") continue
    var from = m.index > 40 ? m.index - 40 : 0
    var context = lower.slice(from, m.index + m[0].length + 40)
    if (context.indexOf("order") >= 0 || context.indexOf("tracking") >= 0 || context.indexOf("$") >= 0)
      continue
    if (!best || (code.length === 6 && best.length !== 6))
      best = code
  }
  return best
}

function decorateTranscript(messages, nowEpoch) {
  var list = messages || []
  var out = []
  var lastStamp = 0
  var lastMine = false
  var lastDay = ""
  var n = Math.min(list.length, MAX_MESSAGES)
  var now = nowEpoch || Date.now() / 1000
  for (var i = 0; i < n; i++) {
    var m = list[i]
    if (!m) continue
    var stamp = epochOf(m.timestamp)
    var day = stamp ? formatDayHeading(stamp, now) : ""
    if (day && day !== lastDay) {
      out.push({ kind: "day", label: day })
      lastDay = day
      lastStamp = 0
    }
    var grouped = lastStamp > 0 && m.mine === lastMine && stamp - lastStamp < GROUP_WINDOW_SECONDS && sameLocalDay(lastStamp, stamp)
    out.push({
      kind: "msg",
      handle: m.handle,
      thread: m.thread,
      name: m.name,
      body: m.body,
      html: linkify(m.body),
      timestamp: stamp,
      mine: !!m.mine,
      read: m.read !== false,
      otp: m.otp || extractOtp(m.body),
      showStamp: !grouped,
      stamp: grouped ? "" : formatStamp(stamp)
    })
    lastStamp = stamp
    lastMine = !!m.mine
  }
  return out
}

function normalizeHandle(value) {
  var h = String(value || "").replace(/^\s+|\s+$/g, "")
  if (!h) return ""
  if (h.indexOf("tel:") === 0 || h.indexOf("email:") === 0 || h.indexOf("group:") === 0)
    return field(h, MAX_HANDLE)
  if (h.indexOf("mailto:") === 0) return field("email:" + h.slice(7), MAX_HANDLE)
  if (h.indexOf("@") >= 0) return field("email:" + h, MAX_HANDLE)
  var digits = h.replace(/[^\d+]/g, "")
  if (!digits) return ""
  return field("tel:" + digits, MAX_HANDLE)
}

function threadByHandle(threads, handle) {
  var h = normalizeHandle(handle)
  if (!h) return null
  var list = threads || []
  var n = Math.min(list.length, MAX_THREADS)
  for (var i = 0; i < n; i++) {
    if (list[i] && list[i].handle === h) return list[i]
  }
  return null
}

function fileFromUrl(url) {
  var u = String(url || "")
  if (u.indexOf("file://") === 0) {
    u = decodeURIComponent(u.slice(7))
    if (u.indexOf("localhost/") === 0) u = u.slice(9)
    else if (u.indexOf("/localhost/") === 0) u = u.slice(10)
  }
  return u
}

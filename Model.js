// Parsers and formatters for Tether's daemon JSON.
// Tether is Zack Bartel's project: https://github.com/zackb/tether
// This plugin does not reimplement iMessage; it talks to tetherd.sock.

var MAX_JSON = 1048576
var MAX_DEVICES = 32
var MAX_CALLS = 8
var MAX_THREADS = 100
var MAX_MESSAGES = 200
var MAX_CONTACTS = 100
var MAX_CONTACT_FIELDS = 16
var MAX_SUGGESTIONS = 80
var MAX_NOTICES = 80
var MAX_NAME = 128
var MAX_PREVIEW = 240
var MAX_BODY = 2048
var MAX_NOTE = 240
var MAX_HANDLE = 256
var MAX_ADDR = 64
var MAX_STATUS = 64
var GROUP_WINDOW_SECONDS = 300
var APP_ID_MESSAGES = "com.apple.MobileSMS"
var LOCAL_HANDLE_PREFIX = "local-"

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

function utf8Len(s) {
  s = String(s == null ? "" : s)
  var n = 0
  var i = 0
  var c
  while (i < s.length) {
    c = s.charCodeAt(i)
    if (c < 0x80) n += 1
    else if (c < 0x800) n += 2
    else if (c >= 0xD800 && c <= 0xDBFF) {
      n += 4
      i += 1
    } else n += 3
    i += 1
  }
  return n
}

function emptyDict() {
  return Object.create(null)
}

function takeSocketLines(buf, chunk, maxBytes) {
  buf = String(buf == null ? "" : buf)
  chunk = String(chunk == null ? "" : chunk)
  var max = parseInt(maxBytes, 10)
  if (isNaN(max) || max < 1) max = MAX_JSON
  var lines = []
  var i = 0
  var bufBytes = utf8Len(buf)
  while (i < chunk.length) {
    var nl = chunk.indexOf("\n", i)
    var piece = nl < 0 ? chunk.slice(i) : chunk.slice(i, nl)
    var n = utf8Len(piece)
    if (bufBytes + n > max) return { buf: "", lines: lines, overflow: true }
    buf += piece
    bufBytes += n
    if (nl >= 0) {
      lines.push(buf)
      buf = ""
      bufBytes = 0
      i = nl + 1
    } else {
      return { buf: buf, lines: lines, overflow: false }
    }
  }
  return { buf: buf, lines: lines, overflow: false }
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
    ancs: obj.ancs_ready === true,
    mapError: field(obj.map_error, MAX_STATUS),
    note: field(obj.profile_reason || obj.link_reason, MAX_NOTE),
    linkReason: field(obj.link_reason, MAX_NOTE),
    profileReason: field(obj.profile_reason, MAX_NOTE),
    ancsReason: field(obj.ancs_reason, MAX_NOTE)
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

function addressKind(handle) {
  var h = String(handle || "")
  if (h.indexOf("email:") === 0 || h.indexOf("mailto:") === 0) return "email"
  return "phone"
}

function flattenContactSuggestions(contacts) {
  var list = contacts || []
  var out = []
  var n = Math.min(list.length, MAX_CONTACTS)
  for (var i = 0; i < n && out.length < MAX_SUGGESTIONS; i++) {
    var c = list[i]
    if (!c) continue
    var entries = c.entries || []
    if (!entries.length) {
      if (!c.handle) continue
      out.push({
        name: c.name || c.handle,
        handle: c.handle,
        label: c.handle,
        kind: addressKind(c.handle)
      })
      continue
    }
    var k = Math.min(entries.length, MAX_CONTACT_FIELDS)
    for (var j = 0; j < k && out.length < MAX_SUGGESTIONS; j++) {
      var e = entries[j]
      if (!e || !e.handle) continue
      out.push({
        name: c.name || e.label || e.handle,
        handle: e.handle,
        label: e.label || e.handle,
        kind: addressKind(e.handle)
      })
    }
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

function parseNotification(row) {
  var n = asObject(row)
  if (!n) return null
  var uid = parseInt(n.uid, 10)
  if (isNaN(uid) || uid < 0) return null
  var title = field(n.title, MAX_NAME)
  var subtitle = field(n.subtitle, MAX_PREVIEW)
  var body = field(n.body, MAX_BODY)
  var appId = field(n.app_id, MAX_HANDLE)
  var appName = field(n.app_name, MAX_NAME) || appId
  var primary = title || body || "New notification"
  var secondary = ""
  if (subtitle) secondary = subtitle
  if (body && body !== primary) {
    if (secondary) secondary += "\n"
    secondary += body
  }
  return {
    uid: uid,
    appId: appId,
    app: appName,
    title: title,
    subtitle: subtitle,
    body: body,
    primary: primary,
    secondary: secondary,
    category: parseInt(n.category, 10) || 0,
    timestamp: epochOf(n.timestamp),
    silent: n.silent === true,
    positive: n.positive_action === true,
    negative: n.negative_action === true,
    messages: appId === APP_ID_MESSAGES,
    otp: extractOtp(title + " " + subtitle + " " + body)
  }
}

function parseNotifications(obj) {
  var rows = asArray(obj && obj.notifications)
  var out = []
  var n = Math.min(rows.length, MAX_NOTICES * 2)
  for (var i = 0; i < n && out.length < MAX_NOTICES; i++) {
    var notice = parseNotification(rows[i])
    if (notice) out.push(notice)
  }
  return out
}

function dropNotice(notifications, uid) {
  var list = notifications || []
  var out = []
  var n = Math.min(list.length, MAX_NOTICES)
  var id = parseInt(uid, 10)
  for (var i = 0; i < n; i++) {
    if (!list[i] || list[i].uid === id) continue
    out.push(list[i])
  }
  return out
}

function filterNotifications(notifications, needle) {
  var list = notifications || []
  var q = fold(needle).replace(/^\s+|\s+$/g, "")
  if (!q) return list
  var out = []
  var n = Math.min(list.length, MAX_NOTICES)
  for (var i = 0; i < n; i++) {
    var notice = list[i]
    if (!notice) continue
    var hay = fold(notice.app) + " " + fold(notice.title) + " " + fold(notice.subtitle) + " " + fold(notice.body) + " " + fold(notice.appId)
    if (hay.indexOf(q) >= 0) out.push(notice)
  }
  return out
}

function noticeCount(notifications) {
  var n = Math.min((notifications || []).length, MAX_NOTICES)
  if (n > 99) return 99
  return n
}

function threadForNotice(threads, notice) {
  if (!notice) return null
  if (notice.messages) {
    var byHandle = threadByHandle(threads, notice.title)
    if (byHandle) return byHandle
  }
  var title = fold(notice.title).replace(/^\s+|\s+$/g, "")
  if (!title) return null
  var list = threads || []
  var n = Math.min(list.length, MAX_THREADS)
  var exact = null
  var exactCount = 0
  for (var i = 0; i < n; i++) {
    var t = list[i]
    if (!t) continue
    if (fold(t.name) === title) {
      exact = t
      exactCount += 1
    }
  }
  if (exactCount === 1) return exact
  return null
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

// nf-md-message — the SMS / iMessage speech bubble in Nerd Fonts.
var BAR_ICON = "󰍡"

function barLabel(unread, mapUp, daemonOk, notices, ancsUp, ringing) {
  if (ringing) return BAR_ICON + " call"
  var n = parseInt(unread, 10)
  if (isNaN(n) || n < 0) n = 0
  if (daemonOk && mapUp && n > 0) return BAR_ICON + " " + String(n)
  var n2 = parseInt(notices, 10)
  if (isNaN(n2) || n2 < 0) n2 = 0
  if (daemonOk && ancsUp && n2 > 0) return BAR_ICON + " " + String(n2)
  return BAR_ICON
}

function statusTitle(status, daemonOk) {
  if (!daemonOk) return "Tether is not running"
  if (!status) return "Not connected"
  if (status.map && status.ancs) return "Messages and notifications"
  if (status.map) return "Messages connected"
  if (status.ancs) return "Notifications connected"
  if (status.note) return status.note
  if (status.ancsReason) return status.ancsReason
  if (status.present) return "Phone linked, Messages not ready"
  return "Pair your iPhone"
}

function setupHint(status, daemonOk) {
  if (!daemonOk) return "Open Tether to start the daemon, then pair your iPhone."
  if (status && status.note) return status.note
  if (status && status.present) return "On the iPhone: Settings → Bluetooth → this PC → Show Message Notifications and Sync Contacts."
  return "Pair the iPhone in Tether, then enable message notifications on the phone."
}

function ancsHint(status, daemonOk) {
  if (!daemonOk) return "Open Tether to start the daemon, then pair your iPhone."
  if (status && status.ancsReason) return status.ancsReason
  if (status && status.present) return "On the iPhone: Settings → Bluetooth → this PC → Show Message Notifications."
  return "Pair the iPhone in Tether to mirror notifications."
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
    if (sameThread(t.handle, handle)) {
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

function unreadThreadHandles(threads) {
  var list = threads || []
  var out = []
  var n = Math.min(list.length, MAX_THREADS)
  var i
  for (i = 0; i < n; i++) {
    if (list[i] && list[i].unread > 0 && list[i].handle) out.push(list[i].handle)
  }
  return out
}

function zeroAllUnread(threads) {
  var list = threads || []
  var out = []
  var n = Math.min(list.length, MAX_THREADS)
  var i
  for (i = 0; i < n; i++) {
    var t = list[i]
    if (!t) continue
    out.push(t.unread ? copyThread(t, { unread: 0 }) : t)
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

function isDnsHostname(host) {
  host = String(host || "").toLowerCase()
  if (!host || host.length > 253) return false
  if (host.charAt(host.length - 1) === ".") host = host.slice(0, -1)
  if (/^\d{1,3}(\.\d{1,3}){3}$/.test(host)) return false
  if (!/^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$/.test(host))
    return false
  var tld = host.split(".").pop()
  if (tld === "local" || tld === "localhost" || tld === "internal" || tld === "lan") return false
  if (tld.length < 2) return false
  return true
}

function parseHttpsUrl(url) {
  var u = String(url == null ? "" : url)
  if (!u || u.length > MAX_BODY) return ""
  if (/[\x00-\x1f\x7f\s<>"'\\]/.test(u)) return ""
  if (u.slice(0, 8).toLowerCase() !== "https://") return ""
  var rest = u.slice(8)
  if (!rest) return ""
  var hostEnd = rest.length
  var slash = rest.indexOf("/")
  var q = rest.indexOf("?")
  var hash = rest.indexOf("#")
  if (slash >= 0 && slash < hostEnd) hostEnd = slash
  if (q >= 0 && q < hostEnd) hostEnd = q
  if (hash >= 0 && hash < hostEnd) hostEnd = hash
  var hostport = rest.slice(0, hostEnd)
  if (!hostport || hostport.indexOf("@") >= 0 || hostport.indexOf("%") >= 0) return ""
  if (hostport.charAt(0) === "[") return ""
  var host = hostport
  var port = ""
  var colon = hostport.lastIndexOf(":")
  if (colon >= 0) {
    host = hostport.slice(0, colon)
    port = hostport.slice(colon + 1)
    if (!/^[1-9][0-9]{0,4}$/.test(port)) return ""
    if (parseInt(port, 10) > 65535) return ""
  }
  if (!isDnsHostname(host)) return ""
  return "https://" + host.toLowerCase() + (port ? ":" + port : "") + rest.slice(hostEnd)
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
    var candidate = url.slice(0, 4).toLowerCase() === "www." ? "https://" + url : url
    var href = parseHttpsUrl(candidate)
    if (href) out += "<a href=\"" + escapeHtml(href) + "\">" + escapeHtml(url) + "</a>"
    else out += escapeHtml(url)
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

function decorateTranscript(messages, nowEpoch, isGroup) {
  var list = messages || []
  var out = []
  var lastStamp = 0
  var lastMine = false
  var lastDay = ""
  var lastName = ""
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
      lastName = ""
    }
    var grouped = lastStamp > 0 && m.mine === lastMine && stamp - lastStamp < GROUP_WINDOW_SECONDS && sameLocalDay(lastStamp, stamp)
    var name = field(m.name, MAX_NAME)
    var showName = !m.mine && !!isGroup && !!name && (!grouped || name !== lastName)
    var stampText = ""
    if (m.pending) stampText = "Sending…"
    else if (m.failed) stampText = "Not sent"
    else if (!grouped) stampText = formatStamp(stamp)
    out.push({
      kind: "msg",
      handle: m.handle,
      thread: m.thread,
      name: name,
      showName: showName,
      body: m.body,
      html: linkify(m.body),
      timestamp: stamp,
      mine: !!m.mine,
      read: m.read !== false,
      pending: m.pending === true,
      failed: m.failed === true,
      otp: m.otp || extractOtp(m.body),
      showStamp: !!stampText,
      stamp: stampText
    })
    lastStamp = stamp
    lastMine = !!m.mine
    lastName = name
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

function telSuffix(raw) {
  var digits = String(raw || "").replace(/\D/g, "")
  if (digits.length < 10) return ""
  return digits.slice(-10)
}

function threadBucket(key) {
  var h = String(key || "")
  if (h.indexOf("tel:") !== 0) return h
  var suffix = telSuffix(h.slice(4))
  if (!suffix) suffix = h.slice(4).replace(/\D/g, "")
  return suffix ? "tel:" + suffix : h
}

function sameThread(a, b) {
  a = String(a || "")
  b = String(b || "")
  if (!a || !b) return false
  if (a === b) return true
  return threadBucket(a) === threadBucket(b)
}

function collapseWs(s) {
  return String(s || "").replace(/\s+/g, " ").replace(/^\s+|\s+$/g, "")
}

function isLocalHandle(handle) {
  return String(handle || "").indexOf(LOCAL_HANDLE_PREFIX) === 0
}

function appendOutgoing(messages, thread, body, nowEpoch) {
  var list = messages || []
  var out = []
  var n = Math.min(list.length, MAX_MESSAGES - 1)
  var i
  for (i = 0; i < n; i++) {
    if (list[i]) out.push(list[i])
  }
  var text = field(body, MAX_BODY)
  var stamp = epochOf(nowEpoch)
  if (!stamp) stamp = Math.floor(Date.now() / 1000)
  out.push({
    handle: LOCAL_HANDLE_PREFIX + String(stamp) + "-" + String(out.length),
    thread: String(thread || ""),
    address: "",
    name: "",
    body: text,
    timestamp: stamp,
    mine: true,
    read: true,
    pending: true,
    failed: false,
    otp: extractOtp(text)
  })
  return out
}

function mergeMessages(server, local, thread) {
  var rows = server || []
  var out = []
  var seen = emptyDict()
  var n = Math.min(rows.length, MAX_MESSAGES)
  var i
  for (i = 0; i < n; i++) {
    if (!rows[i]) continue
    out.push(rows[i])
    if (rows[i].mine) seen[collapseWs(rows[i].body)] = true
  }
  var extras = local || []
  var k = Math.min(extras.length, MAX_MESSAGES)
  for (i = 0; i < k && out.length < MAX_MESSAGES; i++) {
    var m = extras[i]
    if (!m || !m.mine || !isLocalHandle(m.handle)) continue
    if (thread && m.thread && !sameThread(m.thread, thread)) continue
    var body = collapseWs(m.body)
    if (!body || seen[body]) continue
    seen[body] = true
    out.push(m)
  }
  return out
}

function dropLocalOutgoing(messages, body) {
  var want = collapseWs(body)
  var list = messages || []
  var out = []
  var n = Math.min(list.length, MAX_MESSAGES)
  var dropped = false
  var i
  for (i = 0; i < n; i++) {
    var m = list[i]
    if (!dropped && m && m.mine && isLocalHandle(m.handle) && collapseWs(m.body) === want) {
      dropped = true
      continue
    }
    if (m) out.push(m)
  }
  return out
}

function threadByHandle(threads, handle) {
  var h = normalizeHandle(handle) || String(handle || "")
  if (!h) return null
  var list = threads || []
  var n = Math.min(list.length, MAX_THREADS)
  for (var i = 0; i < n; i++) {
    if (list[i] && sameThread(list[i].handle, h)) return list[i]
  }
  return null
}

function draftKey(handle) {
  var h = normalizeHandle(handle) || String(handle || "")
  return threadBucket(h)
}

function getDraft(drafts, handle) {
  var store = drafts || emptyDict()
  var key = draftKey(handle)
  if (key && store[key]) return store[key]
  var raw = String(handle || "")
  if (raw && store[raw]) return store[raw]
  var k
  for (k in store) {
    if (sameThread(k, handle) || sameThread(k, key)) return store[k]
  }
  return ""
}

function putDraft(drafts, handle, text) {
  var next = emptyDict()
  var key = draftKey(handle)
  var old = drafts || emptyDict()
  var k
  for (k in old) {
    if (key && (k === key || sameThread(k, key) || sameThread(k, handle))) continue
    next[k] = old[k]
  }
  var t = String(text || "")
  if (t && key) next[key] = t
  return next
}

function setOutgoingFlags(messages, body, pending, failed) {
  var want = collapseWs(body)
  var list = messages || []
  var out = []
  var n = Math.min(list.length, MAX_MESSAGES)
  var i
  var hit = -1
  for (i = 0; i < n; i++) {
    var m = list[i]
    if (m && m.mine && isLocalHandle(m.handle) && collapseWs(m.body) === want) hit = i
  }
  for (i = 0; i < n; i++) {
    var row = list[i]
    if (!row) continue
    if (i === hit) {
      out.push({
        handle: row.handle,
        thread: row.thread,
        address: row.address,
        name: row.name,
        body: row.body,
        timestamp: row.timestamp,
        mine: true,
        read: true,
        pending: pending === true,
        failed: failed === true,
        otp: row.otp
      })
    } else {
      out.push(row)
    }
  }
  return out
}

function copyThread(t, extra) {
  extra = extra || {}
  return {
    handle: extra.handle != null ? extra.handle : t.handle,
    name: extra.name != null ? extra.name : t.name,
    address: extra.address != null ? extra.address : t.address,
    preview: extra.preview != null ? extra.preview : t.preview,
    timestamp: extra.timestamp != null ? extra.timestamp : t.timestamp,
    unread: extra.unread != null ? extra.unread : t.unread,
    count: extra.count != null ? extra.count : t.count,
    group: extra.group != null ? extra.group : t.group,
    repliable: extra.repliable != null ? extra.repliable : t.repliable,
    replyReason: extra.replyReason != null ? extra.replyReason : t.replyReason
  }
}

function isRawName(t) {
  if (!t || !t.name) return true
  return t.name === t.handle || t.name === t.address
}

function mergeSelectedThread(current, listed) {
  if (!current) return listed || null
  if (!listed) return current
  var name = listed.name
  if (isRawName(listed) && !isRawName(current)) name = current.name
  return copyThread(listed, { name: name })
}

function patchThread(threads, handle, preview, timestamp) {
  var list = threads || []
  var out = []
  var hit = null
  var n = Math.min(list.length, MAX_THREADS)
  var i
  var stamp = epochOf(timestamp)
  if (!stamp) stamp = Math.floor(Date.now() / 1000)
  var text = field(preview, MAX_PREVIEW)
  for (i = 0; i < n; i++) {
    var t = list[i]
    if (!t) continue
    if (sameThread(t.handle, handle)) {
      hit = copyThread(t, { preview: text, timestamp: stamp, unread: 0 })
    } else {
      out.push(t)
    }
  }
  if (!hit) {
    var h = normalizeHandle(handle) || String(handle || "")
    hit = {
      handle: h,
      name: h,
      address: h,
      preview: text,
      timestamp: stamp,
      unread: 0,
      count: 1,
      group: false,
      repliable: true,
      replyReason: ""
    }
  }
  out.unshift(hit)
  return capList(out, MAX_THREADS)
}

function markReadAt(watermarks, handle, epoch) {
  var next = emptyDict()
  var old = watermarks || emptyDict()
  var k
  for (k in old) next[k] = old[k]
  var key = draftKey(handle)
  var stamp = epochOf(epoch)
  if (!stamp) stamp = Math.floor(Date.now() / 1000)
  if (key) next[key] = stamp
  return next
}

function applyReadWatermarks(threads, watermarks) {
  var marks = watermarks || emptyDict()
  var list = threads || []
  var out = []
  var n = Math.min(list.length, MAX_THREADS)
  var i
  for (i = 0; i < n; i++) {
    var t = list[i]
    if (!t) continue
    var w = marks[draftKey(t.handle)]
    if (w && epochOf(t.timestamp) <= w) {
      out.push(copyThread(t, { unread: 0 }))
    } else {
      out.push(t)
    }
  }
  return out
}

function firstUnreadThread(threads) {
  var list = threads || []
  var n = Math.min(list.length, MAX_THREADS)
  var i
  for (i = 0; i < n; i++) {
    if (list[i] && list[i].unread > 0) return list[i]
  }
  return null
}



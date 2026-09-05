// Parsers for the Tether CLI. Tether is Zack Bartel's project:
// https://github.com/zackb/tether
// This plugin does not reimplement iMessage; it only reads/sends via `tether`.

var MAX_INPUT = 65536
var MAX_DEVICES = 32
var MAX_ADAPTERS = 8
var MAX_CALLS = 8
var MAX_THREADS = 100
var MAX_MESSAGES = 200
var MAX_CONTACTS = 300
var MAX_CONTACT_FIELDS = 16
var MAX_NOTICES = 100
var MAX_LAN = 16

var MAX_HOSTS = 8
var MAX_NAME = 128
var MAX_PREVIEW = 240
var MAX_BODY = 2048
var MAX_NOTE = 240
var MAX_HANDLE = 256
var MAX_ADDR = 64
var MAX_TIME = 32
var MAX_FP = 128
var MAX_FLAGS = 160
var MAX_STATUS = 64
var READ_OVERFLOW = 125
var READ_TIMEOUT = 124

function overflowText(text) {
  return String(text || "").length > MAX_INPUT
}

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

function readRejected(code) {
  return code === READ_OVERFLOW || code === READ_TIMEOUT || code === 137
}

function lineYes(text, needle) {
  var lines = String(text || "").split("\n")
  var n = Math.min(lines.length, 256)
  for (var i = 0; i < n; i++) {
    if (lines[i].indexOf(needle) === -1) continue
    return /:\s*yes\b/i.test(lines[i])
  }
  return false
}

function parseConnection(text) {
  if (overflowText(text)) {
    return { present: false, bredr: false, le: false, map: false, pbap: false, ancs: false, note: "", raw: "" }
  }
  var raw = String(text || "")
  return {
    present: lineYes(raw, "Device present"),
    bredr: lineYes(raw, "BR/EDR"),
    le: lineYes(raw, "LE:"),
    map: lineYes(raw, "Messages (MAP)"),
    pbap: lineYes(raw, "Contacts (PBAP)"),
    ancs: lineYes(raw, "Notifications:"),
    note: field(connectionNote(raw), MAX_NOTE),
    raw: ""
  }
}

function connectionNote(raw) {
  var lines = String(raw || "").split("\n")
  var n = Math.min(lines.length, 256)
  for (var i = 0; i < n; i++) {
    var t = lines[i].trim()
    if (t.length > 20 && t.indexOf(":") !== 1) {
      if (/^Device present|^BR\/EDR|^LE:|^Messages|^Contacts|^Notifications/.test(t))
        continue
      return field(t, MAX_NOTE)
    }
  }
  return ""
}

function parseDevices(text) {
  if (overflowText(text)) return []
  var out = []
  var lines = String(text || "").split("\n")
  var n = Math.min(lines.length, 512)
  for (var i = 0; i < n && out.length < MAX_DEVICES; i++) {
    var line = lines[i]
    var m = line.match(/^\s*([0-9A-Fa-f:]{11,})\s+(.+)$/)
    if (!m) continue
    var rest = m[2]
    var role = ""
    var arrow = rest.lastIndexOf("<-")
    if (arrow >= 0) {
      role = rest.slice(arrow + 2).trim()
      rest = rest.slice(0, arrow).trim()
    }
    var fi = rest.search(/\bbonded\b|\bconnected\b/)
    var name = fi < 0 ? rest.trim() : rest.slice(0, fi).trim()
    var flags = fi < 0 ? "" : rest.slice(fi).trim()
    out.push({
      address: field(m[1], MAX_ADDR),
      name: field(name, MAX_NAME),
      flags: field(flags, MAX_FLAGS),
      role: field(role, MAX_NAME),
      connected: flags.indexOf("connected") >= 0,
      map: flags.indexOf("map") >= 0,
      pbap: flags.indexOf("pbap") >= 0,
      ancs: flags.indexOf("ancs") >= 0,
      iphone: /iphone/i.test(role) || flags.indexOf("map") >= 0
    })
  }
  return out
}

function parseThreads(text) {
  if (overflowText(text)) return []
  var out = []
  var cur = null
  var lines = String(text || "").split("\n")
  var n = Math.min(lines.length, 2000)
  for (var i = 0; i < n && out.length < MAX_THREADS; i++) {
    var line = lines[i]
    var handle = line.match(/^\s+((?:tel|mailto):[^\s]+)\s*$/)
    if (handle) {
      if (cur) {
        cur.handle = field(handle[1], MAX_HANDLE)
        out.push(cur)
        cur = null
      }
      continue
    }
    var row = line.match(/^\s+(\S.*?)\s{2,}(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\s+(.*)$/)
    if (row) {
      if (cur) out.push(cur)
      if (out.length >= MAX_THREADS) {
        cur = null
        break
      }
      var preview = row[3].replace(/\s+$/, "")
      var unread = 0
      var um = preview.match(/\s+\((\d+) unread\)\s*$/)
      if (um) {
        unread = parseInt(um[1], 10)
        if (isNaN(unread)) unread = 0
        if (unread > 9999) unread = 9999
        preview = preview.slice(0, um.index).replace(/\s+$/, "")
      }
      cur = {
        name: field(row[1].replace(/\s+$/, ""), MAX_NAME),
        time: field(row[2], MAX_TIME),
        preview: field(preview, MAX_PREVIEW),
        unread: unread,
        handle: ""
      }
    }
  }
  if (cur && out.length < MAX_THREADS) out.push(cur)
  return out
}

function parseMessages(text) {
  if (overflowText(text)) return []
  var out = []
  var lines = String(text || "").split("\n")
  var n = Math.min(lines.length, 4000)
  for (var i = 0; i < n && out.length < MAX_MESSAGES; i++) {
    var line = lines[i]
    if (!line.trim()) continue
    var row = line.match(/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\s+(\S+)\s+(.*)$/)
    if (row) {
      var who = field(row[2].toLowerCase(), 16)
      out.push({
        time: field(row[1], MAX_TIME),
        who: who,
        mine: who === "us" || who === "me" || who === "you",
        body: field(row[3], MAX_BODY)
      })
    } else if (out.length) {
      var last = out[out.length - 1]
      if (last.body.length < MAX_BODY)
        last.body = field(last.body + "\n" + line.trim(), MAX_BODY)
    }
  }
  return out
}

function contactQueryArg(q) {
  q = String(q == null ? "" : q).trim()
  if (!q || q.charAt(0) === "-") return ""
  return field(q, 64)
}

function pushField(list, value, maxLen) {
  var v = field(value, maxLen)
  if (!v) return
  var i
  for (i = 0; i < list.length; i++) {
    if (list[i] === v) return
  }
  if (list.length < MAX_CONTACT_FIELDS) list.push(v)
}

function contactEntries(c) {
  var out = []
  var i
  if (!c) return out
  if (c.tels) {
    for (i = 0; i < c.tels.length && out.length < MAX_CONTACT_FIELDS; i++) {
      var tel = String(c.tels[i])
      out.push({
        kind: "tel",
        label: field(tel.replace(/^tel:/, ""), MAX_HANDLE),
        handle: field(tel.indexOf("tel:") === 0 ? tel : ("tel:" + tel), MAX_HANDLE)
      })
    }
  }
  if (c.emails) {
    for (i = 0; i < c.emails.length && out.length < MAX_CONTACT_FIELDS; i++) {
      var em = String(c.emails[i]).replace(/^email:/, "")
      var mail = em.indexOf("mailto:") === 0 ? em : ("mailto:" + em)
      out.push({
        kind: "email",
        label: field(mail.replace(/^mailto:/, ""), MAX_HANDLE),
        handle: field(mail, MAX_HANDLE)
      })
    }
  }
  if (c.adrs) {
    for (i = 0; i < c.adrs.length && out.length < MAX_CONTACT_FIELDS; i++) {
      out.push({
        kind: "adr",
        label: field(c.adrs[i], MAX_PREVIEW),
        handle: ""
      })
    }
  }
  return out
}

function finishContact(cur) {
  var tels = cur.tels || []
  var emails = cur.emails || []
  var adrs = cur.adrs || []
  var handle = ""
  if (tels.length) {
    handle = tels[0].indexOf("tel:") === 0 ? tels[0] : ("tel:" + tels[0])
  } else if (emails.length) {
    var e = emails[0].replace(/^email:/, "")
    handle = e.indexOf("mailto:") === 0 ? e : ("mailto:" + e)
  }
  var card = {
    name: field(cur.name, MAX_NAME),
    tels: tels,
    emails: emails,
    adrs: adrs,
    handle: field(handle, MAX_HANDLE)
  }
  card.entries = contactEntries(card)
  card.preview = field(contactPreview(card), MAX_PREVIEW)
  return card
}

function contactPreview(c) {
  var entries = contactEntries(c)
  var labels = []
  var i
  for (i = 0; i < entries.length; i++) labels.push(entries[i].label)
  return labels.join(" · ")
}

function parseContacts(text) {
  if (overflowText(text)) return []
  var raw = String(text || "")
  var trimmed = raw.trim()
  if (!trimmed || /^No contacts match/i.test(trimmed) || /^Could not read contacts/i.test(trimmed))
    return []
  var out = []
  var cur = null
  var lines = raw.split("\n")
  var n = Math.min(lines.length, 4000)
  for (var i = 0; i < n && out.length < MAX_CONTACTS; i++) {
    var line = lines[i]
    if (!line.trim()) continue
    var detail = line.match(/^\s{4,}(tel|email|mailto|adr|address|url):\s*(.+?)\s*$/i)
    if (detail && cur) {
      var kind = detail[1].toLowerCase()
      var val = detail[2]
      if (kind === "tel")
        pushField(cur.tels, val.indexOf("tel:") === 0 ? val : ("tel:" + val), MAX_HANDLE)
      else if (kind === "email" || kind === "mailto") {
        val = val.replace(/^email:/, "")
        pushField(cur.emails, val.indexOf("mailto:") === 0 ? val : ("mailto:" + val), MAX_HANDLE)
      } else
        pushField(cur.adrs, val.replace(/^(adr|address|url):/i, ""), MAX_PREVIEW)
      continue
    }
    var nameLine = line.match(/^\s{2}(\S.*)$/)
    if (nameLine && line.indexOf("      ") !== 0) {
      if (cur) out.push(finishContact(cur))
      if (out.length >= MAX_CONTACTS) {
        cur = null
        break
      }
      cur = { name: field(nameLine[1].replace(/\s+$/, ""), MAX_NAME), tels: [], emails: [], adrs: [] }
    }
  }
  if (cur && out.length < MAX_CONTACTS) out.push(finishContact(cur))
  return out
}

function digitsOnly(s) {
  return String(s || "").replace(/[^\d]/g, "")
}

function sameNumber(a, b) {
  var da = digitsOnly(a)
  var db = digitsOnly(b)
  if (!da || !db) return false
  if (da === db) return true
  if (da.length >= 10 && db.length >= 10)
    return da.slice(-10) === db.slice(-10)
  return false
}

function threadByHandle(threads, handle) {
  var h = String(handle || "").toLowerCase()
  if (!h) return null
  var list = threads || []
  var lim = Math.min(list.length, MAX_THREADS)
  for (var i = 0; i < lim; i++) {
    var th = String(list[i].handle || "").toLowerCase()
    if (th === h) return list[i]
    if (h.indexOf("mailto:") === 0 || th.indexOf("mailto:") === 0) {
      if (th.replace(/^mailto:/, "") === h.replace(/^mailto:/, "")) return list[i]
      continue
    }
    if (sameNumber(th, h)) return list[i]
  }
  return null
}

function parseNotifications(text) {
  if (overflowText(text)) return []
  var raw = String(text || "").trim()
  if (!raw || /No notifications yet/i.test(raw) || /Could not read notifications/i.test(raw))
    return []
  var out = []
  var lines = raw.split("\n")
  var n = Math.min(lines.length, 2000)
  var cur = null
  for (var i = 0; i < n && out.length < MAX_NOTICES; i++) {
    var line = lines[i]
    if (!line.trim()) continue
    var row = line.match(/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\s+(\S.*?)\s{2,}(.*)$/)
    if (row) {
      if (cur) out.push(cur)
      if (out.length >= MAX_NOTICES) {
        cur = null
        break
      }
      cur = {
        time: field(row[1], MAX_TIME),
        app: field(row[2].trim(), MAX_NAME),
        title: field(row[3].trim(), MAX_PREVIEW),
        body: ""
      }
      continue
    }
    var titled = line.match(/^\s*(.+?)\s{2,}(.*)$/)
    if (titled && !cur) {
      cur = {
        time: "",
        app: field(titled[1].trim(), MAX_NAME),
        title: field(titled[2].trim(), MAX_PREVIEW),
        body: ""
      }
      continue
    }
    if (cur) {
      if (cur.body.length < MAX_BODY) {
        if (cur.body) cur.body += "\n"
        cur.body = field(cur.body + line.trim(), MAX_BODY)
      }
    } else {
      cur = { time: "", app: "Notification", title: field(line.trim(), MAX_PREVIEW), body: "" }
    }
  }
  if (cur && out.length < MAX_NOTICES) out.push(cur)
  return out
}

function barLabel(status) {
  if (!status) return "Omamessage"
  if (status.map) return "Omamessage"
  if (status.present) return "Omamessage…"
  return "Omamessage"
}

function statusTitle(status) {
  if (!status) return "Tether unavailable"
  if (status.map && status.ancs) return "Messages and notifications"
  if (status.map) return "Messages connected"
  if (status.present) return "Phone linked, Messages not ready"
  return "Not connected"
}

function heroStatus(status) {
  return statusTitle(status).toUpperCase()
}

function threadTime(value) {
  var s = field(value, MAX_TIME)
  if (s.length >= 16) return s.slice(11, 16)
  return s
}

function deviceSubtitle(dev) {
  if (!dev) return ""
  var bits = []
  if (dev.connected) bits.push("connected")
  if (dev.map) bits.push("messages")
  if (dev.pbap) bits.push("contacts")
  if (dev.ancs) bits.push("notify")
  if (dev.role) bits.push(field(dev.role, MAX_NAME))
  return bits.join(" · ")
}

function threadByName(threads, name) {
  if (!name) return null
  var n = String(name).toLowerCase()
  var list = threads || []
  var lim = Math.min(list.length, MAX_THREADS)
  for (var i = 0; i < lim; i++) {
    if (String(list[i].name).toLowerCase() === n) return list[i]
  }
  for (var j = 0; j < lim; j++) {
    if (String(list[j].name).toLowerCase().indexOf(n) >= 0) return list[j]
  }
  return null
}

function wifiConnected(text) {
  return lanConnected(text)
}

function lanConnected(text) {
  if (overflowText(text)) return false
  var lines = String(text || "").split("\n")
  var n = Math.min(lines.length, 256)
  for (var i = 0; i < n; i++) {
    var parts = lines[i].split(":")
    if (parts.length < 3) continue
    var type = parts[1]
    var state = parts[2]
    if (type === "loopback" || type === "bt" || type === "wifi-p2p" || type === "bridge")
      continue
    if (state === "connected" || state.indexOf("connected") === 0)
      return true
  }
  return false
}

function parseDiscover(text) {
  if (overflowText(text)) return []
  var out = []
  var cur = null
  var lines = String(text || "").split("\n")
  var n = Math.min(lines.length, 512)
  for (var i = 0; i < n && out.length < MAX_LAN; i++) {
    var header = lines[i].match(/^\s+(\S.*?)\s+\[([^\]]+)\]\s*$/)
    if (header) {
      if (cur) out.push(cur)
      if (out.length >= MAX_LAN) {
        cur = null
        break
      }
      cur = { name: field(header[1].replace(/\s+$/, ""), MAX_NAME), status: field(header[2].trim(), MAX_STATUS), hosts: [], local: false }
      continue
    }
    var host = lines[i].match(/^\s+(\S.*):(\d+)\s*$/)
    if (host && cur && cur.hosts.length < MAX_HOSTS) {
      var ip = field(host[1], 64)
      var port = parseInt(host[2], 10)
      if (isNaN(port) || port < 1 || port > 65535) continue
      cur.hosts.push({ ip: ip, port: port })
      if (ip === "127.0.0.1" || ip === "::1" || ip === "localhost") cur.local = true
    }
  }
  if (cur && out.length < MAX_LAN) out.push(cur)
  return out
}

function remoteLanPeers(list) {
  var out = []
  var rows = list || []
  var n = Math.min(rows.length, MAX_LAN)
  for (var i = 0; i < n; i++) {
    if (rows[i] && !rows[i].local) out.push(rows[i])
  }
  return capList(out, MAX_LAN)
}

function pairTarget(peer) {
  if (!peer || !peer.hosts || !peer.hosts.length) return null
  var n = Math.min(peer.hosts.length, MAX_HOSTS)
  for (var i = 0; i < n; i++) {
    var h = peer.hosts[i]
    if (String(h.ip).indexOf(":") >= 0) continue
    return h
  }
  return peer.hosts[0]
}

function parseLanDevices(text) {
  if (overflowText(text)) return []
  var raw = String(text || "")
  var start = raw.indexOf("{")
  if (start < 0) return []
  var slice = raw.slice(start)
  if (slice.length > MAX_INPUT) return []
  try {
    var obj = JSON.parse(slice)
    var out = []
    var count = 0
    for (var key in obj) {
      if (!Object.prototype.hasOwnProperty.call(obj, key)) continue
      if (key === "command") continue
      if (String(key).length < 16) continue
      if (count >= MAX_LAN) break
      out.push({ fingerprint: field(key, MAX_FP), name: field(obj[key] || "iPhone app", MAX_NAME) })
      count++
    }
    return out
  } catch (e) {
    return []
  }
}

function parsePendingPair(text) {
  if (overflowText(text)) return null
  var lines = String(text || "").split("\n")
  var n = Math.min(lines.length, 64)
  var pending = null
  for (var i = 0; i < n; i++) {
    var line = lines[i]
    var req = line.match(/\[Pairing Request Pending\] from (.+?)\. Accept by running: tether --accept ([0-9a-fA-F]+)/)
    if (req) {
      pending = { name: field(req[1], MAX_NAME), fingerprint: field(req[2], MAX_FP) }
      continue
    }
    if (/\[Pairing Accepted\]|\[Pairing Rejected\]/.test(line))
      pending = null
  }
  return pending
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

function firstPhone(devices) {
  var list = devices || []
  var n = Math.min(list.length, MAX_DEVICES)
  for (var i = 0; i < n; i++) {
    if (list[i] && list[i].iphone) return list[i]
  }
  return null
}

function clipPreview(text) {
  if (overflowText(text)) return ""
  var raw = String(text || "").replace(/^\[.*?\] \[INFO\]\s*/mg, "").trim()
  if (!raw) return ""
  return neutralizeUi(raw)
}

function initials(name) {
  var s = field(name || "?", 64).trim()
  if (!s) return "?"
  var parts = s.split(/\s+/)
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase()
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
}

function parseBtStatus(text) {
  if (overflowText(text))
    return { mode: "", bond: "", tether: "", classOk: false, adapters: [], adapterId: "", adapterPinned: "", raw: "" }
  var raw = String(text || "")
  var mode = ""
  var bond = ""
  var tether = ""
  var adapterId = ""
  var classOk = /class=ok/.test(raw)
  var adapters = []
  var lines = raw.split("\n")
  var n = Math.min(lines.length, 256)
  for (var i = 0; i < n; i++) {
    var t = lines[i]
    var m = t.match(/^\s*Mode:\s*(.*)$/)
    if (m) { mode = field(m[1].trim(), MAX_STATUS); continue }
    m = t.match(/^\s*Bond:\s*(.*)$/)
    if (m) { bond = field(m[1].trim(), MAX_NOTE); continue }
    m = t.match(/^\s*Tether:\s*(.*)$/)
    if (m) { tether = field(m[1].trim(), MAX_NOTE); continue }
    m = t.match(/^\s*Adapter:\s*(hci\d+)/)
    if (m) { adapterId = field(m[1], 16); continue }
    m = t.match(/^\s+(hci\d+)\s+([0-9A-Fa-f:]{11,})\s+(.*?)\s*$/)
    if (m && adapters.length < MAX_ADAPTERS) {
      var nm = m[3].replace(/\s+<- in use\s*$/, "").replace(/\s+$/, "")
      adapters.push({
        id: field(m[1], 16),
        address: field(m[2], MAX_ADDR),
        name: field(nm, MAX_NAME),
        inUse: /<- in use/.test(m[3])
      })
      if (!adapterId && /<- in use/.test(m[3])) adapterId = field(m[1], 16)
    }
  }
  return {
    mode: mode,
    bond: bond,
    tether: tether,
    classOk: classOk,
    adapters: adapters,
    adapterId: adapterId,
    adapterPinned: "",
    raw: field(raw.trim(), MAX_NOTE)
  }
}

function parseCliCaps(text) {
  var raw = String(text || "")
  return {
    calls: /--bt-calls\b/.test(raw),
    adapter: /--bt-adapter\b/.test(raw),
    forget: /--forget\b/.test(raw)
  }
}

function parseCalls(text) {
  if (overflowText(text)) return []
  var raw = String(text || "").trim()
  if (!raw || /No calls/i.test(raw) || /Unknown action/i.test(raw) || /Could not read calls/i.test(raw))
    return []
  var out = []
  var lines = raw.split("\n")
  var n = Math.min(lines.length, 256)
  for (var i = 0; i < n && out.length < MAX_CALLS; i++) {
    var line = lines[i]
    if (!line.trim()) continue
    if (/^\s+\//.test(line) && out.length) {
      out[out.length - 1].path = field(line.trim(), MAX_HANDLE)
      continue
    }
    var row = line.match(/^(\S+)\s+(\S+)\s+(.*)$/)
    if (!row) continue
    out.push({
      state: field(row[1], MAX_STATUS),
      number: field(row[2], MAX_HANDLE),
      name: field(row[3].trim(), MAX_NAME),
      path: ""
    })
  }
  return out
}

function parseBtSetup(text) {
  if (overflowText(text))
    return { complete: false, text: "" }
  var raw = field(String(text || "").trim(), MAX_BODY)
  return {
    complete: /nothing to do/i.test(raw),
    text: raw
  }
}

function parseRetention(value) {
  var r = String(value || "")
  if (r === "encrypted" || r === "plaintext" || r === "none") return r
  return ""
}

function parseDiagnostics(text) {
  var out = {
    enabled: false,
    ancs: false,
    ancsContent: true,
    retention: "",
    retentionReady: false,
    groupMessages: false,
    callsEnabled: false,
    adapterPinned: "",
    adapterId: "",
    version: ""
  }
  if (overflowText(text)) return out
  var raw = String(text || "")
  var start = raw.indexOf("{")
  if (start < 0) return out
  var slice = raw.slice(start)
  if (slice.length > MAX_INPUT) return out
  try {
    var obj = JSON.parse(slice)
    out.enabled = obj.enabled === true
    out.ancs = obj.ancs_enabled === true
    out.ancsContent = obj.ancs_content_enabled !== false
    out.groupMessages = obj.group_messages_enabled === true
    out.callsEnabled = obj.calls_enabled === true
      || !!(obj.status && obj.status.calls_enabled === true)
    out.retention = parseRetention(obj.retention)
    if (!out.retention && obj.status)
      out.retention = parseRetention(obj.status.retention)
    out.retentionReady = obj.retention_ready === true
      || !!(obj.status && obj.status.retention_ready === true)
    out.adapterPinned = field((obj.adapter || (obj.status && obj.status.adapter) || ""), 16)
    out.adapterId = field(((obj.status && obj.status.capability && obj.status.capability.adapter_id) || ""), 16)
    out.version = field((obj.version || (obj.status && obj.status.version) || ""), 32)
  } catch (e) {
  }
  return out
}

function profileBits(status) {
  var s = status || {}
  return [
    { id: "map", label: "Messages", on: s.map === true },
    { id: "pbap", label: "Contacts", on: s.pbap === true },
    { id: "ancs", label: "Notify", on: s.ancs === true },
    { id: "wifi", label: "Wi-Fi", on: s.wifi === true }
  ]
}

// Parsers for the Tether CLI. Tether is Zack Bartel's project:
// https://github.com/zackb/tether
// This plugin does not reimplement iMessage; it only reads/sends via `tether`.

function lineYes(text, needle) {
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].indexOf(needle) === -1) continue
    return /:\s*yes\b/i.test(lines[i])
  }
  return false
}

function parseConnection(text) {
  var raw = String(text || "")
  return {
    present: lineYes(raw, "Device present"),
    bredr: lineYes(raw, "BR/EDR"),
    le: lineYes(raw, "LE:"),
    map: lineYes(raw, "Messages (MAP)"),
    pbap: lineYes(raw, "Contacts (PBAP)"),
    ancs: lineYes(raw, "Notifications:"),
    note: connectionNote(raw),
    raw: raw
  }
}

function connectionNote(raw) {
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var t = lines[i].trim()
    if (t.length > 20 && t.indexOf(":") !== 1) {
      if (/^Device present|^BR\/EDR|^LE:|^Messages|^Contacts|^Notifications/.test(t))
        continue
      return t
    }
  }
  return ""
}

function parseDevices(text) {
  var out = []
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
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
      address: m[1],
      name: name,
      flags: flags,
      role: role,
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
  var out = []
  var cur = null
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    var handle = line.match(/^\s+((?:tel|mailto):[^\s]+)\s*$/)
    if (handle) {
      if (cur) {
        cur.handle = handle[1]
        out.push(cur)
        cur = null
      }
      continue
    }
    var row = line.match(/^\s+(\S.*?)\s{2,}(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\s+(.*)$/)
    if (row) {
      if (cur) out.push(cur)
      var preview = row[3].replace(/\s+$/, "")
      var unread = 0
      var um = preview.match(/\s+\((\d+) unread\)\s*$/)
      if (um) {
        unread = parseInt(um[1], 10)
        if (isNaN(unread)) unread = 0
        preview = preview.slice(0, um.index).replace(/\s+$/, "")
      }
      cur = {
        name: row[1].replace(/\s+$/, ""),
        time: row[2],
        preview: preview,
        unread: unread,
        handle: ""
      }
    }
  }
  if (cur) out.push(cur)
  return out
}

function parseMessages(text) {
  var out = []
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (!line.trim()) continue
    var row = line.match(/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\s+(\S+)\s+(.*)$/)
    if (row) {
      var who = row[2].toLowerCase()
      out.push({
        time: row[1],
        who: who,
        mine: who === "us" || who === "me" || who === "you",
        body: row[3]
      })
    } else if (out.length) {
      out[out.length - 1].body += "\n" + line.trim()
    }
  }
  return out
}

function parseNotifications(text) {
  var raw = String(text || "").trim()
  if (!raw || /No notifications yet/i.test(raw) || /Could not read notifications/i.test(raw))
    return []
  var out = []
  var lines = raw.split("\n")
  var cur = null
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (!line.trim()) continue
    var row = line.match(/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\s+(\S.*?)\s{2,}(.*)$/)
    if (row) {
      if (cur) out.push(cur)
      cur = { time: row[1], app: row[2].trim(), title: row[3].trim(), body: "" }
      continue
    }
    var titled = line.match(/^\s*(.+?)\s{2,}(.*)$/)
    if (titled && !cur) {
      cur = { time: "", app: titled[1].trim(), title: titled[2].trim(), body: "" }
      continue
    }
    if (cur) {
      if (cur.body) cur.body += "\n"
      cur.body += line.trim()
    } else {
      cur = { time: "", app: "Notification", title: line.trim(), body: "" }
    }
  }
  if (cur) out.push(cur)
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
  var s = String(value || "")
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
  if (dev.role) bits.push(dev.role)
  return bits.join(" · ")
}

function threadByName(threads, name) {
  if (!name) return null
  var n = String(name).toLowerCase()
  for (var i = 0; i < threads.length; i++) {
    if (String(threads[i].name).toLowerCase() === n) return threads[i]
  }
  for (var j = 0; j < threads.length; j++) {
    if (String(threads[j].name).toLowerCase().indexOf(n) >= 0) return threads[j]
  }
  return null
}

function wifiConnected(text) {
  return lanConnected(text)
}

function lanConnected(text) {
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
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
  var out = []
  var cur = null
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var header = lines[i].match(/^\s+(\S.*?)\s+\[([^\]]+)\]\s*$/)
    if (header) {
      if (cur) out.push(cur)
      cur = { name: header[1].replace(/\s+$/, ""), status: header[2].trim(), hosts: [], local: false }
      continue
    }
    var host = lines[i].match(/^\s+(\S.*):(\d+)\s*$/)
    if (host && cur) {
      var ip = host[1]
      var port = parseInt(host[2], 10)
      cur.hosts.push({ ip: ip, port: port })
      if (ip === "127.0.0.1" || ip === "::1" || ip === "localhost") cur.local = true
    }
  }
  if (cur) out.push(cur)
  return out
}

function remoteLanPeers(list) {
  var out = []
  var rows = list || []
  for (var i = 0; i < rows.length; i++) {
    if (rows[i] && !rows[i].local) out.push(rows[i])
  }
  return out
}

function pairTarget(peer) {
  if (!peer || !peer.hosts || !peer.hosts.length) return null
  for (var i = 0; i < peer.hosts.length; i++) {
    var h = peer.hosts[i]
    if (String(h.ip).indexOf(":") >= 0) continue
    return h
  }
  return peer.hosts[0]
}

function parseLanDevices(text) {
  var raw = String(text || "")
  var start = raw.indexOf("{")
  if (start < 0) return []
  try {
    var obj = JSON.parse(raw.slice(start))
    var out = []
    for (var key in obj) {
      if (!Object.prototype.hasOwnProperty.call(obj, key)) continue
      if (key === "command") continue
      if (String(key).length < 16) continue
      out.push({ fingerprint: key, name: String(obj[key] || "iPhone app") })
    }
    return out
  } catch (e) {
    return []
  }
}

function parsePendingPair(text) {
  var lines = String(text || "").split("\n")
  var pending = null
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    var req = line.match(/\[Pairing Request Pending\] from (.+?)\. Accept by running: tether --accept ([0-9a-fA-F]+)/)
    if (req) {
      pending = { name: req[1], fingerprint: req[2] }
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

function parseDownloads(text) {
  var lines = String(text || "").split("\n")
  var out = []
  for (var i = 0; i < lines.length; i++) {
    var n = lines[i].trim()
    if (n) out.push(n)
  }
  return out
}

function firstPhone(devices) {
  var list = devices || []
  for (var i = 0; i < list.length; i++) {
    if (list[i] && list[i].iphone) return list[i]
  }
  return null
}

function clipPreview(text) {
  var raw = String(text || "").replace(/^\[.*?\] \[INFO\]\s*/mg, "").trim()
  if (!raw) return ""
  if (raw.length > 240) return raw.slice(0, 240) + "…"
  return raw
}

function initials(name) {
  var s = String(name || "?").trim()
  if (!s) return "?"
  var parts = s.split(/\s+/)
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase()
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
}

function parseBtStatus(text) {
  var raw = String(text || "")
  var mode = ""
  var bond = ""
  var tether = ""
  var classOk = /class=ok/.test(raw)
  var lines = raw.split("\n")
  for (var i = 0; i < lines.length; i++) {
    var t = lines[i]
    var m = t.match(/^\s*Mode:\s*(.*)$/)
    if (m) { mode = m[1].trim(); continue }
    m = t.match(/^\s*Bond:\s*(.*)$/)
    if (m) { bond = m[1].trim(); continue }
    m = t.match(/^\s*Tether:\s*(.*)$/)
    if (m) { tether = m[1].trim(); continue }
  }
  return {
    mode: mode,
    bond: bond,
    tether: tether,
    classOk: classOk,
    raw: raw.trim()
  }
}

function parseBtSetup(text) {
  var raw = String(text || "").trim()
  return {
    complete: /nothing to do/i.test(raw),
    text: raw
  }
}

function parseDiagnostics(text) {
  var raw = String(text || "")
  var out = { enabled: false, ancs: false, ancsContent: true }
  var start = raw.indexOf("{")
  if (start < 0) return out
  try {
    var obj = JSON.parse(raw.slice(start))
    out.enabled = obj.enabled === true
    out.ancs = obj.ancs_enabled === true
    out.ancsContent = obj.ancs_content_enabled !== false
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



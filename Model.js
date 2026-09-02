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
      cur = {
        name: row[1].replace(/\s+$/, ""),
        time: row[2],
        preview: row[3].replace(/\s+$/, ""),
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
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var parts = lines[i].split(":")
    if (parts.length >= 3 && parts[1] === "wifi" && parts[2] === "connected")
      return true
  }
  return false
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
      out.push({ fingerprint: key, name: String(obj[key] || "iPhone app") })
    }
    return out
  } catch (e) {
    return []
  }
}

function fileFromUrl(url) {
  var u = String(url || "")
  if (u.indexOf("file://") === 0) {
    u = decodeURIComponent(u.slice(7))
    if (u.indexOf("/localhost") === 0) u = u.slice(9)
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

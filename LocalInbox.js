.import "Model.js" as Model

// Local removal records contain identifiers and timestamps, never message text
// or contact names. Tether owns its separate cache; these are display filters.
function parse(value) {
  var data = Model.asObject(value) || {}
  var messages = []
  var threads = []
  Model.asArray(data.messages).forEach(function(row) {
    if (!Model.asObject(row)) return
    var thread = Model.draftKey(row.thread)
    var handle = Model.field(row.handle, Model.MAX_HANDLE)
    if (thread && handle) messages.push({ thread: thread, handle: handle, timestamp: Model.epochOf(row.timestamp) })
  })
  Model.asArray(data.threads).forEach(function(row) {
    if (!Model.asObject(row)) return
    var thread = Model.draftKey(row.thread)
    if (thread) threads.push({ thread: thread, before: Model.epochOf(row.before) })
  })
  return { messages: messages, threads: threads }
}

function cutoff(state, thread) {
  var before = -1
  state.threads.forEach(function(row) {
    if (Model.sameThread(row.thread, thread)) before = Math.max(before, row.before)
  })
  return before
}

function removeMessage(state, message, thread) {
  var next = parse(state)
  var key = Model.draftKey(thread || message.thread)
  if (!key || !message.handle) return next
  next.messages = next.messages.filter(function(row) {
    return row.handle !== message.handle || !Model.sameThread(row.thread, key)
  })
  next.messages.push({ thread: key, handle: message.handle, timestamp: Model.epochOf(message.timestamp) })
  return next
}

function removeThread(state, thread, now) {
  var next = parse(state)
  var before = Math.max(Model.epochOf(now), Model.epochOf(thread.timestamp), cutoff(next, thread.handle))
  next.threads = next.threads.filter(function(row) { return !Model.sameThread(row.thread, thread.handle) })
  next.threads.push({ thread: Model.draftKey(thread.handle), before: before })
  next.messages = next.messages.filter(function(row) {
    return !Model.sameThread(row.thread, thread.handle) || row.timestamp > before
  })
  return next
}

function messages(rows, state, thread) {
  var before = cutoff(state, thread)
  return (rows || []).filter(function(message) {
    // A newly composed local message can share the removal's second. Old
    // optimistic bubbles are explicitly purged when removing a conversation.
    if (!Model.isLocalHandle(message.handle) && Model.epochOf(message.timestamp) <= before) return false
    return !state.messages.some(function(row) {
      return row.handle === message.handle && Model.sameThread(row.thread, thread)
    })
  })
}

function threads(rows, state) {
  var out = []
  var list = rows || []
  list.forEach(function(thread) {
    if (Model.epochOf(thread.timestamp) <= cutoff(state, thread.handle)) return
    var removedPreview = state.messages.some(function(row) {
      return Model.sameThread(row.thread, thread.handle) && row.timestamp >= Model.epochOf(thread.timestamp)
    })
    out.push(removedPreview ? Model.copyThread(thread, { preview: "Message removed", unread: 0 }) : thread)
  })
  return out
}

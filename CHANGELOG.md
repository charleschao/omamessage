# Changelog

## [0.5.3] — 2026-09-14

- Mark-read requests now use Tether's one-message `handle` protocol, so opening a conversation and **Mark all read** update the iPhone correctly.
- Clicking a notification with a complete HTTPS link now opens that exact destination. Truncated iOS URL previews are copied instead of opening a misleading partial link.
- Message bubbles support mouse and keyboard text selection, so a selected portion can be copied with `Ctrl+C`.
- Notifications has a **Clear all** control beside Search; it dismisses every notification for which Tether exposes the dismiss action.

## [0.5.2] — 2026-09-12

- Clicking a link in a message opens it. The copy overlay had been letting that click close the pane.
- Keyboard: `b` back, `n` Notifications tab, `Ctrl+A` mark all messages read.

## [0.5.1] — 2026-09-12

- Sent messages show in the open conversation immediately. A send used to wait on a message list that could arrive under a different thread key (`tel:+1…` vs `tel:…`), so the bubble only appeared after leaving and reopening the chat.
- Send shows **Sending…**, then **Retry** if it fails or times out; the draft comes back. Back after Send already has the new preview on the conversation list.
- Chat title picks up the contact name from Tether instead of staying a raw number. Drafts follow the person across number spellings. Unread badges stay cleared after you open a chat.
- Message box stays clickable after Send. Search no longer breaks when switching tabs. Enter in **To** moves to the message. Empty send says why it failed.
- Opening a chat shows **Loading…** instead of a blank pane. Group bubbles show who spoke. Right-click or hold a bubble to copy it. Right-click the bar icon opens the latest unread chat.
- Bar shows an incoming call, and the notification count when there is no unread SMS. Failed notification dismissals refresh the list. Clicking a non-Messages notification copies it.

## [0.5.0] — 2026-09-10

- Messages and Notifications tabs, matching Tether's ANCS inbox (`bt_list_notifications`)
- Dismiss a mirrored notification with a small X on the row (not a Dismiss chip); copy a one-time code; open the SMS thread when the notice is from Messages
- Live updates on `bt_notification` / `bt_notification_removed`; connection line includes `ancs_ready`
- Transcript stays put if you have scrolled up (same pin-to-bottom rule as tether-gtk 0.2.27)
- Keyboard: `h`/`l` switch tabs, `x` dismisses the selected notification
- Message box stays clickable after Send (it used to disable for the whole Bluetooth send and then ignore clicks)

## [0.4.3] — 2026-09-06

- Open only `https` message links (no userinfo, no IP or localhost)
- Copy OTP through `wl-copy` stdin, not `bash -c` argv
- Require `XDG_RUNTIME_DIR`; do not fall back to `/tmp`
- Cap tetherd socket lines before newline assembly
- IPC no longer launches `tether-gtk`; middle-click and **Open Tether** still do
- Do not spawn `tether` when the socket is down

## [0.4.2] — 2026-09-05

- New message typeahead lists every phone and email for a contact, not only the first.

## [0.4.1] — 2026-09-05

- Bar uses the Nerd Font message bubble (`󰍡`) instead of the word Messages. Unread count sits beside the icon.

## [0.4.0] — 2026-09-05

- Inbox only: search, conversations, reply, new message. No Settings / Link / Notify / Calls / Contacts tabs.
- Talk JSON to `$XDG_RUNTIME_DIR/tether/tetherd.sock` (live events, mark-read, groups, contact typeahead).
- Bar shows **Messages** or the unread count.
- Relative times, day headings, grouped bubbles, clickable links, OTP copy chip.
- Incoming call banner. First-run empty state opens Tether.
- Keyboard: j/k, Enter, Esc, `/` search, `n` new message.

## [0.3.11] — 2026-09-04

- Settings: Bluetooth controller (`--bt-adapter`), per-device pair, copy setup commands, copy diagnostics
- Link: outbound Wi-Fi pair (`--pair --host`) and Forget (`--forget`)
- Link files: Browse from `~/Downloads` (picker closes the overlay first so the file sticks in the field)
- Calls tab when Tether CLI has `--bt-calls` (dial / answer / hang up / enable)

## [0.3.10] — 2026-09-04

- Contacts on the inbox footer (left); Open Tether stays on the right
- Search iPhone contacts via `tether --bt-contacts` and open a chat
- Contacts list shows every phone and email Tether returns (postal if the CLI prints it)
- Settings: on-disk retention (`encrypted` / `plaintext` / `none`) via `tether --bt-retention`

## [0.3.9] — 2026-09-04

- Security: pin every remote-derived `Text` sink to `Text.PlainText`
- Security: neutralize strings before qs.Ui controls (clipboard, notes, tooltip)
- Security: wrap Tether/nmcli reads in `scripts/bounded-cmd.sh` (64 KiB stdout/stderr, TERM then KILL after 8s+2s); reject overflow (exit 125) and timeouts (124) before model insert
- Security: cap parser input, row counts, and per-field lengths in `Model.js`
- Quieter inbox: one status line, smaller tabs, list fills the panel
- New-message row is lighter; To field is wider
- Thread back sits on the title row; timestamps once per run
- Thread compose matches the inbox (no filled bar)
- Link and Settings drop the manuals; Notify empty is one line
- Open Tether only on the Messages tab

## [0.3.8] — 2026-09-02

- Time-only stamps on bubbles (no date)
- Unread dot clears after a conversation is opened (local watermark)
- Compact thread header; conversation list fills the panel
- Open Tether stays on the inbox page only
- Marketplace: `preview.png`, submit tags/category match the live form
- Docs: credit Zack in README, LICENSE, and manifest — not the popout chrome

## [0.3.7] — 2026-09-02

- Pairing Accept reads pairing lines from tetherd.log instead of a 500-line tail (UnixServer spam)
- Do not clear compose text if a send is already in flight
- Docs: LAN includes ethernet; README matches the current UI

## [0.3.6] — 2026-09-02

- Re-advertise is a real button and shows Tether’s reply on Notify
- Link distinguishes Bluetooth messages (already paired) from the iOS app (clipboard)
- Watch `known_hosts.json` so a GTK Wi-Fi pair shows up without waiting for refresh

## [0.3.5] — 2026-09-02

- Link Accept uses a pending `tether --accept` fingerprint from tetherd.log (iOS app initiates Wi-Fi pairing)
- Show pairing status on Link, not only Settings

## [0.3.4] — 2026-09-02

- Link tab discovers the iOS app on the LAN and can send a Wi-Fi pair request
- Clipboard Pull always fills the field; Push notes when the iOS app is not paired
- Footer and Link: **Open Tether**

## [0.3.3] — 2026-09-02

- Quieter inbox: hero + one status line, phone name, no device/status chip soup
- Conversation rows without initials; unread is a small dot
- Compose is a single row like a reply field

## [0.3.2] — 2026-09-02

- Restore plugin id `io.github.charleschao.omamessage`

## [0.3.1] — 2026-09-02

- Keep `.hermes.md`, `AGENTS.md`, and `CLAUDE.md` local — they are not in the public tree

## [0.3.0] — 2026-09-02

- Settings tab: MAP / notification toggles, pair, explicit-pair, unpair, iOS fingerprint accept, `--bt-setup` remaining steps
- Unread counts on the conversation list; Messages / Contacts / Notify / Wi-Fi chips
- Clipboard push uses `tether -s` (no Python helper)
- Follows Omarchy light/dark theme tokens (`Color.muted` / `Color.accent` / `Style` fills)

## [0.2.0] — 2026-09-01

- Inbox popout: device chips, Messages / Notifications / Link tabs
- Click a thread to read and send; New message composer
- Link tab always visible; clipboard/files/iOS disable when PC Wi-Fi is off
- Credits Tether by Zack Bartel; Tether is not bundled

## [0.1.0] — 2026-08

- First local bar widget stub (status card)

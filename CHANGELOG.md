# Changelog

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

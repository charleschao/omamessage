# Omamessage

Omarchy bar inbox for iPhone SMS, iMessage, and notification mirroring — driven by [Tether](https://github.com/zackb/tether) by **Zack Bartel**.

Tether’s advantage over [BlueBubbles](https://bluebubbles.app/) is that you do **not** need a Mac or a macOS VM running in the background. Continuity-style features talk to the iPhone from Linux.

**Requires Tether by Zack Bartel installed separately.** Omamessage is not Apple iMessage, not a Tether fork, and not a standalone messenger. It does not bundle `tetherd`, `tether-gtk`, or the iOS app. If `tetherd` is not running, the widget has nothing to show.

## Required: install Tether first

Arch: install the `tether-bin` package from the AUR, then:

```sh
tether --bt-setup    # follow the printed BlueZ steps once
```

Then:

1. Keep `tetherd` running in the background (the process that holds Bluetooth MAP).
2. Pair in `tether-gtk` (Devices → Pair over Bluetooth).
3. On the iPhone: Settings → Bluetooth → (i) next to this PC → enable **Show Message Notifications** and **Sync Contacts**.

Details: [docs/REQUIRED.md](docs/REQUIRED.md)

## Install (plugin)

After Tether works on the machine:

```sh
omarchy plugin add https://github.com/charleschao/omamessage.git --enable
```

When you enable it in a terminal, Omarchy asks **left / center / right**. The default is **right**. Scripts using `--yes` skip the question and land on the right.

Move it later:

```sh
omarchy bar move io.github.charleschao.omamessage --section left
```

Validate a local checkout:

```sh
omarchy plugin validate .
```

## Remove

```sh
omarchy plugin remove io.github.charleschao.omamessage
```

This plugin writes no state, cache, or credentials of its own. Removal deletes the widget from the Omarchy plugins directory.

It does **not** stop or uninstall Tether. `tetherd`, `tether-gtk`, pairing, and anything Tether stored stay until you remove Tether itself.

## Requirements

- [Omarchy](https://omarchy.org/) with the Quattro shell
- [Tether](https://github.com/zackb/tether) by **Zack Bartel** (`tether` + `tetherd` on `PATH`; Arch: `tether-bin` or `tether`)
- An iPhone paired over Bluetooth with **Show Message Notifications** and **Sync Contacts** enabled
- `tetherd` must stay running (holds the Bluetooth MAP session)

## Features

### Bar

- Nerd Font speech bubble (`󰍡`)
- Unread SMS count beside the icon; notification count when there is no unread SMS
- Incoming call on the label (`call`) while the iPhone is ringing
- Dim when Messages and notification mirroring are both down
- Follows the Omarchy light or dark theme (`omarchy theme set`)

### Messages

- Conversation list with search, unread badges, and relative times
- **New** message with iPhone contact typeahead (every phone and email Tether returns)
- Reply from a thread; Send shows **Sending…** until Tether answers
- Failed or timed-out send restores the draft and offers **Retry**
- Transcript: day headings, grouped bubbles, sender names in group chats
- https links open in the browser (the pane stays open)
- Copy a bubble (right-click or hold); copy chip when an SMS is a one-time code
- Opening a chat shows **Loading…** instead of a blank pane
- Drafts and unread-cleared state follow the person across number spellings (`tel:+1…` / `tel:…`)
- Transcript stays put if you have scrolled up; your own send still jumps to the bottom
- First-run empty state: **Open Tether** and **Ask iPhone** (re-advertise Bluetooth permissions)

### Notifications

- Tether’s ANCS mirror in a second tab
- Dismiss on the iPhone with the small X on the row
- Copy a one-time code from a mirrored notice
- A Messages notice opens that SMS thread; any other notice copies its text

### Calls

- Incoming-call banner in the popout: Answer / Decline (or Hang up)
- Audio stays on the iPhone

Clipboard sync, file transfer, pairing, Bluetooth adapter, retention, OTP vault, and desktop notification *popups* stay in Tether (`tether-gtk` / `tetherd` / the iOS app). Omamessage is the bar inbox and the notification list.

## Keyboard

Shortcuts apply while the popout is focused and you are not typing in Search, To, or Message.

| Key | Action |
| --- | --- |
| `j` / `k` or ↓ / ↑ | Move in the conversation or notification list |
| Enter or Space | Open the selected row |
| `h` / `l` or ← / → | Messages ↔ Notifications (from the inbox); ← / `h` is Back in a thread |
| `n` | Notifications tab |
| `b` or Esc | Back to the list (Esc from the inbox closes the pane) |
| `/` | Search |
| `x` | Dismiss the selected notification |
| `Ctrl+A` | Mark all conversations read |
| Tab | Next Omarchy bar popout |
| Esc in Search | Clear the query, then unfocus (does not close the pane) |

**New** is the button on the Messages tab (not `n`). `Ctrl+A` in a text field still selects all in that field.

## Mouse

| Action | Result |
| --- | --- |
| Left-click the bar icon | Toggle the popout |
| Right-click the bar icon | Open the latest unread chat (or the inbox if none) |
| Middle-click the bar icon | Open `tether-gtk` |
| Click ← | Back to the list |
| Click a https link in a bubble | Open it |
| Right-click or hold a bubble | Copy the message |
| Click a non-Messages notification | Copy its text |
| Click the X on a notification | Dismiss it on the iPhone |

## Limits

Car-kit / MAP limits (not this UI): no tapbacks, no attachments, no blue/green iMessage bubbles, group reply only when Tether has a roster.

https links only (no `http`, no userinfo, no IP or localhost).

## Credit

Tether — daemon, GTK app, iOS companion, Bluetooth MAP/ANCS — is by **Zack Bartel** (`zackb`). Omamessage only talks to the local daemon.

- https://github.com/zackb/tether
- Author: Zack Bartel

## Marketplace

Plugin id: `io.github.charleschao.omamessage`

Listing copy and the submit checklist: [docs/MARKETPLACE.md](docs/MARKETPLACE.md)

Publish flow: [docs/PUBLISH.md](docs/PUBLISH.md)

Changelog: [CHANGELOG.md](CHANGELOG.md)

## License

MIT (this widget only). Tether is a separate MIT project; no Tether source is copied here.

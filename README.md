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
- Unread SMS or notification count beside the icon
- Incoming-call indicator while the iPhone is ringing
- Follows the Omarchy light or dark theme

### Messages

- Searchable conversation list with unread badges and relative times
- New messages with iPhone contact typeahead, plus replies from any thread
- Reliable sending with a visible Sending state, Retry, and draft restoration on failure
- Thread transcript with day headings, grouped bubbles, and group-chat sender names
- Links open in the browser; copy a bubble by right-clicking or holding it
- Detected one-time codes show a clickable **Copy XXXXX code** action
- First-run empty state with **Open Tether** and **Ask iPhone**

### Notifications

- Tether’s ANCS mirror in a second tab
- Dismiss notifications on the iPhone or copy detected one-time codes
- Messages notices open the SMS thread; other notices copy their text

### Calls

- Incoming-call banner with Answer, Decline, or Hang up
- Audio stays on the iPhone

Pairing, Bluetooth, clipboard sync, file transfer, retention, OTP vault, and desktop notification *popups* stay in Tether. Omamessage is the bar inbox and notification list.

## Keyboard

Shortcuts apply while the popout is focused and you are not typing in Search, To, or Message.

| Key | Action |
| --- | --- |
| `j` / `k` or ↓ / ↑ | Move in the conversation or notification list |
| Enter or Space | Open the selected row |
| `h` / `l` or ← / → | Messages ↔ Notifications (from the inbox); ← / `h` is Back in a thread |
| `n` | Notifications tab |
| `Esc` | Back to the list (from the inbox, closes the pane) |
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

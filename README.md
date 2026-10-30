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

The plugin stores local removal identifiers and timestamps in its inline Omarchy bar settings so removed items stay hidden after a shell restart. It stores no message bodies, contact names, or credentials on disk. Plugin removal deletes the widget from the Omarchy plugins directory.

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
- Phone battery, carrier, and signal in the tooltip when Tether supplies them

### Messages

- Searchable conversation list with unread badges and relative times
- New messages with iPhone contact typeahead, plus replies from any thread
- Keep sending while earlier messages finish: an ordered queue with Queued / Sending status on each bubble, Retry and draft restoration for rejected messages
- Missing send results show **Send unconfirmed**; the queue continues without automatically resending a message that may already be on the iPhone. Queued messages wait through a connection loss while the shell stays running.
- Thread transcript with day headings, grouped bubbles, and group-chat sender names
- Every bubble has a visible **Copy text** button; highlight part of a message to use **Copy selection** or `Ctrl+C`
- Right-click a message for **Copy text** or **Delete message from widget**. Right-click a conversation for **Delete conversation from widget**, which removes its row, loaded history, local outgoing copies, and draft without deleting the address-book contact. Messages must finish sending before conversation removal; individual sent bubbles must also sync first.
- Removals persist through refresh and restart. A new message can bring back a removed conversation; its older history stays hidden. Contacts remain available under **New**.
- **These actions remove content from Omamessage only. Tether does not expose individual cache deletion, so its stored history remains; iPhone messages and contacts are unchanged.** Tether's retention controls stay in Tether.
- Links open in the browser
- Detected one-time codes keep a separate **Copy XXXXX** action
- First-run empty state with **Open Tether** and **Ask iPhone**

### Notifications

- Tether’s ANCS mirror in a second tab
- Full, selectable notification text with **Copy text** and **Copy selection** buttons
- Dismiss notifications on the iPhone or copy detected one-time codes
- Messages notices open the SMS thread; other notices copy their text
- App icons from the installed icon theme or Tether, with a generic fallback
- Complete bare-domain links such as `example.com/help` open over HTTPS too

### Phone status and audio

- The popout shows phone battery and cellular status when available, and distinguishes a released Messages connection from one busy on another computer
- If **Hide unknown senders** is enabled in Tether, its filtered inbox is used and the popout shows **Unknown senders hidden**
- **Audio → Turn audio off** keeps the iPhone's music and sounds on the phone. **Turn audio on** routes them to the computer. Your choice stays until you toggle it again or change it in Tether; there is no automatic restore
- If turning audio on stalls, the widget tries one Classic Bluetooth reconnect for the selected iPhone. Messages may briefly reconnect; the Bluetooth pairing and LE notification link are kept. **Cancel · keep on iPhone** stops an in-progress attempt. Failures appear in the Audio menu and leave the toggle available to retry
- Turning audio off waits briefly for an opening stream to settle, avoiding a BlueZ state that can block later audio connections
- Audio routing needs Tether 0.2.43 or newer and an available Bluetooth audio route. The toggle talks directly to the daemon socket. This control does not change your Bluetooth audio roles or enable call audio. Tether may restart WirePlumber once when setting up its per-phone routing rule for the first time

Right-click a conversation for **Remove from Tether inbox…** (Tether 0.2.42+). After confirmation, this hides the displayed history across Tether clients on this computer; a newer message brings it back. The iPhone and Tether's stored history stay unchanged. **Delete conversation from widget** remains a separate, widget-only action. Individual-message removal stays widget-only.

### Calls

- Incoming-call banner with Answer, Decline, or Hang up
- Call audio remains managed by Tether and the system audio configuration

Pairing, Bluetooth, clipboard sync, file transfer, retention, OTP vault, and desktop notification *popups* stay in Tether. Omamessage is the bar inbox and notification list.

## Keyboard

Shortcuts apply while the popout is focused and you are not typing in Search, To, or Message, or selecting message or notification text.

| Key | Action |
| --- | --- |
| `j` / `k` or ↓ / ↑ | Move in the conversation or notification list |
| Enter or Space | Open the selected row |
| `h` / `l` or ← / → | Messages ↔ Notifications (from the inbox); ← / `h` is Back in a thread |
| `n` | Notifications tab |
| `a` | Open the phone audio menu |
| `Esc` | Back to the list (from the inbox, closes the pane) |
| `/` | Search |
| `x` | Dismiss the selected notification |
| `Ctrl+A` | Mark all conversations read |
| Tab | Next Omarchy bar popout |
| Esc in Search | Clear the query, then unfocus (does not close the pane) |

**New** is the button on the Messages tab (not `n`). `Ctrl+A` in a text field or selectable message/notification selects its text. `Esc` leaves text selection before navigating back.

## Mouse

| Action | Result |
| --- | --- |
| Left-click the bar icon | Toggle the popout |
| Right-click the bar icon | Open the latest unread chat (or the inbox if none) |
| Middle-click the bar icon | Open `tether-gtk` |
| Click ← | Back to the list |
| Click a https link in a bubble | Open it |
| Click **Copy text** under a message or notification | Copy its whole text; the button briefly shows **Copied** |
| Drag across message or notification text | Highlight specific text; the button becomes **Copy selection** |
| Click **Copy selection** or press `Ctrl+C` | Copy only the highlighted text |
| Click **Copy XXXXX** | Copy just the detected one-time code |
| Right-click a bubble | Open Copy / Delete from widget menu |
| Right-click a conversation | Open Delete conversation from widget menu |
| Choose **Remove from Tether inbox…** | Confirm removal across Tether clients on this computer |
| **Audio → Turn audio off / on** | Keep music and sounds on the iPhone, or route them to the computer |
| Hold a bubble | Copy the whole message |
| Click **Open** or the header of a notification with a complete HTTPS link | Open that exact web destination (Discord, Telegram, and X links included) |
| Click another non-Messages notification | Copy its text |
| Click the X on a notification | Dismiss it on the iPhone |
| Click **Clear all** in Notifications | Dismiss all notifications that Tether permits this widget to dismiss |
| Click **Read all** in Messages | Mark all conversations read, including those hidden by search |

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

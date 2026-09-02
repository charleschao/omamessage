# Omamessage

Omarchy bar inbox for iPhone SMS, iMessage, notifications, clipboard, and files — driven by [Tether](https://github.com/zackb/tether) by **Zack Bartel**.

**Requires Tether by Zack Bartel installed separately.** Omamessage is not Apple iMessage, not a Tether fork, and not a standalone messenger. It does not bundle `tetherd`, `tether-gtk`, or the iOS app. If `tether` is missing from `PATH`, the widget has nothing to show.

The popout follows the Omarchy light or dark theme (`omarchy theme set`).

Plugin id: `io.github.charleschao.omamessage`

## Required: install Tether first

Arch:

```sh
yay -S tether-bin
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
omarchy bar move io.github.charleschao.omamessage --section right
```

Validate a local checkout:

```sh
omarchy plugin validate .
```

## Remove

```sh
omarchy plugin remove io.github.charleschao.omamessage
```

Removing the bar widget does not stop Messages if `tetherd` / `tether-gtk` still talk to the phone.

## Requirements

- [Omarchy](https://omarchy.org/) with the Quattro shell
- [Tether](https://github.com/zackb/tether) by **Zack Bartel** (`tether` + `tetherd` on `PATH`; Arch: `tether-bin` or `tether`)
- An iPhone paired over Bluetooth with **Show Message Notifications** and **Sync Contacts** enabled
- Optional: Tether iOS app on the same Wi-Fi LAN for clipboard and file transfer
- `tetherd` must stay running (holds the Bluetooth MAP session)

## Features

- Device chips and Messages / Contacts / Notify / Wi-Fi status
- Messages: conversation list (unread counts), transcript, reply, new message
- Notifications: mirrored ANCS (needs Bluetooth LE); re-advertise permissions
- Link (always visible): Bluetooth pair, iOS app status, clipboard pull/push, file drop + Send, recent `~/Downloads`
- Settings: MAP / notification toggles, pair / explicit-pair / unpair, accept iOS fingerprint, `tether --bt-setup` remaining steps
- Middle-click the bar label, or footer **Open app**: `tether-gtk`

Clipboard, files, and iOS pairing **disable while this PC’s Wi-Fi is off**. Bluetooth messages still work.

Not in this bar (they stay in Tether): OTP / TOTP vault, Firefox and Thunderbird add-ons, native-messaging host.

Car-kit limits (groups, tapbacks, attachments, no blue/green bubbles) are Tether/iOS MAP, not this UI.

## Credit

Tether — daemon, GTK app, iOS companion, Bluetooth MAP/ANCS — is by **Zack Bartel** (`zackb`). Omamessage only calls the local `tether` CLI.

- https://github.com/zackb/tether
- Author: Zack Bartel

## Marketplace

Listing copy and the submit checklist: [docs/MARKETPLACE.md](docs/MARKETPLACE.md)

Publish flow: [docs/PUBLISH.md](docs/PUBLISH.md)

## License

MIT (this widget only). Tether is a separate MIT project; no Tether source is copied here.

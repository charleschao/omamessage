# Tether must be installed separately

This Omarchy plugin **does not include Tether**.

It is a bar inbox that talks newline JSON to:

```
$XDG_RUNTIME_DIR/tether/tetherd.sock
```

`XDG_RUNTIME_DIR` must be set. The widget does not fall back to `/tmp`.

The same socket `tether-gtk` uses. Typical commands:

- `subscribe`
- `bt_status` (version, routing availability, and current unknown-sender filtering)
- `bt_connection` / `bt_list_devices` / `bt_list_threads` / `bt_list_messages`
- `bt_list_contacts` / `bt_send_message` / `bt_mark_read`
- `bt_list_notifications` / `bt_notification_action`
- `bt_list_calls` / `bt_call_action`
- `bt_solicit`
- `bt_remove_thread` (optional shared inbox removal; Tether 0.2.42+)
- `bt_set_phone_audio` (on/off music/sound routing; Tether 0.2.43+)

The audio toggle talks JSON directly to the same daemon socket. **Off** selects the iPhone; **On** selects the computer. Tether remembers the choice, and the widget never restores or reverses it automatically. Existing system audio roles determine whether routing is available.

If enabling audio stalls, the widget attempts one recovery with `busctl` on the selected iPhone's `org.bluez.Bearer.BREDR1` interface. This reconnects only the Classic link, so Messages may reconnect briefly while the LE notification link and pairing remain intact. Recovery requires BlueZ's experimental bearer API, which is already a Tether requirement. The widget confirms the actual audio route, displays failures in the Audio menu, and allows cancellation. Turning audio off includes a short settling delay to avoid interrupting AVDTP Open. No scheduled audio restore or shutoff is created.

OTP vault, browser, and mail add-ons stay in Tether (Firefox / Thunderbird). They are not installed by this plugin. Clipboard sync and file transfer stay in `tetherd` / `tether-gtk` / the iOS app.

Those binaries come from [Tether](https://github.com/zackb/tether) by **Zack Bartel**. Install that project first (on Arch: `tether-bin` from the AUR), complete `tether --bt-setup`, and pair the iPhone over Bluetooth.

Without Tether:

- the widget label stays dim
- the conversation list is empty
- replies cannot send

`tetherd` (the daemon) must stay running in the background. That is the process that holds the Bluetooth MAP link. You do **not** need the `tether-gtk` window open.

The Omarchy bar widget is only a UI on top of Tether. If you remove it from the bar, Super+Alt+M still opens tether-gtk. You need one or the other (or both) to read/send from the desktop; you always need `tetherd`.

The plugin must not be listed as a standalone iMessage client. Marketplace description, README, and install steps must say Tether is a required dependency.

Do not copy Tether source into this repo. Keep credit and the GitHub link in the README, LICENSE, and manifest description — not in the popout chrome.

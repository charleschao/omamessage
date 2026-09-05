# Tether must be installed separately

This Omarchy plugin **does not include Tether**.

It is a bar inbox that talks newline JSON to:

```
$XDG_RUNTIME_DIR/tether/tetherd.sock
```

The same socket `tether-gtk` uses. Typical commands:

- `subscribe`
- `bt_connection` / `bt_list_devices` / `bt_list_threads` / `bt_list_messages`
- `bt_list_contacts` / `bt_send_message` / `bt_mark_read`
- `bt_list_calls` / `bt_call_action`
- `bt_solicit`

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

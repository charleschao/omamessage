# Tether must be installed separately

This Omarchy plugin **does not include Tether**.

It is a bar/inbox UI that shells out to:

- `tether --bt-connection`
- `tether --bt-devices`
- `tether --bt-threads`
- `tether --bt-messages`
- `tether --bt-contacts`
- `tether --bt-send`
- `tether --bt-retention`
- `tether --bt-notifications`
- `tether --bt-solicit`
- `tether --bt-pair` / `--bt-unpair` / `--explicit-pair`
- `tether --bt-enable` `--bt-ancs` `--bt-ancs-content`
- `tether --bt-adapter`
- `tether --bt-status` `--bt-setup` `--bt-diagnostics`
- `tether --bt-calls` `--bt-call` `--bt-answer` `--bt-hangup` `--bt-calls-enable` (when the installed CLI has them)
- `tether-gtk` (middle-click / Open Tether)
- `tether --list-devices`, `--discover`, `--pair`, `-g`, `-s`, `-f`, `--accept`, `--forget` — Link / Settings (disabled while this PC has no LAN; ethernet counts)

OTP / browser / mail add-ons stay in Tether (Firefox / Thunderbird). They are not installed by this plugin.

Those binaries come from [Tether](https://github.com/zackb/tether) by **Zack Bartel**. Install that project first (on Arch: `tether-bin` from the AUR), complete `tether --bt-setup`, and pair the iPhone over Bluetooth.

Without Tether:

- the widget label stays dim / disconnected
- thread and notification lists are empty
- replies cannot send

`tetherd` (the daemon) must stay running in the background. That is the process that holds the Bluetooth MAP link. You do **not** need the `tether-gtk` window open.

The Omarchy bar widget is only a UI on top of Tether. If you remove it from the bar, Super+Alt+M still opens tether-gtk. You need one or the other (or both) to read/send from the desktop; you always need `tetherd`.

The plugin must not be listed as a standalone iMessage client. Marketplace description, README, and install steps must say Tether is a required dependency.

Do not copy Tether source into this repo. Keep credit and the GitHub link in the README, LICENSE, and manifest description — not in the popout chrome.

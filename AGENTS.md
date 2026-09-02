# AGENTS.md

Instructions for AI coding tools working in this repository (Grok, Hermes, Claude Code, Codex, Cursor, etc.).

## What this is

Omamessage is an **Omarchy Quattro bar-widget**. It is a QML inbox that shells out to the local [Tether](https://github.com/zackb/tether) CLI by Zack Bartel.

It is **not**:

- Apple iMessage
- A Tether fork
- A standalone messenger
- A second Quickshell process

Do **not** copy Tether source into this repo. Do **not** PR this widget into `zackb/tether`.

## Layout (marketplace contract)

`manifest.json` **must stay in the repository root**. Omarchy `plugin add` clones this git repo as-is.

```
.
├── manifest.json      # schemaVersion 1, id io.github.charleschao.omamessage
├── BarWidget.qml      # kinds: bar-widget entry point
├── Panel.qml          # nested popout (NOT a second manifest kind)
├── Model.js           # Tether CLI parsers only
├── LICENSE
├── README.md
└── docs/
    ├── REQUIRED.md    # Tether is not bundled
    ├── MARKETPLACE.md
    └── PUBLISH.md
```

Plugin id and `moduleName` in both QML files: `io.github.charleschao.omamessage`

Do not rename to omaimessage (sounds like Apple iMessage) or omatext (sounds SMS-only).

## Hard invariants

- README, manifest `description`, LICENSE, and panel footer must say Tether is required and credit **Zack Bartel** / https://github.com/zackb/tether
- `kinds` is only `["bar-widget"]`. Panel is loaded from BarWidget. Do not add a `panel` kind.
- Nested Panel: `manageIpc: false`. Only BarWidget registers `IpcHandler`.
- Link tab is **always visible**. When Wi-Fi is off, disable clipboard/files/iOS actions — do not hide the tab.
- Settings tab is **always visible**. Bluetooth toggles, pair/unpair, and iOS accept live there.
- Do not add OTP, Firefox, or Thunderbird add-ons. Those stay in Tether.
- No `omarchy.*` plugin id. No symlinks in the plugin folder (marketplace rejects them).
- `installation.mode` stays `"manual"` until Tether is no longer a required native binary.

## UI / theme

Follow Omarchy light/dark (`omarchy theme set`).

- `fg`: `bar.foreground` fallback `Color.popups.text`
- `muted`: `Color.muted` (never `Qt.darker(foreground)` — that makes light-theme muted darker)
- `accent`: `Color.accent`
- fills: `Style.normalFillFor` / `selectedFillFor` / `hoverFillFor`
- Tabs, Send, Push, Pull: `qs.Ui` `Button` with `bordered: true` — not accent-filled Rectangles
- Chips and file DropArea: `BorderSurface` + `Border.controlSpec`
- Compose: `qs.Ui` `TextField` (placeholderText) + visible Send. A transparent `TextInput` plus sibling placeholder Text paints an empty gap and **steals clicks**.
- Set `PanelKeyCatcher.blocked` while compose fields have focus or keys never reach the input.
- Do not bind `KeyboardPanel` `contentHeight` to a Column `implicitHeight` that contains ListViews — it can bind at 0. Use a concrete size: `panel.fittedContentHeight(Style.space(560))`.

## CLI the widget may call

Parsers live in `Model.js`. BarWidget `Process` objects call:

- `tether --bt-connection` `--bt-devices` `--bt-threads` `--bt-messages` `--bt-send` `--bt-notifications` `--bt-solicit` `--bt-pair` `--bt-unpair` `--bt-enable` `--bt-ancs` `--bt-ancs-content` `--bt-status` `--bt-setup` `--bt-diagnostics`
- `tether --list-devices` `-g` `-s` `-f` `--accept` (Link / Settings; disable Wi-Fi actions when Wi-Fi is off)
- `nmcli -t -f DEVICE,TYPE,STATE device`
- `tether-gtk` via `uwsm-app -- tether-gtk` (middle-click / Open app)

`tetherd` must stay running for MAP. The gtk window is optional.

## Local run / validate

```sh
omarchy plugin validate .
qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml

# After copying into the live plugins dir:
omarchy-shell shell rescanPlugins
# If the click still shows a stale stub card, force:
omarchy restart shell
```

`listPlugins.active: false` is **normal** for `bar-widget`. Enabled means the id is in `shell.json` bar layout.

Live install on this machine (do not commit machine-specific paths into README):

```
~/.config/omarchy/plugins/io.github.charleschao.omamessage/
```

Canonical public source of truth is **this repo**. After edits, copy into the live plugin dir to test, or `omarchy plugin add` from git once published. Do not leave two diverging copies without syncing.

Stale popout: plugin file saves do not always hot-reload. `omarchy restart shell`, then click **Omamessage** on the bar the user is looking at (IPC `toggle` can open the panel on another monitor).

## Publish

See `docs/PUBLISH.md` and `docs/MARKETPLACE.md`.

- Public GitHub repo, `manifest.json` at root
- Submit via https://plugins.omarchy.org/develop.html and the marketplace submit form
- Ask reviewers for the `manual-setup` label
- Listing copy must lead with “Requires Tether by Zack Bartel installed separately.”

## Out of scope

- Harvesting VM/OpenCore serials, OpenBubbles, BlueBubbles, Beeper
- Disabling iMessage on the daily iPhone
- Bundling Tether binaries
- WhatsApp / Signal

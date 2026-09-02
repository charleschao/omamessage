# Contributing

This is an Omarchy bar widget. Tether itself lives at https://github.com/zackb/tether — file daemon/GTK/MAP bugs there, not here.

## Before a PR

1. Read `AGENTS.md`.
2. Keep plugin id `io.github.charleschao.omamessage`.
3. `omarchy plugin validate .`
4. If QML changed: `qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml`
5. Confirm README + manifest still say Tether is required and not bundled.

## Do not

- Copy Tether source
- Add OTP / browser / mail extensions
- Hide the Link or Settings tab when Wi-Fi is off
- Introduce `omarchy.*` ids or symlinks

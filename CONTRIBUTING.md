# Contributing

This is an Omarchy bar widget. Tether itself lives at https://github.com/zackb/tether — file daemon/GTK/MAP bugs there, not here.

## Before a PR

1. Read `README.md`.
2. Keep plugin id `io.github.charleschao.omamessage`.
3. `omarchy plugin validate .`
4. If QML changed: `qmllint -I "$OMARCHY_PATH/shell" BarWidget.qml Panel.qml`
5. `node scripts/test-model.js`
6. Confirm README + manifest still say Tether is required and not bundled.

## Do not

- Copy Tether source
- Add OTP vault / browser / mail extensions
- Add Settings, Link, Notify, Calls, or Contacts tabs
- Scrape `tether --bt-*` stdout for the inbox (use tetherd.sock JSON)
- Introduce `omarchy.*` ids or symlinks

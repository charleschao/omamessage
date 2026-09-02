# Marketplace listing notes

Use this copy when submitting to https://plugins.omarchy.org/publish.html

Public repository: https://github.com/charleschao/omamessage

## Name

Omamessage

## Short description (manifest)

Requires Tether by Zack Bartel installed separately (github.com/zackb/tether). Omarchy bar inbox for iPhone SMS/iMessage via the local tetherd CLI — not a standalone messenger.

## Longer blurb

Omamessage is an Omarchy bar inbox. It is not Apple iMessage and it does not bundle Tether. Install Tether first, pair your iPhone over Bluetooth, then add this plugin. Tether is by Zack Bartel: https://github.com/zackb/tether

## Tags

messaging, sms, iphone, bluetooth, tether, omamessage

## Category

Communication / Productivity

## Availability

Manual setup

This plugin requires additional setup before it can be enabled. Follow the upstream installation instructions.

On submit, ask reviewers to apply the `manual-setup` label. Tether (`tether-bin`) is a required native binary; `omarchy plugin add` alone does not produce a working inbox.

Maintainer notes (paste into the submission):

```
Manual setup: requires Tether by Zack Bartel (github.com/zackb/tether) installed separately. Please apply manual-setup. Note: This plugin requires additional setup before it can be enabled. Follow the upstream installation instructions.
```

## Checklist before submit

- [ ] README states Tether is required and not bundled
- [ ] Availability is Manual setup (request `manual-setup` on the listing)
- [ ] docs/REQUIRED.md is in the public repo
- [ ] manifest description mentions the dependency and credit
- [ ] LICENSE notes this is the widget only
- [ ] Panel footer still credits Zack Bartel
- [ ] `omarchy plugin validate` passes on a clean clone
- [ ] Test machine has `tether` on PATH; a machine without it fails clearly

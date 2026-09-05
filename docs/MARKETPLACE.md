# Marketplace listing notes

Use this copy when submitting to https://plugins.omarchy.org/publish.html

Public repository: https://github.com/charleschao/omamessage

## Name

Omamessage

## Short description (manifest)

Requires Tether by Zack Bartel installed separately (github.com/zackb/tether). Omarchy bar inbox for iPhone SMS/iMessage via the local tetherd socket — not a standalone messenger.

## Longer blurb

Omamessage is an Omarchy bar widget. It is not Apple iMessage and it does not bundle Tether. Tether talks to the iPhone from Linux — no macOS VM (unlike BlueBubbles). Install Tether first, pair your iPhone over Bluetooth, then add this plugin. It follows the Omarchy light/dark theme. Tether is by Zack Bartel: https://github.com/zackb/tether

## Tags

The submit form allows **one to three** tags from a fixed list. More than three are rejected.

Pick: **Bar**, **Quickshell**, **Hyprland**

Optional suggested tag: `messaging`

## Category

**Widgets** (the form has no Communication option)

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
- [ ] README, LICENSE, and manifest credit Zack Bartel (not the popout chrome)
- [ ] `preview.png` is at the repo root
- [ ] Submit form: category Widgets; tags Bar, Quickshell, Hyprland (max three)
- [ ] `omarchy plugin validate` passes on a clean clone
- [ ] Test machine has `tetherd` on PATH; a machine without it fails clearly

# Publish to the Omarchy plugin marketplace

Official guides:

- Develop: https://plugins.omarchy.org/develop.html
- Publish: https://plugins.omarchy.org/publish.html

This plugin is **manual setup**. `omarchy plugin add` alone does not produce a working inbox. Tether (`tether-bin` on Arch) must already work.

## 1. Public GitHub repository

Marketplace listings must be a **public** GitHub repo with `manifest.json` at the root. Private dotfiles do not qualify.

```sh
cd ~/Projects/omamessage
omarchy plugin validate .
git status
# first time:
gh repo create omamessage --public --source=. --remote=origin --push \
  --description "Omarchy bar widget for Tether (Zack Bartel). Requires Tether installed separately."
```

Confirm: https://github.com/charleschao/omamessage is public and the current commit has `manifest.json` at `/`.

## 2. Listing copy

Use [MARKETPLACE.md](MARKETPLACE.md). Lead with:

> Requires Tether by Zack Bartel installed separately.

Availability: **Manual setup**. Ask reviewers to apply the `manual-setup` label. Paste:

```
Manual setup: requires Tether by Zack Bartel (github.com/zackb/tether) installed separately. Please apply manual-setup. Note: This plugin requires additional setup before it can be enabled. Follow the upstream installation instructions.
```

Optional: add `preview.png` at the repo root (marketplace optimizes it).

## 3. Submit

Open the marketplace submit form from https://plugins.omarchy.org/publish.html with:

- Repository: `https://github.com/charleschao/omamessage`
- Name: Omamessage
- Category: Communication
- Tags: messaging, sms, iphone, bluetooth, tether, omamessage

Automated validation checks the current commit before a maintainer approves.

## 4. After it is listed

Users install with:

```sh
omarchy plugin add https://github.com/charleschao/omamessage.git --enable
```

Bump `manifest.json` `version` for each release users should pull via `omarchy plugin update`.

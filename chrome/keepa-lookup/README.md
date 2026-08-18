# keepa-lookup

A tiny Chrome extension: click the toolbar icon on an Amazon product page and it opens that same listing on keepa.com, in a new tab.

## How it works

- Reads the ASIN from the current tab's URL (`/dp/ASIN` or `/gp/product/ASIN`), falling back to the `data-asin` attribute (or canonical link) on the page if the URL doesn't carry it.
- Maps the Amazon store (`amazon.de`, `amazon.co.uk`, etc.) to Keepa's numeric domainId — Keepa tracks price history per marketplace, and its product URL is `https://keepa.com/#!product/<domainId>-<ASIN>`.
- Opens that URL in a new tab.

Supported stores: `.com`, `.co.uk`, `.de`, `.fr`, `.co.jp`, `.ca`, `.it`, `.es`, `.in`, `.com.mx`, `.com.br` — every store Keepa's own client maps to a domainId. On any other Amazon marketplace the toolbar badge flashes `?`. If the ASIN can't be found (badge flashes `!`), the page likely isn't a standard product listing (search results, cart, etc).

The toolbar icon is greyed out (disabled) except on those stores, via `declarativeContent` — Chrome has no way for a pinned icon to fully disappear off-page, but a disabled one won't trigger anything if clicked, so it's a reliable "is this relevant here" signal. It lights up automatically once you're on a supported Amazon page; no need to click first to find out.

No build step — it's plain JS (Manifest V3), loaded directly.

## Install (unpacked)

`setup.sh` checks whether this extension's path is already in Chrome's profile — if not, it opens `chrome://extensions` and copies this directory's path to your clipboard. From there:

1. Enable "Developer mode" (top right)
2. "Load unpacked" → paste the path (or select this directory, `chrome/keepa-lookup/`, manually)

Chrome doesn't offer a way to install an unpacked extension non-interactively (unlike VS Code's `--install-extension`), so this one click is unavoidable — `setup.sh` just gets you to it.

## Bump `version` on changes

`setup.sh` also flags when the extension's source has changed since it was last loaded, by comparing `manifest.json`'s `version` against the version Chrome has cached for the currently-loaded service worker. When it finds a mismatch it opens `chrome://extensions` for you, same as the not-loaded-yet case, and tells you to click the reload icon. That comparison is only meaningful if `version` gets bumped alongside real changes to `manifest.json` or `background.js` — do that as part of any change here.

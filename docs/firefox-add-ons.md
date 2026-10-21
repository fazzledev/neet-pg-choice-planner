# Firefox Add-ons listing

What to enter on addons.mozilla.org (AMO) for the MCC Filler extension. The Chrome listing is in `chrome-web-store.md`; most of its text carries over.

## How it works in Firefox

- The Chrome and Firefox stores get the same zip. `browser_specific_settings` in `extension/manifest.json` holds the Firefox-only settings, which Chrome ignores: the add-on ID `mcc-filler@neet-pg-choice-planner.fazzle.dev`, Firefox 140+ on desktop (142+ on Android, which web-ext lint requires even though the Android listing stays off), and the data collection declaration.
- In Firefox the extension keeps no usage counts. Firefox only allows the usage category ("technical and interaction data") as an optional permission the user can refuse, and a content script cannot check that choice, so `portal.js` skips counting when it runs in Firefox.
- Data collection declared as required: `websiteContent`, because it reads the choice list on the MCC page and hands it to the planner tab.

## Release a version

The `extension-v<version>` tag builds `choice-planner-filler-<version>.zip` on the GitHub release, the same file the Chrome Web Store gets. Upload it at https://addons.mozilla.org/developers/addon/submit/ and choose "On this site" for distribution. Lint it first with `npx web-ext lint --source-dir <unzipped folder>`.

The code is not minified or bundled, so AMO does not need a separate source upload.

## Listing

**Name and summary:** come from the manifest, as on Chrome.

**Categories:** Other. Leave Firefox for Android unticked: the planner sends phone visitors to a computer, and the Android build is untested.

**Description:** use the Chrome description from `chrome-web-store.md`, but drop the line about anonymous usage counts, which the Firefox version does not keep.

**Homepage:** https://neet-pg-choice-planner.fazzle.dev/extension

**Support site:** https://github.com/fazzledev/neet-pg-choice-planner/issues

**Support email:** hey@fazzle.dev

**Licence:** MIT

**Privacy policy:** https://neet-pg-choice-planner.fazzle.dev/privacy

**Images:** the two screenshots in `docs/store-assets/` work as they are. AMO does not use the promo tile; the icon comes from the package.

**Notes to reviewer:** The extension runs only on the NEET PG Choice Planner site and on MCC's choice-filling page (mcc.admissions.nic.in), which needs a candidate login, so testing on MCC needs a registered NEET PG candidate. To try it without an MCC login, open https://neet-pg-choice-planner.fazzle.dev/plan, add a few choices, then open https://neet-pg-choice-planner.fazzle.dev/practice: a practice copy of the choice-filling page with the same table structure and this year's real choices, where the extension runs as it does on MCC. The extension never presses MCC's lock or final-submit controls (see `FORBIDDEN_CONTROL` in `portal-adapter.js`) and makes no network requests.

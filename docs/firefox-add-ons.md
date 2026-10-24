# Firefox Add-ons listing

What to enter on addons.mozilla.org (AMO) for the MCC Filler extension. The Chrome listing is in `chrome-web-store.md`; most of its text carries over.

## Status

Submitted on 2026-10-22 as version 1.3.1 and awaiting Mozilla's review. Developer profile "Fazzle Dev" (homepage fazzle.dev, sign-in with two-step authentication). Once Mozilla approves it, set `cattr_accessor :firefox_listed, default: true` in `app/models/extension_package.rb`: `/extension` and the landing page then show the Firefox Add-ons badge and list Firefox as available.

## How it works in Firefox

- The Chrome and Firefox stores get the same zip. `browser_specific_settings` in `extension/manifest.json` holds the Firefox-only settings, which Chrome ignores: the add-on ID `mcc-filler@neet-pg-choice-planner.fazzle.dev`, Firefox 140+ on desktop and 142+ on Android, and the data collection declaration. Because the manifest names Android, AMO lists it for Firefox for Android too and won't let that be unticked. It should work there, but it hasn't been tested on a phone.
- In Firefox the extension keeps no usage counts. Firefox only allows the usage category ("technical and interaction data") as an optional permission the user can refuse, and a content script cannot check that choice, so `portal.js` skips counting when it runs in Firefox.
- Data collection declared as required: `websiteContent`, because it reads the choice list on the MCC page and hands it to the planner tab.

## Release a version

The `extension-v<version>` tag builds `choice-planner-filler-<version>.zip` on the GitHub release, the same file the Chrome Web Store gets. For a new version, open the add-on in the Developer Hub and use **Upload New Version**; the first submission used https://addons.mozilla.org/developers/addon/submit/ with "On this site" for distribution. Lint it first with `npx web-ext lint --source-dir <unzipped folder>`.

The code is not minified or bundled, so AMO does not need a separate source upload.

## Listing

Each text box's content is in a code block below, exactly as it should be pasted. AMO supports some Markdown in the description.

**Name and summary:** come from the manifest, as on Chrome.

**Add-on URL:** https://addons.mozilla.org/firefox/addon/neet-pg-choice-plan-mcc-filler/ (AMO allows at most 30 characters, so "planner" became "plan").

**Source code question:** No. The extension is plain JavaScript with no build step.

**Experimental / requires payment:** both unticked.

**Categories:** "My add-on doesn't fit into any of the categories".

### Description

```markdown
Copy your ranked NEET PG choice list to the choice-filling page of the Medical Counselling Committee (MCC), mcc.admissions.nic.in, in one click, or bring MCC's list back into the planner.

**How it works**

1. Make your ranked list at neet-pg-choice-planner.fazzle.dev, in the same browser.
2. Sign in to MCC and open Choice Filling. A small panel shows "In sync" or how many choices differ.
3. Plan → MCC makes MCC's list an exact copy of your plan: it adds missing choices, removes extra ones and puts them in order.
4. Check the list, press Save and Continue, and enter the OTP yourself.
5. MCC → Plan reads your saved MCC list into the planner. Nothing changes until you confirm, and it can be undone.

**Try it first**

Practise on neet-pg-choice-planner.fazzle.dev/practice, a copy of the choice-filling page with this year's choices. Nothing there reaches MCC.

**What it never does**

- Never sees your MCC password, security pin or OTP.
- Never presses Lock or final submit.
- Makes no network requests of its own. Your plan stays in your browser. A list imported from MCC goes only to the planner tab, and is saved to your account only if you're signed in and press Replace.
- In Firefox it keeps no usage counts.

**Open source**

MIT licence: github.com/fazzledev/neet-pg-choice-planner

Independent tool, not affiliated with the Medical Counselling Committee, NBEMS or the Government of India. Always check your list on the official portal before locking.
```

**Support email:** hey@fazzle.dev (shown publicly)

**Support website:** https://github.com/fazzledev/neet-pg-choice-planner/issues

**Licence:** MIT License

### Privacy policy

Tick "This add-on has a Privacy Policy" and paste:

```text
MCC Filler makes no network requests of its own and keeps no usage counts in Firefox.

It stores two things in the extension's own local storage, on your device:
- your ranked plan, copied from the NEET PG Choice Planner tab
- a choice list read from the MCC choice-filling page, waiting to be imported into the planner

It reads the choice list on mcc.admissions.nic.in only when that page is open, and never sees your MCC password, security pin or OTP. A list you import goes only to the planner tab, and is saved to your planner account only if you are signed in and press Replace.

The planner website's own privacy policy: https://neet-pg-choice-planner.fazzle.dev/privacy
```

### Notes to reviewer

```text
No login needed to test. The real MCC page (mcc.admissions.nic.in) requires a NEET PG candidate login, so we run a practice copy of it:
1. Open https://neet-pg-choice-planner.fazzle.dev/plan and press + on 3-4 choices. No account needed.
2. Open https://neet-pg-choice-planner.fazzle.dev/practice. A panel bottom-right shows the differences.
3. Click Plan → MCC, then Yes. Filled choices now match the plan, and the panel says In sync.
4. Remove one filled row, then click MCC → Plan to import it back.

The extension never presses lock or final-submit controls (see FORBIDDEN_CONTROL in portal-adapter.js) and makes no network requests. The code is plain JavaScript, not minified or bundled; the package is a zip of the extension/ folder of https://github.com/fazzledev/neet-pg-choice-planner (built by bin/build-extension, tag extension-v1.3.1).
```

**Images** (the listing's Edit Product Page → Images, after submission; AMO doesn't take the listing icon from the package):
- Add-on icon: `extension/icons/icon-128.png`.
- Screenshots, with captions:
  - `docs/store-assets/screenshot-differences.png`: "The panel compares MCC's choice list with your plan and lists every difference. Shown on the practice page with sample choices."
  - `docs/store-assets/screenshot-synced.png`: "After Plan → MCC, the filled list matches your plan in the same order and the panel says In sync. You then save with the OTP yourself."
- AMO doesn't use the promo tile.

**Homepage:** https://neet-pg-choice-planner.fazzle.dev/extension (Additional Details on the Edit Product Page; AMO first fills it from the manifest's `homepage_url`, the GitHub folder).

# Chrome Web Store listing

What to paste into the Chrome Web Store developer dashboard for the MCC Filler extension, and how a version gets there. Each text box's content is in a code block below, exactly as it should be pasted.

## Status

Live since 2026-10-24 as version 1.3.1: https://chromewebstore.google.com/detail/dknkamnnjakgmgggbeomoakajbkdennd (item ID `dknkamnnjakgmgggbeomoakajbkdennd`, publisher hey@fazzle.dev, non-trader). The developer account needs 2-Step Verification on the Google account and a verified contact email before anything can be uploaded or published. `/extension` links to the listing through `ExtensionPackage::CHROME_WEB_STORE_URL`.

## Release a version

1. Bump `version` in `extension/manifest.json` and merge it.
2. Tag the merge commit `extension-v<version>` and push the tag: `git tag extension-v<version> && git push origin extension-v<version>`.
3. The `Extension release` workflow checks that the tag matches the manifest, builds the package with `bin/build-extension` and publishes a GitHub release with the zip and its SHA-256. The same zip goes to Firefox Add-ons (see `firefox-add-ons.md`).
4. Download `choice-planner-filler-<version>.zip` from the release and upload exactly that file on the existing item's **Package** tab (Upload new package), then submit it for review. Don't rebuild it locally, so anyone can compare the store version with the tagged source.

## Store listing tab

**Title and summary** come from the manifest's `name` and `description`; the dashboard doesn't let you edit them.

**Category:** Workflow & Planning

**Language:** English

### Description

```text
Copy your ranked NEET PG choice list to the choice-filling page of the Medical Counselling Committee (MCC), mcc.admissions.nic.in, in one click, or bring MCC's list back into the planner.

HOW IT WORKS
1. Make your ranked list at neet-pg-choice-planner.fazzle.dev, in the same browser.
2. Sign in to MCC and open Choice Filling. A small panel shows "In sync" or how many choices differ.
3. Plan → MCC makes MCC's list an exact copy of your plan: it adds missing choices, removes extra ones and puts them in order.
4. Check the list, press Save and Continue, and enter the OTP yourself.
5. MCC → Plan reads your saved MCC list into the planner. Nothing changes until you confirm, and it can be undone.

TRY IT FIRST
Practise on neet-pg-choice-planner.fazzle.dev/practice, a copy of the choice-filling page with this year's choices. Nothing there reaches MCC.

WHAT IT NEVER DOES
• Never sees your MCC password, security pin or OTP.
• Never presses Lock or final submit.
• Makes no network requests of its own. Your plan stays in your browser. A list imported from MCC goes only to the planner tab, and is saved to your account only if you're signed in and press Replace.

PRIVACY
In Chrome it counts how often Plan → MCC and MCC → Plan are used on MCC, with the list size in rough bands, and hands those counts to the planner's own visit counter. It never records which choices. Details: neet-pg-choice-planner.fazzle.dev/privacy

OPEN SOURCE
MIT licence: github.com/fazzledev/neet-pg-choice-planner

Independent tool, not affiliated with the Medical Counselling Committee, NBEMS or the Government of India. Always check your list on the official portal before locking.
```

**Images:** store icon `extension/icons/icon-128.png`; screenshots `docs/store-assets/screenshot-differences.png` and `screenshot-synced.png` (1280×800); small promo tile `docs/store-assets/promo-tile.png` (440×280). No marquee tile or video. `docs/store-assets/render.sh` rebuilds the images; the screenshots run the real extension scripts on a sample choice-filling page with made-up choices, so they show no one's MCC details. The icons in `extension/icons/` are rendered from `public/icon.svg` by `bin/render-icons`; rerun it after changing the SVG.

**Homepage URL:** https://neet-pg-choice-planner.fazzle.dev/extension

**Support URL:** https://github.com/fazzledev/neet-pg-choice-planner/issues

**Mature content:** off.

## Privacy tab

### Single purpose description

```text
Keeps a medical student's choice list on the Medical Counselling Committee (MCC) counselling site, mcc.admissions.nic.in, identical to their ranked plan in NEET PG Choice Planner, in either direction: plan to MCC, or MCC to plan.
```

### storage justification

```text
Keeps two things in the extension's own storage so the planner tab and the MCC tab can pass them to each other:
• the student's plan, copied from the planner tab
• a list read from the MCC counselling site, waiting to be imported into the planner
In Chrome it also keeps anonymous usage counts until the planner tab collects them.
The extension makes no network requests.
```

### Host permission justification

```text
• neet-pg-choice-planner.fazzle.dev: the planner sends the student's plan to the extension and receives lists imported from MCC. On /practice, a practice copy of the choice-filling page, the panel runs so students and reviewers can try it without an MCC login.
• mcc.admissions.nic.in, the Medical Counselling Committee (MCC) counselling site: reads and rearranges the choice list on its choice-filling page and shows the sync panel. It never touches sign-in, OTP or lock.
```

**Remote code:** No, I am not using remote code. Every script is bundled in the package.

**Data usage:** tick only "Website content" (it reads the choice list on the MCC page) and "User activity" (in Chrome it counts uses of Plan → MCC and MCC → Plan, with the list size in bands, and the planner sends those counts to its GoatCounter). Then tick all three statements: the data is not sold, not used for anything unrelated to the single purpose, and not used for creditworthiness or lending.

**Privacy policy URL:** https://neet-pg-choice-planner.fazzle.dev/privacy

## Test instructions tab

No username or password. The instructions box allows 500 characters.

```text
No login needed; MCC itself requires a candidate login.
1. Open neet-pg-choice-planner.fazzle.dev/plan and press + on 3-4 choices.
2. Open neet-pg-choice-planner.fazzle.dev/practice, a practice copy of MCC's choice-filling page. A panel shows the differences.
3. Click Plan → MCC, then Yes. Filled choices now match the plan; the panel says In sync.
4. Remove one filled row, then click MCC → Plan to import it back.
It never presses Lock and makes no network requests.
```

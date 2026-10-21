# Chrome Web Store listing

What to paste into the Chrome Web Store developer dashboard for the MCC filler extension, and how a version gets there.

## Release a version

1. Bump `version` in `extension/manifest.json` and merge it.
2. Tag the merge commit `extension-v<version>` and push the tag: `git tag extension-v1.0.0 && git push origin extension-v1.0.0`.
3. The `Extension release` workflow checks that the tag matches the manifest, zips `extension/` (without its README) and publishes a GitHub release with the zip and its SHA-256.
4. Download that zip from the release and upload exactly that file in the developer dashboard. Don't rebuild it locally, so anyone can compare the store version with the tagged source.

## Store listing

**Name:** NEET PG Choice Planner filler

**Summary (132 characters max):** Makes the MCC choice-filling list match your NEET PG Choice Planner plan, or imports it back. Never locks. Not affiliated with MCC.

**Category:** Productivity

**Language:** English

**Description:**

> Copies your ranked choice list from NEET PG Choice Planner to the MCC choice-filling page, or brings the list on MCC back into the planner.
>
> How it works
> • Open NEET PG Choice Planner in the same browser. Your plan syncs to the extension by itself.
> • Sign in to MCC and open Choice Filling. A small panel shows "In sync" or how many choices differ.
> • Plan → MCC makes the MCC list an exact copy of your plan: it removes choices not in the plan, adds the missing ones and puts them in order. You check it, press Save and Continue, and enter the OTP yourself.
> • MCC → Plan reads your saved MCC list and offers to replace your plan with it, which you can undo.
>
> What it never does
> • It never sees your MCC password, security pin or OTP.
> • It never presses anything that locks your choices.
> • It makes no network requests. Your plan is kept in your own browser, and a list you import from MCC goes only to the planner tab. It is saved to your account only if you are signed in and press Replace.
>
> Open source under the MIT licence: https://github.com/fazzledev/neet-pg-choice-planner/tree/main/extension
>
> NEET PG Choice Planner is an independent tool and is not affiliated with the Medical Counselling Committee, NBEMS or the Government of India. Always check your list on the official portal before locking.

**Homepage:** https://neet-pg-choice-planner.fazzle.dev/extension

**Support:** https://github.com/fazzledev/neet-pg-choice-planner/issues

**Privacy policy:** https://neet-pg-choice-planner.fazzle.dev/privacy

**Assets still to make:** at least one 1280×800 screenshot of the MCC panel showing the differences and the Plan → MCC button (blur the candidate's name and roll number), and a 440×280 small promo tile. The 128px icon comes from `extension/icons/icon-128.png`.

## Privacy practices tab

**Single purpose:** Keeps the student's MCC choice-filling list the same as their ranked plan in NEET PG Choice Planner, in either direction.

**Permission justifications:**

- `storage`: Holds the student's plan, copied from the planner tab, and a list read from MCC that is waiting to be imported, so the planner tab and the MCC tab can hand them to each other. The extension makes no network requests. An imported MCC list reaches our server only when the signed-in student presses Replace in the planner.
- Host access to `neet-pg-choice-planner.fazzle.dev`, `neet-pg-choices.fazzle.dev` and `mcc.fazzle.dev`: The planner page sends the student's plan to the extension and receives lists imported from MCC.
- Host access to `mcc.admissions.nic.in`: Reads and rearranges the choice list on MCC's choice-filling page, and shows the sync panel there. It does not touch the sign-in, OTP or lock steps.

**Remote code:** No. Every script is bundled in the package.

**Data usage:** Tick "Website content" only, because it reads the choice list on the MCC page. Then confirm all three statements: the data is not sold, not used for anything unrelated to the single purpose, and not used for creditworthiness or lending.

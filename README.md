# Choice Planner

Plan and rank NEET PG counselling choices. Works without an account (saved in the browser, usable offline); signing in with an emailed link syncs the order across devices with history.

## Setup

    bin/setup
    bin/rails "planner:import_catalog[data/available_choices.json,NEET PG Medical Counselling 2026,neet-pg-2026]"
    bin/rails "planner:admin[you@example.com]"
    bin/rails server

## Deploy

    kamal deploy
    kamal app exec 'bin/rails "planner:import_catalog[data/available_choices.json,NEET PG Medical Counselling 2026,neet-pg-2026]"'

Mail goes through Brevo SMTP; the key lives in Rails credentials under `smtp.password`.

## Data

`data/available_choices.json` is the NEET PG 2026 choice list published by the Medical Counselling Committee (mcc.nic.in). `data/dnb_contacts.json` lists DNB coordinator contacts taken from official hospital and NBEMS pages.

## MCC filler extension

`extension/` is a Chrome extension that copies a planned order into the MCC choice-filling page, one choice per click. Students sign in to MCC themselves and lock their choices themselves. The app serves it at `/extension`.

## License

MIT

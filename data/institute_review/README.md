# Institute city review

Every institute's location, checked by hand (an AI reviewer per batch, reading the official name, address and pincode, with web lookups where those don't settle it).

- `ledger.jsonl`: one row per institute: official name, address, state, current card title, current map city, and the districts GeoNames gives for any pincode in the record. Built by `script/institute_review_ledger`.
- `batches/batch-NN.jsonl`: the ledger split into ten review batches.
- `results/batch-NN.jsonl`: one verdict per institute: actual town, district, state, whether the map city and card title are right (and what they should be), confidence, and the evidence used.

- `second_pass/`: a second independent review of every institute; its verdicts are the ones used.

## From review to the app

- `script/institute_review_merge` writes `final.jsonl`, one pin town per institute. The current map city stays whenever MCC's own name or address for the institute names it, or it is a spelling of the reviewed town (Bengaluru/Bangalore, Rajauri/Rajouri). Only the remaining pins move, to the reviewed town; `decisions.json` settles the spelling for two of those. All of Delhi is one pin. Card titles are not changed.
- `bin/rails planner:place_institutes` writes `data/institute_locations.json` (map pin per institute: lat, lng, town). Each town is looked up once on OpenStreetMap (cached in `data/town_locations.json`); `data/town_overrides.json` holds hand-checked coordinates, with sources, for the towns the lookup got wrong.
- `script/check_town_pins` reverse-looks-up every pin on OpenStreetMap and lists, in `pin_check.json`, any pin whose address there names neither its town nor its district. The 10 left are checked and correct: Tiruvarur, Dholpur and Dimapur (OSM spells them differently; the Dimapur pin is at Chumukedima, where the hospital is), Nagercoil (Wikipedia coordinates; OSM names the taluk), Kanyakumari and Kodagu (pins named after the district, inside it), Gachibowli (OSM names Hyderabad's zone), Hooghly and Kalyani (on the border with the neighbouring area OSM names), Chandigarh in Punjab (the cancer hospital at New Chandigarh, named by its tahsil).
- `script/institute_review_page` builds `review.html`, every institute with its old and new pin.

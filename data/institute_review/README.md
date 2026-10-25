# Institute city review

Every institute's location, checked by hand (an AI reviewer per batch, reading the official name, address and pincode, with web lookups where those don't settle it).

- `ledger.jsonl`: one row per institute: official name, address, state, current card title, current map city, and the districts GeoNames gives for any pincode in the record. Built by `script/institute_review_ledger`.
- `batches/batch-NN.jsonl`: the ledger split into ten review batches.
- `results/batch-NN.jsonl`: one verdict per institute: actual town, district, state, whether the map city and card title are right (and what they should be), confidence, and the evidence used.

## From review to the app

- `final.jsonl` → `bin/rails planner:place_institutes` writes `data/institute_locations.json` (map pin per institute: lat, lng, town) and `data/institute_titles.json` (card titles). Each town is looked up once on OpenStreetMap (cached in `data/town_locations.json`); `data/town_overrides.json` holds hand-checked coordinates, with sources, for the towns the lookup got wrong or couldn't find.
- `script/check_town_pins` reverse-looks-up every pin on OpenStreetMap and lists, in `pin_check.json`, any pin whose address there names neither its town nor its district. The 7 left are all checked and correct: Nagercoil (Wikipedia coordinates; OSM names the taluk), Chumoukedima and Dholpur (spelling), Hooghly, Kalyani and Neyyoor (on the border with the neighbouring area OSM names), New Chandigarh (Mullanpur, named by its tahsil).

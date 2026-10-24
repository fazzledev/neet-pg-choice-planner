# Institute city review

Every institute's location, checked by hand (an AI reviewer per batch, reading the official name, address and pincode, with web lookups where those don't settle it).

- `ledger.jsonl`: one row per institute: official name, address, state, current card title, current map city, and the districts GeoNames gives for any pincode in the record. Built by `script/institute_review_ledger`.
- `batches/batch-NN.jsonl`: the ledger split into ten review batches.
- `results/batch-NN.jsonl`: one verdict per institute: actual town, district, state, whether the map city and card title are right (and what they should be), confidence, and the evidence used.

#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
python3 build_sample_portal.py

shoot() {
  TZ=Asia/Kolkata LANG=en_US.UTF-8 chromium --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
    --window-size=1280,800 --virtual-time-budget=8000 --screenshot="$1" "file://$PWD/sample-portal.html#$2" 2>/dev/null
}

shoot screenshot-differences.png differences
shoot screenshot-synced.png synced

chromium --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files \
  --window-size=440,280 --screenshot=promo-tile.png "file://$PWD/promo-tile.html" 2>/dev/null

# Choice Planner filler

A Chrome extension that copies a Choice Planner order into the MCC choice-filling page, one choice per click. The student signs in to MCC themselves; the extension never solves the security pin, never handles the password or OTP, and refuses to press anything that locks choices.

## Install

1. Open `chrome://extensions` and turn on Developer mode.
2. Load unpacked, and pick this `extension/` folder.

## Use

1. Open Choice Planner in the same browser. The order syncs to the extension on load and after every change.
2. Sign in to MCC and open choice filling. A panel in the corner shows the order.
3. On Choice Filling the panel lists what differs from your order: missing, extra, or in a different position. Add next missing adds one choice per click.

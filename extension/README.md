# Choice Planner filler

A Chrome extension that copies a Choice Planner order into the MCC choice-filling page, one choice per click. The student signs in to MCC themselves; the extension never solves the security pin, never handles the password or OTP, and refuses to press anything that locks choices.

## Install

1. Open `chrome://extensions` and turn on Developer mode.
2. Load unpacked, and pick this `extension/` folder.

## Use

1. In Choice Planner, open My order and press the send button. It appears only while the extension is installed.
2. Sign in to MCC and open choice filling. A panel in the corner shows the order.
3. Compare shows what the portal is missing; Add next adds the next missing choice.
4. Inspect page copies the page's controls and tables (no typed values) so the filler can be mapped to the portal's layout.

# NEET PG Choice Planner filler

A Chrome extension that makes the MCC choice-filling list match a plan from NEET PG Choice Planner, or brings the MCC list into the planner. The student signs in to MCC, saves with the OTP and locks by themselves; the extension never handles the password or OTP and refuses to press anything that locks.

## Install

1. Open `chrome://extensions` and turn on Developer mode.
2. Load unpacked, and pick this `extension/` folder.

## Use

1. Open Choice Planner in the same browser. Your plan syncs to the extension on load and after every change.
2. Sign in to MCC and open Choice Filling. The panel shows In sync, or how many choices differ.
3. Plan → MCC makes the MCC list an exact copy of the plan: it removes choices not in the plan, adds missing ones and arranges them. Check it, then press Save and Continue and enter the OTP.
4. MCC → Plan reads the saved MCC list and offers to replace the plan with it, which can be undone.

---
name: spec-align
description: Check that the owner's Specs describe the current code. Reports the differences in chat; updates the Specs-vbc notes only when Specs and code agree. Changes no code. Use when the user types /spec-align.
---

# /spec-align

Read `WORKFLOW.md` in the folder of this skill first.

Goal: tell the owner whether `Specs/` describes the code that exists. Change no code. Write only in `Specs-vbc/`.

1. Do Step 0. On a failure, stop.
2. Find the code of each construct of the delta: search for the spec name; the `Mapping` entries of the notes give the other names. Compare at the granularity of the spec.
3. If every construct agrees with the code, or differs only as an `Open` entry says: update the `Mapping` entries, set `synced_to` to Specs HEAD, commit the notes.
4. If not: change no notes. Report each difference: the construct, what the spec says, what the code does, the code symbol.
5. Report: aligned or not aligned, the differences, the problems of Step 0 outside the delta.

Argument: the owner's focus. It narrows the run. If the run covers only a part of the delta, do not move `synced_to`. With an empty delta, check the part that the argument names; without an argument, report that Specs and code are in sync.

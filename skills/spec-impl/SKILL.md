---
name: spec-impl
description: Change the code so it satisfies the owner's Specs. Works on the Specs delta since the synced commit, validates one time, updates the Specs-vbc notes in the same commit. Stops without partial work when the spec has a problem. Use when the user types /spec-impl.
---

# /spec-impl

Read `WORKFLOW.md` of the `spec-align` skill first (`../spec-align/WORKFLOW.md` from the folder of this skill).

Goal: change the code so it satisfies `Specs/`. The run does not need `/spec-align` before it.

1. Do Step 0. On a failure, stop.
2. Read the notes of the spec files of the delta, then the code that the delta touches. The work list is: each difference between the delta and the code, and each `Open` entry that the delta or the argument covers. Do not widen the work to related code. Write no notes yet. If stop point 2 applies, stop.
3. Implement with the rule "Optimize", and review the diff. If a subagent writes the code, its brief names the `strict` constructs, the bounds and the optimized forms to write. A construct with exact content (a formula, an order) gets a test with the construct name when no test covers it.
4. Remove the code that this run made dead: no reference is left except its own tests. Remove those tests with it. Prove it first: search the code, the tests, the assets, the build files and access by name. If you cannot prove it, keep the code for step 7. Leave older dead code and name it in the report.
5. Validate one time, on the final state.
6. Update the notes: the `Mapping` entries, an `Open` entry with its reason for each difference that the run could not close, and `synced_to` = Specs HEAD when each difference of the delta is closed or `Open`. Commit code and notes together.
7. If this run made code obsolete that is still referenced, ask the owner. Use one AskUserQuestion call with the list inside the question: the code, what refers to it, what its removal changes. Remove only what the owner approves, in a separate commit, and validate again only what the removal can affect.
8. Report: the commits, the differences closed, the `Open` entries with their reasons, the dead code removed, the optimizations seen outside the scope, the answers of step 7, the validation result, the problems of Step 0 outside the delta, the manual checks that stay with the owner.

Argument: what the owner wants in this run. It directs the run and does not override `Specs/`: a conflict is a stop. With an empty delta, do the part that the argument names; without an argument, report that the code is in sync and list the `Open` entries.

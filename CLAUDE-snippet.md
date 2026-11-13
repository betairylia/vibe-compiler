# Spec-driven projects (`Specs/` and `Specs-vbc/`)

Some projects have this layout at the root:

```
root
 - Specs/        owner-owned intent (the owner's git repo, gitignored in the code repository). READ-ONLY to Claude.
 - Specs-vbc/    Claude's mapping notes: a TRACKED folder of the code repository.
 - the code
```

Rules when a project has this layout:

- Never write, stage or commit inside `Specs/`. When something needs the owner's intent or choice, ask the owner in chat to change `Specs/`. Proposed wording goes in chat only.
- `Specs/` is self-contained and describes a real, working system. The owner chooses the granularity per part. Below that granularity the codebase is the source of truth: no gap, no invented spec. Specs may point outside itself when the pointer is bounded.
- `Specs/` is INTENT, not a letter-by-letter contract. The code satisfies the spec when it has the behaviour, the order and the boundaries that the spec gives, and the time/space complexity stays within the spec where the spec gives one. Favor clean and performant code over a literal transcription: structure, split and names may differ when that makes sense (use the spec's name when it is acceptable, for easy reading). Every spec construct is fuzzy unless it has the keyword `strict`: the code can add fields, steps and helper constructs inside the complexity of the spec form. A `strict` construct has exactly the written fields. The full rule is in the workflow file, section "Fuzzy and strict". It applies while Claude implements; it adds no test and no check step.
- `Specs-vbc/` holds exceptions only, for the current state of the branch: the spec constructs that a search for the spec name does not find in the code, the constructs that the code does not satisfy yet, the open questions for the owner, and the Specs commit that the code satisfies. No history, no line numbers, no owner intent, no owner choices, no design proposals.
- The workflow runs only through the user skills `/spec-align` (check that `Specs/` describes the code; update the notes when they agree; no code change) and `/spec-impl` (change the code to match `Specs/`). Both read `Specs/` ALONE first (committed content only) and stop, without partial work, when the changed part is unclear, not self-contained, contradictory or unsound. Shared rules and the note format: `~/.claude/skills/spec-align/WORKFLOW.md`. Without these commands, ignore the workflow and work as usual.
- The other rules of this file keep applying inside both commands. Checkpoint inside a command: HEAD is the checkpoint. The run commits only the files that it changed, and the owner's uncommitted work stays uncommitted.
- The skill files (`WORKFLOW.md` and the two `SKILL.md`) are project agnostic and user agnostic: no names, no machine paths, no rule of one engine or one project. A project fact goes to the project `CLAUDE.md`.

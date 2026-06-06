# Workflow: validate · compile · ingest

The target project is under git; `vbc/` lives inside it. Every command accepts a single
`.vibe` file **or** a directory (e.g. `vbc/`).

## validate (read-only — never writes code)

1. Determine the target language from `.vbc/project.md`. If it is absent **and** no existing
   code determines it (pure greenfield) → **BLOCK** (axis 2): "target language undetermined".
   This is the one thing the compiler refuses to guess.
2. For each pseudo element, derive its symbol-path(s) (`references/ir-format.md`) and locate it:
   - exists & matches pseudo intent → `LINKED`
   - absent from the entire codebase → `NEW` (this is **not** a BLOCK)
   - exists but the pseudo contradicts it → `DIVERGED` (a BLOCK)
3. Classify every construct with the border (`references/border.md`); record labels and any
   premise/policy promotions (with their surfaced notes).
4. Write the **complete** IR in one shot — including the `DIVERGED` entries — plus each file's
   `source-hash` and `validated-at`. Write the report (`references/report-format.md`).
5. If any BLOCK exists, hard-halt: surface it; produce no green light for compile. (The IR is
   still written — "hard-halt" means *no green light*, not *discard the IR*.)

## compile (transactional)

1. **Precondition (checkable).** For every element to touch, require an IR entry whose status
   is `NEW`, `LINKED`, or `CHANGE_ACK`; for `LINKED`, `validated-at` must be an ancestor of
   HEAD, the `.vibe` `source-hash` unchanged, and no unresolved drift. If an element has **no
   IR entry**, or its entry is `DIVERGED` / `RELINK_PENDING`, or its `.vibe` changed since
   validation → **STOP**: "validate first". (Deterministic refusal, not a silent mis-patch.)
2. Check the **git preconditions** (below).
3. **Stage** all output in memory — write nothing yet:
   - `NEW` → generate net-new code at a path derived from the `project.md` layout; record the
     invented path/namespace as an ASSUME.
   - `LINKED` / `CHANGE_ACK` → apply a **surgical, symbol-level patch** to the linked symbol(s),
     leaving code not covered by pseudo untouched.
4. **Atomic application.** If ANY BLOCK arises during staging, write **nothing** — leave code
   and IR at the last successful state (like a compiler that emits no binary on error) — and
   report. Otherwise write the **whole** staged result at once.
5. On success, update status: a generated `NEW` → `LINKED` (validated-at = the new commit);
   `CHANGE_ACK` → `LINKED`. **Auto-write** (and optionally commit) — no separate confirmation
   gate; the user reviews via `git diff` and rolls back via git.

## Incremental (computation only)

For a directory, reprocess only files whose `source-hash` changed **plus their dependents**
(fall back to the whole `vbc/` unit when the dependency graph is unclear). This decides *what
is re-derived*, never *whether output is written* — application stays atomic (compile step 4).
A directory compile therefore either writes the whole BLOCK-free result, or on any BLOCK leaves
the previous successful state untouched.

## Resolving a BLOCK

A run with any BLOCK produces no code at all; the prior state stays intact. Resolve by one of:

- **edit the pseudo** to remove the ambiguity, or **answer** the question;
- add a scoped **premise/policy** to `.vbc/project.md` (promotes the BLOCK — see border.md);
- for a `DIVERGED` element that is an **intended change**: **acknowledge** it (status →
  `CHANGE_ACK`); the next compile applies the new behavior and re-links. Without this
  acknowledgment, re-running compile re-triggers the same divergence BLOCK forever.

Then re-run the command.

## Drift & rename — identity before behavior

If a stored symbol-path dangles (read-only git finds no symbol there): similarity-match within
the linked file (`references/ir-format.md` threshold), **propose the rename as a re-link for
the user to confirm**, and mark the element `RELINK_PENDING` (a BLOCK for compile). Only AFTER
a confirmed re-link do you compare the re-linked symbol's body to the pseudo; a divergence then
is the normal `DIVERGED` flow. A re-link by itself never overwrites a hand-edited body. Never
guess a re-link silently (prevents split-brain duplicates and clobbering).

## git preconditions

- **Refuse** when the repo has no initial commit (nothing to anchor linkage or roll back to).
- **Warn** on a detached HEAD.
- Do **not** fold compiler writes into a pre-existing dirty working tree without isolating them.
- Untracked `vbc/` content is still hashed from the working tree (pseudo need not be committed).

## ingest (optional helper)

Draft pseudo **from** existing code into `vbc/` for the user to trim. It does **not** mark the
IR as validated; the user then runs `validate`.

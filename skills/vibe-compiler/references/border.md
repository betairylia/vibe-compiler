# Border: OK / ASSUME / BLOCK

Classify **every** inference you make. The label comes from the **axes**, not the
category (perf, compat, error handling, …). Decompose a construct into parts and label
each part separately.

## Decide the label

Mark **BLOCK** if ANY axis holds:

1. **Divergent alternatives** — 2+ defensible readings with *observably different behavior
   the user cares about*, and nothing in pseudo / IR / code / `project.md` picks one.
2. **Costly or irreversible** — bakes in a contract expensive to unwind: data/wire format,
   public API, persisted schema, concurrency model, error/failure semantics, security
   boundary.
3. **Viability-threatening** — a perf/memory/complexity/concurrency guess that, if wrong for
   the *actual* scale, makes the result unusable, and context can't tell you the scale.

Else mark **ASSUME** if a defensible default exists, the alternatives are behaviorally close
**OR** cheap to change later, **AND** you surface it to the user.

Else mark **OK** — the input genuinely determines it: a well-known algorithm fully implied by
its name, the one reasonable implementation, or stdlib usage with no real alternative.

## Decomposition rule

A feature splits across labels; never pick one label for a whole construct. Canonical
example — a safety net:

- *Adding* the guard/shim → **ASSUME** (always surface it).
- *What the guard does* → **OK** if there is one obvious behavior; **BLOCK** the moment it
  changes failure semantics (swallow vs throw vs retry vs default).

## Promotion via project.md Assumptions

(See `references/project-md.md` for the Premises/Policies/Ratified structure and scope syntax.)

- A **Premise** (declared-true fact) may promote a would-be **BLOCK → OK** — but you MUST
  still emit a one-line surfaced note in the report: "resolved OK under premise *X*". Never
  silent.
- A **Policy** (how to resolve a recurring decision) promotes a recurring **BLOCK → ASSUME**.
- Match a premise/policy to a call **only within its declared scope**. If the scope glob does
  not match the call's symbol-path, do not promote.
- **Staleness:** if you observe code contradicting a premise (e.g. locks/threads appear under
  a "single-threaded" premise), do NOT rely on it — flag the premise possibly-stale and raise
  the underlying BLOCK.
- Record *which* premise/policy/ratified-assumption resolved each promoted call in the IR.

## Two contexts (the same labels, different question)

- **Validate** — "Can this pseudo faithfully describe existing code, or be soundly created?"
  A BLOCK means the pseudo *contradicts* reality (status `DIVERGED`). A symbol absent from the
  entire codebase is `NEW`, **not** a BLOCK.
- **Compile** — "Can I generate this logic safely?" A BLOCK means a critical assumption is
  required to produce the code.

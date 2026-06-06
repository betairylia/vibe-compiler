# Vibe Compiler (vbc) — Design

**Date:** 2026-06-06
**Status:** Implemented v1 — skill at `skills/vibe-compiler/`, commands at `commands/`. Revised after adversarial review (2026-06-06); plan at `../plans/2026-06-06-vibe-compiler.md`.

> Revision note: §2–§7 updated per the adversarial review in
> `../reviews/2026-06-06-adversarial-spec-review.md` — atomic/transactional compile,
> symbol-path grammar, NEW/greenfield path, compile precondition + per-element status,
> premise-promotion safety, rename re-link, and git preconditions.

## 1. Concept

A **language-agnostic** "compiler" that turns pseudo-code into real product code while
rigorously respecting the **border** between what the user explicitly specified and what
the compiler had to infer or assume.

Pseudo-code (`*.vibe`) ranges freely from natural language to near-real code. The grammar
is deliberately loose; users write in whatever style they want. The compiler's job is not
just translation — it is to **make every inference visible** and to **refuse to silently
guess** at anything critical.

It ships as a cross-platform **skill + slash commands** that work in both Claude Code and
Codex. This repository is the canonical development home.

## 2. The border (core principle)

Every inference the compiler makes is classified as **OK**, **ASSUME**, or **BLOCK**.
The label is **not** determined by the *category* of the thing (perf, compat, error
handling, …). It is determined by a small set of **axes**, with categories serving only as
illustrative examples. This keeps the discipline robust to novel situations.

### Axes

A decision is **BLOCK** if *any* of these hold:

1. **Materially divergent alternatives** — there are 2+ defensible readings that produce
   *observably different behavior the user cares about*, and nothing in the pseudo, IR,
   existing code, or project config picks one.
2. **Costly or irreversible if wrong** — it bakes in a contract that is expensive to
   unwind: data/wire format, public API, persisted schema, concurrency model, error/
   failure semantics, or a security boundary.
3. **Viability-threatening non-functional assumption** — a performance / memory /
   complexity / concurrency guess that, if wrong for the *actual* scale or context, makes
   the result unusable — and context cannot tell you the scale.

A decision is **ASSUME** if there is a defensible default, the alternatives are
behaviorally close *or* cheap to change later, **and** being wrong is easily caught
*because the assumption was surfaced to the user.*

A decision is **OK** only if the input genuinely determines it: a well-known algorithm
fully implied by its name, the one reasonable implementation, or standard-library usage
with no real alternative.

### Decomposition rule

A single feature often splits across labels. The compiler must decompose rather than pick
one label for a whole construct. Canonical example — adding a safety net:

- *Adding* the guard/shim → **ASSUME** (always surfaced).
- *What the guard does* → **OK** if there is one obvious behavior; **BLOCK** the moment it
  changes failure semantics (swallow vs throw vs retry vs default).

### Worked examples (axis illustrations)

- **O(n²) sweep.** A per-window loop over a high-volume stream is viability-threatening
  (axis 3) → **BLOCK**: ask for expected scale / acceptable complexity bound. The identical
  loop over an obviously-tiny collection → **ASSUME + surface** ("this is O(n²)").
- **Workaround compromising a stated goal.** A workaround that silently fails to deliver
  what the user asked → **BLOCK** (axis 1/2). A behavior-preserving compat shim → **ASSUME
  + surface**.
- **Underdetermined selection.** When a procedure could operate on one of two states (e.g.
  a live vs. snapshotted buffer) and the selection logic is unspecified, choosing wrong is
  a correctness bug → **BLOCK**.

See §7 for full, self-contained worked examples.

### Project-wide assumptions (config-driven promotion)

The project config (`.vbc/project.md`) carries an **Assumptions** section with two
user-authored kinds, plus one compiler-maintained kind:

- **Premises** — facts declared true that the compiler may *rely on* (e.g. "all timestamps
  are UTC"; "single-threaded unless a construct uses locks"). A premise can remove a
  divergence/uncertainty entirely → promotes a would-be **BLOCK → OK**.
- **Policies** — how to *resolve* recurring decisions (e.g. "errors: throw, never swallow";
  "unset numeric config: BLOCK, do not default"; "add null guards on public methods"). A
  policy promotes a recurring **BLOCK → ASSUME**.
- **Ratified assumptions** — a compiler-*appended* subsection: when the same ASSUME recurs,
  the compiler proposes it here (dated, with source `.vibe`) for the user to ratify. The
  compiler **never** edits user-authored Premises/Policies — it only appends proposals.

In every case the IR records *which* premise/policy/ratified assumption resolved a call, so
the audit trail shows the decision was made under a declared assumption rather than freely.

**Promotion safety.** Because **OK is silent** (only ASSUME is surfaced), an unchecked
premise could quietly green-light wrong code. Therefore:

- A premise that promotes **BLOCK → OK** must still emit a **one-line surfaced note**
  ("resolved OK under premise *X*") in the run report, so the promotion is auditable at
  code-review time — not only inside the IR.
- Each premise/policy declares an explicit **scope** (which files / symbols / construct
  kinds it governs) so matching a premise to a call is deterministic, not freeform judgment.
- Validate runs a **staleness re-check**: if it observes code that contradicts a premise
  (e.g. locks/threads appear under a "single-threaded" premise), it flags the premise as
  **possibly-stale** and re-raises the underlying BLOCK instead of relying on it.

## 3. Border applies in two contexts

The same OK/ASSUME/BLOCK labeling is used in two distinct operations:

- **Validate** — "Can this pseudo faithfully describe the existing code — or, for net-new
  elements, be soundly created?" A BLOCK here means the pseudo *contradicts* existing
  reality (a `DIVERGED` element); a symbol simply absent from the codebase is `NEW`, not a
  BLOCK (§4).
- **Compile** — "Can I generate this logic safely?" A BLOCK here means a critical assumption
  is required to produce the code.

## 4. Workflow — three phases

1. **Understand.** The user reads an existing codebase and writes `*.vibe` pseudo capturing
   their mental model. (Optionally drafted via `ingest`.)

2. **Validate** (`/vbc-validate <file.vibe | dir>`). Read-only. The compiler links each
   pseudo element to the actual implementation **without modifying anything**,
   builds/updates the annotated IR, classifies the border, and records per-element
   **status** (§5) plus the git commit each linkage was verified against. Three outcomes
   per element:
   - symbol **exists and matches** → `LINKED` (a verified correspondence);
   - symbol **absent from the entire codebase** → `NEW` (to-be-created — *not* a BLOCK;
     this is the greenfield / new-feature case);
   - symbol **exists but the pseudo contradicts it** → `DIVERGED`, a **BLOCK** (the §7.3
     case).

   Validate records **every** reached element's status in a single, complete IR write (it
   never leaves a half-written IR), then **hard-halts if any BLOCK exists** (a `DIVERGED`
   element, or a generation-axis BLOCK). The IR — including the `DIVERGED` entries — is still
   written, so the report and later acknowledgment work; "hard-halt" means *no green light
   for compile*, not *discard the IR*. If no `project.md` declares the target language **and**
   there is no existing code to determine it (pure greenfield), the language is undetermined
   → hard **BLOCK** (axis 2, irreversible) — the one thing the compiler refuses to guess.
   Validate establishes a verified correspondence between abstraction and reality before any
   change.

3. **Compile** (`/vbc-compile <file.vibe | dir>`). Lowers the IR into the target language:
   **generates** net-new code for `NEW` elements (at paths derived from the `project.md`
   layout; any invented path/namespace choice is recorded as ASSUME) and applies
   **surgical, symbol-level patches** for `LINKED` / `CHANGE_ACK` elements, leaving code not
   covered by pseudo untouched. On a successful write, a generated `NEW` element becomes
   `LINKED` (validated-at = the new commit) so a later compile patches it rather than
   regenerating it; a `CHANGE_ACK` element likewise returns to `LINKED`.

   **Precondition (checkable).** For every element it would touch, compile requires an IR
   entry whose status is `NEW`, `LINKED`, or `CHANGE_ACK`, and — for `LINKED` — whose
   validated-at commit is an ancestor of HEAD with the source `.vibe` content hash unchanged
   and no unresolved drift (§6). If an element has **no IR entry** (never validated), or its
   entry is `DIVERGED` / `RELINK_PENDING`, or its `.vibe` changed since validation, compile
   **stops and tells the user to validate first**. This turns "I ran compile before validate"
   and "a validate that hard-halted left `DIVERGED` entries" into deterministic refusals, not
   silent mis-patches.

   **Atomic application (transaction).** Compile **stages** all generated/patched code and
   computes the whole result *before writing anything*. It writes to disk **only if the
   entire processed set is BLOCK-free**; if any BLOCK arises, it writes **nothing** and the
   implementation (and IR) remain exactly at the last successful state — like a compiler
   that emits no binary on error. Incremental recomputation (§6) only decides *what is
   re-derived*; it never makes the write partial.

   **Auto-write.** A BLOCK-free compile writes (and may commit) without a separate
   confirmation gate — the border discipline is the guard, and the user reviews via
   `git diff` and rolls back via git. This relies on the git preconditions in §6.

Plus **Ingest** (`/vbc-ingest`, optional helper). Drafts pseudo *from* existing code to
lower the blank-page cost on a large unfamiliar codebase. The user then edits/trims the
draft. Not part of the always-used spine; validate + compile are the spine.

### Resolving a BLOCK

A run with any BLOCK produces **no code at all** (atomic — see phase 3); the prior state
stays intact. The user resolves a BLOCK by one of:

- **editing the pseudo** to remove the ambiguity, or **answering** the question;
- adding a **premise/policy** to `.vbc/project.md` (promotes the BLOCK per §2);
- for a `DIVERGED` element that is an **intended change** (§7.3 case b): **acknowledging**
  it, which sets the element's status to `CHANGE_ACK`. The next compile is then authorized
  to apply the change and re-link to the new behavior (status returns to `LINKED` at the new
  commit). Without this acknowledgment, re-running compile would re-trigger the same
  divergence BLOCK forever — the acknowledgment is what breaks that deadlock.

Then the user re-runs the command.

## 5. Artifacts (inside the target project)

- `vbc/` — pseudo sources (`*.vibe`).
- `.vbc/project.md` — `CLAUDE.md`-style project config. Declares target language(s),
  source layout, conventions, build/test commands, and an **Assumptions** section
  (Premises, Policies, and a compiler-appended Ratified-assumptions subsection — see §2).
  This is what makes the compiler language-neutral.
- `.vbc/ir/` — **persistent, committed, language-neutral** annotated IR. For each pseudo
  element it records:
  - **linkage**: pseudo element → one or more `(file, symbol-path)` targets (e.g.
    `LruCache.Evict`), where `symbol-path` is the canonical identity key defined in §6;
  - **status**: one of `NEW` (to-be-created), `LINKED` (validated against existing code),
    `DIVERGED` (validate BLOCK — pseudo contradicts code), `CHANGE_ACK` (user-acknowledged
    intended change; compile may apply), or `RELINK_PENDING` (linked symbol gone after a
    rename/delete, awaiting confirmation). An element that was never validated has **no IR
    entry** at all (there is no separate "unvalidated" status); a `.vibe` edited since
    validation is detected by content-hash mismatch (§6), not by a status;
  - **border labels** (OK/ASSUME/BLOCK) with assumption notes and, where applicable, the
    premise/policy/ratified assumption that resolved a call;
  - the **git commit** the linkage was validated against, and the **content hash** of the
    source `.vibe` at last processing (the incremental-build cache — see §6).
- `.vbc/reports/` — the border report from the last run: ASSUMEs to review and BLOCKs to
  resolve.

## 6. Change tracking, drift & incremental compile

The target project is assumed to be under git, and `vbc/` lives **inside that one repo** —
there is no separate/nested repo for the pseudo. Two complementary signals decide what is
stale, both derived from the single repo:

**Pseudo side — content hash.** The IR stores a content hash per `.vibe` file (via
`git hash-object`, which hashes the *working-tree* content, so uncommitted edits are
caught). On each run the compiler recomputes hashes; a changed hash marks that `.vibe`
stale. Full pseudo *history* comes free from `git log`/`git blame` on `vbc/`.

**Code side — symbol drift.** Linkage is **symbol-level**: pseudo element →
`(file, symbol-path)`. Symbols survive reformatting and edits *elsewhere*, making linkage
robust (chosen over fragile character-span linkage). The IR stores the git commit each
linkage was validated against; on each run the compiler uses **read-only git**
(`git log`/`diff`/`blame`) on the linked symbols to detect drift, flags stale links,
re-checks them, and **notifies the user when the gap is significant**.

**Symbol-path grammar (the linkage identity key).** `symbol-path` is the identity that both
the build cache and drift detection compare, so it must be derived deterministically — two
agents must produce the same path for the same construct. Canonical rules:

- **Separator** `.` joins nesting; the path is rooted at the file's top-level scope.
- **Members** of a type/namespace: `Type.Member` (e.g. `LruCache.Evict`); nested types
  nest: `Outer.Inner.M`.
- **Free / module-level functions**: `Module.func`, where `Module` is the module name (or
  the file stem in languages without modules).
- **Module-level statements** (e.g. a top-level driver loop) anchor to a synthetic member
  `Module.__main__` (ordinal-suffixed if several: `__main__#2`).
- **Overloads** disambiguate by the **full parameter-type signature**, always:
  `Type.Get(K)`, `Type.Get(K,V)` (arity is implied; never use an arity-only form). This is
  the single canonical form — no fallback chain.
- **Lambdas/closures** anchor to the enclosing named symbol with an ordinal:
  `Type.M.$lambda#1`.
- **One-to-many / many-to-one**: a pseudo element may link to a *set* of symbol-paths (e.g.
  the §7.1 row implying `MoveToFront`, `InsertAtFront`, `Evict`, `map.Find`); the IR stores
  the set explicitly. A pseudo element with no symbol counterpart yet is `NEW` (§4/§5).

Worked symbol-path tables accompany the §7.1 and §7.2 examples.

**Rename / dangling-symbol drift.** Symbol-path survives reformatting and edits *elsewhere*
but **not a rename of the symbol itself** — the path *is* the identity, so rename changes
it. When read-only git finds no symbol at a stored path, the compiler does **not** guess: it
similarity-matches (signature + body) within the linked file, **proposes the rename as a
re-link for the user to confirm**, and meanwhile marks the element `RELINK_PENDING` (a BLOCK
for compile). An unconfirmed re-link is never applied silently, preventing split-brain
duplicates. **Identity is resolved before behavior:** while a stored path dangles the element
is `RELINK_PENDING` and the user first confirms (or rejects) the re-link; only *after* a
confirmed re-link does the compiler compare the re-linked symbol's body to the pseudo. If the
re-linked body then diverges — e.g. it was also hand-edited — that surfaces as the normal
`DIVERGED` case (§7.3), resolved by fixing the pseudo or acknowledging the change. A re-link
by itself never overwrites a hand-edited body.

**Incremental compile against a directory.** `/vbc-validate` and `/vbc-compile` accept a
single `.vibe` file *or* a directory (e.g. `vbc/`). For a directory, the compiler walks the
tree and reprocesses only what is stale by either signal — like an incremental `make`, with
the IR manifest (hashes + validated-at commits) as the build cache. Because `.vibe` files
can reference each other, v1 is conservative: it reprocesses a changed file **and its
dependents**, falling back to the whole `vbc/` unit when the dependency graph is unclear.
Precise dependency-graph tracking is a later refinement.

This is purely a *computation* optimization: it decides **what is re-derived**, never
**whether output is written**. Application is **atomic** (§4 phase 3) — the content hash is
a skip-work cache, and correctness never depends on it. A directory compile therefore either
writes the whole BLOCK-free result or, on any BLOCK, leaves the previous successful state
untouched.

"Monitoring" pseudo changes is therefore **on-demand at command time**, not a background
watcher — which fits a slash-command tool that runs inside an agent session.

**Git preconditions.** The atomic "previous state" guarantee and the validated-at anchor
both require a usable git baseline. Compile **refuses** when the repo has no initial commit
(nothing to anchor linkage or roll back to) and **warns** on a detached HEAD; it will not
fold its writes into a pre-existing dirty working tree without isolating them. Untracked
`vbc/` content is still hashed from the working tree (pseudo need not be committed), but
generated code is written against a committed baseline.

## 7. Worked examples (canonical — ship in the skill)

These are self-contained, invented examples (no real/owned project code). They match two
grammar "flavors": a systems/struct flavor and a pipeline/dataflow flavor.

### 7.1 Compile context — systems/struct flavor (LRU cache)

```csharp
// vbc/cache.vibe
struct LruCache<K, V>
{
    Dictionary<K, Node> map;
    Node head, tail;             // intrusive list, MRU at head
    List<(K, V)> _dirty;         // write-back buffer
    bool _writeBackEnabled;
    long hits, misses;
    long _evictLock;
}

partial struct LruCache<K, V>
{
    const int CAPACITY = ...;            // not specified

    V Get(K key)
    {
        node = map.Find(key);
        if (node == null) { misses++; return /* miss? */; }
        MoveToFront(node);               // LRU bookkeeping
        hits++; return node.value;
    }

    void Put(K key, V value)
    {
        if (map.Count >= CAPACITY)
            lock (_evictLock) Evict();   // drop least-recently-used
        InsertAtFront(key, value);
        if (_writeBackEnabled) MarkDirty(key, value);
    }
}
```

| Construct | Label | Why (axis) |
|---|---|---|
| `MoveToFront`, `InsertAtFront`, `Evict`, `map.Find` | **OK** | LRU fully implied by name |
| `return /* miss? */` on miss | **BLOCK** | axis 1 — throw vs `default(V)` vs Option is observably different error semantics |
| `CAPACITY = ...` | **BLOCK** → ASSUME if a policy/premise supplies it | governs memory + eviction; divergent + costly |
| `_evictLock` present, `Get` unsynchronized | **BLOCK** → OK if a "single-threaded" premise is declared | axis 2 — concurrency contract |
| `_dirty` flush timing unstated | **ASSUME + surface** | defensible default, cheap to change, surfaced |

**Symbol-paths (§6 grammar).** Project linkage targets: the type `LruCache` (with field
members `LruCache.map`, `LruCache.head`, …), `LruCache.CAPACITY`, `LruCache.Get`,
`LruCache.Put`, `LruCache.Evict`, `LruCache.MoveToFront`, `LruCache.InsertAtFront`,
`LruCache.MarkDirty`. The one-to-many "OK" row links a single pseudo line to the **set**
{`LruCache.MoveToFront`, `LruCache.InsertAtFront`, `LruCache.Evict`}. Fields **declared in
the pseudo** (`LruCache.map`, `LruCache.head`, …) are linkage targets; **library calls** on
them (`map.Find`, `lock`) are not.

### 7.2 Compile context — pipeline/dataflow flavor (trending terms)

```python
# vbc/trending.vibe
# Find terms surging above their historical baseline rate.

def find_trending(events: Stream, window):
    counts = {}
    for e in window_of(events, window):
        counts[normalize(e.term)] += 1        # normalize: case-fold; stem?
    baseline = load_baseline_rates()
    out = []
    for term, c in counts:
        expected = baseline.get(term)         # term never seen before?
        if surprise(c, expected) > threshold: # surprise = ???
            out.append(term)
    return top_k(out, k)                       # k = ???

for window in tumbling_windows(events, every="1min"):
    find_trending(window, ...)
```

| Construct | Label | Why (axis) |
|---|---|---|
| `top_k`, `tumbling_windows` | **OK** | well-known |
| `normalize` | **ASSUME** | case-fold obvious; stemming surfaced as a sub-choice |
| `surprise(c, expected)` | **BLOCK** | axis 1 — ratio vs z-score vs KL give materially different results |
| `baseline.get(term)` for unseen term | **BLOCK** | missing value → div-by-zero / error semantics |
| `threshold`, `k` | **BLOCK** → ASSUME via policy/premise | unset critical config |
| per-window loop | **ASSUME** → BLOCK if stream declared huge | axis 3 — perf/scale |

**Symbol-paths (§6 grammar).** Module = file stem `trending`. Linkage targets:
`trending.find_trending`, `trending.normalize`, `trending.surprise`,
`trending.load_baseline_rates`, and the module-level driver loop
`for window in tumbling_windows(...)` → `trending.__main__`. Well-known library calls
(`top_k`, `tumbling_windows`, `window_of`) are **not** linkage targets.

### 7.3 Validate context — pseudo contradicts existing code

The keystone phase. Validate is read-only and asks "does this pseudo faithfully describe
what the code *currently is*?" — not "what should it become."

```
# vbc/cache.vibe says:        Evict();   // drop least-recently-used   (tail)
# but existing Cache.cs has:  void Evict() => Remove(head);            // head = MRU

# /vbc-validate cache.vibe  →  BLOCK
#   LruCache.Evict — pseudo intent: drop LRU (tail).
#   Reality: drops head (MRU). Pseudo cannot be linked to current code.
#   Resolve by either:
#     (a) the pseudo is meant to DESCRIBE reality → fix the pseudo to match, or
#     (b) the divergence is an INTENDED change → acknowledge it and use /vbc-compile.
```

Validate cannot tell a mistaken description from an intended change, so it hard-halts and
makes the user choose. This is what makes later edits meaningful.

**`NEW` vs `DIVERGED`.** This BLOCK fires only when a symbol *exists* and the pseudo
contradicts it (`DIVERGED`). A symbol absent from the whole codebase is `NEW` — validate
records it for creation rather than blocking, so greenfield pseudo validates cleanly (§4).

**Acknowledging an intended change.** When the divergence is in fact the change the user
wants (case b), they acknowledge it, flipping the element to `CHANGE_ACK`; the next compile
applies the new behavior and re-links at the new commit. This is the mechanism that resolves
the otherwise-permanent re-trigger of the same divergence BLOCK (§4, *Resolving a BLOCK*).

## 8. Cross-platform packaging

- **Skill** `vibe-compiler` — holds all methodology (the border axes, the workflow, the IR
  format, surgical-patch rules). Written tool-agnostic. Installed to `~/.claude/skills` and
  `~/.agents/skills`.
- **Thin command prompts** (`vbc-validate`, `vbc-compile`, `vbc-ingest`) — minimal
  frontmatter, use `$ARGUMENTS`, defer all logic to the skill. Installed to
  `.claude/commands/` and `~/.codex/prompts/`.
- `install.sh` fans out from this repo into both agents' directories. Repo layout:

  ```
  vibe-compiler/
    skills/vibe-compiler/SKILL.md        # methodology (language-neutral)
    skills/vibe-compiler/references/     # IR format, border axes, templates
    commands/vbc-validate.md             # canonical command bodies
    commands/vbc-compile.md
    commands/vbc-ingest.md
    AGENTS.md                            # Codex project context
    CLAUDE.md -> AGENTS.md               # symlink, shared context
    install.sh                           # fan-out installer
  ```

## 9. Build order

Implement **validate-first** (the keystone — verified correspondence and the border
discipline), then **compile** (surgical patching), then **ingest** (the optional helper).

## 10. Out of scope for v1 (YAGNI)

- Character-span linkage (symbol-level only).
- Projects not under git.
- Automatic code → pseudo back-sync (code edits silently updating pseudo).
- Cross-file symbol moves / large refactors beyond single-file rename re-link (§6).
- Precise cross-`.vibe` dependency-graph tracking (conservative reprocessing in v1 — §6).

## 11. Decisions settled with defaults (changeable)

- **Command names:** `/vbc-validate`, `/vbc-compile`, `/vbc-ingest`.
- **IR format:** structured Markdown (human-readable, doubles as the audit trail) rather
  than JSON.

## 12. Open questions for the implementation plan

All four are now **resolved in the v1 skill references**:

- IR entry Markdown formatting → `skills/vibe-compiler/references/ir-format.md` (on-disk schema).
- `.vbc/project.md` template + premise/policy **scope syntax** →
  `skills/vibe-compiler/references/project-md.md`.
- Border report format → `skills/vibe-compiler/references/report-format.md`.
- Similarity / "significant gap" threshold (≥ 0.6 match to propose a re-link; else BLOCK) →
  `skills/vibe-compiler/references/ir-format.md`.

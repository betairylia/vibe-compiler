# Vibe Compiler (vbc) — Design

**Date:** 2026-06-06
**Status:** Approved design, pending implementation plan

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

## 3. Border applies in two contexts

The same OK/ASSUME/BLOCK labeling is used in two distinct operations:

- **Validate** — "Can this pseudo faithfully describe the existing code?" A BLOCK here means
  the pseudo claims something that cannot be reconciled with reality.
- **Compile** — "Can I generate this logic safely?" A BLOCK here means a critical assumption
  is required to produce the code.

## 4. Workflow — three phases

1. **Understand.** The user reads an existing codebase and writes `*.vibe` pseudo capturing
   their mental model. (Optionally drafted via `ingest`.)

2. **Validate** (`/vbc-validate <file.vibe>`). Read-only. The compiler links the pseudo to
   the actual implementation **without modifying anything**, builds/updates the annotated
   IR recording that linkage, classifies the border, and **hard-halts on any BLOCK**. It
   records the git commit each linkage was verified against. This establishes a verified
   correspondence between abstraction and reality *before* any change is made.

3. **Compile** (`/vbc-compile <file.vibe>`). The user has edited the *validated* pseudo to
   express desired **changes**. Compile lowers the IR into the target language via
   **surgical, symbol-level patches**, applying changes to the real implementation while
   leaving code not covered by pseudo untouched. Hard-halts on any BLOCK.

Plus **Ingest** (`/vbc-ingest`, optional helper). Drafts pseudo *from* existing code to
lower the blank-page cost on a large unfamiliar codebase. The user then edits/trims the
draft. Not part of the always-used spine; validate + compile are the spine.

### Hard-halt semantics

If **any** BLOCK exists, no code is produced anywhere until every BLOCK is resolved. The
user resolves a BLOCK by editing the pseudo, answering the question, or adding a standing
policy to `.vbc/project.md`, then re-running the command.

## 5. Artifacts (inside the target project)

- `vbc/` — pseudo sources (`*.vibe`).
- `.vbc/project.md` — `CLAUDE.md`-style project config. Declares target language(s),
  source layout, conventions, build/test commands, and an **Assumptions** section
  (Premises, Policies, and a compiler-appended Ratified-assumptions subsection — see §2).
  This is what makes the compiler language-neutral.
- `.vbc/ir/` — **persistent, committed, language-neutral** annotated IR. For each pseudo
  element it records:
  - **linkage**: pseudo element → `(file, symbol-path)` (e.g. `Sector.SetSlot`);
  - **border labels** (OK/ASSUME/BLOCK) with assumption notes and, where applicable, the
    standing policy that resolved a call;
  - the **git commit** the linkage was validated against.
- `.vbc/reports/` — the border report from the last run: ASSUMEs to review and BLOCKs to
  resolve.

## 6. Linkage & git-based drift tracking

- Linkage is **symbol-level**: pseudo element → `(file, symbol-path)`. Symbols survive
  reformatting and edits elsewhere, making linkage robust to drift (chosen over fragile
  character-span linkage).
- The IR stores the git commit each linkage was validated against.
- On validate/compile, the compiler uses **read-only git** (`git log` / `diff` / `blame`)
  on the linked files/symbols to detect drift since the last validation, flags stale links,
  re-checks them, and **notifies the user when the gap is significant**.
- The target project is assumed to be under git source control.

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

## 11. Decisions settled with defaults (changeable)

- **Command names:** `/vbc-validate`, `/vbc-compile`, `/vbc-ingest`.
- **IR format:** structured Markdown (human-readable, doubles as the audit trail) rather
  than JSON.

## 12. Open questions for the implementation plan

- Exact structured-Markdown schema for IR entries.
- `.vbc/project.md` template (sections, policy syntax).
- Border report format (how ASSUMEs and BLOCKs are presented for review/resolution).
- How "significant gap" is thresholded for drift notification.

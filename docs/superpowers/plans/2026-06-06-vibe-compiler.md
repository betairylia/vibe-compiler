# Vibe Compiler (vbc) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `vibe-compiler` skill + `vbc-validate`/`vbc-compile`/`vbc-ingest` slash commands that turn loose pseudo-code (`*.vibe`) into real product code while enforcing the OK/ASSUME/BLOCK border, working in both Claude Code and Codex.

**Architecture:** A single language-neutral **skill** (`SKILL.md` + `references/`) holds all methodology; three **thin command bodies** defer to it. The skill operates on a target project's `vbc/` (pseudo), `.vbc/project.md` (config + Assumptions), `.vbc/ir/` (persistent annotated IR), and `.vbc/reports/`. Compile is transactional (any BLOCK → write nothing). `install.sh` fans the skill/commands out to both agents' directories.

**Tech Stack:** Markdown (skill, references, IR, reports), POSIX shell (`install.sh`), `git` (read-only drift + content hashing via `git hash-object`). No compiled code — the "compiler" is an LLM executing the skill.

**Source spec:** `docs/superpowers/specs/2026-06-06-vibe-compiler-design.md` (revised).
**RED baseline (already established):** `docs/superpowers/reviews/2026-06-06-adversarial-spec-review.md` documents how an agent diverges without this skill — that is our failing test. We do **not** re-run baseline; we verify GREEN.

---

## Testing approach (read first)

This builds instructions for an LLM, so "tests" are **scenario verifications**: dispatch one subagent that is given *only* the built skill + a scenario, and check its behavior matches the spec. Per the cost constraint, **all behavioral verification is one final batch of ≤5 subagents** (Task 9), not per-task. Content tasks (2–8) instead end with a **self-review gate**: the author confirms the artifact fully specifies its concern with no placeholder and matches the spec section cited.

The five canonical scenarios (the GREEN gate, from the review's simulator):
- **S1 Greenfield:** `vbc/cache.vibe`, no code, no `project.md` → compile must BLOCK on unknown target language; with `project.md` present, generate net-new and mark `NEW→LINKED`.
- **S2 Validate-mismatch:** code drops MRU, pseudo says LRU → `DIVERGED` BLOCK; the intended-change path reaches `CHANGE_ACK`→compile.
- **S3 Directory + one BLOCK:** 3 files, 1 blocks → atomic: nothing written, prior state intact, report lists compiled-vs-blocked.
- **S4 Drift/rename:** linked symbol renamed → `RELINK_PENDING`, propose re-link, never clobber.
- **S5 Border labeling:** the §7.1 (LRU) and §7.2 (trending) constructs label exactly as the spec tables.

---

## File Structure

Files created in **this repo** (the development home):

| Path | Responsibility |
|---|---|
| `skills/vibe-compiler/SKILL.md` | Entry point: when-to-use description, the 3-phase spine, links to references. Concise. |
| `skills/vibe-compiler/references/border.md` | OK/ASSUME/BLOCK axes, decomposition rule, premise/policy promotion + promotion safety. |
| `skills/vibe-compiler/references/ir-format.md` | Symbol-path grammar, status enum + transitions, on-disk IR markdown schema, content-hash/drift. |
| `skills/vibe-compiler/references/workflow.md` | validate / compile / ingest procedures: linkage, NEW/LINKED/DIVERGED, atomic write, precondition, resolving-BLOCK, rename re-link, git preconditions, incremental. |
| `skills/vibe-compiler/references/project-md.md` | `.vbc/project.md` template + premise/policy **scope syntax**. |
| `skills/vibe-compiler/references/report-format.md` | Border-report markdown layout. |
| `skills/vibe-compiler/references/examples.md` | The §7 worked examples (LRU, trending, validate-mismatch) with label + symbol-path tables. |
| `commands/vbc-validate.md` | Thin command body → invoke skill, validate phase. |
| `commands/vbc-compile.md` | Thin command body → invoke skill, compile phase. |
| `commands/vbc-ingest.md` | Thin command body → invoke skill, ingest phase. |
| `install.sh` | Fan-out: skill → `~/.claude/skills` + `~/.agents/skills`; commands → `~/.claude/commands` + `~/.codex/prompts`. |
| `AGENTS.md` | Repo working context (points at the spec + skill). |
| `CLAUDE.md` | Symlink → `AGENTS.md`. |
| `README.md` | Repo overview + install instructions. |

Build order follows spec §9: validate-first (border + IR + workflow), then compile (already in workflow.md), then ingest, then packaging.

---

## Task 1: Repo scaffold + packaging

**Files:**
- Create: `skills/vibe-compiler/` and `skills/vibe-compiler/references/` (directories)
- Create: `commands/` (directory)
- Create: `install.sh`
- Create: `AGENTS.md`
- Create: `CLAUDE.md` (symlink → `AGENTS.md`)
- Create: `README.md`

- [ ] **Step 1: Create directories and `.gitkeep` placeholders**

```bash
mkdir -p skills/vibe-compiler/references commands
```

- [ ] **Step 2: Write `install.sh`**

```bash
#!/usr/bin/env bash
# Fan out the vibe-compiler skill + commands into Claude Code and Codex dirs.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

link() { # src dest  -> symlink, replacing any existing
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest"
  ln -s "$src" "$dest"
  echo "linked $dest -> $src"
}

# Skill (folder) → both agents
link "$REPO/skills/vibe-compiler" "$HOME/.claude/skills/vibe-compiler"
link "$REPO/skills/vibe-compiler" "$HOME/.agents/skills/vibe-compiler"

# Commands (files) → Claude Code commands + Codex prompts
for c in vbc-validate vbc-compile vbc-ingest; do
  link "$REPO/commands/$c.md" "$HOME/.claude/commands/$c.md"
  link "$REPO/commands/$c.md" "$HOME/.codex/prompts/$c.md"
done
echo "vbc installed."
```

- [ ] **Step 3: Write `AGENTS.md`** (repo working context)

```markdown
# vibe-compiler — repo context

This repo develops the `vibe-compiler` skill + slash commands. Canonical design:
- Spec: `docs/superpowers/specs/2026-06-06-vibe-compiler-design.md`
- Review: `docs/superpowers/reviews/2026-06-06-adversarial-spec-review.md`
- Plan: `docs/superpowers/plans/2026-06-06-vibe-compiler.md`

Skill source lives in `skills/vibe-compiler/`; commands in `commands/`.
Run `./install.sh` to link them into `~/.claude` and `~/.agents`/`~/.codex`.
Edit the source here, never the installed symlink targets.
```

- [ ] **Step 4: Create `CLAUDE.md` symlink and `README.md`**

```bash
ln -sf AGENTS.md CLAUDE.md
```

```markdown
<!-- README.md -->
# vibe-compiler (vbc)

A language-agnostic "compiler" that turns pseudo-code (`*.vibe`) into real product
code while making every inference visible (OK / ASSUME / BLOCK) and refusing to
silently guess anything critical. Works in Claude Code and Codex.

## Install
    ./install.sh

## Use (inside a target project under git)
- Write pseudo in `vbc/`, configure `.vbc/project.md`.
- `/vbc-validate <file.vibe | dir>` — link pseudo ↔ code, build the IR (read-only).
- `/vbc-compile  <file.vibe | dir>` — generate/patch code (transactional).
- `/vbc-ingest   <path>` — draft pseudo from existing code (optional helper).

See `docs/superpowers/specs/` for the full design.
```

- [ ] **Step 5: Self-review gate**

Confirm: `install.sh` is executable-ready (`chmod +x install.sh`), `CLAUDE.md` resolves to `AGENTS.md`, directories exist. Do NOT run `install.sh` yet (skill files not written).

- [ ] **Step 6: Commit**

```bash
chmod +x install.sh
git add -A && git commit -m "scaffold vbc repo: install.sh, AGENTS.md, CLAUDE.md, README, dirs"
```

---

## Task 2: Border reference (`references/border.md`)

**Files:**
- Create: `skills/vibe-compiler/references/border.md`

Implements spec §2 as **operational instructions** (imperative, for an executing agent).

- [ ] **Step 1: Write `border.md`**

````markdown
# Border: OK / ASSUME / BLOCK

Classify **every** inference you make. The label comes from the **axes**, not the
category. Decompose a construct into parts and label each part separately.

## Decide the label

Mark **BLOCK** if ANY axis holds:
1. **Divergent alternatives** — 2+ defensible readings with observably different behavior the
   user cares about, and nothing in pseudo / IR / code / `project.md` picks one.
2. **Costly or irreversible** — bakes in a contract expensive to unwind: data/wire format,
   public API, persisted schema, concurrency model, error/failure semantics, security boundary.
3. **Viability-threatening** — a perf/memory/complexity/concurrency guess that, if wrong for
   the actual scale, makes the result unusable, and context can't tell you the scale.

Else mark **ASSUME** if a defensible default exists, alternatives are behaviorally close OR
cheap to change later, AND you surface it to the user.

Else mark **OK** (input genuinely determines it: well-known algorithm implied by name, the one
reasonable implementation, stdlib usage).

## Decomposition rule
A feature splits across labels. E.g. a safety net: *adding* the guard → ASSUME (surface it);
*what the guard does* → OK if one obvious behavior, BLOCK the moment it changes failure
semantics (swallow vs throw vs retry vs default).

## Promotion via project.md Assumptions (see references/project-md.md)
- A **Premise** (declared-true fact) may promote a would-be **BLOCK → OK** — but you MUST still
  emit a one-line surfaced note in the report: "resolved OK under premise <X>". Never silent.
- A **Policy** (how to resolve a recurring decision) promotes a recurring **BLOCK → ASSUME**.
- Match a premise/policy to a call only within its declared **scope** (project-md.md). If scope
  doesn't cover the call, do not promote.
- **Staleness:** if you observe code contradicting a premise (e.g. locks/threads under a
  "single-threaded" premise), do NOT rely on it — flag the premise possibly-stale and raise the
  underlying BLOCK.
- Record which premise/policy/ratified-assumption resolved each promoted call in the IR.

## Two contexts
- **Validate:** "can this pseudo faithfully describe existing code (or be soundly created)?"
  BLOCK = pseudo contradicts reality (`DIVERGED`). A symbol absent everywhere is `NEW`, not BLOCK.
- **Compile:** "can I generate this safely?" BLOCK = a critical assumption is required.
````

- [ ] **Step 2: Self-review gate**

Cross-check every bullet against spec §2 (axes verbatim, decomposition, promotion safety's 3 rules). No placeholder, no "etc." Confirm the §7.1/§7.2 constructs would label as the spec tables under these rules (mental trace). Behavioral check deferred to Task 9 / S5.

- [ ] **Step 3: Commit**

```bash
git add skills/vibe-compiler/references/border.md
git commit -m "vbc: border reference (OK/ASSUME/BLOCK axes + promotion safety)"
```

---

## Task 3: IR format reference (`references/ir-format.md`)

**Files:**
- Create: `skills/vibe-compiler/references/ir-format.md`

Implements spec §5 (IR record) + §6 (symbol-path grammar, drift). **Defines the concrete on-disk schema** (spec §12 item 1 — formatting).

- [ ] **Step 1: Write `ir-format.md`**

````markdown
# IR format & symbol-path

## Location
One IR file per pseudo file, mirroring the path:
`vbc/<name>.vibe` → `.vbc/ir/<name>.vibe.md`. Persistent, committed.

## symbol-path (the identity key — derive deterministically; two agents must agree)
- Separator `.`, rooted at the file's top-level scope.
- Type/namespace members: `Type.Member`; nested: `Outer.Inner.M`.
- Free / module-level functions: `Module.func` (`Module` = module name, else file stem).
- Module-level statements (e.g. a top-level loop): synthetic `Module.__main__` (ordinal
  `__main__#2` if several).
- Overloads: **full parameter-type signature, always** — `Type.Get(K)`, `Type.Get(K,V)`.
  Single canonical form; no arity-only `/1` form, no fallback chain.
- Lambdas/closures: anchor to enclosing named symbol + ordinal — `Type.M.$lambda#1`.
- One-to-many / many-to-one: a pseudo element may link to a **set** of symbol-paths.
- Fields declared in pseudo are linkage targets (`Type.field`); library calls on them are not.

## status (per element)
`NEW` (absent everywhere → to-be-created) · `LINKED` (validated vs existing code) ·
`DIVERGED` (validate BLOCK: pseudo contradicts code) · `CHANGE_ACK` (user-acknowledged intended
change; compile may apply) · `RELINK_PENDING` (linked symbol gone after rename/delete).
**No `UNVALIDATED`:** a never-validated element simply has **no IR entry**. A `.vibe` edited
since validation is detected by content-hash mismatch, not a status.

### transitions
- validate: writes `LINKED` / `NEW` / `DIVERGED` per element, in one complete IR write.
- compile success: generated `NEW` → `LINKED` (validated-at = new commit); `CHANGE_ACK` → `LINKED`.
- drift, symbol gone: `LINKED`/`CHANGE_ACK` → `RELINK_PENDING` until user confirms re-link → `LINKED`.

## Drift & content hash
- Per-file `source-hash` = `git hash-object vbc/<name>.vibe` (working tree; catches uncommitted).
- Per-linkage `validated-at` = HEAD commit at validation.
- Drift check (read-only git on linked symbols): notify when a linked symbol's body changed
  since `validated-at`, or moved/renamed (→ `RELINK_PENDING`). Re-link similarity threshold:
  best signature+normalized-body match score ≥ 0.6 → propose that single match; if none ≥ 0.6
  or two-or-more tie → BLOCK and ask the user.

## On-disk schema (markdown)
```markdown
# IR: cache.vibe
- source-hash: <git hash-object output>
- validated-at: <commit sha>
- target-language: csharp
- summary: 2 LINKED, 1 NEW, 0 DIVERGED, 0 RELINK_PENDING

## LruCache.Get(K)
- targets: src/Cache.cs :: LruCache.Get(K)
- status: DIVERGED
- labels:
  - miss return → BLOCK (axis 1: error semantics; pseudo=default(V), code=throws)
- resolved-by: —

## LruCache.Evict()
- targets: src/Cache.cs :: LruCache.Evict()
- status: LINKED
- labels:
  - body → OK (LRU implied by name)
- resolved-by: —
```
````

- [ ] **Step 2: Self-review gate**

Verify the grammar produces exactly the §7.1/§7.2 worked symbol-paths (e.g. `trending.__main__` for the driver loop, `LruCache.Get(K)` overload form). No placeholders. Status set matches spec §5 (UNVALIDATED absent). Behavioral check deferred to Task 9 / S5.

- [ ] **Step 3: Commit**

```bash
git add skills/vibe-compiler/references/ir-format.md
git commit -m "vbc: IR format + symbol-path grammar + on-disk schema"
```

---

## Task 4: Workflow reference (`references/workflow.md`)

**Files:**
- Create: `skills/vibe-compiler/references/workflow.md`

Implements spec §3, §4, §6 as the operational procedures. This is the core.

- [ ] **Step 1: Write `workflow.md`**

````markdown
# Workflow: validate · compile · ingest

Target project is under git; `vbc/` lives inside it. Accept a single `.vibe` file OR a directory.

## validate (read-only — never writes code)
1. Determine target language from `.vbc/project.md`. If absent AND no existing code determines
   it (pure greenfield) → **BLOCK** (axis 2): "target language undetermined".
2. For each pseudo element, derive its symbol-path(s) (references/ir-format.md) and locate it:
   - exists & matches pseudo intent → `LINKED`
   - absent from the entire codebase → `NEW` (NOT a block)
   - exists but pseudo contradicts it → `DIVERGED` (a BLOCK)
3. Classify every construct with the border (references/border.md); record labels + any
   premise/policy promotions (+ surfaced notes).
4. Write the **complete** IR in one shot (including `DIVERGED` entries) + `source-hash` +
   `validated-at`. Write the report (references/report-format.md).
5. If any BLOCK exists, hard-halt: report it; produce no green light for compile. (IR is still written.)

## compile (transactional)
1. **Precondition:** for every element to touch, require an IR entry with status `NEW`,
   `LINKED`, or `CHANGE_ACK`; for `LINKED`, `validated-at` must be an ancestor of HEAD, the
   `.vibe` `source-hash` unchanged, and no unresolved drift. Otherwise (no entry / `DIVERGED` /
   `RELINK_PENDING` / hash changed) → STOP: "validate first".
2. Check git preconditions (§ below). 
3. **Stage** all output in memory: generate net-new code for `NEW` (paths from `project.md`
   layout; record invented path/namespace as ASSUME); surgically patch the linked symbol(s)
   for `LINKED`/`CHANGE_ACK`, leaving uncovered code untouched.
4. If ANY BLOCK arises during generation, write **nothing** — leave code + IR at the last
   successful state — and report. Else write the **whole** staged result atomically.
5. On success: `NEW`→`LINKED` (validated-at = new commit), `CHANGE_ACK`→`LINKED`. Auto-write
   (and optionally commit); the user reviews via `git diff`. No separate confirmation gate.

## Incremental (computation only)
For a directory, reprocess only files whose `source-hash` changed plus their dependents (fall
back to whole `vbc/` if the dep graph is unclear). This decides WHAT is re-derived, never
WHETHER output is written — application stays atomic (compile step 4).

## Resolving a BLOCK
Edit the pseudo / answer the question / add a premise|policy to `project.md` / for a `DIVERGED`
intended change, acknowledge it (→ `CHANGE_ACK`, next compile applies + re-links). Re-run.

## Drift & rename (identity before behavior)
If a stored symbol-path dangles: similarity-match within the file, propose the rename as a
re-link for the user to confirm, mark `RELINK_PENDING` (BLOCK for compile). Only AFTER a
confirmed re-link compare the body to pseudo; a divergence then is the normal `DIVERGED` flow.
A re-link never overwrites a hand-edited body.

## git preconditions
Refuse when the repo has no initial commit (nothing to anchor/roll back to). Warn on detached
HEAD. Do not fold writes into a pre-existing dirty tree without isolation. Untracked `vbc/` is
still hashed from the working tree.

## ingest (optional helper)
Draft pseudo FROM existing code into `vbc/` for the user to trim. Does not write the IR as
validated; the user then runs validate.
````

- [ ] **Step 2: Self-review gate**

Trace S1–S4 mentally against this procedure; confirm each reaches the spec-mandated outcome (greenfield language BLOCK; DIVERGED→CHANGE_ACK; atomic no-write on block; RELINK_PENDING). No placeholder. Behavioral check in Task 9.

- [ ] **Step 3: Commit**

```bash
git add skills/vibe-compiler/references/workflow.md
git commit -m "vbc: workflow reference (validate/compile/ingest, atomic, drift, git)"
```

---

## Task 5: project.md template + scope syntax (`references/project-md.md`)

**Files:**
- Create: `skills/vibe-compiler/references/project-md.md`

Resolves spec §12 item 2.

- [ ] **Step 1: Write `project-md.md`** (template + scope syntax)

````markdown
# .vbc/project.md template

`project.md` makes the compiler language-neutral and carries project-wide Assumptions.

## Scope syntax
Each Premise/Policy line begins with `[scope: <glob>]` where `<glob>` matches symbol-paths
(`*` within a segment, `**` across segments). Examples: `[scope: **]` (whole project),
`[scope: LruCache.*]` (one type). A premise/policy applies to a call only if its scope glob
matches the call's symbol-path.

## Template
```markdown
# vbc project: <name>

## Target
- language: csharp            # REQUIRED; if missing and greenfield → BLOCK
- source-root: src/
- layout: <Type>.cs, namespace mirrors folder path   # how NEW elements choose a file/path
- build: dotnet build
- test: dotnet test

## Conventions
- <free-text style notes the generator should follow>

## Assumptions

### Premises   (declared true; may promote BLOCK→OK; promotion still emits a surfaced note)
- [scope: **] all timestamps are UTC
- [scope: LruCache.*] single-threaded; no locking required

### Policies   (how to resolve recurring decisions; promote BLOCK→ASSUME)
- [scope: **] errors: throw; never silently swallow
- [scope: **] unset numeric config: BLOCK, do not default

### Ratified assumptions   (compiler-appended; user ratifies; compiler never edits Premises/Policies)
<!-- vbc appends dated proposals below, e.g.: -->
<!-- - [2026-06-06] [scope: trending.normalize] normalize = case-fold only (from trending.vibe) -->
```
````

- [ ] **Step 2: Self-review gate**

Confirm scope syntax is unambiguous and referenced consistently by `border.md`. The "language missing → BLOCK" matches `workflow.md` step 1. No placeholder.

- [ ] **Step 3: Commit**

```bash
git add skills/vibe-compiler/references/project-md.md
git commit -m "vbc: project.md template + premise/policy scope syntax"
```

---

## Task 6: Report format (`references/report-format.md`)

**Files:**
- Create: `skills/vibe-compiler/references/report-format.md`

Resolves spec §12 item 3.

- [ ] **Step 1: Write `report-format.md`**

````markdown
# Border report format

Written to `.vbc/reports/<command>-latest.md` each run.

```markdown
# vbc <validate|compile> report

## Summary
- files processed: 3 (cache, auth, trending)
- compiled: cache, auth          # compile only; omit on validate
- BLOCKED: trending               # → NOTHING written this run (atomic)
- counts: ASSUME 2 · BLOCK 1 · promotions 1

## BLOCKs (must resolve before code is produced)
- [trending.surprise] axis 1 — surprise(c,expected) underdetermined: ratio vs z-score vs KL.
  Resolve: specify in pseudo, or add a scoped policy.

## ASSUMEs (review)
- [cache.LruCache._dirty] flush-on-Evict assumed; change pseudo if undesired.

## Promotions (resolved under a declared assumption)
- [cache.LruCache.Get(K)] concurrency BLOCK→OK under premise "[scope: LruCache.*] single-threaded".
```

Rules: list every BLOCK with its axis and a concrete resolution hint; every ASSUME; and every
promotion (premise/policy) so BLOCK→OK is never invisible. On compile, the Summary MUST state
compiled-vs-blocked files and that a blocked run wrote nothing.
````

- [ ] **Step 2: Self-review gate**

Confirm the report surfaces promotions (D1), and compiled-vs-blocked (A1 atomicity). No placeholder.

- [ ] **Step 3: Commit**

```bash
git add skills/vibe-compiler/references/report-format.md
git commit -m "vbc: border report format"
```

---

## Task 7: Worked examples (`references/examples.md`)

**Files:**
- Create: `skills/vibe-compiler/references/examples.md`

Ports spec §7 verbatim (LRU, trending, validate-mismatch) including label tables and symbol-path tables. These are the few-shot anchors the skill leans on.

- [ ] **Step 1: Write `examples.md`** — copy the three worked examples from spec §7.1, §7.2, §7.3 (code blocks + label tables + symbol-path notes) into operational framing ("Given this pseudo, you should label / link as follows").

(Repeat the exact §7 content — do not summarize. The engineer copies the three fenced examples, both label tables, and both symbol-path notes from the spec file `docs/superpowers/specs/2026-06-06-vibe-compiler-design.md` §7.)

- [ ] **Step 2: Self-review gate**

Diff against spec §7 — examples must match exactly (same labels, same symbol-paths). No drift.

- [ ] **Step 3: Commit**

```bash
git add skills/vibe-compiler/references/examples.md
git commit -m "vbc: worked examples (LRU, trending, validate-mismatch)"
```

---

## Task 8: SKILL.md + command bodies

**Files:**
- Create: `skills/vibe-compiler/SKILL.md`
- Create: `commands/vbc-validate.md`, `commands/vbc-compile.md`, `commands/vbc-ingest.md`

- [ ] **Step 1: Write `SKILL.md`** (entry point; description = WHEN to use only, no workflow summary)

````markdown
---
name: vibe-compiler
description: Use when turning pseudo-code (vbc/*.vibe) into real product code, or when running /vbc-validate, /vbc-compile, or /vbc-ingest — enforces the explicit-vs-assumed border (OK/ASSUME/BLOCK)
---

# Vibe Compiler

Turn loose pseudo-code (`*.vibe`, natural language → near-real code) into real product code,
making every inference visible and refusing to silently guess anything critical.

## The spine
1. **Understand** — user writes `vbc/*.vibe` (optionally drafted via ingest).
2. **/vbc-validate <file|dir>** — read-only; link pseudo ↔ code, build the IR, classify the
   border, hard-halt on any BLOCK.
3. **/vbc-compile <file|dir>** — transactional; generate/patch code; any BLOCK → write nothing.

## Read before acting
- Classifying anything: **references/border.md** (OK/ASSUME/BLOCK axes + promotion safety).
- Linking / IR / symbol-path / drift: **references/ir-format.md**.
- Running a phase: **references/workflow.md** (validate/compile/ingest, atomic write, git).
- Project config & assumptions: **references/project-md.md**.
- Report layout: **references/report-format.md**.
- Worked examples: **references/examples.md**.

Never silently guess a critical decision: BLOCK and ask. Surface every ASSUME and every
premise-promotion in the report.
````

- [ ] **Step 2: Write the three command bodies** (thin; portable; `$ARGUMENTS`)

`commands/vbc-validate.md`:
```markdown
---
description: Validate vbc pseudo against the codebase (read-only) and build the IR
argument-hint: <file.vibe | dir>
---
Use the `vibe-compiler` skill. Run the **validate** phase (references/workflow.md) on: $ARGUMENTS
```

`commands/vbc-compile.md`:
```markdown
---
description: Compile vbc pseudo into real code (transactional; any BLOCK writes nothing)
argument-hint: <file.vibe | dir>
---
Use the `vibe-compiler` skill. Run the **compile** phase (references/workflow.md) on: $ARGUMENTS
```

`commands/vbc-ingest.md`:
```markdown
---
description: Draft vbc pseudo from existing code (optional helper)
argument-hint: <path>
---
Use the `vibe-compiler` skill. Run the **ingest** phase (references/workflow.md) on: $ARGUMENTS
```

- [ ] **Step 3: Self-review gate**

`SKILL.md` description states only WHEN to use (no workflow summary, per writing-skills CSO). Frontmatter `name` is hyphen-only. Command bodies are thin and use `$ARGUMENTS`. 

- [ ] **Step 4: Commit**

```bash
git add skills/vibe-compiler/SKILL.md commands/
git commit -m "vbc: SKILL.md entry point + thin command bodies"
```

---

## Task 9: GREEN verification — scenario batch (≤5 subagents)

**Files:** none modified (verification only). Creates throwaway fixtures under `/tmp`.

- [ ] **Step 1: Install locally**

```bash
./install.sh
```
Expected: symlinks reported for skill + 3 commands in both `~/.claude` and `~/.agents`/`~/.codex`.

- [ ] **Step 2: Build five fixtures** under `/tmp/vbc-verify/S{1..5}/` — each a tiny git repo with the pseudo (and, for S2/S4, seeded code) described in the "Testing approach" scenarios. (Greenfield S1: `cache.vibe`, no `project.md`. S2: code drops MRU. S3: 3 files, trending blocks. S4: linked symbol renamed. S5: the §7.1/§7.2 pseudo.)

- [ ] **Step 3: Run ONE batch of ≤5 subagents** (one per scenario), each given only the installed skill + its fixture, instructed to execute the relevant command and report what it did. Verify against expected:
  - S1 → BLOCK "target language undetermined"; with `project.md` added, generates + `NEW→LINKED`.
  - S2 → `DIVERGED` BLOCK; acknowledge path reaches `CHANGE_ACK` then compiles.
  - S3 → nothing written, prior state intact, report lists compiled-vs-blocked.
  - S4 → `RELINK_PENDING` + proposed re-link; no clobber.
  - S5 → labels + symbol-paths match spec §7 tables exactly.

- [ ] **Step 4: Triage & fix**

For any scenario that diverges, fix the responsible reference file and re-run ONLY that scenario (single subagent). Repeat until all five pass.

- [ ] **Step 5: Commit any fixes**

```bash
git add -A && git commit -m "vbc: fixes from GREEN scenario verification"
```

---

## Task 10: Finalize

- [ ] **Step 1:** Update `README.md` if any command/flag changed during verification.
- [ ] **Step 2:** Confirm `docs/superpowers/specs` §12 open items are now all resolved in references (IR schema → ir-format.md; project.md template + scope → project-md.md; report → report-format.md; threshold → ir-format.md). 
- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "vbc: finalize v1 (docs + open items closed)"
```

---

## Self-Review (author checklist — completed)

**Spec coverage:** §1 concept→SKILL.md/README; §2 border→border.md (Task 2); §3 two contexts→border.md/workflow.md; §4 phases + atomic + precondition + resolving-BLOCK→workflow.md (Task 4); §5 artifacts/IR→ir-format.md (Task 3) + project-md.md (Task 5) + report-format.md (Task 6); §6 drift/symbol-path/incremental/git→ir-format.md + workflow.md; §7 examples→examples.md (Task 7); §8 packaging→Task 1 + Task 8; §9 build order→task order; §10 YAGNI→not built (correct); §11 defaults→command names + markdown IR honored; §12 open items→Tasks 3/5/6 close them. No gap found.

**Placeholder scan:** Task 7 instructs copying §7 verbatim rather than inlining (acceptable — exact source cited); all other content tasks inline full artifact text. No "TBD/handle-edge-cases".

**Type consistency:** status set `{NEW, LINKED, DIVERGED, CHANGE_ACK, RELINK_PENDING}` (no UNVALIDATED) used identically in ir-format.md, workflow.md, report-format.md. symbol-path overload form `Type.Get(K)` consistent. Command names `vbc-validate/compile/ingest` consistent across install.sh, SKILL.md, command files.

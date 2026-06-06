# IR format & symbol-path

## Location

One IR file per pseudo file, mirroring the path:
`vbc/<name>.vibe` → `.vbc/ir/<name>.vibe.md`. Persistent, committed to the project's git.

## symbol-path — the identity key

`symbol-path` is the identity that both the build cache and drift detection compare, so it
**must** be derived deterministically — two agents must produce the same path for the same
construct.

- **Separator** `.` joins nesting; the path is rooted at the file's top-level scope.
- **Type/namespace members:** `Type.Member`; nested types nest: `Outer.Inner.M`.
- **Free / module-level functions:** `Module.func`, where `Module` is the module name (or the
  file stem in languages without modules).
- **Module-level statements** (e.g. a top-level driver loop): synthetic member
  `Module.__main__` (ordinal-suffixed if several: `__main__#2`).
- **Overloads:** the **full parameter-type signature, always** — `Type.Get(K)`,
  `Type.Get(K,V)`. Single canonical form; no arity-only `/1` form, no fallback chain.
- **Lambdas/closures:** anchor to the enclosing named symbol + ordinal — `Type.M.$lambda#1`.
- **One-to-many / many-to-one:** a pseudo element may link to a **set** of symbol-paths; store
  the set explicitly.
- **Fields declared in pseudo** are linkage targets (`Type.field`); **library calls** on them
  (`map.Find`, `lock`) are not.

## status — per element

- `NEW` — absent from the entire codebase → to-be-created.
- `LINKED` — validated against existing code.
- `DIVERGED` — validate BLOCK: pseudo contradicts the code.
- `CHANGE_ACK` — user-acknowledged intended change; compile may apply it.
- `RELINK_PENDING` — linked symbol gone after a rename/delete; awaiting confirmation.

There is **no `UNVALIDATED` status**: a never-validated element simply has **no IR entry**. A
`.vibe` edited since validation is detected by content-hash mismatch (below), not by a status.

### Transitions

- **validate** writes `LINKED` / `NEW` / `DIVERGED` per element, in one complete IR write.
- **compile success:** a generated `NEW` → `LINKED` (validated-at = the new commit);
  `CHANGE_ACK` → `LINKED`.
- **drift, symbol gone:** `LINKED`/`CHANGE_ACK` → `RELINK_PENDING` until the user confirms a
  re-link → `LINKED`.

## Drift & content hash

- Per-file `source-hash` = `git hash-object vbc/<name>.vibe` (hashes the **working tree**, so
  uncommitted edits are caught).
- Per-linkage `validated-at` = the HEAD commit at validation time.
- Drift check (read-only git on linked symbols) **notifies** when a linked symbol's body
  changed since `validated-at`, or it moved/renamed (→ `RELINK_PENDING`).
- **Re-link similarity threshold:** the best signature + normalized-body match score within
  the file must be ≥ 0.6 to *propose* that single match; if none reaches 0.6, or two or more
  tie, **BLOCK** and ask the user.

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
  - miss return -> BLOCK (axis 1: error semantics; pseudo=default(V), code=throws)
- resolved-by: -

## LruCache.Evict()
- targets: src/Cache.cs :: LruCache.Evict()
- status: LINKED
- labels:
  - body -> OK (LRU implied by name)
- resolved-by: -
```

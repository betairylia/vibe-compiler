# .vbc/project.md template

`project.md` makes the compiler language-neutral and carries project-wide Assumptions.

## Scope syntax

Each Premise/Policy line begins with `[scope: <glob>]`, where `<glob>` matches symbol-paths
(`*` within a path segment, `**` across segments). A premise/policy applies to a call only if
its scope glob matches that call's symbol-path. Examples:

- `[scope: **]` — the whole project.
- `[scope: LruCache.*]` — every member of `LruCache`.
- `[scope: trending.normalize]` — one symbol.

## Template

```markdown
# vbc project: <name>

## Target
- language: csharp            # REQUIRED; if missing and greenfield -> BLOCK
- source-root: src/
- layout: <Type>.cs, namespace mirrors folder path   # how NEW elements choose a file/path
- build: dotnet build
- test: dotnet test

## Conventions
- <free-text style notes the generator should follow>

## Assumptions

### Premises   (declared true; may promote BLOCK->OK; promotion still emits a surfaced note)
- [scope: **] all timestamps are UTC
- [scope: LruCache.*] single-threaded; no locking required

### Policies   (how to resolve recurring decisions; promote BLOCK->ASSUME)
- [scope: **] errors: throw; never silently swallow
- [scope: **] unset numeric config: BLOCK, do not default

### Ratified assumptions   (compiler-appended; user ratifies; compiler never edits Premises/Policies)
<!-- vbc appends dated proposals below, e.g.: -->
<!-- - [2026-06-06] [scope: trending.normalize] normalize = case-fold only (from trending.vibe) -->
```

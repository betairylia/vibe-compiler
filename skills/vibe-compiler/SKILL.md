---
name: vibe-compiler
description: Use when turning pseudo-code (vbc/*.vibe) into real product code, or when running /vbc-validate, /vbc-compile, or /vbc-ingest — enforces the explicit-vs-assumed border (OK/ASSUME/BLOCK)
---

# Vibe Compiler

Turn loose pseudo-code (`*.vibe`, natural language → near-real code) into real product code,
making every inference visible and refusing to silently guess anything critical.

## The spine

1. **Understand** — the user writes `vbc/*.vibe` (optionally drafted via ingest).
2. **/vbc-validate `<file|dir>`** — read-only; link pseudo ↔ code, build the IR, classify the
   border, hard-halt on any BLOCK.
3. **/vbc-compile `<file|dir>`** — transactional; generate/patch code; any BLOCK → write nothing.

## Read before acting

- Classifying anything → **references/border.md** (OK/ASSUME/BLOCK axes + promotion safety).
- Linking / IR / symbol-path / drift → **references/ir-format.md**.
- Running a phase → **references/workflow.md** (validate/compile/ingest, atomic write, git).
- Project config & assumptions → **references/project-md.md**.
- Report layout → **references/report-format.md**.
- Worked examples → **references/examples.md**.

## The one rule

Never silently guess a critical decision: **BLOCK and ask**. Surface every ASSUME and every
premise-promotion in the report. Compile is transactional — if any BLOCK exists, write nothing
and leave the previous successful state intact.

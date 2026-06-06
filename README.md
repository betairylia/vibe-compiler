# vibe-compiler (vbc)

A language-agnostic "compiler" that turns pseudo-code (`*.vibe`) into real product
code while making every inference visible (OK / ASSUME / BLOCK) and refusing to
silently guess anything critical. Works in Claude Code and Codex.

## Install

    ./install.sh

Links the skill into `~/.claude/skills` + `~/.agents/skills` and the commands into
`~/.claude/commands` + `~/.codex/prompts`.

## Use (inside a target project under git)

- Write pseudo in `vbc/`, configure `.vbc/project.md`.
- `/vbc-validate <file.vibe | dir>` — link pseudo ↔ code, build the IR (read-only).
- `/vbc-compile  <file.vibe | dir>` — generate/patch code (transactional: any BLOCK writes nothing).
- `/vbc-ingest   <path>` — draft pseudo from existing code (optional helper).

## Design

See `docs/superpowers/specs/2026-06-06-vibe-compiler-design.md` for the full design,
`docs/superpowers/reviews/` for the adversarial review, and
`docs/superpowers/plans/` for the implementation plan.

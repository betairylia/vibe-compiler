# vibe-compiler — repo context

This repo develops the `vibe-compiler` skill + slash commands. Canonical design:

- Spec: `docs/superpowers/specs/2026-06-06-vibe-compiler-design.md`
- Review: `docs/superpowers/reviews/2026-06-06-adversarial-spec-review.md`
- Plan: `docs/superpowers/plans/2026-06-06-vibe-compiler.md`

Skill source lives in `skills/vibe-compiler/`; commands in `commands/`.
Run `./install.sh` to link them into `~/.claude` and `~/.agents`/`~/.codex`.
Edit the source here, never the installed symlink targets.

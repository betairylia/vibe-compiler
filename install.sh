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

# Skill (folder) -> both agents
link "$REPO/skills/vibe-compiler" "$HOME/.claude/skills/vibe-compiler"
link "$REPO/skills/vibe-compiler" "$HOME/.agents/skills/vibe-compiler"

# Commands (files) -> Claude Code commands + Codex prompts
for c in vbc-validate vbc-compile vbc-ingest; do
  link "$REPO/commands/$c.md" "$HOME/.claude/commands/$c.md"
  link "$REPO/commands/$c.md" "$HOME/.codex/prompts/$c.md"
done

echo "vbc installed."

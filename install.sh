#!/usr/bin/env bash
# Link the spec workflow skills into ~/.claude/skills.
# Windows (Git Bash): directory junctions. Other systems: symlinks.
# An existing entry is not replaced: remove it first.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
DEST="$HOME/.claude/skills"
mkdir -p "$DEST"

for s in spec-align spec-impl; do
  src="$REPO/skills/$s"
  dst="$DEST/$s"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    echo "skip $dst: it exists"
    continue
  fi
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) MSYS2_ARG_CONV_EXCL='*' cmd /c mklink /J "$(cygpath -w "$dst")" "$(cygpath -w "$src")" > /dev/null ;;
    *) ln -s "$src" "$dst" ;;
  esac
  echo "linked $dst -> $src"
done

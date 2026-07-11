#!/usr/bin/env bash
# install.sh — one-shot installer for the MariaDB Cloud skill.
#
# The `npx skills add` CLI currently installs only SKILL.md and does not copy
# the references/ folder that the skill relies on. This script installs the
# complete skill (SKILL.md + references/) into the correct on-disk path for
# each target agent, so the manual `git clone && cp -r references/ ...` step
# is not needed.
#
# Usage:
#   scripts/install.sh                     # install for all detected agents
#   scripts/install.sh claude              # ~/.claude/skills/mariadb-cloud
#   scripts/install.sh agents              # ~/.agents/skills/mariadb-cloud (Cursor/Codex/Windsurf/Devin/...)
#   scripts/install.sh claude agents       # both
#
# Environment overrides:
#   CLAUDE_SKILLS_DIR   default: $HOME/.claude/skills
#   AGENTS_SKILLS_DIR   default: $HOME/.agents/skills
#   SKILL_NAME          default: mariadb-cloud

set -euo pipefail

SKILL_NAME="${SKILL_NAME:-mariadb-cloud}"
CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
AGENTS_SKILLS_DIR="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ ! -f "$SRC_DIR/SKILL.md" || ! -d "$SRC_DIR/references" ]]; then
  echo "error: expected SKILL.md and references/ under $SRC_DIR" >&2
  exit 1
fi

install_into() {
  local target_root="$1"
  local dest="$target_root/$SKILL_NAME"
  mkdir -p "$dest"
  cp "$SRC_DIR/SKILL.md" "$dest/"
  rm -rf "$dest/references"
  cp -R "$SRC_DIR/references" "$dest/"
  echo "installed: $dest"
}

targets=("$@")
if [[ ${#targets[@]} -eq 0 ]]; then
  targets=(claude agents)
fi

for t in "${targets[@]}"; do
  case "$t" in
    claude) install_into "$CLAUDE_SKILLS_DIR" ;;
    agents) install_into "$AGENTS_SKILLS_DIR" ;;
    *)      echo "unknown target: $t (expected 'claude' or 'agents')" >&2; exit 2 ;;
  esac
done

echo "done. Restart Claude Desktop if you installed for 'claude'."

#!/usr/bin/env bash
# PostToolUse:ExitPlanMode — copy the plan Claude Code just wrote into the Obsidian vault.
#
# ExitPlanMode carries no plan text: Claude Code writes the plan to a file in
# ~/.claude/plans/ first, then calls the tool. So this takes the newest file there.
# Never fails the session — every path exits 0.
set -uo pipefail

PLANS_SRC=${CLAUDE_PLANS_DIR:-$HOME/.claude/plans}
PLANS_DEST=${VAULT_PLANS_DIR:-$HOME/Notes/Plans}

payload=$(cat 2>/dev/null)
field() { printf '%s' "$payload" | jq -r "$1 // empty" 2>/dev/null; }

src=$(ls -t "$PLANS_SRC"/*.md 2>/dev/null | head -1)
[ -n "$src" ] || exit 0
[ -d "$PLANS_DEST" ] || exit 0

cwd=$(field .cwd); [ -n "$cwd" ] || cwd=$PWD
session=$(field .session_id)
repo=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null); repo=${repo##*/}
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)

title=$(grep -m1 '^# ' "$src" 2>/dev/null | sed 's/^#* *//')
[ -n "$title" ] || title=$(basename "$src" .md)
# filenames Obsidian and macOS both tolerate
safe=$(printf '%s' "$title" | tr '/:|#^[]' '-')
if [ ${#safe} -gt 70 ]; then safe=$(printf '%s' "${safe:0:70}" | sed 's/ [^ ]*$//'); fi
safe=$(printf '%s' "$safe" | sed 's/ *$//')

dest="$PLANS_DEST/$(date +%F) $safe.md"
n=2
while [ -e "$dest" ] && ! grep -qxF "source: $src" "$dest" 2>/dev/null; do
  dest="$PLANS_DEST/$(date +%F) $safe $n.md"
  n=$((n + 1))
done

{
  echo '---'
  echo "created: $(date '+%Y-%m-%d %H:%M')"
  [ -n "$repo" ] && echo "repo: $repo"
  [ -n "$branch" ] && echo "branch: $branch"
  echo "cwd: $cwd"
  [ -n "$session" ] && echo "session: $session"
  echo "source: $src"
  echo 'tags:'
  echo '  - plan'
  echo '---'
  echo
  cat "$src"
} > "$dest" 2>/dev/null || exit 0

# link it from today's Notes section — best effort, a missing day section is not an error here
daily_note=${DAILY_NOTE_SH:-$HOME/.claude/skills/obsidian/scripts/daily-note.sh}
name=$(basename "$dest" .md)
linked=""
if [ -x "$daily_note" ] && ! "$daily_note" list Notes 2>/dev/null | grep -qF "[[$name]]"; then
  "$daily_note" append Notes "[[$name]]" >/dev/null 2>&1 && linked=" and linked in today's note"
fi

jq -n --arg p "${dest/#$HOME/~}" --arg l "$linked" \
  '{systemMessage: ("Plan saved to " + $p + $l), suppressOutput: true}' 2>/dev/null
exit 0

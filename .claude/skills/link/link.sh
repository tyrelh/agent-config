#!/bin/sh
# Links every skill directory from skills/ into ~/.claude/skills.
# Re-run after adding or removing a skill.
set -eu

REPO=$(cd "$(dirname "$0")/../../.." && pwd)
DEST=${1:-$HOME/.claude/skills}

# The dest used to be a symlink to a single source dir; replace it with a real one.
[ -L "$DEST" ] && rm "$DEST"
mkdir -p "$DEST"

# Drop links we own that no longer resolve, so a deleted skill doesn't linger.
for link in "$DEST"/*; do
	case $(readlink "$link" 2>/dev/null || echo) in
		"$REPO"/*) [ -d "$link" ] || rm "$link" ;;
	esac
done

for src in "$REPO"/skills/*/; do
	[ -d "$src" ] || continue
	name=$(basename "$src")
	link=$DEST/$name
	target=${src%/}
	if [ -e "$link" ] && [ ! -L "$link" ]; then
		echo "skip $name: $link exists and is not a symlink" >&2
		continue
	fi
	current=$(readlink "$link" 2>/dev/null || echo)
	[ "$current" = "$target" ] && continue
	case $current in
		"") ;;
		"$REPO"/*) ;;                       # ours, safe to repoint
		*) echo "skip $name: linked outside the repo, to $current" >&2; continue ;;
	esac
	ln -sfn "$target" "$link"
	echo "linked $name -> $target"
done

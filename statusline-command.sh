#!/bin/sh
# Claude Code statusLine: model name + context usage progress bar

input=$(cat)

model=$(printf '%s' "$input" | jq -r '.model.display_name')
model=${model% (*)}  # drop trailing variant suffix, e.g. " (1M context)"
used=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')
# effort absent when model doesn't support the reasoning effort param
effort=$(printf '%s' "$input" | jq -r '.effort.level // empty')
[ -n "$effort" ] && effort=" $effort"

# Plugin mode badges (caveman, ponytail). Each script prints a bare badge or
# nothing if its flag file is absent. ponytail: hardcoded plugin paths, revisit
# if plugins move out of marketplaces/.
plugins="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/marketplaces"
badges=""
for p in caveman ponytail; do
  s="$plugins/$p/hooks/$p-statusline.sh"
  [ -f "$s" ] || continue
  b=$(bash "$s" </dev/null 2>/dev/null)
  [ -n "$b" ] && badges="${badges} ${b}"
done

width=10

if [ -n "$used" ]; then
  filled=$(awk -v u="$used" -v w="$width" 'BEGIN{v=int(u/100*w+0.5); if(v>w)v=w; if(v<0)v=0; printf "%d", v}')
  pct=$(printf '%.0f' "$used")
else
  filled=0
  pct=0
fi
empty=$((width - filled))

bar=""
if [ "$filled" -gt 0 ]; then
  bar=$(printf '%0.s█' $(seq 1 "$filled"))
fi
if [ "$empty" -gt 0 ]; then
  bar="${bar}$(printf '%0.s░' $(seq 1 "$empty"))"
fi

if [ "$pct" -ge 90 ]; then
  color=$(printf '\033[31m')
elif [ "$pct" -ge 70 ]; then
  color=$(printf '\033[33m')
else
  color=$(printf '\033[32m')
fi
dim=$(printf '\033[2m')
reset=$(printf '\033[0m')

printf '%s\n' "${dim}${model}${effort}${reset} ${color}[${bar}]${reset} ${dim}${pct}%${reset}${badges}"

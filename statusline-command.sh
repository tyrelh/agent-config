#!/bin/sh
# Claude Code statusLine: model name + context usage progress bar

input=$(cat)

model=$(printf '%s' "$input" | jq -r '.model.display_name')
used=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')

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

printf '%s\n' "${dim}${model}${reset} ${color}[${bar}]${reset} ${dim}${pct}%${reset}"

#!/bin/sh
# Claude Code statusLine: model, effort, context + rate-limit meters, plugin badges

input=$(cat)

model=$(printf '%s' "$input" | jq -r '.model.display_name // empty')
model=${model% (*)}  # drop trailing variant suffix, e.g. " (1M context)"
# effort absent when model doesn't support the reasoning effort param
effort=$(printf '%s' "$input" | jq -r '.effort.level // empty')
[ -n "$effort" ] && effort=" $effort"

# rate_limits absent on API-key/Bedrock accounts; empty => meter not rendered
eval "$(printf '%s' "$input" | jq -r '
  "used=\(.context_window.used_percentage // "")
   five=\(.rate_limits.five_hour.used_percentage // "")
   five_at=\(.rate_limits.five_hour.resets_at // "")
   seven=\(.rate_limits.seven_day.used_percentage // "")
   seven_at=\(.rate_limits.seven_day.resets_at // "")"')"

esc=$(printf '\033')
dim="${esc}[2m"
reset="${esc}[0m"
purple="${esc}[38;5;141m"
sep="${dim} · ${reset}"

# bar PCT WIDTH [BASECOLOR] -> "[████░░] 37%". Warn thresholds always
# override the base colour, so a recoloured bar keeps its yellow at 70% and
# its red at 90%. Default base colour is green.
bar() {
  _w=$2
  _f=$(awk -v u="$1" -v w="$_w" 'BEGIN{v=int(u/100*w+0.5); if(v>w)v=w; if(v<0)v=0; printf "%d", v}')
  _e=$((_w - _f))
  _pct=$(printf '%.0f' "$1")
  _bar=""
  [ "$_f" -gt 0 ] && _bar=$(printf '%0.s█' $(seq 1 "$_f"))
  [ "$_e" -gt 0 ] && _bar="${_bar}$(printf '%0.s░' $(seq 1 "$_e"))"
  if [ "$_pct" -ge 90 ]; then _c="${esc}[31m"
  elif [ "$_pct" -ge 70 ]; then _c="${esc}[33m"
  else _c="${3:-${esc}[32m}"; fi
  # a bar with its own base colour tints the percentage to match, dimmed; the plain
  # green meters keep a dim percentage so they stay visually secondary
  _p="${3:+$dim$_c}"
  printf '%s[%s]%s %s%s%%%s' "$_c" "$_bar" "$reset" "${_p:-$dim}" "$_pct" "$reset"
}

# countdown EPOCH -> "3d4h" / "2h14m" / "12m"; empty once elapsed
countdown() {
  _r=$(( $1 - $(date +%s) ))
  [ "$_r" -le 0 ] && return
  _h=$((_r / 3600))
  _m=$(((_r % 3600) / 60))
  if [ "$_h" -ge 24 ]; then printf '%dd%dh' $((_h / 24)) $((_h % 24))
  elif [ "$_h" -gt 0 ]; then printf '%dh%dm' "$_h" "$_m"
  else printf '%dm' "$_m"; fi
}

# meter LABEL PCT WIDTH RESETS_AT -> " 5h [██░░░░] 23% 1h12m", nothing if pct empty
meter() {
  [ -n "$2" ] || return
  printf '%s%s%s%s %s' "$sep" "$dim" "$1" "$reset" "$(bar "$2" "$3")"
  if [ -n "$4" ]; then
    _cd=$(countdown "$4")
    [ -n "$_cd" ] && printf ' %s%s%s' "$dim" "$_cd" "$reset"
  fi
}

# Plugin mode badges, read straight from the flag files the caveman/ponytail
# hooks write, so the label stays compact. Refuse symlinks and strip to
# [a-z0-9-] like the upstream scripts do: the flag content is rendered to the
# terminal, so unfiltered bytes would allow ANSI-escape injection.
badges=""
badge() {  # NAME SHORT COLOR
  _f="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.$1-active"
  { [ -f "$_f" ] && [ ! -L "$_f" ]; } || return
  _m=$(head -c 64 "$_f" 2>/dev/null | tr -d '\n\r' | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')
  case "$_m" in
    ''|off) return ;;
    full) _l="$2" ;;
    *) _l="$2:$_m" ;;
  esac
  badges="${badges}${badges:+ }${esc}[38;5;${3}m[${_l}]${reset}"
}
badge caveman CM 172
badge ponytail PT 108

printf '%s%s%s%s%s%s%s' "$purple" "$model" "$dim" "$effort" "$reset" "$sep" "$(bar "${used:-0}" 10 "$purple")"
meter 5h "$five" 6 "$five_at"
meter 7d "$seven" 6 "$seven_at"
printf '%s\n' "${badges:+$sep$badges}"

#!/bin/sh
# Claude Code statusLine
#   line 1: project, branch, dirty count, PR       ...  plugin badges
#   line 2: model, effort, context meter            ...  rate-limit meters

# Segment toggles. 1 shows the segment, anything else hides it. A hidden
# segment costs nothing: its data is never fetched and its separator never
# rendered. Hide every segment on a line and the line itself disappears.
SHOW_PROJECT=1        # project name, git branch, dirty file count
SHOW_PR=1             # PR number and review state
SHOW_DIFF=1           # lines added / removed this session
SHOW_MODEL=1          # model name and effort level
SHOW_CONTEXT=1        # context window meter and percentage
SHOW_SESSION_LIMIT=1  # 5-hour rate limit meter
SHOW_WEEKLY_LIMIT=1   # 7-day rate limit meter
SHOW_MODES=1          # thinking / fast mode badges
SHOW_PLUGINS=1        # caveman / ponytail mode badges

# Progress bar style.
#   RIGHT_MARGIN columns held back from COLUMNS when right-aligning. The
#     statusline row is indented and reserves trailing columns, so filling the
#     full width makes the renderer truncate the tail with an ellipsis. Raise
#     it if the badges get clipped, lower it if they sit too far in.
#   BAR_WIDTH cells per bar, all three meters share it
#   BAR_CAPS  1 wraps each bar in [ ], 0 renders it bare
#   BAR_STYLE block   ████░░░░░░
#             braille ⣿⣿⣿⣿⣀⣀⣀⣀⣀⣀
#             pips    ▰▰▱▱▱
#             dash    ▰▰▰----
#             shade   ▓▓▓▓▒▒▒▒▒▒
#             circles ●●●●○○○○○○
RIGHT_MARGIN=6
BAR_WIDTH=5
BAR_CAPS=0
BAR_STYLE=braille

input=$(cat)

# rate_limits absent on API-key/Bedrock accounts, pr absent outside a repo or
# until one is found; empty => that segment isn't rendered. @sh quotes every
# value, so a path or URL holding shell metacharacters can't break the eval.
eval "$(printf '%s' "$input" | jq -r '@sh "
  model=\(.model.display_name // "")
  effort=\(.effort.level // "")
  used=\(.context_window.used_percentage // "")
  ctx_size=\(.context_window.context_window_size // "")
  five=\(.rate_limits.five_hour.used_percentage // "")
  five_at=\(.rate_limits.five_hour.resets_at // "")
  seven=\(.rate_limits.seven_day.used_percentage // "")
  seven_at=\(.rate_limits.seven_day.resets_at // "")
  cwd=\(.workspace.current_dir // .cwd // "")
  repo=\(.workspace.repo.name // "")
  proj=\(.workspace.project_dir // .cwd // "")
  pr_num=\(.pr.number // "")
  pr_state=\(.pr.review_state // "")
  pr_url=\(.pr.url // "")
  add=\(.cost.total_lines_added // "")
  del=\(.cost.total_lines_removed // "")
  thinking=\(.thinking.enabled // "")
  fast=\(.fast_mode // "")"')"

esc=$(printf '\033')
dim="${esc}[2m"
reset="${esc}[0m"
purple="${esc}[38;5;141m"
green="${esc}[32m"
cyan="${esc}[36m"
sep="${dim} · ${reset}"

case "$BAR_STYLE" in
  block) bar_fill="█" bar_empty="░" ;;
  pips)  bar_fill="▰" bar_empty="▱" ;;
  dash)  bar_fill="▰" bar_empty="-" ;;
  shade) bar_fill="▓" bar_empty="▒" ;;
  circles) bar_fill="●" bar_empty="○" ;;
  *)     bar_fill="⣿" bar_empty="⣀" ;;  # braille, the default
esac
[ "$BAR_CAPS" = 1 ] && { cap_l="["; cap_r="]"; } || { cap_l=""; cap_r=""; }

# vislen TEXT — printable width, ignoring SGR colours and OSC 8 hyperlinks.
# wc -m counts characters rather than bytes, which matches cells for the block,
# braille and box-drawing glyphs here; emoji or CJK would measure short.
vislen() {
  printf '%s' "$1" | sed -e "s/${esc}\[[0-9;]*m//g" -e "s/${esc}]8;;[^${esc}]*${esc}\\\\//g" | wc -m
}

# push SEGMENT — append to $acc, inserting a separator only between segments
# that actually rendered, so toggles never leave a stray delimiter behind.
push() {
  [ -n "$1" ] || return
  acc="${acc}${acc:+$sep}$1"
}

# emit LEFT RIGHT — one line with RIGHT flush to the terminal edge. The gap
# separates the two groups, so neither needs a trailing "·". Prints nothing
# when both are empty.
emit() {
  if [ -n "$2" ]; then
    _pad=$(( ${COLUMNS:-80} - RIGHT_MARGIN - $(vislen "$1") - $(vislen "$2") ))
    [ "$_pad" -lt 1 ] && _pad=1
    printf '%s%*s%s\n' "$1" "$_pad" "" "$2"
  elif [ -n "$1" ]; then
    printf '%s\n' "$1"
  fi
}

# bar PCT WIDTH [BASECOLOR] -> "[⣿⣿⣿⣿⣀⣀] 37%", glyphs and caps per
# BAR_STYLE / BAR_CAPS. Warn thresholds always
# override the base colour, so a recoloured bar keeps its yellow at 70% and
# its red at 90%. Default base colour is green.
bar() {
  _w=$2
  _f=$(awk -v u="$1" -v w="$_w" 'BEGIN{v=int(u/100*w+0.5); if(v>w)v=w; if(v<0)v=0; printf "%d", v}')
  _e=$((_w - _f))
  _pct=$(printf '%.0f' "$1")
  _bar=""
  [ "$_f" -gt 0 ] && _bar=$(printf "%0.s$bar_fill" $(seq 1 "$_f"))
  [ "$_e" -gt 0 ] && _bar="${_bar}$(printf "%0.s$bar_empty" $(seq 1 "$_e"))"
  if [ "$_pct" -ge 90 ]; then _c="${esc}[31m"
  elif [ "$_pct" -ge 70 ]; then _c="${esc}[33m"
  else _c="${3:-$green}"; fi
  # a bar with its own base colour tints the percentage to match, dimmed; the plain
  # green meters keep a dim percentage so they stay visually secondary
  _p="${3:+$dim$_c}"
  printf '%s%s%s%s%s %s%s%%%s' "$_c" "$cap_l" "$_bar" "$cap_r" "$reset" "${_p:-$dim}" "$_pct" "$reset"
}

# tokens N -> "1M" / "1.5M" / "200k"; empty when the size is unknown
tokens() {
  [ -n "$1" ] || return
  if [ "$1" -ge 1000000 ]; then
    _t=$(( $1 % 1000000 / 100000 ))
    if [ "$_t" -gt 0 ]; then printf '%d.%dM' $(( $1 / 1000000 )) "$_t"
    else printf '%dM' $(( $1 / 1000000 )); fi
  else
    printf '%dk' $(( $1 / 1000 ))
  fi
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

# meter LABEL PCT WIDTH RESETS_AT -> "5h [⣿⣿⣀⣀⣀⣀] 23% 1h12m", nothing if pct empty
meter() {
  [ -n "$2" ] || return
  # passing a base colour tints the percentage to match the label; the warn
  # thresholds still override the bar itself at 70% and 90%
  printf '%s%s%s %s' "$cyan" "$1" "$reset" "$(bar "$2" "$3" "$cyan")"
  if [ -n "$4" ]; then
    _cd=$(countdown "$4")
    [ -n "$_cd" ] && printf ' %s%s(%s)%s' "$dim" "$cyan" "$_cd" "$reset"
  fi
}

# flag LABEL COLOR — append a bare badge to the right-hand group
flag() {
  badges="${badges}${badges:+ }${esc}[38;5;${2}m[${1}]${reset}"
}

# badge NAME SHORT COLOR — read the flag files the caveman/ponytail hooks
# write, so the label stays compact. Refuse symlinks and strip to [a-z0-9-]
# like the upstream scripts do: the flag content is rendered to the terminal,
# so unfiltered bytes would allow ANSI-escape injection.
badges=""
badge() {
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

# Line 1: project, branch, dirty count, PR
acc=""
if [ "$SHOW_PROJECT" = 1 ]; then
  # The only shelling out this script does — neither branch nor dirty state is
  # in the statusline JSON. One `status --porcelain --branch` call covers both:
  # line 1 is the branch header, the rest are changed files. The header reads
  # "## HEAD (no branch)" on a detached HEAD, and origin's name only appears
  # after "...".
  branch=""
  dirty=0
  if [ -n "$cwd" ]; then
    _st=$(git -C "$cwd" status --porcelain --branch 2>/dev/null)
    if [ -n "$_st" ]; then
      _hdr=${_st%%"
"*}
      branch=${_hdr#\#\# }
      branch=${branch%%...*}
      case "$branch" in *"no branch"*) branch="" ;; esac
      dirty=$(($(printf '%s\n' "$_st" | wc -l) - 1))
    fi
  fi
  # repo name when there's an origin remote, else the launch directory's name
  project="${repo:-${proj##*/}}"
  # project and branch join with a slash into one segment — a path-like pair
  # reads differently from the "·" that divides unrelated segments
  _pb="${project:+${esc}[1m${project}${reset}}"
  [ -n "$branch" ] && _pb="${_pb}${_pb:+${dim}/${reset}}${cyan}${branch}${reset}"
  push "$_pb"
  [ "$dirty" -gt 0 ] && push "${esc}[33m*${dirty}${reset}"
fi

if [ "$SHOW_PR" = 1 ] && [ -n "$pr_num" ]; then
  case "$pr_state" in
    approved) _pc="${esc}[32m" ;;
    changes_requested) _pc="${esc}[31m" ;;
    pending) _pc="${esc}[33m" ;;
    *) _pc="$dim" ;;
  esac
  # OSC 8 makes the number clickable in iTerm2, Kitty, and WezTerm
  _n="#${pr_num}"
  [ -n "$pr_url" ] && _n="${esc}]8;;${pr_url}${esc}\\${_n}${esc}]8;;${esc}\\"
  push "${_pc}${_n}${reset}${pr_state:+ ${dim}${pr_state}${reset}}"
fi
# Lines added and removed by this session, not the working tree diff — the
# dirty count above already covers uncommitted files.
if [ "$SHOW_DIFF" = 1 ] && [ "${add:-0}${del:-0}" != "00" ]; then
  _d=""
  [ "${add:-0}" -gt 0 ] && _d="${green}+${add}${reset}"
  [ "${del:-0}" -gt 0 ] && _d="${_d}${_d:+ }${esc}[31m-${del}${reset}"
  push "$_d"
fi
left=$acc

if [ "$SHOW_MODES" = 1 ]; then
  [ "$fast" = true ] && flag FAST 203
  [ "$thinking" = true ] && flag THINK 147
fi
if [ "$SHOW_PLUGINS" = 1 ]; then
  badge caveman CAVE 172
  badge ponytail PONY 108
fi
emit "$left" "$badges"

# Line 2: model and context on the left, rate-limit meters on the right
acc=""
if [ "$SHOW_MODEL" = 1 ] && [ -n "$model" ]; then
  model=${model% (*)}  # drop trailing variant suffix, e.g. " (1M context)"
  # effort absent when the model doesn't support the reasoning effort param
  push "${purple}${model}${dim}${effort:+ $effort}${reset}"
fi
if [ "$SHOW_CONTEXT" = 1 ]; then
  _cs=$(tokens "$ctx_size")
  push "${_cs:+${dim}${purple}${_cs}${reset} }$(bar "${used:-0}" "$BAR_WIDTH" "$purple")"
fi
left=$acc

acc=""
[ "$SHOW_SESSION_LIMIT" = 1 ] && push "$(meter 5h "$five" "$BAR_WIDTH" "$five_at")"
[ "$SHOW_WEEKLY_LIMIT" = 1 ] && push "$(meter 7d "$seven" "$BAR_WIDTH" "$seven_at")"
emit "$left" "$acc"

exit 0  # an empty line 2 must not look like a failed statusline

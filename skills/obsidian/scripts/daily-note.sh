#!/usr/bin/env bash
# Read or edit one H2 section inside today's H1 in the current term log note.
# Edits the markdown file on disk directly. See ../SKILL.md for the vault layout.
set -euo pipefail

usage() {
  cat <<'USAGE'
usage:
  daily-note.sh list   <section>                print the section's lines
  daily-note.sh add    <section> <text>         insert at the TOP of the section
  daily-note.sh append <section> <text>         insert at the BOTTOM of the section
  daily-note.sh done   <section> <substring>    check off first open task matching substring

sections are H2 headings inside today's H1, e.g. Tasks, Notes, Meetings, Personal.

env:
  NOTES=~/Notes            vault root
  TODO_DAY="Thu Sep 3"     target another day's section (default: today)
USAGE
  exit 2
}

[ $# -ge 2 ] || usage
mode=$1 section=$2; shift 2

notes=${NOTES:-$HOME/Notes}
day=${TODO_DAY:-$(date +'%a %b %-d')}   # matches the H1 format: "# Fri Sep 4"

shopt -s nullglob
files=("$notes"/inbox/*now*.md)
if [ ${#files[@]} -ne 1 ]; then
  echo "ERR: expected exactly one '*now*.md' note in $notes/inbox, found ${#files[@]}" >&2
  exit 1
fi
file=${files[0]}

run_awk() {
  awk -v mode="$mode" -v day="# $day" -v section="$section" -v arg="${1-}" '
    { L[NR] = $0 }
    END {
      dayre = "^" day "([^0-9]|$)"
      secre = "^##[[:space:]]+" section "[[:space:]]*$"
      for (i = 1; i <= NR; i++) if (L[i] ~ dayre) { start = i; break }
      if (!start) exit 3
      end = NR + 1
      for (i = start + 1; i <= NR; i++) if (L[i] ~ /^# /) { end = i; break }
      for (i = start + 1; i < end; i++) if (L[i] ~ secre) { sec = i; break }
      if (!sec) exit 4

      stop = end                                   # first line past the section body
      for (i = sec + 1; i < end; i++) if (L[i] ~ /^#/) { stop = i; break }
      last = sec
      for (i = sec + 1; i < stop; i++) if (L[i] ~ /[^[:space:]]/) last = i

      if (mode == "list") {
        for (i = sec + 1; i < stop; i++) print L[i]
        exit 0
      }
      if (mode == "add") at = sec
      else if (mode == "append") at = last
      else if (mode == "done") {
        for (i = sec + 1; i < stop; i++)
          if (L[i] ~ /^[[:space:]]*-[[:space:]]*\[ \]/ && index(tolower(L[i]), tolower(arg))) { hit = i; break }
        if (!hit) exit 5
        sub(/\[ \]/, "[x]", L[hit])
      }
      for (i = 1; i <= NR; i++) {
        print L[i]
        if (at && i == at) print arg
      }
    }
  ' "$file"
}

fail() {
  case $1 in
    3) echo "ERR: no '# $day' heading in $file — insert the daily note template first" >&2 ;;
    4) echo "ERR: no '## $section' heading under '# $day' in $file" >&2 ;;
    5) echo "ERR: no open task under '## $section' matching \"${2-}\"" >&2 ;;
    *) echo "ERR: awk failed (rc=$1)" >&2 ;;
  esac
  exit 1
}

case "$mode" in
  list)
    run_awk || fail $?
    ;;
  add|append|done)
    [ $# -ge 1 ] || usage
    text=$*
    if [ "$mode" != done ] && [ "$section" = Tasks ]; then
      case "$text" in -\ \[*|-\[*) ;; *) text="- [ ] $text" ;; esac
    fi
    tmp=$(mktemp)
    if run_awk "$text" > "$tmp"; then
      cat "$tmp" > "$file"   # write in place so Obsidian sees a modification, not a replacement
      rm -f "$tmp"
      case "$mode" in
        done) echo "done in ${file/#$HOME/~} # $day: $text" ;;
        *) echo "added to ${file/#$HOME/~} # $day / $section: $text" ;;
      esac
    else
      rc=$?
      rm -f "$tmp"
      fail $rc "$text"
    fi
    ;;
  *) usage ;;
esac

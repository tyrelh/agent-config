#!/bin/sh
# Colour reference for statusline-command.sh. Run it in the terminal that
# renders the statusline — the swatches only mean anything there.
e=$(printf '\033')

echo "== basic 30-37 / bright 90-97 (follow the terminal theme) =="
for c in 30 31 32 33 34 35 36 37; do printf "%s[%sm %s ██ %s" "$e" "$c" "$c" "$e[0m"; done; echo
for c in 90 91 92 93 94 95 96 97; do printf "%s[%sm %s ██ %s" "$e" "$c" "$c" "$e[0m"; done; echo
echo
echo "== attributes =="
printf "%s[1mbold%s  %s[2mdim%s  %s[3mitalic%s  %s[4munderline%s  %s[7mreverse%s\n" \
  "$e" "$e[0m" "$e" "$e[0m" "$e" "$e[0m" "$e" "$e[0m" "$e" "$e[0m"
echo
echo "== 256-colour cube: 38;5;N =="
n=0
while [ $n -lt 256 ]; do
  printf "%s[38;5;%sm%3s%s " "$e" "$n" "$n" "$e[0m"
  n=$((n+1))
  [ $((n % 16)) -eq 0 ] && echo
done
echo
echo "== truecolor: 38;2;R;G;B =="
printf "%s[38;2;235;110;70mEB6E46%s  %s[38;2;120;200;255m78C8FF%s  %s[38;2;180;140;255mB48CFF%s\n" \
  "$e" "$e[0m" "$e" "$e[0m" "$e" "$e[0m"
echo

# Keep in sync with statusline-command.sh when a colour changes there.
echo "== in use by statusline-command.sh =="
swatch() { printf "%s%s%-22s%s %s\n" "$e" "[$1m" "$1" "$e[0m" "$2"; }
swatch "1;38;5;105" "project name (bold)"
swatch "33"        "dirty file count, bar 70% warn"
swatch "32"        "lines added, cost, bar default fill"
swatch "31"        "lines removed, PR changes_requested"
swatch "38;5;203"  "bar 90% warn, FAST badge"
swatch "38;5;105"  "project name, model + effort, context meter, 5h/7d labels, rate bars, countdowns"
swatch "38;5;37"   "git branch"
swatch "38;5;213"  "CAVE badge"
swatch "38;5;39"   "PONY badge"
swatch "2"         "dim: separators, percentages, effort, countdowns"

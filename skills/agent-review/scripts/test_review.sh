#!/bin/bash
# Run with /bin/bash to exercise macOS's Bash 3.2. No live model calls.
set -eu
set -o pipefail
script_dir=$(cd "$(dirname "$0")" && pwd -P)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/agent-review-test.XXXXXX")
trap 'rm -rf "$scratch"' EXIT
mkdir "$scratch/bin" "$scratch/repo with spaces"
printf '%s\n' 'unique diff content' > "$scratch/review.diff"
printf '%s\n' 'unique review constraint' > "$scratch/brief.md"

cat > "$scratch/bin/codex" <<'FAKE'
#!/bin/bash
set -eu
if [ "${1:-}" = debug ]; then
    case ${FAKE_MODE:-ok} in
        catalog_failed) exit 2 ;;
        catalog_invalid) printf '%s\n' '{bad'; exit 0 ;;
        catalog_missing) printf '%s\n' '{"models":[]}'; exit 0 ;;
    esac
    printf '%s\n' '{"models":[
      {"slug":"gpt-6-sol","visibility":"list"},
      {"slug":"gpt-6.10-sol","visibility":"list"},
      {"slug":"gpt-6.2-sol","visibility":"list"},
      {"slug":"gpt-7-sol","visibility":"hide"},
      {"slug":"gpt-8-sol-preview","visibility":"list"},
      {"slug":"gpt-6-luna","visibility":"list"},
      {"slug":"gpt-6-astra","visibility":"list"},
      {"slug":"gpt-5.6-terra","visibility":"list"}]}'
    exit 0
fi
prompt=$(cat)
case $prompt in *'unique review constraint'*'unique diff content'*) ;; *) exit 90 ;; esac
[ -z "${CLAUDECODE+x}" ] || exit 91
case ${FAKE_MODE:-ok} in
    timeout)
        # This child must be stopped too; it tries to leave evidence after timeout.
        (sleep 3; touch "$TEST_MARKER") &
        wait
        exit 0 ;;
    failed) printf '%s\n' 'model unavailable' >&2; exit 2 ;;
esac
if [ "$(basename "$0")" = codex ]; then
    report= sandbox= hooks= agents=
    while [ "$#" -gt 0 ]; do
        case $1 in
            --output-last-message) report=$2; shift ;;
            --sandbox) sandbox=$2; shift ;;
            --disable) case $2 in hooks) hooks=yes ;; multi_agent) agents=yes ;; esac; shift ;;
        esac
        shift
    done
    [ "$sandbox" = read-only ] && [ "$hooks" = yes ] && [ "$agents" = yes ] || exit 92
    [ "${FAKE_MODE:-ok}" = empty ] || printf '%s\n' 'candidate report' > "$report"
    printf '%s\n' '{"type":"turn.completed"}'
else
    tools= bare= mcp=
    while [ "$#" -gt 0 ]; do
        case $1 in
            --tools) tools=$2; shift ;; --bare) bare=yes ;; --disallowedTools) mcp=$2; shift ;;
        esac
        shift
    done
    [ "$tools" = Read,Grep,Glob ] && [ "$bare" = yes ] && [ "$mcp" = 'mcp__*' ] || exit 93
    case ${FAKE_MODE:-ok} in
        invalid) printf '%s\n' '{bad' ;;
        is_error) printf '%s\n' '{"subtype":"error_max_turns","is_error":true}' ;;
        empty) printf '%s\n' '{"subtype":"success","result":""}' ;;
        *) printf '%s\n' '{"subtype":"success","is_error":false,"result":"candidate report","modelUsage":{"claude-opus-example":{}}}' ;;
    esac
fi
FAKE
cp "$scratch/bin/codex" "$scratch/bin/claude"
chmod +x "$scratch/bin/codex" "$scratch/bin/claude"
export PATH="$scratch/bin:$PATH" CLAUDECODE=parent-session
export TEST_MARKER="$scratch/escaped-child"
count=0

invoke() {
    count=$((count + 1))
    receipt=$scratch/receipt-$count.json
    code=0
    /bin/bash "$script_dir/review.sh" run "$@" --repo "$scratch/repo with spaces" \
        --diff "$scratch/review.diff" --brief "$scratch/brief.md" \
        --output-dir "$scratch/result $count" --timeout 1 > "$receipt" 2> "$scratch/test.stderr" || code=$?
}

assert_json() { jq -e "$1" "$receipt" >/dev/null || { cat "$receipt"; exit 1; }; }

invoke sol
[ "$code" -eq 0 ]; assert_json '.status == "ok" and .model == "gpt-6.10-sol"'
report=$(jq -r '.report' "$receipt")
[ "$(cat "$report")" = 'candidate report' ]
invoke luna
[ "$code" -eq 0 ]; assert_json '.model == "gpt-6-luna"'
invoke astra
[ "$code" -eq 0 ]; assert_json '.model == "gpt-6-astra"'
invoke terra
[ "$code" -eq 0 ]; assert_json '.model == "gpt-5.6-terra"'
invoke claude opus
[ "$code" -eq 0 ]; assert_json '.model == "opus" and .actual_models == ["claude-opus-example"]'
invoke fable
[ "$code" -eq 0 ]; assert_json '.harness == "claude" and .model == "fable"'
invoke codex gpt-6-sol
[ "$code" -eq 0 ]; assert_json '.model == "gpt-6-sol"'
invoke claude luna
[ "$code" -eq 1 ]; assert_json '.status == "error"'
invoke unknown
[ "$code" -eq 1 ]; assert_json '.status == "error"'

for mode in failed empty is_error invalid; do
    export FAKE_MODE=$mode
    invoke opus
    [ "$code" -eq 1 ]; assert_json '.status == "error"'
done
export FAKE_MODE=empty
invoke sol
[ "$code" -eq 1 ]; assert_json '.status == "error"'
for mode in catalog_failed catalog_invalid catalog_missing; do
    export FAKE_MODE=$mode
    invoke sol
    [ "$code" -eq 1 ]; assert_json '.status == "error"'
done
export FAKE_MODE=timeout
invoke sol
[ "$code" -eq 1 ]; assert_json '.status == "timeout-or-interrupted"'
sleep 3
[ ! -e "$TEST_MARKER" ] || { printf '%s\n' 'Timed-out descendant escaped.' >&2; exit 1; }
export FAKE_MODE=ok
# Exercise the containment check directly.
code=0
/bin/bash "$script_dir/review.sh" run sol --repo "$scratch/repo with spaces" \
    --diff "$scratch/review.diff" --brief "$scratch/brief.md" \
    --output-dir "$scratch/repo with spaces/forbidden" > "$scratch/containment.json" || code=$?
[ "$code" -eq 1 ]
[ ! -e "$scratch/repo with spaces/forbidden" ]
ln -s "$scratch/repo with spaces" "$scratch/alias"
code=0
/bin/bash "$script_dir/review.sh" run sol --repo "$scratch/repo with spaces" \
    --diff "$scratch/review.diff" --brief "$scratch/brief.md" \
    --output-dir "$scratch/alias/forbidden" > "$scratch/symlink.json" || code=$?
[ "$code" -eq 1 ]
[ ! -e "$scratch/repo with spaces/forbidden" ]
printf 'Passed %s harness cases plus containment and symlink checks on %s.\n' "$count" "$BASH_VERSION"

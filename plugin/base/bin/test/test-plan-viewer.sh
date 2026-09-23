#!/usr/bin/env bash
# The graph viewer serves the selected plan afresh on every request.
set -uo pipefail

HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
BIN="$HERE/.."
SERVER="$BIN/viewer/serve.py"
SOURCE="$HERE/fixtures/emanate-plan/clean-three-waves/expected-stdout.json"

pass=0; fail=0
ok(){ echo "PASS $1"; pass=$((pass+1)); }
bad(){ echo "FAIL $1"; fail=$((fail+1)); }
eq(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }

TMP="$(mktemp -d -t inspire-plan-viewer.XXXXXX)" || exit 1
pid=""
cleanup(){
  if [ -n "$pid" ]; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT

cp "$SOURCE" "$TMP/plan.json"
python3 "$SERVER" --check "$TMP/plan.json" > "$TMP/check.out" 2> "$TMP/check.err"
eq "the server accepts a v2 emanation plan" "$?" "0"
eq "check identifies the contract" "$(grep -c 'inspire.emanation-plan/2' "$TMP/check.out" | tr -d ' ')" "1"

printf '{"schema":"wrong"}\n' > "$TMP/wrong.json"
if python3 "$SERVER" --check "$TMP/wrong.json" > /dev/null 2> "$TMP/wrong.err"; then
  bad "the server refuses an unknown contract"
else
  ok "the server refuses an unknown contract"
fi
eq "the refusal names the expected schema" "$(grep -c 'schema must be' "$TMP/wrong.err" | tr -d ' ')" "1"

python3 "$SERVER" --port 0 "$TMP/plan.json" > "$TMP/server.out" 2> "$TMP/server.err" &
pid=$!
i=0
while [ "$i" -lt 100 ] && ! grep -q '^Emanation plan viewer:' "$TMP/server.out" 2>/dev/null; do
  sleep 0.03
  i=$((i+1))
done
url="$(sed -n 's/^Emanation plan viewer: //p' "$TMP/server.out")"
if [ -n "$url" ]; then ok "the server publishes its selected port"; else bad "the server publishes its selected port"; fi

curl -fsS "$url" > "$TMP/index.html"
eq "the root serves the graph UI" "$(grep -c '<title>INSPIRE — Emanation plan</title>' "$TMP/index.html" | tr -d ' ')" "1"
eq "the page polls without a reload" "$(grep -c 'setInterval(load, POLL_MS)' "$TMP/index.html" | tr -d ' ')" "1"

curl -fsS "${url}plan.json" > "$TMP/first.json"
eq "the plan endpoint serves the selected document" "$(jq -r '.floor' "$TMP/first.json")" "3"
jq '.floor = 7' "$TMP/plan.json" > "$TMP/next.json"
mv "$TMP/next.json" "$TMP/plan.json"
curl -fsS "${url}plan.json" > "$TMP/second.json"
eq "a source edit reaches the endpoint without restarting" "$(jq -r '.floor' "$TMP/second.json")" "7"
curl -fsS -D "$TMP/headers" -o /dev/null "${url}plan.json"
eq "the live endpoint disables browser caching" "$(tr -d '\r' < "$TMP/headers" | grep -ci '^cache-control: no-store')" "1"

sed -n '/^  <script>$/,/^  <\/script>$/p' "$BIN/viewer/index.html" \
  | sed '1d;$d' > "$TMP/viewer.js"
if ! command -v node >/dev/null 2>&1; then
  echo "SKIP the embedded viewer JavaScript parses (node is not installed)"
elif node --check "$TMP/viewer.js" > "$TMP/node.out" 2>&1; then
  ok "the embedded viewer JavaScript parses"
else
  bad "the embedded viewer JavaScript parses"
  cat "$TMP/node.out"
fi

echo ""
echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]

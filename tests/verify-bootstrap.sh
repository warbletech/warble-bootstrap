#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() { echo "FAIL: $*" >&2; exit 1; }

bash -n scripts/clone-warbletech.sh

eval "$(sed -n '/^group_for()/,/^}/p' scripts/clone-warbletech.sh)"

[ "$(group_for starling-ex public)" = enterprise ] || fail "starling-ex should be enterprise"
[ "$(group_for starling-ex-community private)" = enterprise ] || fail "community should be enterprise"
[ "$(group_for warble-idp-portal private)" = internal ] || fail "idp-portal should be internal"
[ "$(group_for warble-saas-marketplace private)" = internal ] || fail "marketplace should be internal"
[ "$(group_for warble-founders-gtm private)" = internal ] || fail "founders-gtm should be internal"
[ "$(group_for warble-idp-portal public)" = internal ] || fail "idp-portal stays internal even if public"
[ "$(group_for aviika-llm private)" = products ] || fail "aviika-llm should be products"
[ "$(group_for some-public-lib public)" = oss ] || fail "unknown public repo should be oss"
[ "$(group_for some-private-lib private)" = internal ] || fail "unknown private repo should be internal"

platforms="$ROOT/docs/platforms.md"
python3 - "$platforms" << 'ENDPY'
import sys
from pathlib import Path
raw = Path(sys.argv[1]).read_bytes()
if bytes([7]) in raw:
    raise SystemExit("platforms.md still contains a BEL character")
text = raw.decode("utf-8")
needles = [
    "app.warblecloud.com",
    "idp.warblecloud.com",
    "dex.warblecloud.com",
    "warble-idp-portal",
    "warble-saas-marketplace",
    "warble-founders-gtm",
    "35.190.63.216",
    "Infrastructure target matrix",
]
for needle in needles:
    if needle not in text:
        raise SystemExit(f"platforms.md missing {needle}")
print("platforms.md matrix checks ok")
ENDPY

for name in warble-idp-portal warble-saas-marketplace warble-founders-gtm Get-RepoGroup; do
  grep -q "$name" scripts/clone-warbletech.ps1 || fail "ps1 missing $name"
done
grep -F "param(" scripts/clone-warbletech.ps1 >/dev/null || fail "ps1 missing param("

can_list_section1=0
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  can_list_section1=1
  for repo in warble-idp-portal warble-saas-marketplace warble-founders-gtm; do
    if ! gh repo view "warbletech/${repo}" --json name >/dev/null 2>&1; then
      can_list_section1=0
      break
    fi
  done
fi

if [ "$can_list_section1" -eq 1 ]; then
  dest="$(mktemp -d)"
  scripts/clone-warbletech.sh --list --dest "$dest" > "$dest/list.out"
  for repo in warble-idp-portal warble-saas-marketplace warble-founders-gtm; do
    grep -E "^internal[[:space:]]+${repo}[[:space:]]" "$dest/list.out" >/dev/null \
      || fail "--list did not place ${repo} in internal"
    grep -q "$repo" "$dest/INDEX.md" || fail "INDEX.md missing ${repo}"
  done
  echo "--list includes Section 1 repos under internal/"
else
  echo "skip live --list (gh cannot see the Section 1 private repos)"
fi

echo "verify-bootstrap: ok"

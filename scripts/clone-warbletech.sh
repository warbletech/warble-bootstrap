#!/usr/bin/env bash
# List every repository in https://github.com/orgs/warbletech/repositories
# and clone it under ~/warble-enterprise.
#
# Layout:
#   enterprise/   Starling EX
#   oss/          public repositories
#   products/     vertical apps and satellite sites
#   internal/     the rest of the private platform
#
# Usage:
#   ./clone-warbletech.sh              clone anything that is not already checked out
#   ./clone-warbletech.sh --list       print the org list and target path, do not clone
#   ./clone-warbletech.sh --clean      delete each checkout and clone it again
#   ./clone-warbletech.sh --dest DIR   clone somewhere other than ~/warble-enterprise
#   ./clone-warbletech.sh --jobs N     parallel clones (default 6)
#
# Platforms that receive a deploy are listed in docs/platforms.md.
# Requires: gh (authenticated), git. Does not touch checkouts that have
# uncommitted changes unless --force is also passed.

set -u

ORG="warbletech"
DEST="${HOME}/warble-enterprise"
JOBS=6
CLEAN=0
LIST_ONLY=0
FORCE=0

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --clean) CLEAN=1 ;;
    --list) LIST_ONLY=1 ;;
    --force) FORCE=1 ;;
    --dest) DEST=$2; shift ;;
    --jobs) JOBS=$2; shift ;;
    -h|--help) usage ;;
    *) echo "unknown argument: $1" >&2; usage ;;
  esac
  shift
done

if ! command -v gh >/dev/null 2>&1; then
  echo "gh is not installed" >&2
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "gh is not authenticated" >&2
  exit 1
fi

group_for() {
  name=$1
  visibility=$2
  case "$name" in
    starling-ex|starling-ex-community)
      echo enterprise
      ;;
    ananta|aviika-llm|avinizer.tech|chirp-ccp|chirpstack-gatesay|cityguide|drona-edtech|petrol-pump-mvp|pramana|surveillance-mvp|warble-future)
      echo products
      ;;
    *)
      if [ "$visibility" = "private" ]; then
        echo internal
      else
        echo oss
      fi
      ;;
  esac
}

safe_name() {
  case "$1" in
    *[!a-zA-Z0-9._-]*) return 1 ;;
    "") return 1 ;;
    *) return 0 ;;
  esac
}

mkdir -p "$DEST/enterprise" "$DEST/internal" "$DEST/oss" "$DEST/products"

LIST=$(mktemp)
FAILS=$(mktemp)
trap 'rm -f "$LIST" "$FAILS"' EXIT

gh repo list "$ORG" --limit 500 \
  --json name,isPrivate,description,url,updatedAt,primaryLanguage \
  --jq '.[] | [
      .name,
      (if .isPrivate then "private" else "public" end),
      .url,
      (.updatedAt[0:10]),
      (.primaryLanguage.name // ""),
      ((.description // "") | gsub("[\\t\\r\\n]"; " ") | gsub("\\|"; "/"))
    ] | @tsv' > "$LIST"

count=$(wc -l < "$LIST" | tr -d ' ')
if [ "$count" -eq 0 ]; then
  echo "no repositories returned for ${ORG}" >&2
  exit 1
fi

echo "org https://github.com/orgs/${ORG}/repositories"
echo "repos ${count}"
echo "dest ${DEST}"
echo

index_tmp=$(mktemp)
{
  echo "# warbletech repositories"
  echo
  echo "Every repository in https://github.com/orgs/${ORG}/repositories."
  echo "Cloned by \`clone-warbletech.sh\`."
  echo
  echo "Public repos are in \`oss/\`. Starling EX is in \`enterprise/\`. Vertical apps and satellite sites are in \`products/\`. The rest of the private platform is in \`internal/\`."
  echo
} > "$index_tmp"

for group in enterprise internal oss products; do
  echo "## ${group}" >> "$index_tmp"
  echo >> "$index_tmp"
  echo "| Repo | Visibility | Language | Updated | Description |" >> "$index_tmp"
  echo "|---|---|---|---|---|" >> "$index_tmp"
  while IFS="$(printf '\t')" read -r name visibility url updated lang desc; do
    g=$(group_for "$name" "$visibility")
    [ "$g" = "$group" ] || continue
    [ -n "$lang" ] || lang="—"
    echo "| [${name}](${url}) | ${visibility} | ${lang} | ${updated} | ${desc} |" >> "$index_tmp"
  done < "$LIST"
  echo >> "$index_tmp"
done
echo "Total: ${count} repositories." >> "$index_tmp"
echo >> "$index_tmp"
mv "$index_tmp" "$DEST/INDEX.md"
chmod 644 "$DEST/INDEX.md"

printf "%-12s %-28s %s\n" "GROUP" "REPO" "URL"
while IFS="$(printf '\t')" read -r name visibility url updated lang desc; do
  g=$(group_for "$name" "$visibility")
  printf "%-12s %-28s %s\n" "$g" "$name" "$url"
done < "$LIST"
echo

if [ "$LIST_ONLY" -eq 1 ]; then
  echo "list only; wrote ${DEST}/INDEX.md"
  exit 0
fi

clone_one() {
  name=$1
  visibility=$2
  group=$(group_for "$name" "$visibility")
  if ! safe_name "$name"; then
    echo "FAIL ${name}: unexpected repository name" >&2
    echo "$name" >> "$FAILS"
    return
  fi
  case "$group" in
    enterprise|internal|oss|products) ;;
    *) echo "FAIL ${name}: bad group" >&2; echo "$name" >> "$FAILS"; return ;;
  esac
  path="${DEST}/${group}/${name}"
  case "$path" in
    "${DEST}/${group}/${name}") ;;
    *) echo "FAIL ${name}: path escaped dest" >&2; echo "$name" >> "$FAILS"; return ;;
  esac

  if [ -d "${path}/.git" ]; then
    dirty=$(git -C "$path" status --porcelain 2>/dev/null || true)
    if [ -n "$dirty" ] && [ "$FORCE" -ne 1 ]; then
      echo "SKIP ${group}/${name}: uncommitted changes (pass --force to replace)"
      return
    fi
    if [ "$CLEAN" -eq 1 ]; then
      rm -rf "$path"
    else
      echo "SKIP ${group}/${name}: already cloned"
      return
    fi
  elif [ -e "$path" ]; then
    echo "FAIL ${group}/${name}: path exists and is not a git checkout" >&2
    echo "$name" >> "$FAILS"
    return
  fi

  mkdir -p "${DEST}/${group}"
  if gh repo clone "${ORG}/${name}" "$path" >/tmp/clone-${name}.log 2>&1; then
    echo "OK   ${group}/${name}"
  else
    echo "FAIL ${group}/${name}" >&2
    tail -n 3 "/tmp/clone-${name}.log" >&2 || true
    echo "$name" >> "$FAILS"
  fi
}

running=0
while IFS="$(printf '\t')" read -r name visibility url updated lang desc; do
  clone_one "$name" "$visibility" &
  running=$((running + 1))
  if [ "$running" -ge "$JOBS" ]; then
    wait
    running=0
  fi
done < "$LIST"
wait

fail_count=$(wc -l < "$FAILS" | tr -d ' ')
echo
if [ "$fail_count" -gt 0 ]; then
  echo "finished with ${fail_count} failure(s):"
  cat "$FAILS"
  exit 1
fi
echo "finished: ${count} repositories under ${DEST}"

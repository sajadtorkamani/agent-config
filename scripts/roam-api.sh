#!/usr/bin/env bash
# Calls the Roam Research backend API for one graph. The token is read from
# ~/.config/roam/token and only ever goes into the request header, never to stdout.
#
# Usage:
#   roam-api.sh -g <graph> outline "<page title>"   Print the page as an outline with block uids
#   roam-api.sh -g <graph> q <body.json>            Run a query (body: {"query": ..., "args": [...]})
#   roam-api.sh -g <graph> write <body.json>        Run a write (body: {"action": "batch-actions", "actions": [...]})
set -euo pipefail

graph=""
if [ "${1:-}" = "-g" ]; then
  graph="${2:-}"
  shift 2 || true
fi
if [ -z "$graph" ]; then
  echo "Pass the graph name first: $0 -g <graph> ..." >&2
  exit 1
fi
token_file="$HOME/.config/roam/token"

if [ ! -s "$token_file" ]; then
  echo "No Roam API token at $token_file" >&2
  exit 1
fi

call_api() {
  local endpoint="$1"
  local body_file="$2"
  # --location-trusted keeps the auth header when Roam redirects to the graph's peer
  curl -sS --fail-with-body --location-trusted -X POST \
    "https://api.roamresearch.com/api/graph/$graph/$endpoint" \
    -H @<(printf 'Authorization: Bearer %s\n' "$(< "$token_file")") \
    -H 'Content-Type: application/json' -H 'Accept: application/json' \
    --data @"$body_file"
}

command="${1:-}"
case "$command" in
  q | write)
    [ -f "${2:-}" ] || { echo "Usage: $0 -g <graph> $command <body.json>" >&2; exit 1; }
    call_api "$command" "$2"
    echo
    ;;
  outline)
    [ -n "${2:-}" ] || { echo "Usage: $0 -g <graph> outline \"<page title>\"" >&2; exit 1; }
    work_dir="$(mktemp -d)"
    trap 'rm -rf "$work_dir"' EXIT
    TITLE="$2" python3 -I -c '
import json, os
query = "[:find (pull ?page [:block/uid :node/title :block/string :block/order {:block/children ...}]) :in $ ?title :where [?page :node/title ?title]]"
print(json.dumps({"query": query, "args": [os.environ["TITLE"]]}))
' > "$work_dir/body.json"
    call_api q "$work_dir/body.json" > "$work_dir/page.json"
    python3 -I "$(dirname "$0")/roam-outline.py" "$work_dir/page.json" "$2"
    ;;
  *)
    sed -n '2,8p' "$0" >&2
    exit 1
    ;;
esac

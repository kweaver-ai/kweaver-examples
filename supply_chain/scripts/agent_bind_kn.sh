#!/usr/bin/env bash
# Bind imported decision agent to the knowledge network by name (from network.bkn) and agent key (from agents/*.json).
# Run after: kweaver bkn push + agent import.
# Usage: ./agent_bind_kn.sh <case_dir> [--publish]
set -euo pipefail

command -v kweaver >/dev/null 2>&1 || { echo "kweaver CLI not found" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq not found (brew install jq)" >&2; exit 1; }

PUBLISH=false
CASE_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --publish) PUBLISH=true; shift ;;
    *) CASE_DIR="${1:-}"; shift ;;
  esac
done

if [[ -z "$CASE_DIR" || ! -d "$CASE_DIR" ]]; then
  echo "Usage: $0 <case_dir> [--publish]" >&2
  exit 2
fi

NET_FILE="$CASE_DIR/bkn/network.bkn"
AGENT_JSON=""
shopt -s nullglob
for g in "$CASE_DIR/agents/"*.json; do AGENT_JSON="$g"; break; done
shopt -u nullglob

if [[ ! -f "$NET_FILE" ]]; then
  echo "Missing $NET_FILE" >&2
  exit 1
fi
if [[ -z "$AGENT_JSON" ]]; then
  echo "No agents/*.json under $CASE_DIR" >&2
  exit 1
fi

KN_NAME="$(awk '/^name:/{sub(/^name:[[:space:]]+/,""); print; exit}' "$NET_FILE" | tr -d '\r')"
if [[ -z "$KN_NAME" ]]; then
  echo "Could not read knowledge network name from $NET_FILE" >&2
  exit 1
fi

AGENT_KEY="$(jq -r '.agents[0].key // empty' "$AGENT_JSON")"
if [[ -z "$AGENT_KEY" ]]; then
  echo "Could not read agents[0].key from $AGENT_JSON" >&2
  exit 1
fi

KN_ID="$(
  kweaver bkn list --name-pattern "$KN_NAME" --limit 30 --pretty |
    jq -r --arg n "$KN_NAME" '
      (if type == "array" then . else (.entries // .data // []) end)
      | map(select(.name == $n)) | .[0].id // empty
    '
)" || true

if [[ -z "$KN_ID" ]]; then
  echo "Could not find knowledge network named exactly: $KN_NAME (kweaver bkn list --name-pattern)" >&2
  exit 1
fi

AGENT_ID="$(kweaver agent get-by-key "$AGENT_KEY" --pretty | jq -r '.id // empty')"
if [[ -z "$AGENT_ID" ]]; then
  echo "Could not resolve agent id for key $AGENT_KEY" >&2
  exit 1
fi

echo "Binding agent $AGENT_ID to knowledge network $KN_ID ($KN_NAME) ..."
kweaver agent update "$AGENT_ID" --knowledge-network-id "$KN_ID"
echo "OK (knowledge network bound)."
if [[ "$PUBLISH" == true ]]; then
  echo "Publishing agent $AGENT_ID ..."
  kweaver agent publish "$AGENT_ID"
  echo "OK (published)."
fi

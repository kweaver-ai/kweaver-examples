#!/usr/bin/env bash
# Bind imported decision agent to the knowledge network by name (from network.bkn) and agent key (from agents/*.json).
# Run after: kweaver bkn push + agent import.
# Usage: ./agent_bind_kn.sh <case_dir> [--publish]
set -euo pipefail

err() { echo "ERROR: $*" >&2; }

command -v kweaver >/dev/null 2>&1 || { err "kweaver CLI not found"; exit 1; }
command -v jq >/dev/null 2>&1 || { err "jq not found (e.g. brew install jq)"; exit 1; }

PUBLISH=false
CASE_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --publish) PUBLISH=true; shift ;;
    *) CASE_DIR="${1:-}"; shift ;;
  esac
done

if [[ -z "${CASE_DIR:-}" || ! -d "$CASE_DIR" ]]; then
  echo "Usage: $0 <case_dir> [--publish]" >&2
  exit 2
fi

CASE_DIR="$(cd "$CASE_DIR" && pwd)"

NET_FILE="$CASE_DIR/bkn/network.bkn"
AGENT_JSON=""
shopt -s nullglob
for g in "$CASE_DIR/agents/"*.json; do AGENT_JSON="$g"; break; done
shopt -u nullglob

if [[ ! -f "$NET_FILE" ]]; then
  err "Missing $NET_FILE"
  exit 1
fi
if [[ -z "$AGENT_JSON" ]]; then
  err "No agents/*.json under $CASE_DIR"
  exit 1
fi

if ! jq -e '.agents | type == "array" and length > 0' "$AGENT_JSON" >/dev/null 2>&1; then
  err "$AGENT_JSON must contain a non-empty .agents array"
  exit 1
fi

KN_NAME="$(awk '/^name:/{sub(/^name:[[:space:]]+/,""); print; exit}' "$NET_FILE" | tr -d '\r')"
if [[ -z "$KN_NAME" ]]; then
  err "Could not read knowledge network name from $NET_FILE (expected YAML key name:)"
  exit 1
fi

AGENT_KEY="$(jq -r '.agents[0].key // empty' "$AGENT_JSON")"
if [[ -z "$AGENT_KEY" ]]; then
  err "Could not read .agents[0].key from $AGENT_JSON"
  exit 1
fi

LIST_OUT="$(mktemp)"
LIST_ERR="$(mktemp)"
AGENT_OUT="$(mktemp)"
AGENT_ERR="$(mktemp)"
cleanup() { rm -f "$LIST_OUT" "$LIST_ERR" "$AGENT_OUT" "$AGENT_ERR"; }
trap cleanup EXIT

if ! kweaver bkn list --name-pattern "$KN_NAME" --limit 30 --pretty >"$LIST_OUT" 2>"$LIST_ERR"; then
  err "kweaver bkn list failed"
  [[ -s "$LIST_ERR" ]] && cat "$LIST_ERR" >&2
  exit 1
fi
if [[ ! -s "$LIST_OUT" ]]; then
  err "kweaver bkn list returned empty body"
  exit 1
fi
if ! jq -e . >/dev/null 2>&1 "$LIST_OUT"; then
  err "kweaver bkn list returned invalid JSON"
  [[ -s "$LIST_ERR" ]] && cat "$LIST_ERR" >&2
  exit 1
fi

KN_ID="$(jq -r --arg n "$KN_NAME" '
  (if type == "array" then . else (.entries // .data // []) end)
  | if type != "array" then error("unexpected list shape") else . end
  | map(select(.name == $n)) | .[0].id // empty
' "$LIST_OUT")"

if [[ -z "$KN_ID" ]]; then
  err "No knowledge network with exact name \"$KN_NAME\" in bkn list (pattern search can return partial matches; we require exact name)."
  exit 1
fi

if ! kweaver agent get-by-key "$AGENT_KEY" --pretty >"$AGENT_OUT" 2>"$AGENT_ERR"; then
  err "kweaver agent get-by-key failed for key=$AGENT_KEY"
  [[ -s "$AGENT_ERR" ]] && cat "$AGENT_ERR" >&2
  exit 1
fi
if [[ ! -s "$AGENT_OUT" ]]; then
  err "kweaver agent get-by-key returned empty body"
  exit 1
fi

AGENT_ID="$(jq -r '.id // empty' "$AGENT_OUT")"
if [[ -z "$AGENT_ID" ]]; then
  err "Response JSON has no .id (agent import may have failed or key mismatch)"
  exit 1
fi

echo "Binding agent $AGENT_ID to knowledge network $KN_ID ($KN_NAME) ..."
if ! kweaver agent update "$AGENT_ID" --knowledge-network-id "$KN_ID" 2>"$AGENT_ERR"; then
  err "kweaver agent update --knowledge-network-id failed"
  [[ -s "$AGENT_ERR" ]] && cat "$AGENT_ERR" >&2
  exit 1
fi
echo "OK (knowledge network bound)."
if [[ "$PUBLISH" == true ]]; then
  echo "Publishing agent $AGENT_ID ..."
  if ! kweaver agent publish "$AGENT_ID" 2>"$AGENT_ERR"; then
    err "kweaver agent publish failed"
    [[ -s "$AGENT_ERR" ]] && cat "$AGENT_ERR" >&2
    exit 1
  fi
  echo "OK (published)."
fi

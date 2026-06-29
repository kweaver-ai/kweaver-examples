#!/usr/bin/env bash
# Environment checks before bootstrap: CLI, auth, optional model inventory.
# Usage: preflight.sh <case_dir> [--require-models]
# Exit 0 = OK, 1 = failure (stderr explains).
set -euo pipefail

err() { echo "preflight: $*" >&2; }

CASE_DIR="${1:?case directory}"
shift || true
REQUIRE_MODELS=false
[[ "${1:-}" == "--require-models" ]] && REQUIRE_MODELS=true

cd "$CASE_DIR" || { err "not a directory: $CASE_DIR"; exit 1; }

FAIL=0

check_cmd() {
  local name="$1"
  shift
  if ! command -v "$name" >/dev/null 2>&1; then
    err "missing command: $name ($*)"
    FAIL=1
    return 1
  fi
  return 0
}

echo -e "\033[1;33m=== Preflight (environment) ===\033[0m"

check_cmd node "Node.js is required for kweaver SDK" || true
check_cmd npm "npm is required to install @kweaver-ai/kweaver-sdk" || true
check_cmd curl "curl is used for import APIs in bootstrap" || true
check_cmd kweaver "Install: npm i -g @kweaver-ai/kweaver-sdk" || true

if command -v node >/dev/null 2>&1; then
  nv="$(node -p "process.versions.node" 2>/dev/null || echo "?")"
  echo "  node: $nv"
  major="${nv%%.*}"
  if [[ "$major" =~ ^[0-9]+$ ]] && [[ "$major" -lt 18 ]]; then
    err "Node 18+ recommended (found major=$major)"
    FAIL=1
  fi
fi

if command -v kweaver >/dev/null 2>&1; then
  kv="$(kweaver --version 2>/dev/null || kweaver -V 2>/dev/null || echo "?")"
  echo "  kweaver: $kv"
fi

if ! command -v kweaver >/dev/null 2>&1; then
  echo -e "\033[0;31mPreflight failed (kweaver missing).\033[0m" >&2
  exit 1
fi

BASE_URL="$(kweaver config show 2>/dev/null | awk -F': +' '/^Platform:/ {print $2; exit}')"
BASE_URL="${BASE_URL%/}"
if [[ -z "$BASE_URL" ]]; then
  err "kweaver: no platform URL — run: kweaver auth login <url>"
  FAIL=1
else
  echo "  platform: $BASE_URL"
fi

TOKEN="$(kweaver token 2>/dev/null || true)"
if [[ -z "$TOKEN" ]]; then
  err "no access token — run: kweaver auth login <url>"
  FAIL=1
else
  echo "  token: ok"
fi

if [[ "$FAIL" != 0 ]]; then
  echo -e "\033[0;31mPreflight failed (auth / CLI).\033[0m" >&2
  exit 1
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

if ! kweaver call "/api/mf-model-manager/v1/llm/list?page=1&size=200" --pretty >"$TMP" 2>/dev/null; then
  err "kweaver call .../llm/list failed — check network and business domain (--bd)"
  exit 1
fi
if ! jq -e . >/dev/null 2>&1 "$TMP"; then
  err "model list response is not valid JSON"
  exit 1
fi

NORM="$(mktemp)"
trap 'rm -f "$TMP" "$NORM"' EXIT

jq -c '
  # `//` only catches null/false, not errors. When the response is {data:[...]}
  # (data already an array), `.data.records` raises "Cannot index array with
  # string records" and aborts. Wrap each index in `try` so an error becomes
  # empty and falls through. Final `.` catches a top-level array response.
  ((try .data.records) // (try .data.list) // (try .data) // (try .records) // (try .list) // .)
  | if type == "array" then . else [] end
  | map(select((.id // .model_id // "") != ""))
' "$TMP" >"$NORM"

TOTAL="$(jq 'length' "$NORM")"
N_LLM="$(jq '[.[] | select((.model_type // .type // "") | tostring | ascii_downcase | test("llm|chat|text|generation"))] | length' "$NORM")"
N_EMB="$(jq '[.[] | select((.model_type // .type // "") | tostring | ascii_downcase | test("embed"))] | length' "$NORM")"

echo "  model registry: $TOTAL model(s) (llm/chat-like: $N_LLM, embedding-like: $N_EMB)"

if [[ "$REQUIRE_MODELS" == true ]]; then
  if [[ "$TOTAL" -eq 0 ]]; then
    err "no models registered on platform — add 大模型/小模型 in Studio or model factory first"
    exit 1
  fi
  if [[ "$N_LLM" -eq 0 ]] || [[ "$N_EMB" -eq 0 ]]; then
    err "need at least one chat/LLM and one embedding model (matched by model_type). Found llm-like=$N_LLM embed-like=$N_EMB"
    exit 1
  fi
fi

echo -e "\033[0;32mPreflight OK.\033[0m"
exit 0

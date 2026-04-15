#!/usr/bin/env bash
# Set default LLM id in agent config (nested JSON in .config) via kweaver agent get + update.
# Prerequisite: jq, kweaver CLI; platform already has LLM models registered.
# Usage: ./agent_set_llm.sh <agent_id> <llm_id>
set -euo pipefail

err() { echo "ERROR: $*" >&2; }

command -v kweaver >/dev/null 2>&1 || { err "kweaver CLI not found"; exit 1; }
command -v jq >/dev/null 2>&1 || { err "jq not found (e.g. brew install jq)"; exit 1; }

if [[ $# -lt 2 || -z "${1:-}" || -z "${2:-}" ]]; then
  echo "Usage: $0 <agent_id> <llm_id>" >&2
  exit 2
fi

AGENT_ID="${1//[$'\t\r\n']/}"
LLM_ID="${2//[$'\t\r\n']/}"
if [[ -z "$AGENT_ID" || -z "$LLM_ID" ]]; then
  err "agent_id and llm_id must be non-empty"
  exit 2
fi

TMP="$(mktemp)"
TMP_JQ="$(mktemp)"
GET_ERR="$(mktemp)"
JQ_ERR="$(mktemp)"
UPD_ERR="$(mktemp)"
cleanup() { rm -f "$TMP" "$TMP_JQ" "$GET_ERR" "$JQ_ERR" "$UPD_ERR"; }
trap cleanup EXIT

if ! kweaver agent get "$AGENT_ID" --pretty >"$TMP" 2>"$GET_ERR"; then
  err "kweaver agent get failed for id=$AGENT_ID"
  [[ -s "$GET_ERR" ]] && cat "$GET_ERR" >&2
  exit 1
fi
if [[ ! -s "$TMP" ]]; then
  err "kweaver agent get returned an empty response"
  exit 1
fi
if ! jq -e . >/dev/null 2>"$JQ_ERR" "$TMP"; then
  err "kweaver agent get did not return valid JSON"
  [[ -s "$JQ_ERR" ]] && cat "$JQ_ERR" >&2
  exit 1
fi

if ! jq --arg lid "$LLM_ID" '
  (.config
    | if type == "string" then (try fromjson catch error("config string is not valid JSON"))
      elif type == "object" then .
      else error(".config must be a JSON string or object") end
  ) as $inner |
  if ($inner.llms | length) == 0 then error("No llms[] in agent config") else
    ($inner.llms | map(.is_default == true) | index(true)) as $idx |
    (if $idx != null then $idx else 0 end) as $i |
    ($inner
      | .llms[$i].llm_config = (.llms[$i].llm_config // {})
      | .llms[$i].llm_config.id = $lid) as $patched |
    .config = ($patched | tojson)
  end
' "$TMP" >"$TMP_JQ" 2>"$JQ_ERR"; then
  err "failed to patch agent config (check llms[] and embedded JSON in .config)"
  [[ -s "$JQ_ERR" ]] && cat "$JQ_ERR" >&2
  exit 1
fi
mv "$TMP_JQ" "$TMP"

if ! kweaver agent update "$AGENT_ID" --config-path "$TMP" 2>"$UPD_ERR"; then
  err "kweaver agent update failed"
  [[ -s "$UPD_ERR" ]] && cat "$UPD_ERR" >&2
  exit 1
fi

echo "OK: set default LLM id to $LLM_ID"

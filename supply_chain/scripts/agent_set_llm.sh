#!/usr/bin/env bash
# Set default LLM id in agent config (nested JSON in .config) via kweaver agent get + update.
# Prerequisite: jq, kweaver CLI; platform already has LLM models registered.
# Usage: ./agent_set_llm.sh <agent_id> <llm_id>
set -euo pipefail

command -v kweaver >/dev/null 2>&1 || { echo "kweaver CLI not found" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq not found (brew install jq)" >&2; exit 1; }

if [[ $# -lt 2 || -z "${1:-}" || -z "${2:-}" ]]; then
  echo "Usage: $0 <agent_id> <llm_id>" >&2
  exit 2
fi

AGENT_ID="$1"
LLM_ID="$2"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

kweaver agent get "$AGENT_ID" --pretty >"$TMP"

jq --arg lid "$LLM_ID" '
  (.config | if type == "string" then fromjson else . end) as $inner |
  if ($inner.llms | length) == 0 then error("No llms[] in agent config") else
    ($inner.llms | map(.is_default == true) | index(true)) as $idx |
    (if $idx != null then $idx else 0 end) as $i |
    ($inner
      | .llms[$i].llm_config = (.llms[$i].llm_config // {})
      | .llms[$i].llm_config.id = $lid) as $patched |
    .config = ($patched | tojson)
  end
' "$TMP" >"${TMP}.out"
mv "${TMP}.out" "$TMP"

kweaver agent update "$AGENT_ID" --config-path "$TMP"
echo "OK: set default LLM id to $LLM_ID"

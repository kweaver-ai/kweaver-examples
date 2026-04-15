#!/usr/bin/env bash
# Try to set the embedding (small) model on a knowledge network using kweaver bkn get + update.
# Platform JSON shape may differ; if no known field is present, print Studio instructions only.
# Usage: ./kn_set_embedding.sh <kn_id> <embedding_model_id>
set -euo pipefail

err() { echo "kn_set_embedding.sh: $*" >&2; }

command -v kweaver >/dev/null 2>&1 || { err "kweaver CLI not found"; exit 1; }
command -v jq >/dev/null 2>&1 || { err "jq not found"; exit 1; }

if [[ $# -lt 2 || -z "${1:-}" || -z "${2:-}" ]]; then
  echo "Usage: $0 <kn_id> <embedding_model_id>" >&2
  exit 2
fi

KN_ID="$1"
EMB_ID="$2"

TMP="$(mktemp)"
PATCH="$(mktemp)"
GET_ERR="$(mktemp)"
trap 'rm -f "$TMP" "$PATCH" "$GET_ERR"' EXIT

if ! kweaver bkn get "$KN_ID" --pretty >"$TMP" 2>"$GET_ERR"; then
  err "kweaver bkn get failed"
  [[ -s "$GET_ERR" ]] && cat "$GET_ERR" >&2
  exit 1
fi
if [[ ! -s "$TMP" ]] || ! jq -e . >/dev/null 2>&1 "$TMP"; then
  err "bkn get returned empty or invalid JSON"
  exit 1
fi

# Merge embedding id into common shapes; only patch if we touch a known path.
if ! jq --arg e "$EMB_ID" '
  def merge:
    if has("embedding_model_id") then .embedding_model_id = $e
    elif has("embeddingModelId") then .embeddingModelId = $e
    elif (.index_config | type == "object") and (.index_config | has("embedding_model_id")) then
      .index_config.embedding_model_id = $e
    elif (.indexConfig | type == "object") and (.indexConfig | has("embeddingModelId")) then
      .indexConfig.embeddingModelId = $e
    elif (.vector_config | type == "object") and (.vector_config | has("embedding_model_id")) then
      .vector_config.embedding_model_id = $e
    else
      .
    end;
  merge
' "$TMP" >"$PATCH" 2>/dev/null; then
  err "jq merge failed"
  exit 1
fi

if cmp -s "$TMP" "$PATCH"; then
  echo "Note: KN detail has no recognized embedding field (embedding_model_id / index_config…)." >&2
  echo "      请在 Studio 中为该知识网络配置索引用小模型，模型 id: $EMB_ID" >&2
  exit 0
fi

UPD_ERR="$(mktemp)"
trap 'rm -f "$TMP" "$PATCH" "$GET_ERR" "$UPD_ERR"' EXIT

if ! kweaver bkn update "$KN_ID" --body-file "$PATCH" 2>"$UPD_ERR"; then
  err "kweaver bkn update failed (your platform may require setting the embedding model in Studio)"
  [[ -s "$UPD_ERR" ]] && cat "$UPD_ERR" >&2
  echo "      小模型 id: $EMB_ID" >&2
  exit 0
fi

echo "OK: knowledge network $KN_ID embedding model set to $EMB_ID"

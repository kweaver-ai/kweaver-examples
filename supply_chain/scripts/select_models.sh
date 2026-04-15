#!/usr/bin/env bash
# Fetch LLM + embedding models via kweaver (model factory API), then let the user pick one of each.
# Prints shell assignments to stdout for: eval "$(./select_models.sh)"
#
# Non-interactive (e.g. CI): pass ids via env:
#   SELECTED_LLM_ID=... SELECTED_EMBEDDING_ID=... ./select_models.sh --non-interactive
#
set -euo pipefail

err() { echo "select_models.sh: $*" >&2; }

command -v kweaver >/dev/null 2>&1 || { err "kweaver CLI not found"; exit 1; }
command -v jq >/dev/null 2>&1 || { err "jq not found"; exit 1; }

NON_INTERACTIVE=false
if [[ "${1:-}" == "--non-interactive" ]]; then
  NON_INTERACTIVE=true
fi

if [[ "$NON_INTERACTIVE" == true ]]; then
  if [[ -z "${SELECTED_LLM_ID:-}" || -z "${SELECTED_EMBEDDING_ID:-}" ]]; then
    err "for --non-interactive, set SELECTED_LLM_ID and SELECTED_EMBEDDING_ID"
    exit 2
  fi
  printf 'SELECTED_LLM_ID=%q\nSELECTED_EMBEDDING_ID=%q\n' "$SELECTED_LLM_ID" "$SELECTED_EMBEDDING_ID"
  exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP" "${TMP}.norm" "${TMP}.emb" "${TMP}.llm"' EXIT

if ! kweaver call "/api/mf-model-manager/v1/llm/list?page=1&size=200" --pretty >"$TMP" 2> "${TMP}.err"; then
  err "kweaver call llm/list failed"
  [[ -s "${TMP}.err" ]] && cat "${TMP}.err" >&2
  exit 1
fi
if [[ ! -s "$TMP" ]] || ! jq -e . >/dev/null 2>&1 "$TMP"; then
  err "llm/list returned empty or invalid JSON"
  [[ -s "${TMP}.err" ]] && cat "${TMP}.err" >&2
  exit 1
fi

jq -c '
  ((.data.records // .data.list // .data // .records // .list // null)
    | if . == null then []
      elif type == "array" then .
      else []
      end
  ) as $r
  | $r
  | map(select((.id // .model_id // "") != ""))
  | map({
      id: (.id // .model_id),
      name: (.name // .display_name // .model_name // "-"),
      model_type: ((.model_type // .type // "") | tostring)
    })
' "$TMP" >"${TMP}.norm"

if [[ ! -s "${TMP}.norm" ]]; then
  err "could not parse model records from API response"
  exit 1
fi

COUNT="$(jq 'length' "${TMP}.norm")"
if [[ "$COUNT" -eq 0 ]]; then
  err "no models in list response"
  exit 1
fi

jq -c 'map(select((.model_type|ascii_downcase) | test("embed"))) | if length > 0 then . else [] end' "${TMP}.norm" >"${TMP}.emb"
jq -c 'map(select((.model_type|ascii_downcase) | test("llm|chat|text|generation"))) | if length > 0 then . else [] end' "${TMP}.norm" >"${TMP}.llm"

if [[ "$(jq 'length' "${TMP}.llm")" -eq 0 ]]; then
  echo "Note: no model_type matching llm/chat; showing full list for 大模型." >&2
  cp "${TMP}.norm" "${TMP}.llm"
fi
if [[ "$(jq 'length' "${TMP}.emb")" -eq 0 ]]; then
  echo "Note: no model_type matching embed; showing full list for 小模型." >&2
  cp "${TMP}.norm" "${TMP}.emb"
fi

pick_index() {
  local label="$1"
  local file="$2"
  local n
  n="$(jq 'length' "$file")"
  echo "" >&2
  echo -e "\033[1;33m=== ${label} ===\033[0m" >&2
  local i=1
  while [[ "$i" -le "$n" ]]; do
    jq -r --argjson idx "$((i - 1))" '.[$idx] | "  " + (($idx + 1) | tostring) + ") " + .id + "  " + .name + "  [" + .model_type + "]"' "$file" >&2
    i=$((i + 1))
  done
  echo "" >&2
  local choice=""
  while true; do
    read -r -p "  选择序号 [1-${n}] > " choice || true
    choice="${choice// /}"
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 && "$choice" -le "$n" ]]; then
      echo "$((choice - 1))"
      return 0
    fi
    err "请输入 1 到 ${n} 之间的数字"
  done
}

pick_id_from_file() {
  local file="$1"
  local idx="$2"
  jq -r --argjson i "$idx" '.[$i].id' "$file"
}

LLM_IDX="$(pick_index "大模型（对话 / Agent）" "${TMP}.llm")"
EMB_IDX="$(pick_index "小模型（向量 / 嵌入，用于知识网络索引）" "${TMP}.emb")"

SEL_LLM="$(pick_id_from_file "${TMP}.llm" "$LLM_IDX")"
SEL_EMB="$(pick_id_from_file "${TMP}.emb" "$EMB_IDX")"

if [[ -z "$SEL_LLM" || -z "$SEL_EMB" ]]; then
  err "failed to resolve model ids"
  exit 1
fi

printf 'SELECTED_LLM_ID=%q\nSELECTED_EMBEDDING_ID=%q\n' "$SEL_LLM" "$SEL_EMB"
echo "" >&2
echo -e "\033[0;32m已选择 大模型 id=\033[1m${SEL_LLM}\033[0;32m  小模型 id=\033[1m${SEL_EMB}\033[0m\033[0m" >&2

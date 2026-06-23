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
trap 'rm -f "$TMP" "${TMP}.err" "${TMP}.llm.raw" "${TMP}.emb.raw" "${TMP}.llm" "${TMP}.emb"' EXIT

# 大模型(对话/Agent）与小模型（embedding/向量）是两个不同 registry，各用各自的 kweaver 子命令拉取。
# 小模型必须走 `model small list`：旧实现查 `/llm/list` 再按 model_type 过滤 embed，那个 registry 里根本没有小模型。
if ! kweaver model llm list --limit 200 --json >"${TMP}.llm.raw" 2>"${TMP}.err"; then
  err "kweaver model llm list 失败"
  [[ -s "${TMP}.err" ]] && cat "${TMP}.err" >&2
  exit 1
fi
if ! kweaver model small list --type embedding --limit 200 --json >"${TMP}.emb.raw" 2>"${TMP}.err"; then
  err "kweaver model small list --type embedding 失败"
  [[ -s "${TMP}.err" ]] && cat "${TMP}.err" >&2
  exit 1
fi

# 统一成 [{id,name,model_type}];兼容 {count,data:[...]} / {data:[...]} / [...]
normalize() {
  jq -c '
    ((.data // .) | if type == "array" then . else [] end)
    | map(select((.model_id // .id // "") != ""))
    | map({
        id: (.model_id // .id),
        name: (.model_name // .name // .display_name // "-"),
        model_type: ((.model_type // .type // "") | tostring)
      })
  ' "$1"
}
normalize "${TMP}.llm.raw" >"${TMP}.llm"
normalize "${TMP}.emb.raw" >"${TMP}.emb"

if [[ "$(jq 'length' "${TMP}.llm" 2>/dev/null || echo 0)" -eq 0 ]]; then
  err "目标平台没有大模型（kweaver model llm list 为空）— 先在模型工厂注册大模型"
  exit 1
fi
if [[ "$(jq 'length' "${TMP}.emb" 2>/dev/null || echo 0)" -eq 0 ]]; then
  err "目标平台没有 embedding 小模型（kweaver model small list --type embedding 为空）"
  err "— 先注册一个，否则知识网络索引会报 ModelFactory.ExternalSmallModel.GetInfo.IdNotExist"
  exit 1
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

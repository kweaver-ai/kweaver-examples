#!/usr/bin/env bash
# Re-map platform-specific IDs in an exported BKN JSON (e.g. 供应链业务知识网络demo.json) to the
# TARGET platform before importing it.
#
# An exported KN JSON carries IDs from the platform it was exported from:
#   - per data_property:  index_config.vector_config.model_id  -> small/embedding model id (snowflake)
#   - per object/relation type: data_source.id                 -> data_view id (old data_view model)
# On a different platform those IDs do not exist, so索引构建任务报:
#   ModelFactory.ExternalSmallModel.GetInfo.IdNotExist  "部分配置id不存在"
#
# This targets the OLD data_view platform model (object types bound to data_view, build + vectorize):
#   - embedding model id  <- kweaver model small list --type embedding   (or --embedding-id / --embedding-name)
#   - data_view ids       <- kweaver call GET /api/mdl-data-model/v1/data-views?data_source_id=<id>
#                            (new SDK dropped the `dataview` subcommand; `kweaver call` still reaches the
#                             old endpoint, so NO SDK downgrade is needed). type stays "data_view".
# Only vector_config blocks with enabled==true get the embedding id; disabled ones are cleared to "".
#
# Usage:
#   ./patch_demo_json.sh <export.json> --datasource-id <data-connection-datasource-id> \
#       [--embedding-id <id> | --embedding-name <name>] [--strip-actions] [--out <path>] [--strict] [--insecure]
#
#   <data-connection-datasource-id>: the OLD datasource id, see GET /api/data-connection/v1/datasource
#
# Output: writes a patched copy (default <input>.patched.json); the input file is left unchanged.
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
err() { echo -e "${RED}patch_demo_json.sh: $*${NC}" >&2; }
note() { echo -e "${YELLOW}$*${NC}" >&2; }
ok()  { echo -e "${GREEN}$*${NC}" >&2; }

IN=""
DS_ID=""
EMB_ID=""
EMB_NAME=""
OUT=""
STRICT=false
INSECURE=false
STRIP_ACTIONS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --datasource-id) DS_ID="${2:-}"; shift 2 ;;
    --embedding-id) EMB_ID="${2:-}"; shift 2 ;;
    --embedding-name) EMB_NAME="${2:-}"; shift 2 ;;
    --out) OUT="${2:-}"; shift 2 ;;
    --strict) STRICT=true; shift ;;
    --strip-actions) STRIP_ACTIONS=true; shift ;;
    --insecure|-k) INSECURE=true; shift ;;
    -h|--help)
      sed -n '2,30p' "$0"; exit 0 ;;
    -*) err "unknown option: $1"; exit 2 ;;
    *) IN="$1"; shift ;;
  esac
done

[[ -n "$IN" ]] || { err "需要导出的 BKN JSON 路径 (e.g. bkn/供应链业务知识网络demo.json)"; exit 2; }
[[ -f "$IN" ]] || { err "文件不存在: $IN"; exit 1; }
command -v kweaver >/dev/null 2>&1 || { err "kweaver CLI 未安装 (npm i -g @kweaver-ai/kweaver-sdk)"; exit 1; }
command -v jq >/dev/null 2>&1 || { err "jq 未安装 (brew install jq)"; exit 1; }
jq -e . >/dev/null 2>&1 "$IN" || { err "输入不是合法 JSON: $IN"; exit 1; }

[[ "$INSECURE" == true ]] && export NODE_TLS_REJECT_UNAUTHORIZED=0

OUT="${OUT:-${IN%.json}.patched.json}"

# ---------- 1. 解析 embedding 小模型 id ----------
resolve_embedding_id() {
  if [[ -n "$EMB_ID" ]]; then
    echo "$EMB_ID"; return 0
  fi
  local tmp errf; tmp="$(mktemp)"; errf="$(mktemp)"
  if ! kweaver model small list --type embedding --json >"$tmp" 2>"$errf"; then
    err "kweaver model small list 失败"; [[ -s "$errf" ]] && cat "$errf" >&2
    rm -f "$tmp" "$errf"; return 1
  fi
  rm -f "$errf"
  # 兼容 {count,data:[...]} / {data:[...]} / [...]
  local list; list="$(jq -c '(.data // .) | if type=="array" then . else [] end' "$tmp")"
  rm -f "$tmp"
  local id
  if [[ -n "$EMB_NAME" ]]; then
    id="$(echo "$list" | jq -r --arg n "$EMB_NAME" '[.[] | select(.model_name==$n or .name==$n)] | .[0].model_id // .[0].id // empty')"
    [[ -n "$id" ]] || { err "目标平台没有名为 '$EMB_NAME' 的 embedding 小模型"; return 1; }
  else
    local cnt; cnt="$(echo "$list" | jq 'length')"
    if [[ "$cnt" -eq 0 ]]; then
      err "目标平台没有任何 embedding 小模型 — 先在模型工厂注册一个 (kweaver model small add ... --type embedding)"; return 1
    fi
    id="$(echo "$list" | jq -r '.[0].model_id // .[0].id // empty')"
    if [[ "$cnt" -gt 1 ]]; then
      note "  平台有 $cnt 个 embedding 小模型,默认取第一个 id=$id;如需指定用 --embedding-id 或 --embedding-name。"
      echo "$list" | jq -r '.[] | "    - \(.model_id // .id)  \(.model_name // .name)"' >&2
    fi
  fi
  echo "$id"
}

EMB_RESOLVED="$(resolve_embedding_id)" || exit 1
ok "embedding 小模型 id = $EMB_RESOLVED"

# ---------- 2. 解析 data_view id,按表名(老 data_view 模型,保持 type=data_view) ----------
# 抽取所有 data_source 名字(对象类 + 关系类)
NAMES="$(jq -r '[.. | .data_source? // empty | select(type=="object") | .name? // empty] | unique[]' "$IN")"

# bash 3.2 (macOS) 无关联数组:用 jq 累加 name->id map,计数另存。
MAP_JSON="{}"
RESOLVED_COUNT=0
UNRESOLVED=()

# 老平台用 data_view 模型:数据视图在 /api/mdl-data-model/v1/data-views。
# 新版 SDK(0.8.x)已删掉 `kweaver dataview` 子命令,但 `kweaver call` 能直接打这个老端点 —— 无需降级 SDK。
# 预取该数据源下全部 data_view 一次,再按 name / technical_name / meta_table_name 匹配 demo.json 里的表名。
DV_LIST="[]"
if [[ -n "$DS_ID" ]]; then
  dv_tmp="$(mktemp)"; dv_err="$(mktemp)"
  if kweaver call "/api/mdl-data-model/v1/data-views?data_source_id=${DS_ID}&limit=500" >"$dv_tmp" 2>"$dv_err"; then
    DV_LIST="$(jq -c '(.entries // .data // .data.list // []) | map({name, technical_name, meta_table_name, id})' "$dv_tmp" 2>/dev/null || echo "[]")"
  else
    [[ -s "$dv_err" ]] && cat "$dv_err" >&2
    note "  WARN: 拉取 data_view 列表失败(GET /api/mdl-data-model/v1/data-views)"
  fi
  rm -f "$dv_tmp" "$dv_err"
else
  note "  未给 --datasource-id:无法解析 data_view id(老平台请传 data-connection 数据源 id,见 /api/data-connection/v1/datasource)"
fi

# demo.json 的 data_source.name 是表名;data_view 可能 name=显示名、technical_name/meta_table_name=表名,逐字段精确比对。
resolve_view_id() {
  local name="$1"
  echo "$DV_LIST" | jq -r --arg n "$name" '
    [ .[] | select(.name==$n or .technical_name==$n or .meta_table_name==$n) ] | .[0].id // empty
  ' 2>/dev/null
}

if [[ -n "$NAMES" ]]; then
  echo "解析 data_view id (datasource=${DS_ID:-<未指定>}) ..." >&2
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    rid="$(resolve_view_id "$name" || true)"
    if [[ -n "$rid" ]]; then
      MAP_JSON="$(echo "$MAP_JSON" | jq --arg k "$name" --arg v "$rid" '. + {($k): $v}')"
      RESOLVED_COUNT=$((RESOLVED_COUNT + 1))
      echo "  $name -> $rid" >&2
    else
      UNRESOLVED+=("$name")
      note "  WARN: 数据源里找不到表名为 '$name' 的 data_view — 该对象 data_source.id 保持不变"
    fi
  done <<< "$NAMES"
fi

# ---------- 3. jq 一次性改写:vector_config.model_id + data_source.id ----------
jq --arg emb "$EMB_RESOLVED" --argjson map "$MAP_JSON" '
  walk(
    if type=="object" and has("vector_config") and (.vector_config|type=="object") then
      .vector_config |= (if .enabled==true then .model_id=$emb else .model_id="" end)
    else . end
  )
  | walk(
    if type=="object" and has("data_source") and (.data_source|type=="object")
       and (.data_source.name? != null) and ($map[.data_source.name] != null) then
      # 老 data_view 模型:只替换 id,保持 type=data_view(不转 resource)。
      .data_source.id = $map[.data_source.name]
    else . end
  )
  | (if $strip and (.action_types? != null) then .action_types = [] else . end)
' --argjson strip "$STRIP_ACTIONS" "$IN" > "$OUT"

PATCHED_VEC="$(jq '[.. | objects | select(has("vector_config")) | .vector_config | select(.enabled==true)] | length' "$OUT")"
ORIG_ACTIONS="$(jq '(.action_types // []) | length' "$IN")"
ok "已写出: $OUT"
ok "  - 向量字段填入 embedding id: $PATCHED_VEC 处"
ok "  - data_view id 替换: ${RESOLVED_COUNT} 个 (未解析: ${#UNRESOLVED[@]})"
if [[ "$STRIP_ACTIONS" == true ]] && [[ "$ORIG_ACTIONS" -gt 0 ]]; then
  note "  - 已剥离 ${ORIG_ACTIONS} 个行动类(--strip-actions):其 tool binding(box_id/tool_id)是宿主平台的,导入后请在 Studio 重新绑定工具。"
elif [[ "$ORIG_ACTIONS" -gt 0 ]]; then
  note "  - 注意:有 ${ORIG_ACTIONS} 个行动类带写死的 tool binding(box_id/tool_id);若目标平台无对应工具箱,导入会报「工具箱不存在」。可加 --strip-actions 先剥离。"
fi

if [[ ${#UNRESOLVED[@]} -gt 0 ]]; then
  note "未解析的 data_view (该数据源下没有同表名的数据视图,需先在平台为这些表建 data_view):"
  printf '    - %s\n' "${UNRESOLVED[@]}" >&2
  if [[ "$STRICT" == true ]]; then
    err "strict: 有未解析的 data_view,终止。"; exit 1
  fi
fi

cat >&2 <<EOF

下一步:导入打好补丁的 JSON:
  - 在 Studio -> BKN 用 $OUT 导入,或调 BKN 导入 API。
  - 小模型仍报错时:确认 $EMB_RESOLVED 在目标平台存在(kweaver model small list)且其后端可用(账号未欠费),
    否则对象类概念索引/向量化会报 ExternalSmallModel.UnknownError。
EOF

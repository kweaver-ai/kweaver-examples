#!/usr/bin/env bash
# Supply-chain case: push BKN, import agent/dataflow/tools, optional data source — this directory is the case root.
# Prerequisite: kweaver CLI installed and `kweaver auth login <url>` completed (-k if self-signed; --no-auth if no OAuth).
# Product docs: https://github.com/kweaver-ai/kweaver-core/tree/main/help (quick-start, datasource, bkn, decision-agent, model)
# Run from this directory: cd supply_chain && ./bootstrap.sh [options]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CASE_DIR="$SCRIPT_DIR"
CASE_NAME="$(basename "$CASE_DIR")"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
  cat <<'EOF'
Usage: ./bootstrap.sh [options]

Run this script from the supply_chain directory (it always uses this directory as the case root).

Options:
  --only STEPS           Comma-separated: data_source,bkn,agents,dataflow,tools
  --dry-run              Print planned actions only
  --yes, -y              Non-interactive (skip prompts; use --ds-* for data source)
  --bd DOMAIN            x-business-domain header (default: bd_public or KWEAVER_BUSINESS_DOMAIN)
  --ds-type TYPE         Database type for kweaver ds connect (default: mysql)
  --ds-name NAME         Display name for the data source
  --ds-host HOST
  --ds-port PORT         (default: 3306 for mysql)
  --ds-db DATABASE
  --ds-user USER
  --ds-pass PASS
  --ds-schema SCHEMA     Optional (postgresql/oracle/...)
  --insecure, -k         Skip TLS verify (curl -k; also NODE_TLS_REJECT_UNAUTHORIZED=0 for kweaver)
  --skip-data-source     Skip data_source step (e.g. datasource already connected on the platform)
  --skip-bkn-validate    Skip "kweaver bkn validate" before push (not recommended)
  --sync-dataviews       Before bkn validate/push: patch object_types/*.bkn data_view UUIDs from the platform
  --strict-dataviews     With --sync-dataviews: fail if any data_view row cannot be resolved (CI-safe)
  --datasource-id ID     Datasource UUID for --sync-dataviews (or env KWEAVER_DATASOURCE_ID)
  --bkn-staging          Copy bkn/ to a temp dir, patch/push there (repo unchanged; pairs well with --sync-dataviews)
  --agent-bind-kn        After imports: kweaver agent update --knowledge-network-id (matches network.bkn name + agent key)
  --agent-publish        After --agent-bind-kn (and optional LLM): kweaver agent publish
  --llm-id ID            Set default LLM id in imported agent config (see model manager)
  --embedding-id ID      Small / embedding model id for knowledge-network indexing (see model manager)
  --pick-models          Query models via kweaver, then interactively choose 大模型 + 小模型 (use with -y and --llm-id + --embedding-id for CI)
  --auto-llm             Pick first LLM from GET /api/mf-model-manager/v1/llm/list (ignored if --pick-models)
  --retries N            Retry transient API/kweaver failures (default: 3; use 1 to disable backoff)
  --retry-delay SEC      Seconds between retries (default: 8)
  --skip-preflight       Skip scripts/preflight.sh (not recommended)
  --ignore-state-deps    Allow --only <step> even if state file shows prerequisites missing
  --rollback-last        Undo the last recorded reversible action (publish / bind / set_llm), then exit

Prerequisites (see kweaver-core help):
  - CLI: npm i -g @kweaver-ai/kweaver-sdk (Node 22+)
  - jq: for JSON patching in scripts (bootstrap post-config, dataview patch, agent bind, LLM helper)
  - Auth: kweaver auth login <platform-url>  (add -k for self-signed HTTPS)
  - No-OAuth deployments: kweaver auth login <url> --no-auth
  - Business domain: use --bd or KWEAVER_BUSINESS_DOMAIN; minimal installs may not support
    kweaver config list-bd / set-bd (404 is expected — rely on config show)

Examples:
  ./bootstrap.sh
  ./bootstrap.sh --only bkn,agents
  ./bootstrap.sh -y -k --skip-data-source
  ./bootstrap.sh -y -k --skip-data-source --datasource-id <ds-uuid> --sync-dataviews \\
      --bkn-staging --agent-bind-kn --auto-llm --agent-publish
  ./bootstrap.sh -y --ds-host db.internal --ds-db tem --ds-user root --ds-pass secret

State / rollback:
  Progress is recorded in .kweaver_bootstrap_state.json (step completion + rollback stack).
  Reversible post-config actions (publish, bind KN, set LLM) can be undone one at a time:
    ./bootstrap.sh --rollback-last
EOF
}

YES=false
DRY_RUN=false
ONLY_RAW=""
BD="${KWEAVER_BUSINESS_DOMAIN:-bd_public}"
DS_TYPE="mysql"
DS_NAME=""
DS_HOST=""
DS_PORT=""
DS_DB=""
DS_USER=""
DS_PASS=""
DS_SCHEMA=""
CURL_INSECURE=false
SKIP_DATA_SOURCE=false
SKIP_BKN_VALIDATE=false
SYNC_DATAVIEWS=false
DATASOURCE_ID="${KWEAVER_DATASOURCE_ID:-}"
AGENT_BIND_KN=false
AGENT_PUBLISH=false
AUTO_LLM=false
PICK_MODELS=false
LLM_ID=""
EMBEDDING_ID=""
BKN_STAGING=false
STRICT_DATAVIEWS=false
RETRIES=3
RETRY_DELAY_SEC=8
SKIP_PREFLIGHT=false
IGNORE_STATE_DEPS=false
ROLLBACK_LAST=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --only) ONLY_RAW="${2:-}"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --yes|-y) YES=true; shift ;;
    --bd) BD="${2:-}"; shift 2 ;;
    --ds-type) DS_TYPE="${2:-}"; shift 2 ;;
    --ds-name) DS_NAME="${2:-}"; shift 2 ;;
    --ds-host) DS_HOST="${2:-}"; shift 2 ;;
    --ds-port) DS_PORT="${2:-}"; shift 2 ;;
    --ds-db) DS_DB="${2:-}"; shift 2 ;;
    --ds-user) DS_USER="${2:-}"; shift 2 ;;
    --ds-pass) DS_PASS="${2:-}"; shift 2 ;;
    --ds-schema) DS_SCHEMA="${2:-}"; shift 2 ;;
    --insecure|-k) CURL_INSECURE=true; shift ;;
    --skip-data-source) SKIP_DATA_SOURCE=true; shift ;;
    --skip-bkn-validate) SKIP_BKN_VALIDATE=true; shift ;;
    --sync-dataviews) SYNC_DATAVIEWS=true; shift ;;
    --strict-dataviews) STRICT_DATAVIEWS=true; shift ;;
    --datasource-id) DATASOURCE_ID="${2:-}"; shift 2 ;;
    --agent-bind-kn) AGENT_BIND_KN=true; shift ;;
    --agent-publish) AGENT_PUBLISH=true; shift ;;
    --llm-id) LLM_ID="${2:-}"; shift 2 ;;
    --embedding-id) EMBEDDING_ID="${2:-}"; shift 2 ;;
    --pick-models) PICK_MODELS=true; shift ;;
    --auto-llm) AUTO_LLM=true; shift ;;
    --bkn-staging) BKN_STAGING=true; shift ;;
    --retries) RETRIES="${2:-3}"; shift 2 ;;
    --retry-delay) RETRY_DELAY_SEC="${2:-8}"; shift 2 ;;
    --skip-preflight) SKIP_PREFLIGHT=true; shift ;;
    --ignore-state-deps) IGNORE_STATE_DEPS=true; shift ;;
    --rollback-last) ROLLBACK_LAST=true; shift ;;
    *) echo -e "${RED}Unknown option: $1${NC}" >&2; usage; exit 2 ;;
  esac
done

[[ "$RETRIES" =~ ^[0-9]+$ ]] && [[ "$RETRIES" -ge 1 ]] || { echo -e "${RED}--retries must be a positive integer${NC}" >&2; exit 2; }
[[ "$RETRY_DELAY_SEC" =~ ^[0-9]+$ ]] || { echo -e "${RED}--retry-delay must be a non-negative integer${NC}" >&2; exit 2; }

if [[ "$SYNC_DATAVIEWS" == true ]] && [[ -z "$DATASOURCE_ID" ]]; then
  echo -e "${RED}--sync-dataviews requires --datasource-id or KWEAVER_DATASOURCE_ID${NC}" >&2
  exit 2
fi
if [[ "$STRICT_DATAVIEWS" == true ]] && [[ "$SYNC_DATAVIEWS" != true ]]; then
  echo -e "${RED}--strict-dataviews only applies with --sync-dataviews${NC}" >&2
  exit 2
fi
if [[ "$SYNC_DATAVIEWS" == true ]] && [[ -n "$DATASOURCE_ID" ]]; then
  if [[ ! "$DATASOURCE_ID" =~ ^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$ ]]; then
    echo -e "${RED}--datasource-id does not look like a UUID: $DATASOURCE_ID${NC}" >&2
    exit 2
  fi
fi

# jq is required for dataview sync and post-config (agent id / KN / LLM / embedding).
if [[ "$SYNC_DATAVIEWS" == true ]] || [[ "$AGENT_BIND_KN" == true || "$AGENT_PUBLISH" == true || "$AUTO_LLM" == true || "$PICK_MODELS" == true || -n "$LLM_ID" || -n "$EMBEDDING_ID" ]]; then
  command -v jq >/dev/null 2>&1 || {
    echo -e "${RED}This run needs jq (brew install jq).${NC}" >&2
    exit 1
  }
fi
if [[ "$AGENT_PUBLISH" == true ]] && [[ "$AGENT_BIND_KN" != true ]]; then
  echo -e "${YELLOW}Note: --agent-publish without --agent-bind-kn — ensure the agent already has the correct knowledge network in Studio.${NC}" >&2
fi
if [[ "$PICK_MODELS" == true ]] && [[ "$AUTO_LLM" == true ]]; then
  echo -e "${YELLOW}Note: --pick-models supersedes --auto-llm for default LLM selection.${NC}" >&2
fi
if [[ "$PICK_MODELS" == true ]] && [[ "$YES" == true ]]; then
  if [[ -z "$LLM_ID" || -z "$EMBEDDING_ID" ]]; then
    echo -e "${RED}--pick-models with -y requires both --llm-id and --embedding-id (non-interactive).${NC}" >&2
    exit 2
  fi
fi

# shellcheck source=/dev/null
source "$SCRIPT_DIR/scripts/bootstrap_state.sh"

POST_CFG_FLAGS=false
[[ "$AGENT_BIND_KN" == true || "$AGENT_PUBLISH" == true || "$AUTO_LLM" == true || "$PICK_MODELS" == true || -n "$LLM_ID" || -n "$EMBEDDING_ID" ]] && POST_CFG_FLAGS=true

SESSION_DONE=""
session_mark_done() { SESSION_DONE="$SESSION_DONE $1"; }
session_is_done() {
  local s="$1"
  [[ " $SESSION_DONE " == *" $s "* ]]
}

# Self-signed HTTPS: kweaver (Node) needs this; curl uses -k via curl_api.
if [[ "$CURL_INSECURE" == true ]]; then
  export NODE_TLS_REJECT_UNAUTHORIZED=0
fi

command -v kweaver >/dev/null 2>&1 || {
  echo -e "${RED}kweaver CLI not found. Install: npm i -g @kweaver-ai/kweaver-sdk${NC}" >&2
  exit 1
}

BASE_URL="$(kweaver config show 2>/dev/null | awk -F': +' '/^Platform:/ {print $2; exit}')"
BASE_URL="${BASE_URL%/}"
if [[ -z "$BASE_URL" ]]; then
  echo -e "${RED}Could not read platform URL from kweaver config. Run: kweaver auth login <url>${NC}" >&2
  exit 1
fi

TOKEN="$(kweaver token 2>/dev/null || true)"
if [[ -z "$TOKEN" ]]; then
  echo -e "${RED}No access token. Run: kweaver auth login <url>${NC}" >&2
  exit 1
fi
if [[ "$TOKEN" == "__NO_AUTH__" ]]; then
  echo -e "${YELLOW}Note: CLI is in no-auth mode (kweaver auth login <url> --no-auth). APIs must allow unauthenticated access.${NC}" >&2
fi

if [[ "$ROLLBACK_LAST" == true ]]; then
  command -v jq >/dev/null 2>&1 || { echo -e "${RED}jq required for rollback${NC}" >&2; exit 1; }
  RB_ENT="$(rollback_pop)"
  if [[ -z "$RB_ENT" ]] || [[ "$RB_ENT" == "null" ]] || ! echo "$RB_ENT" | jq -e '.op' >/dev/null 2>&1; then
    echo -e "${YELLOW}Rollback stack is empty — nothing to undo.${NC}" >&2
    exit 0
  fi
  echo -e "${YELLOW}--- Rollback (one step) ---${NC}"
  rollback_execute_one "$RB_ENT" || exit 1
  echo -e "${GREEN}Rollback finished.${NC}"
  exit 0
fi

if [[ "$SKIP_PREFLIGHT" != true ]] && [[ "$DRY_RUN" != true ]]; then
  PF_ARGS=("$CASE_DIR")
  [[ "$POST_CFG_FLAGS" == true ]] && PF_ARGS+=("--require-models")
  bash "$SCRIPT_DIR/scripts/preflight.sh" "${PF_ARGS[@]}" || exit 1
fi

curl_api() {
  local args=(-sS -X "$1" "${BASE_URL}$2" -H "Authorization: Bearer ${TOKEN}" -H "x-business-domain: ${BD}")
  [[ "$CURL_INSECURE" == true ]] && args=(-k "${args[@]}")
  shift 2
  curl "${args[@]}" "$@"
}

# Set by curl_post_capture: HTTP status and response body (JSON or HTML).
LAST_HTTP_CODE=""
LAST_HTTP_BODY=""

transient_http() {
  [[ "$1" == "502" || "$1" == "503" || "$1" == "504" ]] && return 0
  return 1
}

analyze_http_error() {
  local code="$1"
  local body="$2"
  echo -e "${RED}  Analysis:${NC}" >&2
  case "$code" in
    401|403)
      echo "  Auth or permission denied. Run: kweaver auth login <platform-url> (or check business domain: --bd / kweaver config set-bd)." >&2
      ;;
    404)
      echo "  API not found — wrong platform URL or route." >&2
      ;;
    504|502|503)
      echo "  Gateway/upstream timeout or overload. Confirm platform services; DB must be reachable from the server for ds connect." >&2
      ;;
    000|"")
      echo "  Network or TLS failure. For self-signed HTTPS use: -k" >&2
      ;;
    *)
      echo "  HTTP $code — see response snippet above." >&2
      ;;
  esac
  if echo "$body" | grep -qi 'self-signed\|certificate\|SSL'; then
    echo "  TLS: use ./bootstrap.sh ... -k so curl and kweaver skip verify." >&2
  fi
}

# POST with body written to temp file; sets LAST_HTTP_CODE / LAST_HTTP_BODY.
curl_post_capture() {
  local path="$1"
  shift
  local tmp code
  tmp="$(mktemp)"
  local args=(-sS -X POST "${BASE_URL}${path}" -H "Authorization: Bearer ${TOKEN}" -H "x-business-domain: ${BD}")
  [[ "$CURL_INSECURE" == true ]] && args=(-k "${args[@]}")
  code=$(curl "${args[@]}" -o "$tmp" -w "%{http_code}" "$@") || code="000"
  LAST_HTTP_BODY="$(cat "$tmp")"
  LAST_HTTP_CODE="$code"
  rm -f "$tmp"
}

import_agent_with_retry() {
  local f="$1"
  local attempt=1
  while [[ $attempt -le $RETRIES ]]; do
    curl_post_capture "/api/agent-factory/v3/agent-inout/import" \
      -F "file=@${f};type=application/json" \
      -F "import_type=create"
    if [[ "$LAST_HTTP_CODE" =~ ^2 ]]; then
      echo "$LAST_HTTP_BODY" | head -c 600
      echo ""
      if echo "$LAST_HTTP_BODY" | grep -q '"is_success"[[:space:]]*:[[:space:]]*true'; then
        echo -e "${GREEN}  Agent import OK (is_success=true).${NC}"
        return 0
      fi
      # Idempotent: same agent already exists (create import returns conflict, not an error).
      if echo "$LAST_HTTP_BODY" | grep -q 'agent_key_conflict'; then
        echo -e "${YELLOW}  Agent already exists (agent_key_conflict); treating as success.${NC}"
        return 0
      fi
      echo -e "${RED}  HTTP $LAST_HTTP_CODE but is_success is not true:${NC}" >&2
      echo "$LAST_HTTP_BODY" >&2
      return 1
    fi
    echo -e "${YELLOW}  HTTP $LAST_HTTP_CODE${NC}" >&2
    echo "$LAST_HTTP_BODY" | head -c 600 >&2
    echo "" >&2
    if transient_http "$LAST_HTTP_CODE" && [[ $attempt -lt $RETRIES ]]; then
      echo -e "${YELLOW}  Retrying agent import ($((attempt + 1))/$RETRIES) in ${RETRY_DELAY_SEC}s...${NC}" >&2
      sleep "$RETRY_DELAY_SEC"
      attempt=$((attempt + 1))
      continue
    fi
    analyze_http_error "$LAST_HTTP_CODE" "$LAST_HTTP_BODY"
    return 1
  done
  return 1
}

import_dataflow_with_retry() {
  local f="$1"
  local attempt=1
  while [[ $attempt -le $RETRIES ]]; do
    curl_post_capture "/api/automation/v1/data-flow/flow" \
      -H "Content-Type: application/json" \
      --data-binary @"$f"
    # Duplicate name may be HTTP 200 or 400 depending on platform version.
    if echo "$LAST_HTTP_BODY" | grep -q 'DuplicatedName'; then
      echo -e "${YELLOW}  Dataflow name already exists (DuplicatedName); treating as success.${NC}"
      echo "$LAST_HTTP_BODY" | head -c 400
      echo ""
      return 0
    fi
    if [[ "$LAST_HTTP_CODE" =~ ^2 ]]; then
      echo "$LAST_HTTP_BODY" | head -c 600
      echo ""
      echo -e "${GREEN}  Dataflow import OK.${NC}"
      return 0
    fi
    echo -e "${YELLOW}  HTTP $LAST_HTTP_CODE${NC}" >&2
    echo "$LAST_HTTP_BODY" | head -c 600 >&2
    echo "" >&2
    if transient_http "$LAST_HTTP_CODE" && [[ $attempt -lt $RETRIES ]]; then
      echo -e "${YELLOW}  Retrying dataflow import ($((attempt + 1))/$RETRIES) in ${RETRY_DELAY_SEC}s...${NC}" >&2
      sleep "$RETRY_DELAY_SEC"
      attempt=$((attempt + 1))
      continue
    fi
    analyze_http_error "$LAST_HTTP_CODE" "$LAST_HTTP_BODY"
    return 1
  done
  return 1
}

import_toolbox_with_retry() {
  local f="$1"
  local attempt=1
  while [[ $attempt -le $RETRIES ]]; do
    curl_post_capture "/api/agent-operator-integration/v1/impex/import/toolbox" \
      -F "data=@${f}" \
      -F "mode=upsert"
    if [[ "$LAST_HTTP_CODE" =~ ^2 ]]; then
      echo "$LAST_HTTP_BODY" | head -c 600
      echo ""
      echo -e "${GREEN}  Toolbox import OK (HTTP $LAST_HTTP_CODE).${NC}"
      return 0
    fi
    echo -e "${YELLOW}  HTTP $LAST_HTTP_CODE${NC}" >&2
    echo "$LAST_HTTP_BODY" | head -c 600 >&2
    echo "" >&2
    if transient_http "$LAST_HTTP_CODE" && [[ $attempt -lt $RETRIES ]]; then
      echo -e "${YELLOW}  Retrying toolbox import ($((attempt + 1))/$RETRIES) in ${RETRY_DELAY_SEC}s...${NC}" >&2
      sleep "$RETRY_DELAY_SEC"
      attempt=$((attempt + 1))
      continue
    fi
    analyze_http_error "$LAST_HTTP_CODE" "$LAST_HTTP_BODY"
    return 1
  done
  return 1
}

# Run kweaver and retry on failure (embeddings, transient backend).
kweaver_retry() {
  local desc="$1"
  shift
  local attempt=1 out
  while [[ $attempt -le $RETRIES ]]; do
    out="$(mktemp)"
    if "$@" >"$out" 2>&1; then
      cat "$out"
      rm -f "$out"
      return 0
    fi
    cat "$out" >&2
    rm -f "$out"
    if [[ $attempt -lt $RETRIES ]]; then
      echo -e "${YELLOW}  ${desc} failed, retry $attempt/$RETRIES in ${RETRY_DELAY_SEC}s...${NC}" >&2
      sleep "$RETRY_DELAY_SEC"
    fi
    attempt=$((attempt + 1))
  done
  echo -e "${RED}  ${desc} failed after $RETRIES attempts.${NC}" >&2
  echo -e "${YELLOW}  If the log mentions OpenSearch, vector, or embedding batch size, fix the platform indexing/model service.${NC}" >&2
  echo -e "${YELLOW}  For ds connect timeouts, ensure the DB accepts connections from the platform (not only localhost).${NC}" >&2
  return 1
}

prompt() {
  local msg="$1"
  local default="${2:-}"
  local val
  if [[ "$YES" == true ]]; then
    echo "${default}"
    return
  fi
  if [[ -n "$default" ]]; then
    read -r -p "  ${msg} [${default}] > " val || true
    echo "${val:-$default}"
  else
    read -r -p "  ${msg} > " val || true
    echo "$val"
  fi
}

should_run_step() {
  local step="$1"
  [[ "$step" == "data_source" && "$SKIP_DATA_SOURCE" == true ]] && return 1
  [[ -z "$ONLY_RAW" ]] && return 0
  IFS=',' read -ra parts <<< "$ONLY_RAW"
  for p in "${parts[@]}"; do
    [[ "${p// /}" == "$step" ]] && return 0
  done
  return 1
}

declare -a AVAILABLE_STEPS=()
[[ -d "$CASE_DIR/data_source" && "$SKIP_DATA_SOURCE" != true ]] && AVAILABLE_STEPS+=("data_source")
[[ -f "$CASE_DIR/bkn/network.bkn" ]] && AVAILABLE_STEPS+=("bkn")
compgen -G "$CASE_DIR/agents/"*.json >/dev/null 2>&1 && AVAILABLE_STEPS+=("agents")
compgen -G "$CASE_DIR/dataflow/"*.json >/dev/null 2>&1 && AVAILABLE_STEPS+=("dataflow")
compgen -G "$CASE_DIR/tools/"*.adp >/dev/null 2>&1 && AVAILABLE_STEPS+=("tools")

if [[ ${#AVAILABLE_STEPS[@]} -eq 0 ]]; then
  echo -e "${RED}No bootstrap resources found under $CASE_DIR${NC}" >&2
  exit 1
fi

echo -e "${GREEN}=== KWeaver bootstrap: ${CASE_NAME} ===${NC}"
echo ""
echo "Discovered steps:"
local_i=1
for s in "${AVAILABLE_STEPS[@]}"; do
  case "$s" in
    data_source)
      sql_n=0
      if compgen -G "$CASE_DIR/data_source/"*.sql >/dev/null 2>&1; then
        sql_n=$(ls -1 "$CASE_DIR/data_source/"*.sql 2>/dev/null | wc -l | tr -d ' ')
      fi
      echo "  [${local_i}] data_source  (${sql_n} .sql file(s); load manually before connect)"
      ;;
    bkn)
      ot=$(find "$CASE_DIR/bkn/object_types" -name '*.bkn' 2>/dev/null | wc -l | tr -d ' ')
      rt=$(find "$CASE_DIR/bkn/relation_types" -name '*.bkn' 2>/dev/null | wc -l | tr -d ' ')
      cg=$(find "$CASE_DIR/bkn/concept_groups" -name '*.bkn' 2>/dev/null | wc -l | tr -d ' ')
      echo "  [${local_i}] bkn          (${ot} object types, ${rt} relation types, ${cg} concept groups)"
      ;;
    agents)
      echo "  [${local_i}] agents       ($(ls -1 "$CASE_DIR/agents/"*.json 2>/dev/null | xargs -I{} basename {} | tr '\n' ' '))"
      ;;
    dataflow)
      echo "  [${local_i}] dataflow     ($(ls -1 "$CASE_DIR/dataflow/"*.json 2>/dev/null | xargs -I{} basename {} | tr '\n' ' '))"
      ;;
    tools)
      echo "  [${local_i}] tools        ($(ls -1 "$CASE_DIR/tools/"*.adp 2>/dev/null | xargs -I{} basename {} | tr '\n' ' '))"
      ;;
  esac
  local_i=$((local_i + 1))
done
echo ""

SELECTED_STEPS=()
if [[ -n "$ONLY_RAW" ]]; then
  IFS=',' read -ra ONLY_ARR <<< "$ONLY_RAW"
  for o in "${ONLY_ARR[@]}"; do
    SELECTED_STEPS+=("${o// /}")
  done
elif [[ "$YES" == true ]]; then
  SELECTED_STEPS=("${AVAILABLE_STEPS[@]}")
else
  sel="$(prompt "Which steps to run? (comma-separated numbers, or 'all')" "all")"
  sel="${sel// /}"
  if [[ "$sel" == "all" || -z "$sel" ]]; then
    SELECTED_STEPS=("${AVAILABLE_STEPS[@]}")
  else
    IFS=',' read -ra nums <<< "$sel"
    for n in "${nums[@]}"; do
      idx=$((n))
      if [[ $idx -ge 1 && $idx -le ${#AVAILABLE_STEPS[@]} ]]; then
        SELECTED_STEPS+=("${AVAILABLE_STEPS[$((idx - 1))]}")
      fi
    done
  fi
fi

SELECTED_SORTED=()
for a in "${AVAILABLE_STEPS[@]}"; do
  for s in "${SELECTED_STEPS[@]}"; do
    [[ "$s" == "$a" ]] && SELECTED_SORTED+=("$a")
  done
done
if [[ ${#SELECTED_SORTED[@]} -gt 0 ]]; then
  SELECTED_STEPS=("${SELECTED_SORTED[@]}")
fi

step_in_selected() {
  local s="$1"
  for x in "${SELECTED_STEPS[@]}"; do
    [[ "$x" == "$s" ]] && return 0
  done
  return 1
}

step_previous_in_available() {
  local target="$1"
  local prev=""
  for s in "${AVAILABLE_STEPS[@]}"; do
    [[ "$s" == "$target" ]] && { echo "$prev"; return 0; }
    prev="$s"
  done
  echo ""
}

check_step_prerequisite() {
  local step="$1"
  [[ "$DRY_RUN" == true ]] && return 0
  [[ "$IGNORE_STATE_DEPS" == true ]] && return 0
  local prev
  prev="$(step_previous_in_available "$step")"
  [[ -z "$prev" ]] && return 0
  if step_in_selected "$prev"; then
    session_is_done "$prev" || {
      echo -e "${RED}Prerequisite failed: '$step' requires '$prev' completed earlier in this run.${NC}" >&2
      exit 1
    }
  else
    state_completed_p "$prev" || {
      echo -e "${RED}Prerequisite failed: '$step' requires completed '$prev' (see state: $(bootstrap_state_file)).${NC}" >&2
      echo -e "${YELLOW}Run ./bootstrap.sh --only $prev first, or omit --only. Override: --ignore-state-deps${NC}" >&2
      exit 1
    }
  fi
}

check_post_config_prereq() {
  [[ "$DRY_RUN" == true ]] || [[ "$IGNORE_STATE_DEPS" == true ]] && return 0
  local has_agents=false
  compgen -G "$CASE_DIR/agents/"*.json >/dev/null 2>&1 && has_agents=true
  if [[ "$has_agents" != true ]]; then
    echo -e "${RED}Post-config requires agents/*.json${NC}" >&2
    exit 1
  fi
  if step_in_selected "agents"; then
    session_is_done "agents" || { echo -e "${RED}Post-config requires agents step to succeed first.${NC}" >&2; exit 1; }
  else
    state_completed_p "agents" || {
      echo -e "${RED}Post-config requires agents import completed (e.g. ./bootstrap.sh --only agents).${NC}" >&2
      exit 1
    }
  fi
}

run_title() {
  echo -e "${YELLOW}--- $1 ---${NC}"
}

SKIP_DS=false

# --- data_source ---
if should_run_step "data_source" && step_in_selected "data_source" && [[ -d "$CASE_DIR/data_source" ]]; then
  check_step_prerequisite "data_source"
  if [[ "$YES" == true ]]; then
    if [[ -z "$DS_HOST" || -z "$DS_DB" || -z "$DS_USER" ]]; then
      echo -e "${RED}Non-interactive mode requires --ds-host, --ds-db, and --ds-user.${NC}" >&2
      exit 1
    fi
  else
    echo "Note: load any .sql under data_source/ into your database before connecting."
    c="$(prompt "Create data source connection now? (y/n)" "y")"
    cl="$(echo "$c" | tr '[:upper:]' '[:lower:]')"
    if [[ ! "$cl" =~ ^y ]]; then
      SKIP_DS=true
      echo "Skipping data_source."
    fi
  fi
  if [[ "$SKIP_DS" != true ]]; then
    DS_HOST="${DS_HOST:-$(prompt "Host")}"
    default_port="3306"
    [[ "$DS_TYPE" == "postgresql" ]] && default_port="5432"
    DS_PORT="${DS_PORT:-$(prompt "Port" "$default_port")}"
    DS_DB="${DS_DB:-$(prompt "Database name")}"
    DS_USER="${DS_USER:-$(prompt "Username")}"
    if [[ "$YES" != true ]] && [[ -z "$DS_PASS" ]]; then
      read -r -s -p "  Password > " DS_PASS || true
      echo ""
    fi
    DS_NAME="${DS_NAME:-$(prompt "Data source display name" "$CASE_NAME")}"
    run_title "Create data source"
    if [[ "$DRY_RUN" == true ]]; then
      echo "  (dry-run) kweaver ds connect $DS_TYPE $DS_HOST $DS_PORT $DS_DB --account $DS_USER --name $DS_NAME"
    else
      # With `set -u`, expanding an empty array (`schema_args[@]`) errors; branch instead.
      if [[ -n "$DS_SCHEMA" ]]; then
        kweaver_retry "Data source connect" kweaver ds connect "$DS_TYPE" "$DS_HOST" "$DS_PORT" "$DS_DB" \
          --account "$DS_USER" --password "$DS_PASS" --name "$DS_NAME" --schema "$DS_SCHEMA" || exit 1
      else
        kweaver_retry "Data source connect" kweaver ds connect "$DS_TYPE" "$DS_HOST" "$DS_PORT" "$DS_DB" \
          --account "$DS_USER" --password "$DS_PASS" --name "$DS_NAME" || exit 1
      fi
      echo -e "${GREEN}  Data source step finished.${NC}"
      session_mark_done "data_source"
      state_mark_complete "data_source"
    fi
  fi
fi

# --- bkn ---
if should_run_step "bkn" && step_in_selected "bkn" && [[ -f "$CASE_DIR/bkn/network.bkn" ]]; then
  check_step_prerequisite "bkn"
  BKN_PUSH_ROOT="$CASE_DIR/bkn"
  BKN_STAGE=""
  if [[ "$BKN_STAGING" == true ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      echo "  (dry-run) cp -a $CASE_DIR/bkn -> \$TMPDIR/bkn-staging (then patch/validate/push from staging)"
    else
      BKN_STAGE="$(mktemp -d)"
      cp -a "$CASE_DIR/bkn/." "$BKN_STAGE/"
      BKN_PUSH_ROOT="$BKN_STAGE"
      trap '[[ -n "${BKN_STAGE:-}" ]] && rm -rf "$BKN_STAGE"' EXIT
    fi
  fi
  if [[ "$DRY_RUN" == true ]]; then
    if [[ "$SYNC_DATAVIEWS" == true ]]; then
      run_title "Sync data_view IDs from datasource"
      if [[ "$STRICT_DATAVIEWS" == true ]]; then
        echo "  (dry-run) $SCRIPT_DIR/scripts/patch_bkn_dataviews.sh --strict --datasource-id $DATASOURCE_ID $BKN_PUSH_ROOT"
      else
        echo "  (dry-run) $SCRIPT_DIR/scripts/patch_bkn_dataviews.sh --datasource-id $DATASOURCE_ID $BKN_PUSH_ROOT"
      fi
    fi
    if [[ "$SKIP_BKN_VALIDATE" != true ]]; then
      run_title "Validate BKN (local)"
      echo "  (dry-run) kweaver bkn validate $BKN_PUSH_ROOT"
    fi
    run_title "Push BKN"
    echo "  (dry-run) kweaver bkn push $BKN_PUSH_ROOT"
  else
    if [[ "$SYNC_DATAVIEWS" != true ]] && [[ "$SKIP_BKN_VALIDATE" != true ]]; then
      if compgen -G "$BKN_PUSH_ROOT/object_types"/*.bkn >/dev/null 2>&1 && grep -l '{{DV:' "$BKN_PUSH_ROOT/object_types"/*.bkn >/dev/null 2>&1; then
        echo -e "${RED}object_types/*.bkn use {{DV:...}} placeholders — run with --sync-dataviews --datasource-id <uuid>,${NC}" >&2
        echo -e "${RED}or use --skip-bkn-validate (not recommended).${NC}" >&2
        exit 1
      fi
    fi
    if [[ "$SYNC_DATAVIEWS" == true ]]; then
      run_title "Sync data_view IDs from datasource"
      if [[ "$STRICT_DATAVIEWS" == true ]]; then
        bash "$SCRIPT_DIR/scripts/patch_bkn_dataviews.sh" --strict --datasource-id "$DATASOURCE_ID" "$BKN_PUSH_ROOT" || exit 1
      else
        bash "$SCRIPT_DIR/scripts/patch_bkn_dataviews.sh" --datasource-id "$DATASOURCE_ID" "$BKN_PUSH_ROOT" || exit 1
      fi
    fi
    if [[ "$SKIP_BKN_VALIDATE" != true ]]; then
      run_title "Validate BKN (local)"
      kweaver bkn validate "$BKN_PUSH_ROOT" || exit 1
    fi
    run_title "Push BKN"
    kweaver_retry "BKN push" kweaver bkn push "$BKN_PUSH_ROOT" || exit 1
    echo -e "${GREEN}  BKN push finished.${NC}"
    session_mark_done "bkn"
    state_mark_complete "bkn"
  fi
fi

# --- agents ---
if should_run_step "agents" && step_in_selected "agents"; then
  check_step_prerequisite "agents"
  shopt -s nullglob
  for f in "$CASE_DIR/agents/"*.json; do
    run_title "Import agent $(basename "$f")"
    if [[ "$DRY_RUN" == true ]]; then
      echo "  (dry-run) POST .../agent-inout/import file=$f"
    else
      import_agent_with_retry "$f" || exit 1
    fi
  done
  shopt -u nullglob
  if [[ "$DRY_RUN" != true ]]; then
    session_mark_done "agents"
    state_mark_complete "agents"
  fi
fi

# --- dataflow ---
if should_run_step "dataflow" && step_in_selected "dataflow"; then
  check_step_prerequisite "dataflow"
  shopt -s nullglob
  for f in "$CASE_DIR/dataflow/"*.json; do
    run_title "Import dataflow $(basename "$f")"
    if [[ "$DRY_RUN" == true ]]; then
      echo "  (dry-run) POST .../data-flow/flow body=@$f"
    else
      import_dataflow_with_retry "$f" || exit 1
    fi
  done
  shopt -u nullglob
  if [[ "$DRY_RUN" != true ]]; then
    session_mark_done "dataflow"
    state_mark_complete "dataflow"
  fi
fi

# --- tools ---
if should_run_step "tools" && step_in_selected "tools"; then
  check_step_prerequisite "tools"
  shopt -s nullglob
  for f in "$CASE_DIR/tools/"*.adp; do
    run_title "Import toolbox $(basename "$f")"
    if [[ "$DRY_RUN" == true ]]; then
      echo "  (dry-run) POST .../impex/import/toolbox file=$f"
    else
      import_toolbox_with_retry "$f" || exit 1
    fi
  done
  shopt -u nullglob
  if [[ "$DRY_RUN" != true ]]; then
    session_mark_done "tools"
    state_mark_complete "tools"
  fi
fi

# --- post-config: bind agent to KN, set default LLM, publish (optional) ---
POST_CFG=false
[[ "$AGENT_BIND_KN" == true || "$AGENT_PUBLISH" == true || "$AUTO_LLM" == true || "$PICK_MODELS" == true || -n "$LLM_ID" || -n "$EMBEDDING_ID" ]] && POST_CFG=true

if [[ "$POST_CFG" == true ]] && [[ "$DRY_RUN" == true ]]; then
  run_title "Post-config (dry-run)"
  [[ "$AGENT_BIND_KN" == true ]] && echo "  (dry-run) $SCRIPT_DIR/scripts/agent_bind_kn.sh $CASE_DIR"
  [[ "$PICK_MODELS" == true ]] && echo "  (dry-run) scripts/select_models.sh (interactive) or use --llm-id + --embedding-id with -y"
  [[ "$PICK_MODELS" != true ]] && [[ "$AUTO_LLM" == true || -n "$LLM_ID" ]] && echo "  (dry-run) kweaver call .../llm/list + scripts/agent_set_llm.sh (if LLM resolved)"
  [[ -n "$EMBEDDING_ID" ]] && echo "  (dry-run) scripts/kn_set_embedding.sh <kn_id> $EMBEDDING_ID (after KN id resolved)"
  [[ "$AGENT_PUBLISH" == true ]] && echo "  (dry-run) kweaver agent publish <agent_id>"
fi

if [[ "$POST_CFG" == true ]] && [[ "$DRY_RUN" != true ]]; then
  check_post_config_prereq
  run_title "Post-config (agent / LLM / publish)"
  AGENT_JSON=""
  shopt -s nullglob
  for g in "$CASE_DIR/agents/"*.json; do AGENT_JSON="$g"; break; done
  shopt -u nullglob
  if [[ -z "$AGENT_JSON" ]]; then
    echo -e "${RED}Post-config requires agents/*.json under $CASE_DIR${NC}" >&2
    exit 1
  fi
  command -v jq >/dev/null 2>&1 || { echo -e "${RED}jq is required for post-config (brew install jq)${NC}" >&2; exit 1; }
  if ! jq -e '.agents | type == "array" and length > 0' "$AGENT_JSON" >/dev/null 2>&1; then
    echo -e "${RED}$AGENT_JSON must contain a non-empty .agents array${NC}" >&2
    exit 1
  fi
  AGENT_KEY="$(jq -r '.agents[0].key // empty' "$AGENT_JSON")"
  if [[ -z "$AGENT_KEY" ]]; then
    echo -e "${RED}Could not read .agents[0].key from $AGENT_JSON${NC}" >&2
    exit 1
  fi

  AGENT_OUT="$(mktemp)"
  AGENT_ERR="$(mktemp)"
  LIST_OUT=""
  LIST_ERR=""
  LLM_TMP=""
  LLM_ERR=""
  cleanup_post_tmp() {
    rm -f "$AGENT_OUT" "$AGENT_ERR" "${LIST_OUT:-}" "${LIST_ERR:-}" "${LLM_TMP:-}" "${LLM_ERR:-}" 2>/dev/null || true
  }
  # Preserve BKN staging cleanup (set earlier when --bkn-staging): chain with temp cleanup.
  trap 'cleanup_post_tmp; [[ -n "${BKN_STAGE:-}" ]] && rm -rf "$BKN_STAGE"' EXIT

  if ! kweaver agent get-by-key "$AGENT_KEY" --pretty >"$AGENT_OUT" 2>"$AGENT_ERR"; then
    echo -e "${RED}kweaver agent get-by-key failed for key=$AGENT_KEY${NC}" >&2
    [[ -s "$AGENT_ERR" ]] && cat "$AGENT_ERR" >&2
    exit 1
  fi
  if [[ ! -s "$AGENT_OUT" ]]; then
    echo -e "${RED}kweaver agent get-by-key returned empty body${NC}" >&2
    exit 1
  fi
  if ! jq -e . >/dev/null 2>&1 "$AGENT_OUT"; then
    echo -e "${RED}kweaver agent get-by-key returned invalid JSON${NC}" >&2
    exit 1
  fi
  AGENT_ID="$(jq -r '.id // empty' "$AGENT_OUT")"
  if [[ -z "$AGENT_ID" ]]; then
    echo -e "${RED}Could not resolve agent id for key $AGENT_KEY (no .id in response)${NC}" >&2
    exit 1
  fi

  OLD_KN="$(jq -r '.knowledge_network_id // .knowledgeNetworkId // .knowledge_network // empty' "$AGENT_OUT")"

  KN_ID=""
  KN_NAME=""
  if [[ -f "$CASE_DIR/bkn/network.bkn" ]]; then
    KN_NAME="$(awk '/^name:/{sub(/^name:[[:space:]]+/,""); print; exit}' "$CASE_DIR/bkn/network.bkn" | tr -d '\r')"
  fi

  resolve_kn_id_from_platform() {
    if [[ -z "$KN_NAME" ]]; then
      echo -e "${RED}Missing knowledge network name in bkn/network.bkn (name:).${NC}" >&2
      return 1
    fi
    LIST_OUT="$(mktemp)"
    LIST_ERR="$(mktemp)"
    if ! kweaver bkn list --name-pattern "$KN_NAME" --limit 30 --pretty >"$LIST_OUT" 2>"$LIST_ERR"; then
      echo -e "${RED}kweaver bkn list failed${NC}" >&2
      [[ -s "$LIST_ERR" ]] && cat "$LIST_ERR" >&2
      rm -f "$LIST_OUT" "$LIST_ERR"
      return 1
    fi
    if [[ ! -s "$LIST_OUT" ]] || ! jq -e . >/dev/null 2>&1 "$LIST_OUT"; then
      echo -e "${RED}kweaver bkn list returned empty or invalid JSON${NC}" >&2
      rm -f "$LIST_OUT" "$LIST_ERR"
      return 1
    fi
    KN_ID="$(jq -r --arg n "$KN_NAME" '
      (if type == "array" then . else (.entries // .data // []) end)
      | map(select(.name == $n)) | .[0].id // empty
    ' "$LIST_OUT")"
    rm -f "$LIST_OUT" "$LIST_ERR"
    if [[ -z "$KN_ID" ]]; then
      echo -e "${RED}Could not find knowledge network named exactly: $KN_NAME (push BKN first).${NC}" >&2
      return 1
    fi
    return 0
  }

  if [[ "$AGENT_BIND_KN" == true ]]; then
    if [[ ! -f "$CASE_DIR/bkn/network.bkn" ]]; then
      echo -e "${RED}--agent-bind-kn requires $CASE_DIR/bkn/network.bkn${NC}" >&2
      exit 1
    fi
    if [[ -z "$KN_NAME" ]]; then
      echo -e "${RED}Could not read knowledge network name from network.bkn${NC}" >&2
      exit 1
    fi
    resolve_kn_id_from_platform || exit 1
    echo "Binding agent $AGENT_ID to knowledge network $KN_ID ($KN_NAME) ..."
    kweaver_retry "Agent bind KN" kweaver agent update "$AGENT_ID" --knowledge-network-id "$KN_ID" || exit 1
    echo -e "${GREEN}  Knowledge network bound.${NC}"
    rollback_push "$(jq -nc --arg id "$AGENT_ID" --arg pk "$OLD_KN" '{op:"agent_bind_kn",agent_id:$id,previous_knowledge_network_id:$pk}')"
  fi

  RESOLVED_LLM_ID="$LLM_ID"
  RESOLVED_EMBEDDING_ID="$EMBEDDING_ID"
  SELECTED_LLM_ID=""
  SELECTED_EMBEDDING_ID=""

  if [[ "$PICK_MODELS" == true ]]; then
    if [[ "$YES" == true ]]; then
      RESOLVED_LLM_ID="$LLM_ID"
      RESOLVED_EMBEDDING_ID="$EMBEDDING_ID"
    else
      echo -e "${YELLOW}  Querying models (kweaver call .../llm/list); choose 大模型 and 小模型:${NC}" >&2
      eval "$(bash "$SCRIPT_DIR/scripts/select_models.sh")"
      RESOLVED_LLM_ID="${SELECTED_LLM_ID:-}"
      RESOLVED_EMBEDDING_ID="${SELECTED_EMBEDDING_ID:-}"
    fi
  fi

  if [[ "$PICK_MODELS" != true ]] && [[ "$AUTO_LLM" == true ]] && [[ -z "$LLM_ID" ]]; then
    LLM_TMP="$(mktemp)"
    LLM_ERR="$(mktemp)"
    if kweaver call "/api/mf-model-manager/v1/llm/list?page=1&size=50" --pretty >"$LLM_TMP" 2>"$LLM_ERR"; then
      if [[ -s "$LLM_TMP" ]] && jq -e . >/dev/null 2>&1 "$LLM_TMP"; then
        R="$(jq -r '
          (.data.records[0].id // .data.list[0].id // .data[0].id // .records[0].id // .list[0].id // empty)
        ' "$LLM_TMP")"
        if [[ -n "$R" ]]; then
          RESOLVED_LLM_ID="$R"
        else
          echo -e "${YELLOW}  --auto-llm: no LLM id in response (unexpected shape); skip.${NC}" >&2
          [[ -s "$LLM_ERR" ]] && echo -e "${YELLOW}  (stderr from kweaver call)${NC}" >&2 && cat "$LLM_ERR" >&2
        fi
      else
        echo -e "${YELLOW}  --auto-llm: empty or non-JSON response; skip.${NC}" >&2
        [[ -s "$LLM_ERR" ]] && cat "$LLM_ERR" >&2
      fi
    else
      echo -e "${YELLOW}  --auto-llm: kweaver call llm list failed; skip.${NC}" >&2
      [[ -s "$LLM_ERR" ]] && cat "$LLM_ERR" >&2
    fi
    rm -f "$LLM_TMP" "$LLM_ERR"
  fi

  if [[ -n "$RESOLVED_EMBEDDING_ID" ]] && [[ -z "$KN_ID" ]] && [[ -n "$KN_NAME" ]]; then
    echo "Resolving knowledge network id for embedding model (name: $KN_NAME) ..."
    resolve_kn_id_from_platform || exit 1
  fi

  if [[ -n "$RESOLVED_LLM_ID" ]]; then
    mkdir -p "$(bootstrap_backup_dir)"
    BKP_LLM="$(bootstrap_backup_dir)/agent_${AGENT_ID}_before_llm.json"
    if ! kweaver agent get "$AGENT_ID" --pretty >"$BKP_LLM" 2>/dev/null || [[ ! -s "$BKP_LLM" ]]; then
      echo -e "${YELLOW}  Could not snapshot agent config before LLM change — rollback for set_llm will not be available.${NC}" >&2
    fi
    bash "$SCRIPT_DIR/scripts/agent_set_llm.sh" "$AGENT_ID" "$RESOLVED_LLM_ID" || exit 1
    if [[ -s "$BKP_LLM" ]]; then
      rollback_push "$(jq -nc --arg id "$AGENT_ID" --arg p "$BKP_LLM" '{op:"agent_set_llm",agent_id:$id,backup_path:$p}')"
    fi
  fi
  if [[ -n "$RESOLVED_EMBEDDING_ID" ]]; then
    if [[ -n "$KN_ID" ]]; then
      bash "$SCRIPT_DIR/scripts/kn_set_embedding.sh" "$KN_ID" "$RESOLVED_EMBEDDING_ID" || true
    else
      echo -e "${YELLOW}  Skipping embedding model on KN: no knowledge network id (need bkn/network.bkn + pushed KN).${NC}" >&2
      echo -e "${YELLOW}  Selected embedding model id: $RESOLVED_EMBEDDING_ID — configure in Studio if needed.${NC}" >&2
    fi
  fi
  if [[ "$AGENT_PUBLISH" == true ]]; then
    kweaver_retry "Agent publish" kweaver agent publish "$AGENT_ID" || exit 1
    echo -e "${GREEN}  Agent published.${NC}"
    rollback_push "$(jq -nc --arg id "$AGENT_ID" '{op:"agent_publish",agent_id:$id}')"
  fi
  session_mark_done "post_config"
  state_mark_complete "post_config"
  cleanup_post_tmp
  trap - EXIT
  if [[ -n "${BKN_STAGE:-}" ]]; then
    trap '[[ -n "${BKN_STAGE:-}" ]] && rm -rf "$BKN_STAGE"' EXIT
  fi
fi

echo -e "${GREEN}=== Bootstrap complete ===${NC}"
echo ""
echo -e "${YELLOW}After import (see kweaver-core help — quick-start, model, decision-agent):${NC}"
echo "  - BKN push/indexing needs embedding + model config; failures often mean missing or misconfigured small embedding model."
echo "  - Use --sync-dataviews --datasource-id to avoid hand-editing data_view UUIDs in .bkn; use --agent-bind-kn / --llm-id / --agent-publish to reduce Studio steps."
echo "  - Tool IDs inside imported agent.json may still differ per platform (toolbox import creates new ids)."

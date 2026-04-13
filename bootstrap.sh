#!/usr/bin/env bash
# Bootstrap a case directory into a KWeaver platform (BKN, agents, dataflow, tools, data source).
# Prerequisite: kweaver CLI installed and `kweaver auth login <url>` completed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
  cat <<'EOF'
Usage: bootstrap.sh <case_dir> [options]

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
  --insecure, -k         Pass curl -k (skip TLS verify)

Examples:
  ./bootstrap.sh supply_chain
  ./bootstrap.sh supply_chain --only bkn,agents
  ./bootstrap.sh supply_chain -y --ds-host db.internal --ds-db tem --ds-user root --ds-pass secret
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

if [[ $# -lt 1 ]]; then
  usage
  exit 2
fi

CASE_DIR_ARG="$1"
shift || true

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
    *) echo -e "${RED}Unknown option: $1${NC}" >&2; usage; exit 2 ;;
  esac
done

resolve_case_dir() {
  local p="$1"
  if [[ -d "$p" ]]; then
    cd "$p" && pwd
    return
  fi
  if [[ -d "$SCRIPT_DIR/$p" ]]; then
    cd "$SCRIPT_DIR/$p" && pwd
    return
  fi
  echo -e "${RED}Case directory not found: $p${NC}" >&2
  exit 1
}

CASE_DIR="$(resolve_case_dir "$CASE_DIR_ARG")"
CASE_NAME="$(basename "$CASE_DIR")"

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

curl_api() {
  local args=(-sS -X "$1" "${BASE_URL}$2" -H "Authorization: Bearer ${TOKEN}" -H "x-business-domain: ${BD}")
  [[ "$CURL_INSECURE" == true ]] && args=(-k "${args[@]}")
  shift 2
  curl "${args[@]}" "$@"
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
  [[ -z "$ONLY_RAW" ]] && return 0
  IFS=',' read -ra parts <<< "$ONLY_RAW"
  for p in "${parts[@]}"; do
    [[ "${p// /}" == "$step" ]] && return 0
  done
  return 1
}

declare -a AVAILABLE_STEPS=()
[[ -d "$CASE_DIR/data_source" ]] && AVAILABLE_STEPS+=("data_source")
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

step_in_selected() {
  local s="$1"
  for x in "${SELECTED_STEPS[@]}"; do
    [[ "$x" == "$s" ]] && return 0
  done
  return 1
}

run_title() {
  echo -e "${YELLOW}--- $1 ---${NC}"
}

SKIP_DS=false

# --- data_source ---
if should_run_step "data_source" && step_in_selected "data_source" && [[ -d "$CASE_DIR/data_source" ]]; then
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
    schema_args=()
    [[ -n "$DS_SCHEMA" ]] && schema_args+=(--schema "$DS_SCHEMA")
    run_title "Create data source"
    if [[ "$DRY_RUN" == true ]]; then
      echo "  (dry-run) kweaver ds connect $DS_TYPE $DS_HOST $DS_PORT $DS_DB --account $DS_USER --name $DS_NAME"
    else
      kweaver ds connect "$DS_TYPE" "$DS_HOST" "$DS_PORT" "$DS_DB" \
        --account "$DS_USER" --password "$DS_PASS" --name "$DS_NAME" "${schema_args[@]}"
      echo -e "${GREEN}  Data source step finished.${NC}"
    fi
  fi
fi

# --- bkn ---
if should_run_step "bkn" && step_in_selected "bkn" && [[ -f "$CASE_DIR/bkn/network.bkn" ]]; then
  run_title "Push BKN"
  if [[ "$DRY_RUN" == true ]]; then
    echo "  (dry-run) kweaver bkn push $CASE_DIR/bkn"
  else
    kweaver bkn push "$CASE_DIR/bkn"
    echo -e "${GREEN}  BKN push finished.${NC}"
  fi
fi

# --- agents ---
if should_run_step "agents" && step_in_selected "agents"; then
  shopt -s nullglob
  for f in "$CASE_DIR/agents/"*.json; do
    run_title "Import agent $(basename "$f")"
    if [[ "$DRY_RUN" == true ]]; then
      echo "  (dry-run) POST .../agent-inout/import file=$f"
    else
      resp="$(curl_api POST "/api/agent-factory/v3/agent-inout/import" \
        -F "file=@${f};type=application/json" -F "import_type=create")"
      echo "$resp" | head -c 400
      echo ""
    fi
  done
  shopt -u nullglob
fi

# --- dataflow ---
if should_run_step "dataflow" && step_in_selected "dataflow"; then
  shopt -s nullglob
  for f in "$CASE_DIR/dataflow/"*.json; do
    run_title "Import dataflow $(basename "$f")"
    if [[ "$DRY_RUN" == true ]]; then
      echo "  (dry-run) POST .../data-flow/flow body=@$f"
    else
      curl_api POST "/api/automation/v1/data-flow/flow" \
        -H "Content-Type: application/json" --data-binary @"$f" | head -c 400
      echo ""
    fi
  done
  shopt -u nullglob
fi

# --- tools ---
if should_run_step "tools" && step_in_selected "tools"; then
  shopt -s nullglob
  for f in "$CASE_DIR/tools/"*.adp; do
    run_title "Import toolbox $(basename "$f")"
    if [[ "$DRY_RUN" == true ]]; then
      echo "  (dry-run) POST .../impex/import/toolbox file=$f"
    else
      curl_api POST "/api/agent-operator-integration/v1/impex/import/toolbox" \
        -F "data=@${f}" -F "mode=upsert" | head -c 400
      echo ""
    fi
  done
  shopt -u nullglob
fi

echo -e "${GREEN}=== Bootstrap complete ===${NC}"

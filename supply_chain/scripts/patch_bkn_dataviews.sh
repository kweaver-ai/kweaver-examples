#!/usr/bin/env bash
# Resolve atomic data_view IDs from the platform into object_types/*.bkn
#
# Two supported forms (middle column of the data_view table row):
#   1) Placeholder: {{DV:warehouse_entity}}  — resolved by name via kweaver dataview find
#   2) Legacy UUID: 8-4-4-4-12 hex — replaced when it differs from the resolved id (uses 4th column as view name)
#
# Usage: ./patch_bkn_dataviews.sh --datasource-id <uuid> <path/to/bkn_directory>
set -euo pipefail

DS_ID=""
BKN_ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --datasource-id) DS_ID="${2:-}"; shift 2 ;;
    -h|--help)
      cat <<'HELP'
Usage: patch_bkn_dataviews.sh --datasource-id <uuid> <path/to/bkn_directory>

In each object_types/*.bkn, the line:
  | data_view | <UUID or {{DV:logical_name}}> | <logical_name> |
is updated in place to:
  | data_view | <resolved-uuid> | <logical_name> |

Placeholders keep the repo environment-agnostic; run this before kweaver bkn validate/push.
HELP
      exit 0
      ;;
    *) BKN_ROOT="${1:-}"; shift ;;
  esac
done

if [[ -z "$DS_ID" || -z "$BKN_ROOT" ]]; then
  echo "Usage: $0 --datasource-id <uuid> <path/to/bkn_directory>" >&2
  exit 2
fi

OT_DIR="$BKN_ROOT/object_types"
if [[ ! -d "$OT_DIR" ]]; then
  echo "No object_types under $BKN_ROOT" >&2
  exit 1
fi

command -v kweaver >/dev/null 2>&1 || { echo "kweaver CLI not found" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 not found" >&2; exit 1; }

resolve_dataview_id() {
  local view_name="$1"
  local out
  if ! out="$(kweaver dataview find --name "$view_name" --exact --datasource-id "$DS_ID" --no-wait --pretty 2>/dev/null)"; then
    return 1
  fi
  python3 -c '
import json,sys
raw=sys.stdin.read()
if not raw.strip():
  sys.exit(1)
j=json.loads(raw)
def emit(x):
  if isinstance(x, dict) and x.get("id"):
    print(x["id"])
    raise SystemExit(0)
if isinstance(j, dict):
  emit(j)
  d = j.get("data")
  if isinstance(d, dict):
    emit(d)
  if isinstance(d, list) and d:
    emit(d[0])
if isinstance(j, list) and j:
  emit(j[0])
sys.exit(1)
' <<<"$out"
}

sed_i() {
  local expr="$1"
  local file="$2"
  if sed --version >/dev/null 2>&1; then
    sed -i "$expr" "$file"
  else
    sed -i '' "$expr" "$file"
  fi
}

patch_file() {
  local f="$1"
  local line new_id old_token view_name logical
  line="$(grep '| data_view |' "$f" | head -1 || true)"
  [[ -n "$line" ]] || return 0
  view_name="$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$4); print $4}')"
  old_token="$(echo "$line" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$3); print $3}')"
  [[ -n "$view_name" ]] || { echo "  skip (no view name column): $f" >&2; return 0; }

  if echo "$old_token" | grep -qE '^\{\{DV:[^}]+\}\}$'; then
    logical="$(echo "$old_token" | sed -n 's/^{{DV:\(.*\)}}$/\1/p')"
    new_id="$(resolve_dataview_id "$logical" || true)"
    if [[ -z "$new_id" ]]; then
      echo "  WARN: no atomic dataview for placeholder {{DV:$logical}} — $f" >&2
      return 0
    fi
    sed_i "s#| data_view | {{DV:${logical}}} |#| data_view | ${new_id} |#g" "$f"
    echo "  placeholder {{DV:${logical}}} -> $new_id  ($f)"
    return 0
  fi

  # Legacy: existing UUID in repo; resolve by table name (4th column)
  if [[ "$old_token" =~ ^[a-fA-F0-9-]{36}$ ]]; then
    new_id="$(resolve_dataview_id "$view_name" || true)"
    if [[ -z "$new_id" ]]; then
      echo "  WARN: no atomic dataview named '$view_name' — left unchanged: $f" >&2
      return 0
    fi
    if [[ "$new_id" == "$old_token" ]]; then
      echo "  OK (unchanged): $view_name"
      return 0
    fi
    sed_i "s#| data_view | ${old_token} |#| data_view | ${new_id} |#g" "$f"
    echo "  uuid $view_name  $old_token -> $new_id"
    return 0
  fi

  echo "  skip (unknown middle column): $f" >&2
}

echo "Patching data_view IDs under $OT_DIR (datasource=$DS_ID) ..."
shopt -s nullglob
for f in "$OT_DIR"/*.bkn; do
  patch_file "$f"
done
shopt -u nullglob
echo "Done."

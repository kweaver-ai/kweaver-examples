#!/usr/bin/env bash
# State + rollback helpers for supply_chain/bootstrap.sh (source this file).
# Expects: CASE_DIR, SCRIPT_DIR, kweaver, jq, RED, GREEN, YELLOW, NC set by caller.
#
# State file: $CASE_DIR/.kweaver_bootstrap_state.json
# Backup dir: $CASE_DIR/.bootstrap_backup/
#
# shellcheck shell=bash

bootstrap_state_file() {
  echo "${CASE_DIR:?}/.kweaver_bootstrap_state.json"
}

bootstrap_backup_dir() {
  echo "${CASE_DIR:?}/.bootstrap_backup"
}

state_read() {
  local f
  f="$(bootstrap_state_file)"
  if [[ -f "$f" ]]; then
    cat "$f"
  else
    echo '{"version":1,"completed":{},"rollback":[]}'
  fi
}

state_write() {
  local json="$1"
  local f
  f="$(bootstrap_state_file)"
  echo "$json" >"${f}.tmp"
  mv "${f}.tmp" "$f"
}

state_mark_complete() {
  local step="$1"
  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")"
  local out
  out="$(state_read | jq --arg s "$step" --arg t "$ts" '.completed[$s] = $t')"
  state_write "$out"
}

state_completed_p() {
  local step="$1"
  state_read | jq -e --arg s "$step" '(.completed | has($s))' >/dev/null 2>&1
}

rollback_push() {
  local op_json="$1"
  local out
  out="$(state_read | jq --argjson op "$op_json" '.rollback += [$op]')"
  state_write "$out"
}

# Pop last rollback entry and print JSON object to stdout; empty object if none.
rollback_pop() {
  local out top rest
  out="$(state_read)"
  top="$(echo "$out" | jq -c 'if (.rollback | length) > 0 then .rollback[-1] else empty end')"
  rest="$(echo "$out" | jq -c '.rollback |= if length > 0 then .[:-1] else [] end')"
  state_write "$rest"
  echo "$top"
}

rollback_execute_one() {
  local entry="$1"
  local op agent_id
  op="$(echo "$entry" | jq -r '.op // empty')"
  agent_id="$(echo "$entry" | jq -r '.agent_id // empty')"
  case "$op" in
    agent_publish)
      echo -e "${YELLOW}Rollback: kweaver agent unpublish $agent_id${NC}" >&2
      kweaver agent unpublish "$agent_id" || return 1
      ;;
    agent_bind_kn)
      local prev
      prev="$(echo "$entry" | jq -r '.previous_knowledge_network_id // ""')"
      echo -e "${YELLOW}Rollback: restore agent $agent_id KN binding to '${prev:-<empty>}'${NC}" >&2
      if [[ -z "$prev" ]]; then
        echo -e "${YELLOW}  (no previous KN id — skipping bind restore; fix in Studio if needed)${NC}" >&2
      else
        kweaver agent update "$agent_id" --knowledge-network-id "$prev" || return 1
      fi
      ;;
    agent_set_llm)
      local backup
      backup="$(echo "$entry" | jq -r '.backup_path // empty')"
      if [[ -z "$backup" || ! -f "$backup" ]]; then
        echo -e "${RED}Rollback set_llm: backup missing; cannot restore agent config.${NC}" >&2
        return 1
      fi
      echo -e "${YELLOW}Rollback: kweaver agent update $agent_id --config-path $backup${NC}" >&2
      kweaver agent update "$agent_id" --config-path "$backup" || return 1
      ;;
    kn_set_embedding)
      echo -e "${YELLOW}Rollback kn_set_embedding: not automated (restore previous KN embedding in Studio).${NC}" >&2
      echo "  kn_id=$(echo "$entry" | jq -r '.kn_id // empty') embedding=$(echo "$entry" | jq -r '.embedding_id // empty')" >&2
      ;;
    *)
      echo -e "${RED}Unknown rollback op: $op${NC}" >&2
      return 1
      ;;
  esac
  return 0
}

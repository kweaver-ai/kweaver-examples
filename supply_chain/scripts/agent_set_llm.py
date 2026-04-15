#!/usr/bin/env python3
"""Set default LLM id inside agent config (nested JSON string) and push via kweaver agent update."""
import json
import subprocess
import sys
import tempfile
import os


def main() -> None:
    if len(sys.argv) < 3:
        print("Usage: agent_set_llm.py <agent_id> <llm_id>", file=sys.stderr)
        sys.exit(2)
    agent_id, llm_id = sys.argv[1], sys.argv[2]
    r = subprocess.run(
        ["kweaver", "agent", "get", agent_id, "--pretty"],
        capture_output=True,
        text=True,
        check=True,
    )
    doc = json.loads(r.stdout)
    cfg = doc.get("config")
    if isinstance(cfg, str):
        inner = json.loads(cfg)
    elif isinstance(cfg, dict):
        inner = cfg
    else:
        print("Unexpected config shape", file=sys.stderr)
        sys.exit(1)
    llms = inner.get("llms")
    if not llms:
        print("No llms[] in agent config", file=sys.stderr)
        sys.exit(1)
    for lm in llms:
        if lm.get("is_default") or len(llms) == 1:
            lm.setdefault("llm_config", {})["id"] = llm_id
            break
    else:
        llms[0].setdefault("llm_config", {})["id"] = llm_id
    doc["config"] = json.dumps(inner, ensure_ascii=False)
    fd, path = tempfile.mkstemp(suffix=".json", prefix="agent-cfg-")
    os.close(fd)
    try:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(doc, f, ensure_ascii=False, indent=2)
        subprocess.run(
            ["kweaver", "agent", "update", agent_id, "--config-path", path],
            check=True,
        )
    finally:
        try:
            os.unlink(path)
        except OSError:
            pass
    print(f"OK: set default LLM id to {llm_id}")


if __name__ == "__main__":
    main()

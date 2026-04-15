#!/usr/bin/env python3
"""Read mf-model-manager llm/list JSON from stdin; print first model id or nothing."""
import json
import sys


def main() -> None:
    j = json.load(sys.stdin)
    d = j.get("data")
    if isinstance(d, dict):
        rec = d.get("records") or d.get("list") or d.get("items") or []
        if isinstance(rec, list) and rec:
            mid = rec[0].get("id")
            if mid:
                print(mid)
                return
    if isinstance(d, list) and d:
        mid = d[0].get("id")
        if mid:
            print(mid)
            return
    rows = j.get("records") or j.get("list") or []
    if isinstance(rows, list) and rows:
        mid = rows[0].get("id")
        if mid:
            print(mid)


if __name__ == "__main__":
    main()

# Supply chain example

This case mirrors assets from [kweaver-core `deploy/auto_cofig`](https://github.com/kweaver-ai/kweaver-core/tree/main/deploy/auto_cofig): demo MySQL schema, BKN definitions, a decision agent, a dataflow, and a toolbox package.

## Layout

| Directory | Contents |
|-----------|----------|
| `data_source/` | `dump-tem.sql` — import into MySQL **before** creating the platform data source |
| `bkn/` | Business knowledge network (`.bkn` modules); see `bkn/SKILL.md` |
| `agents/` | `agent.json` — supply-chain Q&A agent (import) |
| `dataflow/` | `dataflow.json` — evaluation / batch flow (import) |
| `tools/` | Structured data analysis toolbox `.adp` (import) |

## Prerequisites

1. **KWeaver CLI** — Node.js 22+, `npm i -g @kweaver-ai/kweaver-sdk`
2. **Login** — `kweaver auth login <your-platform-url>`
3. **MySQL** — create database, run `data_source/dump-tem.sql`, ensure the platform can reach the host

## Bootstrap (recommended)

From the repository root:

```bash
chmod +x bootstrap.sh   # once
./bootstrap.sh supply_chain
```

The script is **interactive by default** (English prompts). Use `-y` and `--ds-*` flags for automation; see `./bootstrap.sh --help`.

Typical order:

1. Load `dump-tem.sql` into MySQL.
2. Run bootstrap and choose **data_source** when prompted; complete `kweaver ds connect …`.
3. Run **bkn** to `kweaver bkn push` this directory’s BKN.
4. Run **agents**, **dataflow**, **tools** to call import APIs.

## After import

- In **Studio → BKN**, open the network and **bind object types** to the correct data views for your environment (UUIDs in the shipped BKN point at the original demo platform).
- In **Decision agent** settings, attach the knowledge network, models, and tools as in the upstream README.

## Validate BKN only

```bash
kweaver bkn validate supply_chain/bkn
```

## Refreshing BKN from the platform

This repo ships the `.bkn` tree as the source of truth. To align with a live network, use `kweaver bkn pull <kn-id> <dir>` after changes on the platform, or edit the `.bkn` files here and `kweaver bkn push`. The JSON export in [kweaver-core `deploy/auto_cofig`](https://github.com/kweaver-ai/kweaver-core/tree/main/deploy/auto_cofig) is the upstream reference if you need a full platform dump.

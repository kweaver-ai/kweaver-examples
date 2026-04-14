# Supply chain example

[简体中文](README.zh-CN.md)

This case mirrors assets from the [kweaver-core deploy/auto_cofig](https://github.com/kweaver-ai/kweaver-core/tree/main/deploy/auto_cofig) directory: MySQL seed data, BKN modules, a decision agent, a dataflow, and a toolbox package you can import with the KWeaver CLI.

## Layout

| Directory       | Contents                                                                 |
| --------------- | ------------------------------------------------------------------------ |
| `data_source/`  | `import_data.sql` and `demo_data/*.csv` — `CREATE TABLE` + `LOAD DATA LOCAL INFILE` |
| `bkn/`          | Business knowledge network (`.bkn` modules); see [`bkn/SKILL.md`](bkn/SKILL.md) |
| `agents/`       | `agent.json` — supply-chain Q&A agent (import)                           |
| `dataflow/`     | `dataflow.json` — evaluation / batch flow (import)                       |
| `tools/`        | Structured data analysis toolbox `.adp` (import)                         |
| `reference/`    | Optional internal PRD / notes (e.g. planning & kitting scenarios)        |

## Prerequisites

1. **KWeaver CLI** — Node.js 22+, `npm i -g @kweaver-ai/kweaver-sdk`
2. **Login** — `kweaver auth login <your-platform-url>`
3. **MySQL** — create an empty database, load `data_source/import_data.sql`, and ensure the platform can reach the host

## Import demo data (MySQL)

CSV files live under `supply_chain/data_source/demo_data/`. The script `import_data.sql` drops/creates tables (columns as `TEXT`) and loads each file with `LOAD DATA LOCAL INFILE` and a plain column list (no per-column `SET` / `NULLIF`).

From the **repository root**:

```bash
mysql --local-infile=1 -u <user> -p <database> < supply_chain/data_source/import_data.sql
```

Notes:

- `LOAD DATA` paths in the SQL are **relative to the repo root**; run the command from there, or edit those paths.
- If you add or rename CSVs under `demo_data/`, update `import_data.sql` (table name, file path, and column list per block).
- All columns are `TEXT` to keep the script small; change `CREATE TABLE` if you need strict numeric or date types.

## Bootstrap (recommended)

From the repository root:

```bash
chmod +x bootstrap.sh   # once
./bootstrap.sh supply_chain
```

The script is **interactive by default** (English prompts). For automation use `-y` and the `--ds-*` flags; see `./bootstrap.sh --help`.

Typical order:

1. Load `import_data.sql` into MySQL.
2. Run bootstrap and choose **data_source** when prompted; complete `kweaver ds connect …`.
3. Run **bkn** to `kweaver bkn push` this directory’s BKN.
4. Run **agents**, **dataflow**, and **tools** to call the import APIs.

## After import

- In **Studio → BKN**, open the network and **bind object types** to the correct data views for your environment (UUIDs in the shipped BKN still point at the original demo platform).
- In **Decision agent** settings, attach the knowledge network, models, and tools as described in the upstream README.

## Validate BKN only

```bash
kweaver bkn validate supply_chain/bkn
```

## Syncing BKN with the platform

This repo treats the `.bkn` tree as the source of truth. After changes on the platform, use `kweaver bkn pull <kn-id> <dir>` to align a copy, or edit the `.bkn` files here and `kweaver bkn push`. The JSON export under [kweaver-core deploy/auto_cofig](https://github.com/kweaver-ai/kweaver-core/tree/main/deploy/auto_cofig) remains the upstream reference if you need a full platform dump.

# Supply chain example

[简体中文](README.zh-CN.md)

This case mirrors assets from the [kweaver-core deploy/auto_cofig](https://github.com/kweaver-ai/kweaver-core/tree/main/deploy/auto_cofig) directory: MySQL seed data, BKN modules, a decision agent, a dataflow, and a toolbox package you can import with the KWeaver CLI.

> **Relationship to the product tutorial**: the KWeaver product doc "快速从 0 到 1 搭建供应链数字员工场景" is the **step-by-step walkthrough** (what to click on the platform); this repo is the matching **importable asset bundle** (BKN / agent / dataflow / toolbox / seed data) that the tutorial consumes.

> **Two import paths — don't mix them**:
> 1. **Push the `.bkn` source tree** (recommended): `bootstrap.sh` → `kweaver bkn push`. The `.bkn` files use `{{DV:...}}` placeholders and carry no hard-coded model ids, so they are portable across platforms.
> 2. **Import the full export `bkn/供应链业务知识网络demo.json`**: a snapshot exported from **one** platform that **embeds that platform's ids** (small-model `model_id`, data_view id, action-type toolbox binding). Importing it directly to a **different** platform fails — run `scripts/patch_demo_json.sh` first to re-map the ids to the target platform. See [Importing the full export JSON](#importing-the-full-export-json).

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
2. **jq** — JSON helpers used by `bootstrap.sh` and `scripts/*.sh` (e.g. `brew install jq`)
3. **Login** — `kweaver auth login <your-platform-url>`
4. **MySQL** — create an empty database, load `data_source/import_data.sql`, and ensure the platform can reach the host

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

From the **repository root**:

```bash
cd supply_chain
chmod +x bootstrap.sh   # once
./bootstrap.sh
```

> **Windows users**: a `.sh` file does **nothing** when double-clicked or run from cmd / PowerShell — it is a bash script, run it under **WSL** or **Git Bash**. Confirm `bash --version`, `kweaver --version`, and `jq --version` work, and that your current directory is `supply_chain`, or the script will not start.

This script lives in this directory and **only** drives this case. It is **interactive by default** (English prompts). For automation use `-y` and the `--ds-*` flags; see `./bootstrap.sh --help`. Helper scripts are under `scripts/` in this directory.

> **Note**: newer CLI versions removed `kweaver ds connect`; datasource connection moved to `kweaver vega catalog create --connector-type mysql --connector-config '{...}'`, and atomic views are resolved with `kweaver resource find`. Replace the `ds connect` wording in "Typical order" accordingly on a newer CLI.

**Preflight:** before mutating the platform, `bootstrap.sh` runs `scripts/preflight.sh` (Node/kweaver/curl, auth token, and at least one chat + one embedding model when post-config needs models). Use `--skip-preflight` only in exceptional cases.

**Step order / state:** steps run in resource order (`data_source` → `bkn` → `agents` → …). If you use `--only agents` (or similar), the script checks that earlier steps completed in a **previous** run (see `.kweaver_bootstrap_state.json`). Override with `--ignore-state-deps` if you know what you are doing.

**Rollback:** after post-config, reversible actions are pushed to a stack (`publish` → unpublish, `bind_kn` → restore previous KN id, `set_llm` → restore config from `.bootstrap_backup/`). Run `./bootstrap.sh --rollback-last` to undo the **last** recorded action. BKN push and imports are not auto-reverted (delete resources in Studio if needed).

Typical order:

1. Load `import_data.sql` into MySQL.
2. Run bootstrap and choose **data_source** when prompted; complete `kweaver ds connect …`.
3. Run **bkn** to `kweaver bkn push` this directory’s BKN.
4. Run **agents**, **dataflow**, and **tools** to call the import APIs.

## After import

- **Data views (automated):** each object type row uses a placeholder `| data_view | {{DV:logical_table_name}} | logical_table_name |`. At bootstrap time, `--sync-dataviews --datasource-id <uuid>` resolves those names via `kweaver dataview find` and substitutes real UUIDs (use `--bkn-staging` to patch a temp copy so the repo stays unchanged). Use `--strict-dataviews` with `--sync-dataviews` in CI so any unresolved view fails the run instead of only warning.
- **Studio (optional):** if you do not use the bootstrap flags above, bind object types to data views manually in **Studio → BKN**.
- **Decision agent:** use bootstrap `--agent-bind-kn` / `--llm-id` / `--agent-publish`, or attach the knowledge network, models, and tools in agent settings.
- **Models (大模型 / 小模型):** use `--pick-models` so the script calls `kweaver call …/llm/list`, prints numbered lists (chat LLM vs embedding), and you choose by index. With `-y` (non-interactive), pass both `--llm-id` and `--embedding-id`. The small model is applied to the knowledge network via `scripts/kn_set_embedding.sh` when the platform JSON exposes a known field; otherwise follow the script’s Studio hint.

## Importing the full export JSON

`bkn/供应链业务知识网络demo.json` is a full platform export that **hard-codes three classes of source-platform ids**, so importing it to a different platform fails one stage at a time:

| Hard-coded id | Error on direct import |
| --- | --- |
| per-property `vector_config.model_id` (small / embedding, ~30) | `ModelFactory.ExternalSmallModel.GetInfo.IdNotExist` |
| per-object-type `data_source.id` (data_view, 18) | `BknBackend.ObjectType.InvalidParameter` "data view [uuid] does not exist" |
| action-type `action_source.box_id` / `tool_id` (toolbox binding, 1) | `AgentOperatorIntegration.BadRequest.ToolBoxNotFound` |

`scripts/patch_demo_json.sh` re-maps these by **fetching real ids from the target platform** at run time (it does not trust the values baked into the file):

- small-model id ← `kweaver model small list --type embedding` (first one by default, or `--embedding-id` / `--embedding-name`)
- data_view id ← `kweaver resource list --datasource-id <catalog>`, matched by table name (the `dbname.` prefix is ignored), and `data_source.type` is switched from the old `data_view` to the platform's `resource`
- action-type toolbox binding cannot be auto-resolved: pass `--strip-actions` to drop the action types, then re-bind tools in Studio

```bash
cd supply_chain
# 1. The demo.json's matching datasource is data_source/mydatabase.sql (table names align 18/18 with the
#    18 views). NOTE: demo_data/*.csv + import_data.sql is a DIFFERENT set whose table names do not fully
#    match — do not mix them. Register the DB as a vega catalog on the target platform and discover it:
#      kweaver vega catalog create --name sc --connector-type mariadb \
#        --connector-config '{"host":"<DB IP reachable by the platform>","port":3306,"username":"root","password":"***","databases":["supplychaindata"]}'
#      kweaver vega catalog discover <catalog-id> --wait
# 2. Re-map ids and import:
./scripts/patch_demo_json.sh bkn/供应链业务知识网络demo.json \
    --datasource-id <catalog-id> --strip-actions --strict --out /tmp/demo.patched.json
kweaver bkn create --body-file /tmp/demo.patched.json --import-mode overwrite
```

> **data_view vs resource (two binding models, different behavior)**:
> - Old platforms use `data_view`: import triggers **build + vectorization** into OpenSearch and **needs a working small model** — a wrong id is the `IdNotExist` from the screenshot.
> - New platforms use `resource`: object types are queried from vega **in real time, no build, no embedding**. The patcher switches to `resource` by default.
>
> Either way the **small model itself must be usable**: even with a correct id, if its upstream (e.g. Aliyun DashScope) is unpaid/unavailable, vectorization still fails with `ExternalSmallModel.UnknownError` (e.g. `Arrearage`) — a platform/billing issue; register a working small model in the model factory.

## Validate BKN only

With `{{DV:...}}` placeholders you must run `./scripts/patch_bkn_dataviews.sh` (or `./bootstrap.sh --sync-dataviews`) first; otherwise validation may fail.

```bash
cd supply_chain
kweaver bkn validate bkn
```

## Syncing BKN with the platform

This repo treats the `.bkn` tree as the source of truth. After changes on the platform, use `kweaver bkn pull <kn-id> <dir>` to align a copy, or edit the `.bkn` files here and `kweaver bkn push`. The JSON export under [kweaver-core deploy/auto_cofig](https://github.com/kweaver-ai/kweaver-core/tree/main/deploy/auto_cofig) remains the upstream reference if you need a full platform dump.

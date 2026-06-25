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
| `data_source/`  | `mydatabase.sql` — full MySQL dump (schema + data) matching `供应链业务知识网络demo.json` |
| `bkn/`          | Business knowledge network (`.bkn` modules); see [`bkn/SKILL.md`](bkn/SKILL.md) |
| `agents/`       | `agent.json` — supply-chain Q&A agent (import)                           |
| `dataflow/`     | `dataflow.json` — evaluation / batch flow (import)                       |
| `tools/`        | Structured data analysis toolbox `.adp` (import)                         |
| `reference/`    | Optional internal PRD / notes (e.g. planning & kitting scenarios)        |

## Prerequisites

1. **KWeaver CLI** — Node.js 22+, `npm i -g @kweaver-ai/kweaver-sdk`
2. **jq** — JSON helpers used by `bootstrap.sh` and `scripts/*.sh` (e.g. `brew install jq`)
3. **Login** — `kweaver auth login <your-platform-url>`
4. **MySQL** — create an empty database, load `data_source/mydatabase.sql`, and ensure the platform can reach the host

## Import demo data (MySQL)

`data_source/mydatabase.sql` is a full MySQL dump (schema + data) whose 18 tables align 1:1 with the data views in `供应链业务知识网络demo.json`. Load it into your database:

```bash
mysql --local-infile=1 -u <user> -p <database> < supply_chain/data_source/mydatabase.sql
```

This is the single seed dataset for the case — used by both the `.bkn` push flow and the `demo.json` import flow.

## Bootstrap (recommended)

From the **repository root**:

```bash
cd supply_chain
chmod +x bootstrap.sh   # once
./bootstrap.sh
```

> **Windows users**: a `.sh` file does **nothing** when double-clicked or run from cmd / PowerShell — it is a bash script, run it under **WSL** or **Git Bash**. Confirm `bash --version`, `kweaver --version`, and `jq --version` work, and that your current directory is `supply_chain`, or the script will not start.

This script lives in this directory and **only** drives this case. It is **interactive by default** (English prompts). For automation use `-y` and the `--ds-*` flags; see `./bootstrap.sh --help`. Helper scripts are under `scripts/` in this directory.

> **SDK version is handled for you (important)**: this case uses the old data_view model, which needs `kweaver ds connect` and the data-view APIs — removed in the new SDK (0.8.x). `bootstrap.sh` has **`--legacy-sdk` ON by default**: if the active kweaver is 0.8.x (or not installed) it auto-installs and uses `kweaver-sdk@0.7.4` (still has `ds`/`dataview`) under `./.legacy-sdk/` (global install untouched); if already 0.7.x it uses it as-is. Pass `--no-legacy-sdk` on new resource-model platforms. The `ds connect` in "Typical order" is provided by that legacy CLI.

**Preflight:** before mutating the platform, `bootstrap.sh` runs `scripts/preflight.sh` (Node/kweaver/curl, auth token, and at least one chat + one embedding model when post-config needs models). Use `--skip-preflight` only in exceptional cases.

**Step order / state:** steps run in resource order (`data_source` → `bkn` → `agents` → …). If you use `--only agents` (or similar), the script checks that earlier steps completed in a **previous** run (see `.kweaver_bootstrap_state.json`). Override with `--ignore-state-deps` if you know what you are doing.

**Rollback:** after post-config, reversible actions are pushed to a stack (`publish` → unpublish, `bind_kn` → restore previous KN id, `set_llm` → restore config from `.bootstrap_backup/`). Run `./bootstrap.sh --rollback-last` to undo the **last** recorded action. BKN push and imports are not auto-reverted (delete resources in Studio if needed).

Typical order:

1. Load `mydatabase.sql` into MySQL.
2. Run bootstrap and choose **data_source** when prompted; complete `kweaver ds connect …` (note the datasource id it creates).
3. Run **bkn**: `--sync-dataviews --datasource-id <ds-id>` resolves placeholders, then `kweaver bkn push`.
4. **Build (required):** push only creates the schema; **you must trigger a build to vectorize the data and make the KN usable**:
   ```bash
   kweaver bkn list --name-pattern 供应链业务知识网络 --pretty   # get the kn-id
   kweaver bkn build <kn-id> --wait                              # wait until the task shows "completed"
   ```
   The build needs a working embedding (small) model on the platform (see "A working small model is mandatory" below).
5. Run **agents**, **dataflow**, and **tools** to call the import APIs.
6. **Create the digital employee:** in the DIP UI (as admin) create the supply-chain agent, pick the built knowledge network as its knowledge, and publish (see the product tutorial).

## After import

- **Data views (automated):** each object type row uses a placeholder `| data_view | {{DV:logical_table_name}} | logical_table_name |`. At bootstrap time, `--sync-dataviews --datasource-id <ds-id>` resolves those names (one `kweaver call GET /api/mdl-data-model/v1/data-views`, matched by table name) and substitutes real ids (use `--bkn-staging` to patch a temp copy so the repo stays unchanged). Use `--strict-dataviews` with `--sync-dataviews` in CI so any unresolved view fails the run instead of only warning.
- **Studio (optional):** if you do not use the bootstrap flags above, bind object types to data views manually in **Studio → BKN**.
- **Decision agent:** use bootstrap `--agent-bind-kn` / `--llm-id` / `--agent-publish`, or attach the knowledge network, models, and tools in agent settings.
- **Models (大模型 / 小模型):** use `--pick-models` so the script lists models via `kweaver model llm list` (chat LLM) and `kweaver model small list --type embedding` (embedding), prints numbered lists, and you choose by index. With `-y` (non-interactive), pass both `--llm-id` and `--embedding-id`. The small model is applied to the knowledge network via `scripts/kn_set_embedding.sh` when the platform JSON exposes a known field; otherwise follow the script’s Studio hint.

## Importing the full export JSON

`bkn/供应链业务知识网络demo.json` is a full platform export that **hard-codes three classes of source-platform ids**, so importing it to a different platform fails one stage at a time:

| Hard-coded id | Error on direct import |
| --- | --- |
| per-property `vector_config.model_id` (small / embedding, ~30) | `ModelFactory.ExternalSmallModel.GetInfo.IdNotExist` |
| per-object-type `data_source.id` (data_view, 18) | `BknBackend.ObjectType.InvalidParameter` "data view [uuid] does not exist" |
| action-type `action_source.box_id` / `tool_id` (toolbox binding, 1) | `AgentOperatorIntegration.BadRequest.ToolBoxNotFound` |

`scripts/patch_demo_json.sh` re-maps these by **fetching real ids from the target platform** at run time (it does not trust the values baked into the file):

- small-model id ← `kweaver model small list --type embedding` (first one by default, or `--embedding-id` / `--embedding-name`)
- data_view id ← `kweaver call GET /api/mdl-data-model/v1/data-views?data_source_id=<ds>`, matched by name / technical_name / meta_table_name (the new SDK has no `dataview` subcommand, but `kweaver call` still reaches the old endpoint — **no downgrade needed**); `data_source.type` stays `data_view`
- action-type toolbox binding cannot be auto-resolved: pass `--strip-actions` to drop the action types, then re-bind tools in Studio

```bash
cd supply_chain
# Datasource: load mydatabase.sql into a DB, then register it as a data_connection datasource on the
#   platform (DIP UI "Data connection", or old SDK: kweaver ds connect maria <host> <port> <db>
#   --account <user> --password <pass>, or bootstrap's data_source step). Scan it so all 18 tables have a
#   same-named data_view; <ds-id> is that datasource id.
./scripts/patch_demo_json.sh bkn/供应链业务知识网络demo.json \
    --datasource-id <ds-id> --strip-actions --strict --out /tmp/demo.patched.json
kweaver bkn create --body-file /tmp/demo.patched.json --import-mode overwrite
kweaver bkn build <kn-id> --wait      # required: build after create, or the KN is not usable
```

> **A working small model is mandatory**: for both `.bkn` and demo.json, BKN push/build **vectorizes concept groups + object-type concepts into OpenSearch**, which always calls the small model. Even with a correct id, if its upstream (e.g. a cloud vendor) is unpaid/unavailable, it fails with `ExternalSmallModel.UnknownError` (e.g. `Arrearage`) — a platform/billing issue; register a working small model in the model factory.

## Validate BKN only

With `{{DV:...}}` placeholders you must run `./scripts/patch_bkn_dataviews.sh` (or `./bootstrap.sh --sync-dataviews`) first; otherwise validation may fail.

```bash
cd supply_chain
kweaver bkn validate bkn
```

## Syncing BKN with the platform

This repo treats the `.bkn` tree as the source of truth. After changes on the platform, use `kweaver bkn pull <kn-id> <dir>` to align a copy, or edit the `.bkn` files here and `kweaver bkn push`. The JSON export under [kweaver-core deploy/auto_cofig](https://github.com/kweaver-ai/kweaver-core/tree/main/deploy/auto_cofig) remains the upstream reference if you need a full platform dump.

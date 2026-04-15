# 供应链示例

[English](README.md)

本案例与 [kweaver-core 的 deploy/auto_cofig 目录](https://github.com/kweaver-ai/kweaver-core/tree/main/deploy/auto_cofig) 资产对应：包含 MySQL 示例数据、BKN 模块、决策智能体、数据流与工具箱等，可通过 KWeaver CLI 导入平台。

## 目录说明

| 目录            | 内容                                                                     |
| --------------- | ------------------------------------------------------------------------ |
| `data_source/`  | `import_data.sql` 与 `demo_data/*.csv` — `CREATE TABLE` + `LOAD DATA LOCAL INFILE` |
| `bkn/`          | 业务知识网络（`.bkn` 模块）；说明见 [`bkn/SKILL.md`](bkn/SKILL.md)       |
| `agents/`       | `agent.json` — 供应链问答类智能体（导入用）                             |
| `dataflow/`     | `dataflow.json` — 评测 / 批处理数据流（导入用）                         |
| `tools/`        | 结构化数据分析工具箱 `.adp`（导入用）                                   |
| `reference/`    | 可选内部 PRD / 说明（如动态计划、齐套分析等场景）                         |

## 前置条件

1. **KWeaver CLI** — Node.js 22+，`npm i -g @kweaver-ai/kweaver-sdk`
2. **jq** — `bootstrap.sh` 与 `scripts/*.sh` 解析 JSON 用（如 `brew install jq`）
3. **登录** — `kweaver auth login <平台地址>`
4. **MySQL** — 创建空库并执行 `data_source/import_data.sql`，并保证平台能访问该数据库

## 导入示例数据（MySQL）

CSV 位于 `supply_chain/data_source/demo_data/`。`import_data.sql` 会删表/建表（列类型为 `TEXT`），并用 `LOAD DATA LOCAL INFILE` 按列名列表导入，无逐列 `SET` / `NULLIF` 清洗块。

在**仓库根目录**执行：

```bash
mysql --local-infile=1 -u <user> -p <database> < supply_chain/data_source/import_data.sql
```

说明：

- SQL 中的 `LOAD DATA` 路径相对**仓库根目录**，请在根目录执行上述命令，或自行修改路径。
- 若在 `demo_data/` 中增删或重命名 CSV，需同步修改 `import_data.sql`（表名、文件路径、列清单）。
- 为保持脚本简短，列统一为 `TEXT`；若业务需要严格数值/日期类型，请自行调整 `CREATE TABLE`。

## 引导脚本（推荐）

脚本与辅助工具在本目录：`bootstrap.sh`、`scripts/`。在**本目录**执行：

```bash
cd supply_chain
chmod +x bootstrap.sh   # 仅需一次
./bootstrap.sh
```

默认**交互式**（英文提示）。自动化可使用 `-y` 与 `--ds-*` 参数，详见 `./bootstrap.sh --help`。

建议顺序：

1. 将 `import_data.sql` 导入 MySQL。
2. 运行 bootstrap，在提示中选择 **data_source**，完成 `kweaver ds connect …`。
3. 执行 **bkn** 步骤：`kweaver bkn push` 本目录 BKN。
4. 按需执行 **agents**、**dataflow**、**tools** 完成各资源导入。

## 导入之后

- **数据视图（可自动化）：** 对象类型里使用占位符 `| data_view | {{DV:逻辑表名}} | 逻辑表名 |`。执行 bootstrap 时加 `--sync-dataviews --datasource-id <uuid>`，脚本会按表名解析原子视图 ID 并替换；加 `--bkn-staging` 则在临时目录打补丁并 push，**不改动仓库文件**。CI 场景可同时加 `--strict-dataviews`，任一视图解析失败则整次失败退出（默认仅告警并跳过未解析行）。
- **Studio（可选）：** 若不用上述参数，再在 **Studio → BKN** 里手工绑定数据视图。
- **决策智能体：** 可用 bootstrap 的 `--agent-bind-kn` / `--llm-id` / `--agent-publish`，或在平台里配置。

## 仅校验 BKN

存在 `{{DV:...}}` 占位符时须先运行 `./scripts/patch_bkn_dataviews.sh`（或带 `--sync-dataviews` 的 `./bootstrap.sh`），否则校验可能失败。

```bash
cd supply_chain
kweaver bkn validate bkn
```

## 与平台上的 BKN 对齐

本仓库以 `.bkn` 文件树为源。若在平台上改过网络，可用 `kweaver bkn pull <kn-id> <目录>` 拉取对齐；或在此编辑 `.bkn` 后执行 `kweaver bkn push`。若需要完整平台导出，仍以 [kweaver-core deploy/auto_cofig](https://github.com/kweaver-ai/kweaver-core/tree/main/deploy/auto_cofig) 中的 JSON 为上游参考。

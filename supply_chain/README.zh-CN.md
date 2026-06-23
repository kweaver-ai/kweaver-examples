# 供应链示例

[English](README.md)

本案例与 [kweaver-core 的 deploy/auto_cofig 目录](https://github.com/kweaver-ai/kweaver-core/tree/main/deploy/auto_cofig) 资产对应：包含 MySQL 示例数据、BKN 模块、决策智能体、数据流与工具箱等，可通过 KWeaver CLI 导入平台。

> **与产品教程的关系**：KWeaver 产品文档里的《快速从 0 到 1 搭建供应链数字员工场景》是**操作教程**（讲在平台上点哪、看什么）；本仓库是该教程配套的**可导入素材包**（BKN / 决策智能体 / 数据流 / 工具箱 / 种子数据）。教程负责“怎么操作”，本目录负责“导入什么”。

> **两种导入方式，别混用**：
> 1. **推送 `.bkn` 源码树**（推荐）：用 `bootstrap.sh` → `kweaver bkn push`。`.bkn` 里数据视图用占位符 `{{DV:...}}`、不含写死的模型 id，跨平台可移植。
> 2. **导入整库导出 `bkn/供应链业务知识网络demo.json`**：这是从**某台平台导出**的整库快照，**内含该平台的写死 ID**（小模型 model_id、数据视图 id、行动类工具箱绑定）。**直接导到另一台平台会报错**，必须先用 `scripts/patch_demo_json.sh` 把 ID 换成目标平台的真实值，见下文《导入整库导出 JSON》。

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

> **Windows 用户**：`.sh` 在 cmd / PowerShell 里**直接双击或运行没有任何反应**——这是 bash 脚本，需在 **WSL** 或 **Git Bash** 里跑。先确认 `bash --version`、`kweaver --version`、`jq --version` 都正常，并且当前目录就是 `supply_chain`，否则脚本不会启动。

默认**交互式**（英文提示）。自动化可使用 `-y` 与 `--ds-*` 参数，详见 `./bootstrap.sh --help`。

> **注**：较新版本 CLI 已移除 `kweaver ds connect`，数据源连接迁到 `kweaver vega catalog create --connector-type mysql --connector-config '{...}'`，原子视图改用 `kweaver resource find`。下文“建议顺序”中的 `ds connect` 字样在新 CLI 上请相应替换。

**环境预检：** 执行前会运行 `scripts/preflight.sh`（检查 Node/kweaver/curl、登录 token；若本次会做 post-config 模型相关操作，则要求平台上至少各有一条「对话类」与「嵌入类」模型）。一般勿用 `--skip-preflight`。

**步骤依赖 / 状态：** 若使用 `--only` 只跑某一步，脚本会检查**更早的步骤**是否已在**上一次成功运行**中完成（见目录下 `.kweaver_bootstrap_state.json`）。确需跳过检查可用 `--ignore-state-deps`。

**回退：** post-config 中可逆操作（发布、绑定 KN、修改默认 LLM）会写入回退栈；执行 `./bootstrap.sh --rollback-last` 可**撤销上一次记录的操作**。BKN push 与各类 import 不会自动删除，需在平台侧自行处理。

建议顺序：

1. 将 `import_data.sql` 导入 MySQL。
2. 运行 bootstrap，在提示中选择 **data_source**，完成 `kweaver ds connect …`。
3. 执行 **bkn** 步骤：`kweaver bkn push` 本目录 BKN。
4. 按需执行 **agents**、**dataflow**、**tools** 完成各资源导入。

## 导入之后

- **数据视图（可自动化）：** 对象类型里使用占位符 `| data_view | {{DV:逻辑表名}} | 逻辑表名 |`。执行 bootstrap 时加 `--sync-dataviews --datasource-id <uuid>`，脚本会按表名解析原子视图 ID 并替换；加 `--bkn-staging` 则在临时目录打补丁并 push，**不改动仓库文件**。CI 场景可同时加 `--strict-dataviews`，任一视图解析失败则整次失败退出（默认仅告警并跳过未解析行）。
- **Studio（可选）：** 若不用上述参数，再在 **Studio → BKN** 里手工绑定数据视图。
- **决策智能体：** 可用 bootstrap 的 `--agent-bind-kn` / `--llm-id` / `--agent-publish`，或在平台里配置。
- **大模型 / 小模型：** 使用 `--pick-models`，脚本会通过 `kweaver call …/llm/list` 拉取列表并**按序号交互选择**对话大模型与向量（嵌入）小模型。配合 `-y` 非交互时需同时指定 `--llm-id` 与 `--embedding-id`。小模型会尝试通过 `scripts/kn_set_embedding.sh` 写回知识网络；若平台 JSON 无对应字段，请按脚本提示在 Studio 中配置。

## 导入整库导出 JSON（`供应链业务知识网络demo.json`）

`bkn/供应链业务知识网络demo.json` 是整库平台导出，**写死了导出源平台的三类 ID**，换平台直接导入会逐个报错：

| 写死的 ID | 直接导入的报错 |
| --- | --- |
| 每个属性 `vector_config.model_id`（小模型/embedding，约 30 处） | `ModelFactory.ExternalSmallModel.GetInfo.IdNotExist`「部分配置 id 不存在」 |
| 每个对象类 `data_source.id`（数据视图，18 个） | `BknBackend.ObjectType.InvalidParameter`「数据视图 [uuid] 不存在」 |
| 行动类 `action_source.box_id` / `tool_id`（工具箱绑定，1 个） | `AgentOperatorIntegration.BadRequest.ToolBoxNotFound`「工具箱不存在」 |

`scripts/patch_demo_json.sh` 在导入前**从目标平台动态拉取真实 ID 回填**（不依赖文件里写死的值）：

- 小模型 id ← `kweaver model small list --type embedding`（不指定就取第一个，或用 `--embedding-id` / `--embedding-name`）
- 数据视图 id ← `kweaver resource list --datasource-id <catalog>`，按表名（自动忽略 `库名.` 前缀）匹配，并把 `data_source.type` 由旧的 `data_view` 改为当前平台的 `resource`
- 行动类工具绑定无法自动解析：用 `--strip-actions` 先剥离，导入后在 Studio 里重新绑定工具

```bash
cd supply_chain
# 1. 准备数据源：本案例的 demo.json 对应 data_source/mydatabase.sql（表名与 18 个视图 18/18 对齐；
#    注意 demo_data/*.csv + import_data.sql 是另一套、表名不完全一致，不要混用）。
#    在目标平台用 vega 注册该库为 catalog，并 discover 出资源：
#      kweaver vega catalog create --name sc --connector-type mariadb \
#        --connector-config '{"host":"<DB能被平台访问的IP>","port":3306,"username":"root","password":"***","databases":["supplychaindata"]}'
#      kweaver vega catalog discover <catalog-id> --wait
# 2. 改 ID 后导入：
./scripts/patch_demo_json.sh bkn/供应链业务知识网络demo.json \
    --datasource-id <catalog-id> --strip-actions --strict --out /tmp/demo.patched.json
kweaver bkn create --body-file /tmp/demo.patched.json --import-mode overwrite
```

> **数据视图 vs 资源（两种绑定模型，行为不同）**：
> - 老平台用 `data_view`：导入后会 **build + 向量化**写入 OpenSearch，**依赖可用的小模型**——小模型 id 不对就是截图里的 `IdNotExist`。
> - 新平台用 `resource`：对象类**实时查询 vega，不 build、不用 embedding**。patcher 默认改成 `resource`，导入即用。
>
> 不论哪种，**小模型本身必须可用**：即使 id 正确，若该模型后端（如阿里云 DashScope）欠费/不可用，向量化仍会报 `ExternalSmallModel.UnknownError`（如 `Arrearage`）——这是平台/账单问题，需在模型工厂里换一个可用的小模型。

## 仅校验 BKN

存在 `{{DV:...}}` 占位符时须先运行 `./scripts/patch_bkn_dataviews.sh`（或带 `--sync-dataviews` 的 `./bootstrap.sh`），否则校验可能失败。

```bash
cd supply_chain
kweaver bkn validate bkn
```

## 与平台上的 BKN 对齐

本仓库以 `.bkn` 文件树为源。若在平台上改过网络，可用 `kweaver bkn pull <kn-id> <目录>` 拉取对齐；或在此编辑 `.bkn` 后执行 `kweaver bkn push`。若需要完整平台导出，仍以 [kweaver-core deploy/auto_cofig](https://github.com/kweaver-ai/kweaver-core/tree/main/deploy/auto_cofig) 中的 JSON 为上游参考。

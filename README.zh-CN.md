# kweaver-examples

面向 KWeaver 平台的示例 **案例**：可用 `kweaver` CLI 推送的资源，以及可选的一键引导脚本。

[English](README.md)

## 文档

KWeaver Core 官方产品文档（后端 API、CLI、SDK 等）见上游仓库： [kweaver-core/help](https://github.com/kweaver-ai/kweaver-core/tree/main/help) — 入口：[英文](https://github.com/kweaver-ai/kweaver-core/blob/main/help/en/README.md)、[中文](https://github.com/kweaver-ai/kweaver-core/blob/main/help/zh/README.md)。

## 案例

| 案例 | 说明 |
|------|------|
| [`supply_chain/`](supply_chain/) | 供应链 BKN、决策智能体、数据流、工具箱与 MySQL 示例数据 — 说明见 [`README.zh-CN.md`](supply_chain/README.zh-CN.md) |

新增案例时，按相同约定建目录即可：`data_source/`、`bkn/`、`agents/`、`dataflow/`、`tools/`（均为可选）。

## 引导脚本

供应链案例自带 [`supply_chain/bootstrap.sh`](supply_chain/bootstrap.sh) 与 [`supply_chain/scripts/`](supply_chain/scripts/)（数据视图、`kweaver` 智能体绑定；可选 `--pick-models` 从 `kweaver call …/llm/list` **交互选择**大模型与小模型；仅 shell + `jq`）。在**该目录下**执行：

**前提：**
- Node.js 22+ 与 `jq`；并完成 `kweaver auth login <平台地址>`。
- **SDK 版本自动处理**：本案例走老的 data_view 模型，需要 `kweaver ds` / `dataview`（新 SDK 0.8.x 已移除）。`bootstrap.sh` 默认会在 `supply_chain/.legacy-sdk/` **本地自动安装并使用 0.7.x**（全局安装不动；机器上没装过 kweaver 时也会自动装）。新版 resource 平台加 `--no-legacy-sdk`。
- **平台需有一个“可用”的小模型（embedding）**：建知识网络时会把概念向量化写入 OpenSearch，**强制调用小模型**。平台若没有有效小模型（或其后端欠费/不可用），`kweaver bkn push` 会报 `ModelFactory.ExternalSmallModel.*`。请先在模型工厂配好可用小模型。

```bash
cd supply_chain
chmod +x bootstrap.sh
./bootstrap.sh              # 交互式
./bootstrap.sh --help       # 查看参数
./bootstrap.sh -y --ds-host db.example.com --ds-db tem --ds-user root --ds-pass secret
```

## 许可

见 [LICENSE](LICENSE)。

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

供应链案例自带 [`supply_chain/bootstrap.sh`](supply_chain/bootstrap.sh) 与 [`supply_chain/scripts/`](supply_chain/scripts/)（数据视图、`kweaver` 智能体绑定与默认 LLM；仅 shell + `jq`）。在**该目录下**执行：

**前提：** 已安装 CLI（`npm i -g @kweaver-ai/kweaver-sdk`），并完成 `kweaver auth login <平台地址>`。

```bash
cd supply_chain
chmod +x bootstrap.sh
./bootstrap.sh              # 交互式
./bootstrap.sh --help       # 查看参数
./bootstrap.sh -y --ds-host db.example.com --ds-db tem --ds-user root --ds-pass secret
```

## 许可

见 [LICENSE](LICENSE)。

# kweaver-examples

面向 KWeaver 平台的示例 **案例**：可用 `kweaver` CLI 推送的资源，以及可选的一键引导脚本。

[English](README.md)

## 案例

| 案例 | 说明 |
|------|------|
| [`supply_chain/`](supply_chain/) | 供应链 BKN、决策智能体、数据流、工具箱与 MySQL 示例数据 — 说明见 [`README.zh-CN.md`](supply_chain/README.zh-CN.md) |

新增案例时，按相同约定建目录即可：`data_source/`、`bkn/`、`agents/`、`dataflow/`、`tools/`（均为可选）。

## 引导脚本

[`bootstrap.sh`](bootstrap.sh) 会扫描案例目录下已有内容，并依次执行：连接数据源、`kweaver bkn push`、导入 Agent / 数据流 / 工具箱等。

**前提：** 已安装 CLI（`npm i -g @kweaver-ai/kweaver-sdk`），并完成 `kweaver auth login <平台地址>`。

```bash
chmod +x bootstrap.sh
./bootstrap.sh supply_chain              # 交互式
./bootstrap.sh supply_chain --help       # 查看参数
./bootstrap.sh supply_chain -y --ds-host db.example.com --ds-db tem --ds-user root --ds-pass secret
```

## 许可

见 [LICENSE](LICENSE)。

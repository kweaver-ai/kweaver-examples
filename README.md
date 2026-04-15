# kweaver-examples

[中文版](README.zh-CN.md)

Example **cases** for the KWeaver platform: assets you can push with the `kweaver` CLI and optional automation.

## Documentation

Official **KWeaver Core** product docs (backend APIs, CLI, SDKs) live in the upstream repo: [kweaver-core/help](https://github.com/kweaver-ai/kweaver-core/tree/main/help) — entry points: [English](https://github.com/kweaver-ai/kweaver-core/blob/main/help/en/README.md), [中文](https://github.com/kweaver-ai/kweaver-core/blob/main/help/zh/README.md).

## Cases


| Case                             | Description                                                    |
| -------------------------------- | -------------------------------------------------------------- |
| [`supply_chain/`](supply_chain/) | Supply-chain BKN, agent, dataflow, toolbox, and MySQL seed data — see [`supply_chain/README.md`](supply_chain/README.md) |


Add a new case by creating a directory with the same conventions (`data_source/`, `bkn/`, `agents/`, `dataflow/`, `tools/` — each optional).

## Bootstrap (per case)

The supply-chain case includes its own [`supply_chain/bootstrap.sh`](supply_chain/bootstrap.sh) and [`supply_chain/scripts/`](supply_chain/scripts/) (dataview patch, agent bind, LLM helpers). Run from that directory:

**Prerequisite:** `kweaver auth login <url>` with a working CLI install (`npm i -g @kweaver-ai/kweaver-sdk`).

```bash
cd supply_chain
chmod +x bootstrap.sh
./bootstrap.sh              # interactive
./bootstrap.sh --help       # options
./bootstrap.sh -y --ds-host db.example.com --ds-db tem --ds-user root --ds-pass secret
```

## License

See [LICENSE](LICENSE).
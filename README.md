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

The supply-chain case includes its own [`supply_chain/bootstrap.sh`](supply_chain/bootstrap.sh) and [`supply_chain/scripts/`](supply_chain/scripts/) (dataview patch, agent bind, optional `--pick-models` to choose chat + embedding models from `kweaver call …/llm/list`, then apply via `kweaver agent` / `kn_set_embedding.sh`). Shell + `jq` only. Run from that directory:

**Prerequisites:**
- Node.js 22+ and `jq`; `kweaver auth login <url>`.
- **SDK version is handled for you**: this case uses the old data_view model, which needs `kweaver ds` / `dataview` (removed in SDK 0.8.x). `bootstrap.sh` auto-installs and uses kweaver-sdk 0.7.x locally under `supply_chain/.legacy-sdk/` (global install untouched; it also installs one if no kweaver is present). Pass `--no-legacy-sdk` on new resource-model platforms.
- **The platform must have a usable small (embedding) model**: creating the knowledge network vectorizes concepts into OpenSearch and always calls the small model. Without a valid/funded one, `kweaver bkn push` fails with `ModelFactory.ExternalSmallModel.*`. Configure a working small model in the model factory first.

```bash
cd supply_chain
chmod +x bootstrap.sh
./bootstrap.sh              # interactive
./bootstrap.sh --help       # options
./bootstrap.sh -y --ds-host db.example.com --ds-db tem --ds-user root --ds-pass secret
```

## License

See [LICENSE](LICENSE).
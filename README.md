# kweaver-examples

[中文版](README.zh-CN.md)

Example **cases** for the KWeaver platform: assets you can push with the `kweaver` CLI and optional automation.

## Cases


| Case                             | Description                                                    |
| -------------------------------- | -------------------------------------------------------------- |
| `[supply_chain/](supply_chain/)` | Supply-chain BKN, agent, dataflow, toolbox, and MySQL seed SQL |


Add a new case by creating a directory with the same conventions (`data_source/`, `bkn/`, `agents/`, `dataflow/`, `tools/` — each optional).

## Bootstrap script

`[bootstrap.sh](bootstrap.sh)` discovers what exists under a case directory and runs the right steps (data source connect, `kweaver bkn push`, agent / dataflow / toolbox imports).

**Prerequisite:** `kweaver auth login <url>` with a working CLI install (`npm i -g @kweaver-ai/kweaver-sdk`).

```bash
chmod +x bootstrap.sh
./bootstrap.sh supply_chain              # interactive
./bootstrap.sh supply_chain --help       # options
./bootstrap.sh supply_chain -y --ds-host db.example.com --ds-db tem --ds-user root --ds-pass secret
```

## License

See [LICENSE](LICENSE).
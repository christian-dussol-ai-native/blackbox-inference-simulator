# BLIS lab: what a serving simulator lets you learn without a GPU

A small, reproducible lab built on **[BLIS](https://github.com/inference-sim/inference-sim)**
(Blackbox Inference Simulator), the CPU-only, deterministic discrete-event
simulator for LLM inference serving.

The lab does not try to teach BLIS exhaustively. It asks one question and
answers it with commands you can run yourself:

> **What can you actually learn about LLM serving without touching a GPU, and
> where does silicon become unavoidable?**

Everything here runs on a laptop. No GPU, no cloud account, no cost.

## The reading grid

The lab rests on one distinction, applied to every mechanism a serving stack
has (tensor parallelism, KV cache, routing, prefill/decode disaggregation, and
the rest). Three questions that are easy to collapse into one, and must not be:

| Level | Question | What establishes it |
|-------|----------|---------------------|
| **① Configurable** | Can I declare it to the simulator? | a flag in the configuration reference |
| **② Modeled** | Are the mechanism *and its cost* represented? | a metric that moves when the parameter moves |
| **③ Validated** | Does that simulated cost match real hardware? | the published calibration scope, and nothing else |

**A flag that exists does not prove the simulator models what the dimension
costs.** That is the trap this lab is built to avoid, and level ③ is mostly out
of reach on a CPU: it is a limit to state, not one to work around.

## Repository contents

| Path | What it is |
|------|------------|
| [`labs/lab-00-what-is-configurable.md`](labs/lab-00-what-is-configurable.md) | Survey the CLI and the docs, fill column ① only, conclude nothing |
| [`labs/lab-01-baseline.md`](labs/lab-01-baseline.md) | One run, one instance: see the tool work and learn to read its output |
| [`labs/lab-02-latency-models.md`](labs/lab-02-latency-models.md) | Roofline against trained-physics: what calibration actually buys |
| [`scripts/`](scripts/) | One setup script, one runnable script per lab |

## Prerequisites

- **Go ≥ 1.24** to build BLIS (`go.mod` requires 1.24.0).
- **jq** to extract the cluster summary from multi-instance runs.
- About 2 GB of disk for the BLIS repository and its build cache.
- No GPU. That is the point.

Optional: `export HF_TOKEN=...` to avoid HuggingFace rate limits. On first run
BLIS fetches the model's `config.json` (about a second for a public model) and
caches it in `model_configs/`. After that, the labs run offline.

## Setup

```bash
git clone https://github.com/christian-dussol-ai-native/blackbox-inference-simulator.git
cd blackbox-inference-simulator
./scripts/setup.sh
```

`setup.sh` clones BLIS next to this repository, checks out the pinned commit,
and builds the `blis` binary. To use a BLIS you already have, point the scripts
at it instead:

```bash
export BLIS_BIN=/path/to/your/inference-sim/blis
```

## Running the labs

```bash
./scripts/lab-01-baseline.sh          # under a second
./scripts/lab-02-latency-models.sh    # a couple of seconds
```

Both are fast: BLIS is a discrete-event simulator, so 500 requests across 4
instances cost a fraction of a second of CPU. The only slow steps are the
one-off Go build in `setup.sh` and, on the very first run, fetching the model
config from HuggingFace.

Lab 00 has no script: it is a reading exercise, and its verification commands
are in the lab file itself.

Each lab file follows the same shape: the question, **the expectation written
down before running**, the commands, what to look at, what was actually
observed, and what the result does and does not establish.

That third-to-last step matters more than it looks. The gap between what you
expected and what the simulator printed is the only thing in this lab that
teaches anything, and it evaporates if you reconstruct it afterwards. Write the
expectation down first, even when it is wrong. **Especially when it is wrong.**

## Reproducibility

BLIS is deterministic: same seed, same version, same flags, identical output to
the bit. The numbers reported in the lab files were produced with:

| | |
|---|---|
| **BLIS commit** | [`f4c8c619`](https://github.com/inference-sim/inference-sim/commit/f4c8c619) (2026-09-03) |
| **Model** | `qwen/qwen3-14b` |
| **Simulated hardware** | H100, TP=1 |
| **Observed on** | 2026-09-04 |

BLIS moves fast. A later commit may produce different numbers, and the shape of
the result is what matters here, not the third decimal. If you run against a
newer version, record the commit alongside your numbers, as the labs do.

## What this lab is not

**Simulated is not measured.** Nothing here is a benchmark. Every number is the
output of a latency model, and the honest way to use one is to say so.

BLIS publishes a calibration scope: 7 to 9% median error on end-to-end and
inter-token latency, over 36 validation experiments, on models from 8B to 141B,
dense and MoE, on H100, A100 and L40S. **Outside that scope, fidelity is
unknown**, and no CPU experiment will establish it. The labs stay near the
validated configurations and say when they leave.

The lab also does not cover MoE internals, expert parallelism as a placement
problem, or anything requiring real hardware.

## Further reading

- [inference-sim/inference-sim](https://github.com/inference-sim/inference-sim): the BLIS source.
- [inference-sim.github.io/inference-sim/latest](https://inference-sim.github.io/inference-sim/latest/): the documentation. When a command in this lab disagrees with the docs, the docs win.

## Where this fits

Other labs and educational resources are indexed in the
[AI Native Hub](https://github.com/christian-dussol-ai-native/ai-native-hub), and
the deep-dives behind each build are at
[www.christiandussol.dev](https://www.christiandussol.dev).

## License

[Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)](LICENSE),
© 2026 Christian Dussol.

*BLIS itself is a separate project, Apache 2.0 licensed. This repository
contains only lab material, not BLIS.*

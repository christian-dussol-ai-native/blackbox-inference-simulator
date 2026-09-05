# Lab 00: what is configurable

**Goal:** fill **column ① only** of the reading grid. What can be *declared* to
BLIS?

**Rule for this lab:** conclude nothing about what is *modeled*. A flag that
exists proves that a parameter can be set, not that varying it changes any
metric. That is lab 02's job.

**Time:** 20 minutes of reading, no simulation run.

---

## The question

A serving stack has many mechanisms: five parallelism dimensions, KV cache,
routing, scheduling, admission control, prefill/decode disaggregation. Which of
them does BLIS expose at all?

This is a documentation and CLI survey. It is the cheapest step of the lab, and
the one most often skipped, which is why people conclude from a flag list what
only an experiment can establish.

## Commands

From the BLIS repository (see [`scripts/setup.sh`](../scripts/setup.sh)):

```bash
# Every parallelism-related flag the CLI exposes
./blis run --help | grep -E -- '--(tp|dp|pp|enable-expert-parallel|moe-comm-backend)'

# What the docs say about pipeline parallelism
grep -rn "Pipeline parallelism is not yet modeled" docs/

# Is there any context-parallel surface at all?
grep -ril "context.parallel" docs/ cmd/ || echo "no occurrence"

# Prefill/decode disaggregation: the CLI versus the configuration reference
grep -c "prefill-instances\|pd-decider\|pd-prefix-threshold" cmd/root.go
grep -c "prefill-instances" docs/reference/configuration.md
```

## What was observed

Commit `f4c8c619`, 2026-09-04.

| Dimension | Flag exists? | What the documentation says |
|-----------|--------------|-----------------------------|
| **Tensor parallelism** | yes, `--tp` | Modeled by both backends. Cross-node TP traffic is priced from real placement. |
| **Pipeline parallelism** | **no flag** | Explicitly *"Pipeline parallelism is not yet modeled"*. |
| **Expert parallelism** | yes, `--enable-expert-parallel`, `--moe-comm-backend` | MoE only, `trained-physics` only. A latency-model term; expert-parallelism-as-placement is a separate open issue. Rejects `--dp > 1`. |
| **Data parallelism** | yes, `--dp` | MoE only, `trained-physics` only. Spawns N real single-node replicas. Rejects expert parallelism, PD disaggregation, autoscaler, node pools. |
| **Context parallelism** | **no flag** | No occurrence anywhere in the docs or the CLI. |
| **Prefill/decode disaggregation** | yes, many | `--prefill-instances`, `--decode-instances`, `--pd-decider`, `--pd-prefix-threshold`, `--pd-transfer-bandwidth`, per-role TP and hardware. `blis run` only. |
| **KV cache** | yes, extensively | Block count and size, dtype, tiered offload with promotion and eviction, transfer bandwidth and latency, auto-sizing from architecture and GPU memory. |
| **Routing and scheduling** | yes, extensively | 4 routing policies, 9 composable scorers, 4 schedulers, 2 preemption policies, 5 admission policies, flow control with SLO tiers. |

## What this establishes

Two of the five parallelism dimensions have **no CLI surface at all**: pipeline
and context parallelism. For those, BLIS is not "less accurate", it is silent.
Any capacity plan that depends on them is outside what this tool can express,
and that is worth knowing before running anything rather than after.

The three that exist are not equivalent either. Tensor parallelism works
everywhere; expert and data parallelism are restricted to MoE models under one
specific latency backend, and they mutually exclude each other.

## What this does not establish

**Nothing about whether varying these flags changes any metric.** The
documentation states that `--enable-expert-parallel` adds a term to the
step-time model. Only an experiment shows whether that term is observable on a
realistic workload. Column ② stays empty at the end of this lab, on purpose.

## One incidental finding, worth the survey on its own

The prefill/decode flags appear **10 times in `cmd/root.go` and 0 times in
`docs/reference/configuration.md`**. They are documented in the guides, not in
the reference page.

Reading only the page titled "Configuration Reference" would leave you
convinced that disaggregation has no CLI surface. It has ten flags. The lesson
generalizes past BLIS: **a reference page that is incomplete is more misleading
than one that is absent**, because it reads as exhaustive.

---

Next: [lab 01, the baseline](lab-01-baseline.md).

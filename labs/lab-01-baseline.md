# Lab 01: the baseline

**Goal:** see BLIS run, and learn to read its output. Draw no conclusions.

**Time:** seconds.

**Script:** [`scripts/lab-01-baseline.sh`](../scripts/lab-01-baseline.sh)

---

## The question

None yet. This lab exists so that the output format stops being abstract before
the labs that actually ask something.

It is also the one experiment worth running **before** reading up on serving
concepts. Everything after it assumes you know what TTFT, inter-token latency
and preemption are; this one does not.

## Write your expectation first

Before running, write down what you expect. Mine, in full, including the part I
got wrong:

- The binary runs and prints JSON after a `=== Simulation Metrics ===` header.
- `preemption_count == 0` and `still_queued == 0`: at 1 request per second on a
  single instance, the load is very low.
- `dropped_unservable == 0`: prompts and outputs around 512 tokens sit well
  inside an H100's budget.
- **TTFT in the hundreds of milliseconds.** Rough arithmetic: Qwen3-14B is
  about 30 GFLOPs per prefill token, times 512 tokens, over an H100's 1.9
  PFLOPs at 45% MFU, gives about 20 ms of pure compute, plus overhead.
- **ITL in the tens of milliseconds.** Decode is memory-bound: 28 GB of weights
  over 3.35 TB/s of HBM is about 8 ms per token.
- `completed_requests == 100`.

## The command

```bash
./blis run --model qwen/qwen3-14b
```

Defaults: 100 requests, 1 request per second, one instance, `trained-physics`
latency model, TP=1 (from `defaults.yaml`), prompts and outputs around 512
tokens.

Logs go to **stderr**, results to **stdout**. That separation is what makes the
runs scriptable:

```bash
./blis run --model qwen/qwen3-14b 2>/dev/null
```

## What to look at

**Health indicators first**, before any latency number:

| Field | Meaning |
|-------|---------|
| `preemption_count` | a running request was evicted to make room. Non-zero suggests overload. |
| `dropped_unservable` | rejected: too large for the configured memory or context. |
| `still_queued`, `still_running` | not finished when the simulation window closed. |

If any of these is non-zero, the latency numbers describe a system under
stress, and reading them as a baseline is a mistake.

**Then** latency (`ttft_*`, `itl_*`, `e2e_*`, in milliseconds, as mean/p90/p95/p99)
and throughput (`tokens_per_sec`, `responses_per_sec`, `completed_requests`).

## What was observed

Commit `f4c8c619`, 2026-09-04.

| Metric | Value |
|--------|-------|
| completed / injected | 100 / 100 |
| `preemption_count`, `still_queued`, `dropped_unservable` | 0, 0, 0 |
| TTFT mean / p99 | **36.4 ms** / 43.7 ms |
| ITL mean / p99 | **12.9 ms** / 13.7 ms |
| E2E mean / p99 | 7.0 s / 15.6 s |
| `scheduling_delay_p99_ms` | 27.9 ms |
| throughput | 501 tokens/s, 0.93 req/s |

A clean baseline: nothing queued, nothing preempted, nothing dropped, and an
arrival rate the system absorbs without saturating.

## Expectation versus observation

- Every health indicator predicted at zero came out at zero.
- ITL landed in the predicted order of magnitude, around 13 ms.
- **TTFT was off by an order of magnitude.** I predicted hundreds of
  milliseconds; the simulator printed 36 ms. My back-of-the-envelope
  calculation over-counted overhead.

That last line is the reason the expectation gets written down first. It
calibrates *my* intuition, and it says nothing about whether BLIS is right. Two
different claims, and only the first one is established here.

An incidental find worth knowing: BLIS also emits
`vllm_estimated_duration_s` (108 s here), a wall-clock envelope for the whole
batch, consistent with 100 requests arriving over 100 seconds plus the last
one's residency.

## What this establishes

That the tool runs and that its output is readable. Nothing else.

## What this does not establish

**Anything about what is modeled.** These latencies are the output of a
calibrated model with about 7% median error over a restricted set of
configurations. They are not measurements, and they are not a benchmark of an
H100.

---

Previous: [lab 00, what is configurable](lab-00-what-is-configurable.md) ·
Next: [lab 02, the latency models](lab-02-latency-models.md).

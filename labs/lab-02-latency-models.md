# Lab 02: the latency models

**Goal:** compare BLIS's two latency backends on the same workload, and find
out what calibration actually buys.

**Time:** seconds.

**Script:** [`scripts/lab-02-latency-models.sh`](../scripts/lab-02-latency-models.sh)

---

## The question

BLIS ships two ways of estimating how long a step takes:

- **`roofline`**: pure analytics. FLOPs over compute throughput, bytes over
  memory bandwidth, a fixed MFU. No learned correction, no CPU overhead term.
- **`trained-physics`**: the same physical basis functions plus 13 coefficients
  fitted against real hardware, with architecture-aware MoE scaling.

Same workload, same model, same simulated GPU. **How far apart do they land,
and in which direction?**

This is the difference between an estimator and a calibrated simulator, made
observable in two commands.

## Write your expectation first

Mine, before running:

- Roofline ignores the overheads the learned corrections capture, so it should
  be the **optimistic** one across the board.
- **TTFT**: roofline noticeably lower, maybe 20 to 40% apart. The alpha
  coefficients add scheduling and CPU overhead that roofline does not have.
- **ITL**: smaller gap, 10 to 20%. Decode is memory-bandwidth-bound, the regime
  roofline captures best.
- **E2E**: in between, dominated by decode.
- **Throughput**: lower under trained-physics, since a "slower" system
  completes fewer requests per unit of time.

And the anti-expectation, written down because it is the one that would teach
the most: if roofline comes out **more pessimistic** anywhere, my mental model
of the two backends is wrong.

## The commands

Two runs, identical except for one flag:

```bash
./blis run --model qwen/qwen3-14b --latency-model roofline \
  --hardware H100 --tp 1 --num-instances 4 --rate 100 --num-requests 500

./blis run --model qwen/qwen3-14b --latency-model trained-physics \
  --hardware H100 --tp 1 --num-instances 4 --rate 100 --num-requests 500
```

With 4 instances, BLIS prints **one JSON block per instance plus a cluster
summary**, each preceded by a `=== Simulation Metrics ===` header. To pull out
the cluster block, strip the headers first, then slurp:

```bash
./blis run ... 2>/dev/null | grep -v '^=== ' | \
  jq --slurp '.[] | select(.instance_id == "cluster")'
```

> The header line sits on **stdout**, not stderr. Piping straight into
> `jq --slurp` fails with a parse error on it. Dropping the `grep -v` is the
> most common way to get stuck here.

## What was observed

Commit `f4c8c619`, 2026-09-04. Cluster summary, 4 instances, 100 req/s, 500
requests, round-robin routing. No preemptions in either run.

| Metric | roofline | trained-physics | delta |
|--------|----------|-----------------|-------|
| TTFT mean | 32.6 ms | 41.7 ms | **+28%** |
| TTFT p90 | 48.6 ms | 49.3 ms | +1% |
| **TTFT p99** | 59.3 ms | 55.1 ms | **-7%** |
| **ITL mean** | 11.0 ms | 18.7 ms | **+70%** |
| ITL p99 | 44.7 ms | 22.3 ms | -50% |
| E2E mean | 5.69 s | 9.64 s | +69% |
| E2E p99 | 10.4 s | 19.7 s | +90% |
| scheduling delay p99 | 19.3 ms | 33.5 ms | +74% |
| **throughput** | 18 427 tok/s | 10 631 tok/s | **-42%** |

## Expectation versus observation

**Right:** roofline is the optimistic one on ITL, E2E, throughput and
scheduling delay. And the gap is wider on ITL (+70%) than on TTFT mean (+28%),
which fits: prefill is compute-bound with large matrices, exactly the regime
analytical roofline handles well, while decode carries per-token overhead it
ignores.

**Wrong, and this is the interesting part:** TTFT p99 is **lower** under
trained-physics (55 ms) than under roofline (59 ms). The anti-expectation
fired.

The explanation is visible in the rest of the table. Trained-physics produces a
**tighter distribution**: higher mean, shorter tail. Roofline is **burstier**:
lower mean, longer tail, and an ITL p99 at four times its own mean against 1.2x
for trained-physics.

So the learned corrections do not simply shift the average. **They change the
shape of the distribution**, and "optimistic" turns out to be the wrong mental
model for what calibration does.

## The one number that matters for capacity planning

**Cluster throughput drops 42%** between the two backends.

Sizing a fleet on roofline numbers overestimates its capacity by a factor of
about 1.7. Not a rounding error: a wrong instance count, in the expensive
direction.

This is the clearest answer the lab gives to its own question. A calibrated
simulator and an analytical estimator are not two accuracies of the same thing.
They are different tools, and only one of them can be used to size anything.

## What this establishes

**Column ② for the latency model.** The two backends produce structurally
different metrics, not a scale factor: different distributions, different
shapes, and the difference is not uniform across metrics.

It also puts a boundary where the lab was looking for one. What the analytical
formula captures well (prefill, tail TTFT), what it systematically misses
(per-token decode overhead), and what calibration corrects. **That boundary
moves with the metric you look at, not just with the dimension you configure.**

## What this does not establish

**Which one is right.** Neither backend is ground truth here.

Qwen3-14B happens to be inside trained-physics's published validation set, so
its numbers are the closer of the two to reality *for this model*. The roofline
numbers are analytically correct but uncalibrated: they describe an ideal
machine, not a real one.

Outside that validation set, fidelity is **unknown**, and the gap measured here
could invert. Level ③ is not reachable from a laptop.

---

Previous: [lab 01, the baseline](lab-01-baseline.md).

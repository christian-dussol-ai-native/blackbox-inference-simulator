#!/usr/bin/env bash
# Lab 02: roofline against trained-physics, same workload, cluster summary.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
require_jq
BLIS="$(find_blis)"
BLIS_DIR="$(dirname "${BLIS}")"

OUT="${OUT_DIR:-$(mktemp -d)}"
FIELDS='{ttft_mean_ms, ttft_p90_ms, ttft_p99_ms, itl_mean_ms, itl_p99_ms,
         e2e_mean_ms, e2e_p99_ms, scheduling_delay_p99_ms,
         tokens_per_sec, responses_per_sec, preemption_count, completed_requests}'

echo "BLIS:   ${BLIS}"
echo "commit: $(git -C "${BLIS_DIR}" rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
echo "output: ${OUT}"
echo

for model in roofline trained-physics; do
  echo "Running --latency-model ${model} (4 instances, 100 req/s, 500 requests)"
  ( cd "${BLIS_DIR}" && ./blis run --model qwen/qwen3-14b \
      --latency-model "${model}" --hardware H100 --tp 1 \
      --num-instances 4 --rate 100 --num-requests 500 2>/dev/null ) \
    > "${OUT}/${model}.raw"
  cluster_summary < "${OUT}/${model}.raw" | jq "${FIELDS}" > "${OUT}/${model}.json"
done

echo
echo "Cluster summary, roofline versus trained-physics"
echo

jq -n -r --slurpfile r "${OUT}/roofline.json" --slurpfile t "${OUT}/trained-physics.json" '
  ["metric", "roofline", "trained-physics", "delta"],
  ["------", "--------", "---------------", "-----"],
  ( ["ttft_mean_ms","ttft_p90_ms","ttft_p99_ms","itl_mean_ms","itl_p99_ms",
     "e2e_mean_ms","e2e_p99_ms","scheduling_delay_p99_ms",
     "tokens_per_sec","responses_per_sec"][]
    as $k
    | ($r[0][$k]) as $a | ($t[0][$k]) as $b
    | [$k, ($a|tostring|.[0:9]), ($b|tostring|.[0:9]),
       (if $a == 0 then "n/a" else ((($b - $a) / $a * 100) | round | tostring) + "%" end)] )
  | @tsv' | column -t

echo
echo "Per-instance blocks and full JSON kept in ${OUT}"
echo "See labs/lab-02-latency-models.md for the reading."

#!/usr/bin/env bash
# Lab 01: one instance, default load. See the tool run, read its output.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
BLIS="$(find_blis)"
BLIS_DIR="$(dirname "${BLIS}")"

echo "BLIS:   ${BLIS}"
echo "commit: $(git -C "${BLIS_DIR}" rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
echo

echo "Running: blis run --model qwen/qwen3-14b"
echo "(100 requests, 1 req/s, 1 instance, trained-physics, TP=1)"
echo

( cd "${BLIS_DIR}" && ./blis run --model qwen/qwen3-14b 2>/dev/null )

cat <<'MSG'

Read the health indicators before any latency number:
  preemption_count / dropped_unservable / still_queued / still_running

All zero means the latencies below describe an unsaturated system, which is
what a baseline has to be. See labs/lab-01-baseline.md for what to make of it.
MSG

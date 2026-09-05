#!/usr/bin/env bash
# Shared helpers: locate the blis binary and check dependencies.

BLIS_COMMIT="f4c8c619"
BLIS_REPO="https://github.com/inference-sim/inference-sim.git"

# Where setup.sh puts BLIS, unless BLIS_BIN says otherwise.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_BLIS="${REPO_ROOT}/../inference-sim/blis"

find_blis() {
  if [[ -n "${BLIS_BIN:-}" ]]; then
    if [[ ! -x "${BLIS_BIN}" ]]; then
      echo "BLIS_BIN is set to '${BLIS_BIN}' but that is not an executable." >&2
      exit 1
    fi
    echo "${BLIS_BIN}"
    return
  fi

  if [[ -x "${DEFAULT_BLIS}" ]]; then
    echo "${DEFAULT_BLIS}"
    return
  fi

  if command -v blis >/dev/null 2>&1; then
    command -v blis
    return
  fi

  cat >&2 <<'MSG'
Could not find the blis binary.

Run ./scripts/setup.sh to clone and build it, or point at an existing build:

    export BLIS_BIN=/path/to/inference-sim/blis
MSG
  exit 1
}

require_jq() {
  command -v jq >/dev/null 2>&1 || {
    echo "jq is required to extract the cluster summary. Install it and retry." >&2
    exit 1
  }
}

# BLIS prints "=== Simulation Metrics ===" on stdout before each JSON block,
# so the headers have to be stripped before jq can slurp the stream.
cluster_summary() {
  grep -v '^=== ' | jq --slurp '.[] | select(.instance_id == "cluster")'
}

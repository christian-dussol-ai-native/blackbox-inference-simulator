#!/usr/bin/env bash
# Clone BLIS next to this repository and build the pinned commit.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

TARGET="${REPO_ROOT}/../inference-sim"

command -v go >/dev/null 2>&1 || {
  echo "Go is required to build BLIS (go.mod asks for 1.24.0 or later)." >&2
  echo "Install it from https://go.dev/dl/ and retry." >&2
  exit 1
}

echo "Go: $(go version)"

if [[ -d "${TARGET}/.git" ]]; then
  echo "BLIS already cloned at ${TARGET}, fetching."
  git -C "${TARGET}" fetch --quiet origin
else
  echo "Cloning BLIS into ${TARGET}"
  git clone --quiet "${BLIS_REPO}" "${TARGET}"
fi

echo "Checking out pinned commit ${BLIS_COMMIT}"
git -C "${TARGET}" checkout --quiet "${BLIS_COMMIT}" || {
  echo >&2
  echo "Could not check out ${BLIS_COMMIT}. The upstream history may have moved." >&2
  echo "Build the default branch instead, and record the commit you used:" >&2
  echo "    git -C ${TARGET} rev-parse --short HEAD" >&2
  exit 1
}

echo "Building the blis binary"
( cd "${TARGET}" && go build -o blis main.go )

echo
echo "Done: ${TARGET}/blis"
echo "BLIS commit: $(git -C "${TARGET}" rev-parse --short HEAD)"
echo
echo "Next: ./scripts/lab-01-baseline.sh"

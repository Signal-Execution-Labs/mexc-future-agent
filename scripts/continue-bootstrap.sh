#!/usr/bin/env bash
# Continues bootstrap from commit 12 onward (after decode-body).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
source "$(dirname "$0")/bootstrap-commits.sh" 2>/dev/null || true

commit() {
  git add -A
  git commit -m "$1"
}

mkdir -p src/http src/api src/risk src/indicators src/strategies src/bot docs

# Resume at step 12 - paste remaining from bootstrap starting decode-body
# (invoked by re-running fixed bootstrap with SKIP_UNTIL)

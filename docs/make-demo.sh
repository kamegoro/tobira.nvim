#!/usr/bin/env bash
# Generate demo GIFs for tobira.nvim using VHS.
# https://github.com/charmbracelet/vhs
#
# Usage (from anywhere in the repo):
#   bash docs/make-demo.sh            # all three GIFs
#   bash docs/make-demo.sh suggest    # only demo-suggest.gif
#   bash docs/make-demo.sh guide      # only demo-guide.gif
#   bash docs/make-demo.sh progress   # only demo-progress.gif
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

if ! command -v vhs &>/dev/null; then
  echo "vhs not found. Install with: brew install vhs"
  exit 1
fi

TARGET="${1:-all}"

run() {
  local name="$1"
  echo "▶  Recording docs/demo-${name}.tape …"
  vhs "docs/demo-${name}.tape"
  echo "   ✓  docs/demo-${name}.gif  ($(du -h "docs/demo-${name}.gif" | cut -f1))"
}

case "$TARGET" in
  suggest|guide|progress) run "$TARGET" ;;
  all)
    run suggest
    run guide
    run progress
    echo ""
    echo "Done. Commit with:"
    echo "  git add docs/demo-suggest.gif docs/demo-guide.gif docs/demo-progress.gif"
    echo "  git commit -m 'docs: regenerate demo GIFs'"
    ;;
  *)
    echo "Usage: $0 [suggest|guide|progress|all]"
    exit 1
    ;;
esac

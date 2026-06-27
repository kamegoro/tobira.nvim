#!/usr/bin/env bash
# Record docs/demo.gif using VHS (https://github.com/charmbracelet/vhs)
#
# Usage:
#   bash docs/make-demo.sh

set -e
cd "$(git rev-parse --show-toplevel)"

if ! command -v vhs &>/dev/null; then
  echo "vhs not found. Installing via Homebrew..."
  brew install vhs
fi

echo "Recording demo..."
vhs docs/demo.tape

echo ""
echo "Saved: docs/demo.gif ($(du -h docs/demo.gif | cut -f1))"

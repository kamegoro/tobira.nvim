#!/usr/bin/env bash
# Writes demo seed data to tobira's data dir.
# Backs up any existing usage.json first.
set -euo pipefail

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/tobira"
mkdir -p "$DATA_DIR"

BACKUP="$DATA_DIR/usage.json.demo-bak"
if [ -f "$DATA_DIR/usage.json" ]; then
  cp "$DATA_DIR/usage.json" "$BACKUP"
  echo "Backed up existing usage.json → $BACKUP"
fi

cat > "$DATA_DIR/usage.json" << 'EOF'
{"f":{"count":18,"shown":0,"adopted":false},"h":{"count":45,"shown":0,"adopted":false},"j":{"count":62,"shown":0,"adopted":false},"k":{"count":28,"shown":0,"adopted":false},"l":{"count":38,"shown":0,"adopted":false},"w":{"count":15,"shown":0,"adopted":false},"b":{"count":8,"shown":0,"adopted":false},"i":{"count":45,"shown":0,"adopted":false},"x":{"count":22,"shown":0,"adopted":false},"p":{"count":8,"shown":0,"adopted":false},"u":{"count":9,"shown":0,"adopted":false},"n":{"count":15,"shown":0,"adopted":false},"_meta":{"guide_seen":true}}
EOF

echo "Demo seed written to $DATA_DIR/usage.json"

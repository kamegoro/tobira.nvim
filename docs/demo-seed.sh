#!/usr/bin/env bash
# Write demo seed data to tobira's data dir.
# Backs up any existing usage.json first.
set -euo pipefail

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/tobira"
mkdir -p "$DATA_DIR"

if [ -f "$DATA_DIR/usage.json" ]; then
  cp "$DATA_DIR/usage.json" "$DATA_DIR/usage.json.demo-bak"
fi

cat > "$DATA_DIR/usage.json" << 'EOF'
{"f":{"count":18,"sessions":[],"shown":0,"suppressed":false},"h":{"count":45,"sessions":[10,12,8],"shown":0,"suppressed":false},"j":{"count":62,"sessions":[12,15,10],"shown":0,"suppressed":false},"k":{"count":28,"sessions":[6,7,5],"shown":0,"suppressed":false},"l":{"count":38,"sessions":[8,9,7],"shown":0,"suppressed":false},"w":{"count":15,"sessions":[2,3,1],"shown":0,"suppressed":false},"b":{"count":8,"sessions":[1,2,1],"shown":0,"suppressed":false},"i":{"count":45,"sessions":[8,10,7],"shown":0,"suppressed":false},"x":{"count":22,"sessions":[4,5,3],"shown":0,"suppressed":false},"p":{"count":8,"sessions":[1,2,1],"shown":0,"suppressed":false},"u":{"count":9,"sessions":[2,2,1],"shown":0,"suppressed":false},"n":{"count":15,"sessions":[3,4,3],"shown":0,"suppressed":false},"_meta":{"guide_seen":true}}
EOF

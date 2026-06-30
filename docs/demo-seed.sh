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
{
  "h":    {"count":180,"sessions":[8,9,11],"shown":0,"suppressed":false,"pinned":false},
  "j":    {"count":240,"sessions":[12,14,10],"shown":0,"suppressed":false,"pinned":false},
  "k":    {"count":130,"sessions":[6,7,8],"shown":0,"suppressed":false,"pinned":false},
  "l":    {"count":160,"sessions":[9,10,8],"shown":0,"suppressed":false,"pinned":false},
  "w":    {"count":110,"sessions":[5,6,7],"shown":0,"suppressed":false,"pinned":false},
  "b":    {"count":105,"sessions":[4,5,6],"shown":0,"suppressed":false,"pinned":false},
  "i":    {"count":200,"sessions":[10,11,9],"shown":0,"suppressed":false,"pinned":false},
  "u":    {"count":120,"sessions":[6,7,5],"shown":0,"suppressed":false,"pinned":false},
  "dw":   {"count":1200,"sessions":[15,18,20],"shown":0,"suppressed":false,"pinned":false},
  "cw":   {"count":1500,"sessions":[18,20,22],"shown":0,"suppressed":false,"pinned":false},
  "ciw":  {"count":5200,"sessions":[25,28,30],"shown":0,"suppressed":false,"pinned":false},
  "f":    {"count":42,"sessions":[2,3,4],"shown":1,"suppressed":false,"pinned":false},
  "x":    {"count":28,"sessions":[1,2,3],"shown":0,"suppressed":false,"pinned":false},
  "dd":   {"count":88,"sessions":[4,5,3],"shown":0,"suppressed":true,"pinned":false},
  "n":    {"count":35,"sessions":[2,2,3],"shown":0,"suppressed":false,"pinned":false},
  "<C-r>":{"count":12,"sessions":[1,1,2],"shown":0,"suppressed":false,"pinned":true},
  "_meta":{"guide_seen":true}
}
EOF

echo "Demo seed written to $DATA_DIR/usage.json"

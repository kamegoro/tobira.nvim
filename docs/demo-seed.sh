#!/usr/bin/env bash
# Writes demo seed data to tobira's data dir.
# Backs up any existing usage.json first.
# The data mirrors demo-init.lua so manual runs and VHS recordings look identical.
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
  "h":      {"count":5000,"sessions":[25,28,30,32,29],"shown":0,"suppressed":false,"pinned":false},
  "j":      {"count":6200,"sessions":[30,35,32,28,31],"shown":0,"suppressed":false,"pinned":false},
  "k":      {"count":2800,"sessions":[18,20,22,19,21],"shown":0,"suppressed":false,"pinned":false},
  "l":      {"count":3100,"sessions":[20,22,19,21,20],"shown":0,"suppressed":false,"pinned":false},
  "i":      {"count":2500,"sessions":[18,20,18,17,19],"shown":0,"suppressed":false,"pinned":false},
  "ciw":    {"count":5200,"sessions":[25,28,30,27,29],"shown":0,"suppressed":false,"pinned":false},
  "w":      {"count":1100,"sessions":[15,18,20,17,16],"shown":0,"suppressed":false,"pinned":false},
  "b":      {"count":1050,"sessions":[14,17,19,16,15],"shown":0,"suppressed":false,"pinned":false},
  "u":      {"count":1100,"sessions":[15,18,20,17,16],"shown":0,"suppressed":false,"pinned":false},
  "dw":     {"count":1200,"sessions":[15,18,20,17,16],"shown":0,"suppressed":false,"pinned":false},
  "cw":     {"count":1500,"sessions":[18,20,22,19,21],"shown":0,"suppressed":false,"pinned":false},
  "a":      {"count":1800,"sessions":[14,16,18,15,17],"shown":0,"suppressed":false,"pinned":false},
  "o":      {"count":600, "sessions":[8,9,10,8,9],    "shown":0,"suppressed":false,"pinned":false},
  "x":      {"count":280, "sessions":[4,5,6,4,5],     "shown":0,"suppressed":false,"pinned":false},
  "n":      {"count":350, "sessions":[5,6,7,5,6],     "shown":0,"suppressed":false,"pinned":false},
  "p":      {"count":200, "sessions":[3,4,5,3,4],     "shown":0,"suppressed":false,"pinned":false},
  "v":      {"count":450, "sessions":[6,7,8,6,7],     "shown":0,"suppressed":false,"pinned":false},
  "G":      {"count":150, "sessions":[3,4,4,3,3],     "shown":0,"suppressed":false,"pinned":false},
  "f":      {"count":42,  "sessions":[2,3,4,2,3],     "shown":1,"suppressed":false,"pinned":false},
  "*":      {"count":55,  "sessions":[2,3,3,2,3],     "shown":0,"suppressed":false,"pinned":false},
  "}":      {"count":28,  "sessions":[1,2,3,2,1],     "shown":0,"suppressed":false,"pinned":false},
  "{":      {"count":15,  "sessions":[1,1,2,1,1],     "shown":0,"suppressed":false,"pinned":false},
  "^":      {"count":35,  "sessions":[1,2,2,1,2],     "shown":0,"suppressed":false,"pinned":false},
  "$":      {"count":40,  "sessions":[1,2,2,1,2],     "shown":0,"suppressed":false,"pinned":false},
  "%":      {"count":22,  "sessions":[1,1,2,1,1],     "shown":0,"suppressed":false,"pinned":false},
  "<C-o>":  {"count":58,  "sessions":[2,3,3,2,3],     "shown":0,"suppressed":false,"pinned":false},
  "dd":     {"count":88,  "sessions":[4,5,3,4,5],     "shown":0,"suppressed":true, "pinned":false},
  "<C-r>":  {"count":12,  "sessions":[1,1,2,1,1],     "shown":0,"suppressed":false,"pinned":true},
  "_meta":  {"guide_seen":true}
}
EOF

echo "Demo seed written to $DATA_DIR/usage.json"

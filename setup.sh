#!/bin/bash
set -e

SETTINGS_FILE="$HOME/.claude/settings.json"

NEW_ENTRY='{
  "extraKnownMarketplaces": {
    "ontologian": {
      "source": {
        "source": "github",
        "repo": "swszz/ontologian"
      }
    }
  }
}'

mkdir -p "$(dirname "$SETTINGS_FILE")"

if [ -f "$SETTINGS_FILE" ] && [ -s "$SETTINGS_FILE" ]; then
  if command -v jq &>/dev/null; then
    tmp=$(mktemp)
    jq --argjson entry "$NEW_ENTRY" '. * $entry' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
  elif command -v python3 &>/dev/null; then
    python3 - "$SETTINGS_FILE" "$NEW_ENTRY" <<'PYEOF'
import sys, json
path, new_entry_str = sys.argv[1], sys.argv[2]
with open(path) as f:
    settings = json.load(f)
new_entry = json.loads(new_entry_str)
def deep_merge(base, override):
    for k, v in override.items():
        if k in base and isinstance(base[k], dict) and isinstance(v, dict):
            deep_merge(base[k], v)
        else:
            base[k] = v
    return base
settings = deep_merge(settings, new_entry)
with open(path, 'w') as f:
    json.dump(settings, f, indent=2)
PYEOF
  else
    echo "Error: jq or python3 is required."
    exit 1
  fi
else
  echo "$NEW_ENTRY" > "$SETTINGS_FILE"
fi

echo ""
echo "Done. Run this in Claude Code:"
echo ""
echo "  /plugin install ontologian@ontologian"
echo ""

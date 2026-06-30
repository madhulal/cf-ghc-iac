#!/usr/bin/env bash
# Generates a pre-filled Cloudflare account-level API token creation URL from
# cloudflare-token-permissions.json. Run this script whenever permissions change,
# then update the URL in README.md.
#
# Usage: ./generate-cf-token-url.sh [token-name]
# Default token name: "Valoriz IaC"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERMISSIONS_FILE="$SCRIPT_DIR/cloudflare-token-permissions.json"
TOKEN_NAME="${1:-Valoriz IaC}"

if ! command -v python3 &>/dev/null; then
  echo "Error: python3 is required" >&2
  exit 1
fi

if [[ ! -f "$PERMISSIONS_FILE" ]]; then
  echo "Error: $PERMISSIONS_FILE not found" >&2
  exit 1
fi

python3 - "$PERMISSIONS_FILE" "$TOKEN_NAME" <<'EOF'
import sys, json, urllib.parse

permissions_file, token_name = sys.argv[1], sys.argv[2]

with open(permissions_file) as f:
    raw = json.load(f)

# Strip description field — Cloudflare only accepts key + type
permissions = [{"key": p["key"], "type": p["type"]} for p in raw]

encoded = urllib.parse.quote(json.dumps(permissions, separators=(",", ":")))
name    = urllib.parse.quote(token_name)

print(f"https://dash.cloudflare.com/?to=/:account/api-tokens&permissionGroupKeys={encoded}&name={name}")
EOF

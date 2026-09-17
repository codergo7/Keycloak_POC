#!/usr/bin/env bash
set -euo pipefail
TOKEN="${1:-}"
if [ -z "$TOKEN" ]; then
  echo "usage: $0 <jwt>" >&2
  exit 1
fi
python3 - "$TOKEN" <<'PY'
import base64, json, sys
parts = sys.argv[1].split(".")
for name, p in [("header", parts[0]), ("payload", parts[1])]:
    p += "=" * (-len(p) % 4)
    print(f"--- {name} ---")
    print(json.dumps(json.loads(base64.urlsafe_b64decode(p)), indent=2))
PY

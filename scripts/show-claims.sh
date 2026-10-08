#!/usr/bin/env bash
set -euo pipefail

USERNAME="${1:?Usage: $0 <username> <password>}"
PASSWORD="${2:?Usage: $0 <username> <password>}"

TOKEN="$(./scripts/get-token.sh "$USERNAME" "$PASSWORD")"

if [[ -z "$TOKEN" ]]; then
  echo "Failed to obtain token for $USERNAME" >&2
  exit 1
fi

TOKEN="$TOKEN" python3 - <<'PY'
import os
import json
import base64
from datetime import datetime, timezone

token = os.environ["TOKEN"]

try:
    payload = token.split(".")[1]
    payload += "=" * (-len(payload) % 4)

    claims = json.loads(base64.urlsafe_b64decode(payload))

    # Add human-readable timestamps
    for field in ("iat", "exp", "nbf", "auth_time"):
        if isinstance(claims.get(field), (int, float)):
            claims[field + "_readable"] = datetime.fromtimestamp(
                claims[field], tz=timezone.utc
            ).isoformat()

    print(json.dumps(claims, indent=2, ensure_ascii=False))

except (IndexError, ValueError) as exc:
    raise SystemExit(f"Failed to decode JWT: {exc}")
PY
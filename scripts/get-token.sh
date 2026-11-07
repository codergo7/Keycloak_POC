#!/usr/bin/env bash
set -euo pipefail
USER="${1:-alice}"
PASS="${2:-$USER}"
# Optional extra scopes, e.g. "reports" to get aud reports-api
EXTRA_SCOPE="${3:-}"

curl -fsS \
  -H 'Host: keycloak.localhost' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "client_id=cli-client" \
  -d "client_secret=cli-secret" \
  -d "username=${USER}" \
  -d "password=${PASS}" \
  -d "grant_type=password" \
  -d "scope=openid profile email groups app-audience${EXTRA_SCOPE:+ $EXTRA_SCOPE}" \
  http://localhost:8080/realms/demo/protocol/openid-connect/token | jq -r .access_token

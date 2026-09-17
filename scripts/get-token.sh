#!/usr/bin/env bash
set -euo pipefail
USER="${1:-alice}"
PASS="${2:-$USER}"

curl -fsS \
  -H 'Host: keycloak.localhost' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "client_id=cli-client" \
  -d "client_secret=cli-secret" \
  -d "username=${USER}" \
  -d "password=${PASS}" \
  -d "grant_type=password" \
  -d "scope=openid profile email groups app-audience" \
  http://localhost:8080/realms/poc/protocol/openid-connect/token | jq -r .access_token

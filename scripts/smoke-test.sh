#!/usr/bin/env bash
set -euo pipefail

echo "1) Public endpoint should be 200"
curl -fsS -H 'Host: api.localhost' http://localhost:8080/api/public | jq .

echo
echo "2) Protected endpoint without token should be 403"
code="$(curl -sS -o /dev/null -w '%{http_code}' -H 'Host: api.localhost' http://localhost:8080/api/user)"
test "$code" = "403" && echo "OK: 403" || { echo "Expected 403, got $code"; exit 1; }

echo
echo "3) Alice token -> authenticated endpoint should be 200"
ALICE="$(./scripts/get-token.sh alice alice)"
curl -fsS -H 'Host: api.localhost' -H "Authorization: Bearer ${ALICE}" \
  http://localhost:8080/api/user | jq .

echo
echo "4) Alice -> admin endpoint should be 403"
code="$(curl -sS -o /dev/null -w '%{http_code}' -H 'Host: api.localhost' \
  -H "Authorization: Bearer ${ALICE}" http://localhost:8080/api/admin)"
test "$code" = "403" && echo "OK: 403" || { echo "Expected 403, got $code"; exit 1; }

echo
echo "5) Admin token -> admin endpoint should be 200"
ADMIN="$(./scripts/get-token.sh admin admin)"
curl -fsS -H 'Host: api.localhost' -H "Authorization: Bearer ${ADMIN}" \
  http://localhost:8080/api/admin | jq .

echo
echo "Smoke tests passed."

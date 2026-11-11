#!/usr/bin/env bash
set -euo pipefail

API_URL="${API_URL:-http://localhost:8080}"
APP_URL="${APP_URL:-http://localhost:8080}"

PASSED=0
FAILED=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

section() {
  echo
  echo "======================================================================"
  echo "$1"
  echo "======================================================================"
}

pass() {
  echo "✅ PASS: $1"
  PASSED=$((PASSED + 1))
}

fail() {
  echo "❌ FAIL: $1"
  FAILED=$((FAILED + 1))
}

expect_code() {
  local description="$1"
  local expected="$2"
  shift 2

  local actual

  actual="$(curl -sS -o /dev/null -w '%{http_code}' "$@")"

  if [[ "$actual" == "$expected" ]]; then
    pass "$description → HTTP $actual"
  else
    fail "$description → expected HTTP $expected, got HTTP $actual"
  fi
}

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------

echo
echo "######################################################################"
echo "#                                                                    #"
echo "#        Keycloak + Istio Authorization POC Smoke Tests              #"
echo "#                                                                    #"
echo "######################################################################"
echo
echo "This test suite validates:"
echo "  • Public access"
echo "  • JWT authentication"
echo "  • JWT validation failure"
echo "  • Role-based authorization"
echo "  • Audience and client-role authorization (reports API)"
echo "  • OAuth2-Proxy browser redirect"

# ===========================================================================
# 1. PUBLIC ENDPOINT
# ===========================================================================

section "1. Public endpoint — no authentication required"

echo "Scenario:"
echo "  Client → Istio Ingress → /api/public"
echo "  No JWT is supplied."
echo

expect_code \
  "Public endpoint accessible without JWT" \
  "200" \
  -H 'Host: api.localhost' \
  "${API_URL}/api/public"

# ===========================================================================
# 2. PROTECTED ENDPOINT WITHOUT JWT
# ===========================================================================

section "2. Protected endpoint — missing JWT"

echo "Scenario:"
echo "  Client → Istio Ingress → /api/user"
echo "  RequestAuthentication sees no JWT."
echo "  AuthorizationPolicy requires an authenticated requestPrincipal."
echo

expect_code \
  "Protected endpoint rejected without JWT" \
  "403" \
  -H 'Host: api.localhost' \
  "${API_URL}/api/user"

# ===========================================================================
# 3. GET ALICE TOKEN
# ===========================================================================

section "3. Keycloak token — Alice"

echo "Requesting an access token from Keycloak for Alice..."

if ALICE="$(./scripts/get-token.sh alice alice)" && [[ -n "$ALICE" ]]; then
  pass "Alice access token obtained"
else
  fail "Could not obtain Alice access token"
  ALICE=""
fi

# ===========================================================================
# 4. VALID JWT
# ===========================================================================

section "4. Valid JWT — authenticated endpoint"

echo "Scenario:"
echo "  Alice JWT"
echo "      ↓"
echo "  RequestAuthentication validates JWT"
echo "      ↓"
echo "  requestPrincipal exists"
echo "      ↓"
echo "  AuthorizationPolicy allows /api/user"
echo

if [[ -n "$ALICE" ]]; then
  expect_code \
    "Alice can access /api/user" \
    "200" \
    -H 'Host: api.localhost' \
    -H "Authorization: Bearer ${ALICE}" \
    "${API_URL}/api/user"
else
  fail "Alice /api/user test skipped because token was unavailable"
fi

# ===========================================================================
# 5. INVALID JWT
# ===========================================================================

section "5. Invalid JWT — RequestAuthentication rejection"

echo "Scenario:"
echo "  A corrupted JWT is supplied."
echo "  JWT verification must fail before the request reaches the application."
echo

if [[ -n "$ALICE" ]]; then
  expect_code \
    "Corrupted JWT rejected by Istio" \
    "401" \
    -H 'Host: api.localhost' \
    -H "Authorization: Bearer ${ALICE}BROKEN" \
    "${API_URL}/api/user"
else
  fail "Invalid JWT test skipped because Alice token was unavailable"
fi

# ===========================================================================
# 6. AUTHENTICATED BUT NOT AUTHORIZED
# ===========================================================================

section "6. Role authorization — Alice is not admin"

echo "Scenario:"
echo "  Alice has a valid JWT."
echo "  Authentication succeeds."
echo "  Alice does not have the required admin role."
echo

if [[ -n "$ALICE" ]]; then
  expect_code \
    "Alice denied access to /api/admin" \
    "403" \
    -H 'Host: api.localhost' \
    -H "Authorization: Bearer ${ALICE}" \
    "${API_URL}/api/admin"
else
  fail "Alice admin authorization test skipped because token was unavailable"
fi

# ===========================================================================
# 7. ADMIN AUTHORIZATION
# ===========================================================================

section "7. Role authorization — Admin"

echo "Requesting an access token from Keycloak for Admin..."

if ADMIN="$(./scripts/get-token.sh admin admin)" && [[ -n "$ADMIN" ]]; then
  pass "Admin access token obtained"
else
  fail "Could not obtain Admin access token"
  ADMIN=""
fi

if [[ -n "$ADMIN" ]]; then
  expect_code \
    "Admin can access /api/admin" \
    "200" \
    -H 'Host: api.localhost' \
    -H "Authorization: Bearer ${ADMIN}" \
    "${API_URL}/api/admin"
else
  fail "Admin /api/admin test skipped because token was unavailable"
fi

# ===========================================================================
# 8. AUDIENCE — REPORTS API
# ===========================================================================

section "8. Audience — reports API needs aud reports-api"

echo "Scenario:"
echo "  Bob asks for a token without scope=reports."
echo "  The token is valid, but its aud does not contain reports-api."
echo "  The reports sidecar's RequestAuthentication rejects it."
echo "  Envoy answers a wrong audience with 403 (not 401)."
echo

if BOB="$(./scripts/get-token.sh bob bob)" && [[ -n "$BOB" ]]; then
  BODY="$(curl -sS -w ' HTTP %{http_code}' \
    -H 'Host: api.localhost' \
    -H "Authorization: Bearer ${BOB}" \
    "${API_URL}/reports")"
  if [[ "$BODY" == "Audiences in Jwt are not allowed HTTP 403" ]]; then
    pass "Bob without scope=reports rejected by the reports API → $BODY"
  else
    fail "Bob without scope=reports → expected 'Audiences in Jwt are not allowed HTTP 403', got '$BODY'"
  fi
else
  fail "Could not obtain Bob access token"
fi

# ===========================================================================
# 9. CLIENT ROLES — REPORTS API
# ===========================================================================

section "9. Client roles — reports-api viewer and editor"

echo "Scenario:"
echo "  Tokens are requested with scope=reports (aud reports-api)."
echo "  Bob is in /finance, which gives the reports-api viewer role."
echo "  Creating a report needs the editor role (/finance/managers)."
echo "  Alice has realm roles only, so the reports API denies her."
echo

if BOB_R="$(./scripts/get-token.sh bob bob reports)" && [[ -n "$BOB_R" ]]; then
  expect_code \
    "Bob (viewer) can list reports" \
    "200" \
    -H 'Host: api.localhost' \
    -H "Authorization: Bearer ${BOB_R}" \
    "${API_URL}/reports"

  expect_code \
    "Bob (viewer) cannot create a report" \
    "403" \
    -X POST \
    -H 'Host: api.localhost' \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer ${BOB_R}" \
    -d '{"title":"smoke"}' \
    "${API_URL}/reports"
else
  fail "Could not obtain Bob token with scope=reports"
fi

if ALICE_R="$(./scripts/get-token.sh alice alice reports)" && [[ -n "$ALICE_R" ]]; then
  expect_code \
    "Alice (no reports-api role) denied by the reports API" \
    "403" \
    -H 'Host: api.localhost' \
    -H "Authorization: Bearer ${ALICE_R}" \
    "${API_URL}/reports"
else
  fail "Could not obtain Alice token with scope=reports"
fi

# ===========================================================================
# 10. SPOOFED IDENTITY HEADER
# ===========================================================================

section "10. Trust boundary — client-sent identity headers are removed"

echo "Scenario:"
echo "  Alice sends a valid token plus X-Auth-Request-User: admin to api.localhost."
echo "  The route removes it, and the sidecar writes the real user ID from the token."
echo

if [[ -n "$ALICE" ]]; then
  SPOOF_USER="$(curl -sS \
    -H 'Host: api.localhost' \
    -H "Authorization: Bearer ${ALICE}" \
    -H 'X-Auth-Request-User: admin' \
    "${API_URL}/api/whoami" | jq -r .xAuthRequestUser)"
  if [[ -n "$SPOOF_USER" && "$SPOOF_USER" != "null" && "$SPOOF_USER" != "admin" ]]; then
    pass "Spoofed X-Auth-Request-User replaced by the token subject ($SPOOF_USER)"
  else
    fail "Spoofed X-Auth-Request-User reached Spring as '$SPOOF_USER'"
  fi
else
  fail "Spoofed header test skipped because Alice token was unavailable"
fi

# ===========================================================================
# 11. OAUTH2-PROXY BROWSER FLOW
# ===========================================================================

section "11. Browser authentication — OAuth2-Proxy redirect"

echo "Scenario:"
echo "  Browser has no OAuth2-Proxy session."
echo "  RequestAuthentication does not require a JWT by itself."
echo "  OAuth2-Proxy should redirect the browser to Keycloak."
echo

HEADERS="$(mktemp)"
trap 'rm -f "$HEADERS"' EXIT

curl -sS \
  -D "$HEADERS" \
  -o /dev/null \
  -H 'Host: app.localhost' \
  -A 'Mozilla/5.0' \
  "${APP_URL}/"

STATUS="$(awk 'NR==1 {print $2}' "$HEADERS" | tr -d '\r')"
LOCATION="$(awk 'BEGIN{IGNORECASE=1} /^location:/ {
  sub(/^[Ll]ocation:[[:space:]]*/, "");
  gsub(/\r/, "");
  print;
  exit
}' "$HEADERS")"

if [[ "$STATUS" =~ ^30[12378]$ ]] &&
   [[ "$LOCATION" == *"keycloak.localhost"* ]] &&
   [[ "$LOCATION" == *"/protocol/openid-connect/auth"* ]]; then
  pass "OAuth2-Proxy redirects unauthenticated browser to Keycloak"
  echo "   Redirect: ${LOCATION%%\?*}"
else
  fail "Expected OAuth2-Proxy → Keycloak redirect; status=$STATUS location=$LOCATION"
fi

# ===========================================================================
# SUMMARY
# ===========================================================================

section "SMOKE TEST SUMMARY"

echo "Passed: ${PASSED}"
echo "Failed: ${FAILED}"
echo

if [[ "$FAILED" -eq 0 ]]; then
  echo "🎉 ALL SMOKE TESTS PASSED"
  echo
  echo "Validated architecture:"
  echo
  echo "  Browser → OAuth2-Proxy → Keycloak"
  echo "               ✓ redirect/login entry point"
  echo
  echo "  API → RequestAuthentication → AuthorizationPolicy → Spring"
  echo "               ✓ JWT authentication"
  echo "               ✓ invalid JWT rejection"
  echo "               ✓ role authorization"
  echo
  echo "  API → RequestAuthentication (aud) → AuthorizationPolicy (client roles) → FastAPI"
  echo "               ✓ audience check"
  echo "               ✓ client-role authorization"
  echo
  exit 0
else
  echo "❌ ${FAILED} smoke test(s) failed."
  exit 1
fi
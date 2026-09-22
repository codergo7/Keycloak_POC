#!/usr/bin/env bash
set -euo pipefail

API_URL="${API_URL:-http://localhost:8080}"
APP_URL="${APP_URL:-http://localhost:8080}"
SPRING_INTERNAL_URL="http://spring-app.demo.svc.cluster.local:8080/api/internal"

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
echo "  • OAuth2-Proxy browser redirect"
echo "  • Istio service-to-service mTLS"
echo "  • Kubernetes ServiceAccount authorization"

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
# 8. OAUTH2-PROXY BROWSER FLOW
# ===========================================================================

section "8. Browser authentication — OAuth2-Proxy redirect"

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
# 9. SERVICE A → SPRING
# ===========================================================================

section "9. Service-to-service — authorized workload"

echo "Scenario:"
echo "  service-a"
echo "      ↓"
echo "  Istio mTLS"
echo "      ↓"
echo "  ServiceAccount: service-a/service-a"
echo "      ↓"
echo "  AuthorizationPolicy"
echo "      ↓"
echo "  /api/internal"
echo

SERVICE_A_CODE="$(
  kubectl exec \
    -n service-a \
    deploy/service-a \
    -c service-a \
    -- \
    curl -sS -o /dev/null -w '%{http_code}' \
    "$SPRING_INTERNAL_URL" 2>/dev/null
)"

if [[ "$SERVICE_A_CODE" == "200" ]]; then
  pass "service-a/service-a can access /api/internal → HTTP 200"
else
  fail "service-a/service-a expected HTTP 200, got HTTP ${SERVICE_A_CODE}"
fi

# ===========================================================================
# 10. UNAUTHORIZED WORKLOAD
# ===========================================================================

section "10. Service-to-service — unauthorized ServiceAccount"

echo "Creating temporary bad-client..."
echo
echo "Identity:"
echo "  namespace:      service-a"
echo "  ServiceAccount: default"
echo
echo "Expected:"
echo "  mTLS authentication succeeds"
echo "  workload authorization fails"
echo "  → HTTP 403"
echo

BAD_CLIENT="smoke-bad-client"

kubectl delete pod "$BAD_CLIENT" \
  -n service-a \
  --ignore-not-found=true \
  --wait=true >/dev/null

kubectl run "$BAD_CLIENT" \
  -n service-a \
  --image=curlimages/curl:8.12.1 \
  --restart=Never \
  --command -- sleep 3600 >/dev/null

echo "Waiting for bad-client and its Istio sidecar..."

if kubectl wait \
  -n service-a \
  --for=condition=Ready \
  "pod/${BAD_CLIENT}" \
  --timeout=90s >/dev/null; then

  BAD_SA="$(
    kubectl get pod "$BAD_CLIENT" \
      -n service-a \
      -o jsonpath='{.spec.serviceAccountName}'
  )"

  echo "Detected ServiceAccount: ${BAD_SA}"

  BAD_CODE="$(
    kubectl exec \
      -n service-a \
      "$BAD_CLIENT" \
      -c "$BAD_CLIENT" \
      -- \
      curl -sS -o /dev/null -w '%{http_code}' \
      "$SPRING_INTERNAL_URL" 2>/dev/null || true
  )"

  if [[ "$BAD_SA" == "default" && "$BAD_CODE" == "403" ]]; then
    pass "service-a/default is denied access to /api/internal → HTTP 403"
  else
    fail "Unauthorized workload expected HTTP 403; SA=${BAD_SA}, HTTP=${BAD_CODE}"
  fi
else
  fail "bad-client did not become Ready"
fi

echo "Removing temporary bad-client..."

kubectl delete pod "$BAD_CLIENT" \
  -n service-a \
  --ignore-not-found=true \
  --wait=false >/dev/null

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
  echo "  Service A → Istio mTLS → AuthorizationPolicy → Spring"
  echo "               ✓ workload authentication"
  echo "               ✓ ServiceAccount authorization"
  echo
  exit 0
else
  echo "❌ ${FAILED} smoke test(s) failed."
  exit 1
fi
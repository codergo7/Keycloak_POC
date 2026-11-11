#!/usr/bin/env bash
# Live demo of API access (api.localhost): the seven checks from the "Demo: API access"
# slide, one at a time, with the command, the result and what it proves.
#
#   make demo-api            press Enter to run each request and to show the next check
#   make demo-api AUTO=1     run straight through
#
# Step 7 adds bob to /finance/managers through the Keycloak admin API and
# removes him again at the end, so the demo can be repeated.
set -uo pipefail

API="${API:-http://api.localhost:8080}"
KC="${KC:-http://keycloak.localhost:8080}"
AUTO="${AUTO:-0}"

if [[ -t 1 ]]; then
  B=$'\e[1m'; DIM=$'\e[2m'; R=$'\e[0m'
  RED=$'\e[31m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; BLUE=$'\e[34m'; MAGENTA=$'\e[35m'; CYAN=$'\e[36m'
else
  B=; DIM=; R=; RED=; GREEN=; YELLOW=; BLUE=; MAGENTA=; CYAN=
fi

PASSED=0
FAILED=0

STEPS=0
step() {
  # from the second check on, wait before showing the next one
  if (( STEPS > 0 )); then pause "press Enter for the next check"; fi
  STEPS=$((STEPS + 1))
  echo
  echo "${B}${CYAN}━━━ $1 ━━━${R}"
  shift
  for line in "$@"; do echo "  $line"; done
}

# pause [PROMPT]: wait for Enter (skipped with AUTO=1 or without a terminal)
pause() {
  if [[ "$AUTO" != "1" && -t 0 ]]; then
    read -r -p "  ${DIM}${1:-press Enter to run}${R} " _
  fi
}

show_cmd() {
  echo "  ${YELLOW}\$ $1${R}"
}

# run CURL_ARGS... ; sets CODE and BODY
run() {
  local out
  out="$(curl -sS -w $'\n%{http_code}' "$@")"
  CODE="${out##*$'\n'}"
  BODY="${out%$'\n'*}"
}

color_code() {
  case "$1" in
    2*) echo "${GREEN}${B}$1${R}" ;;
    401) echo "${YELLOW}${B}$1${R}" ;;
    *) echo "${RED}${B}$1${R}" ;;
  esac
}

# expect CODE WHY [TEXT]: TEXT, if given, must also appear in the response body
expect() {
  local expected="$1" why="$2" text="${3:-}"
  echo "  → HTTP $(color_code "$CODE")  ${DIM}${BODY:0:70}${R}"
  if [[ "$CODE" == "$expected" && ( -z "$text" || "$BODY" == *"$text"* ) ]]; then
    echo "  ${GREEN}✔ expected $expected${R}  $why"
    PASSED=$((PASSED + 1))
  else
    echo "  ${RED}✘ expected $expected${text:+ with \"$text\"}, got $CODE${R}  $why"
    FAILED=$((FAILED + 1))
  fi
}

# print the claims that matter for this demo, from a JWT
claims() {
  python3 - "$1" <<'PY'
import base64, json, sys
p = sys.argv[1].split(".")[1]
c = json.loads(base64.urlsafe_b64decode(p + "=" * (-len(p) % 4)))
M, R = ("\033[35m", "\033[0m") if sys.stdout.isatty() else ("", "")
aud = c.get("aud"); aud = aud if isinstance(aud, list) else [aud]
print(f"  token claims: {M}aud{R}={aud}  {M}realm roles{R}={c.get('realm_access', {}).get('roles')}"
      f"  {M}reports-api roles{R}={c.get('resource_access', {}).get('reports-api', {}).get('roles', [])}")
PY
}

# snippet FILE RESOURCE: print the YAML on stdin as an excerpt of FILE, with the
# lines that decide the outcome highlighted
snippet() {
  echo "  ${DIM}┌ $1 · $2${R}"
  while IFS= read -r line; do
    if [[ "$line" =~ requestPrincipals|audiences|request\.auth\.claims|values:|issuer:|jwksUri:|-\ (spring|reports)-api$ ]]; then
      echo "  ${DIM}│${R} ${MAGENTA}${B}${line}${R}"
    else
      echo "  ${DIM}│${R} ${BLUE}${line}${R}"
    fi
  done
  echo "  ${DIM}└${R}"
}

# principal JWT: the requestPrincipal Istio derives from a valid token (iss/sub)
principal() {
  python3 - "$1" <<'PY'
import base64, json, sys
p = sys.argv[1].split(".")[1]
c = json.loads(base64.urlsafe_b64decode(p + "=" * (-len(p) % 4)))
M, B, R = ("\033[35m", "\033[1m", "\033[0m") if sys.stdout.isatty() else ("", "", "")
print(f"  {M}requestPrincipal{R} = {B}{c['iss']}/{c['sub']}{R}   (issuer/subject of the verified token)")
PY
}

token() {
  local t
  if ! t="$(./scripts/get-token.sh "$1" "$1" "${2:-}" 2>/dev/null)" || [[ -z "$t" || "$t" == null ]]; then
    echo "${RED}${B}Could not get a token for $1 from Keycloak.${R} Is Keycloak up? Try: make status" >&2
    exit 1
  fi
  echo "$t"
}

preflight() {
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' "$API/api/public")"
  if [[ "$code" != 200 ]]; then
    echo "${RED}${B}The cluster is not answering (GET /api/public → $code).${R}"
    echo "If the laptop slept, the mesh certificates expired: restart the pods (see the debugging backup slide)."
    exit 1
  fi
}

echo "${B}API access · api.localhost · seven checks with curl${R}"
echo "${DIM}Expected result first, then the real answer from the cluster.${R}"
preflight

# ---------------------------------------------------------------------------
step "1. Public endpoint, no token" \
  "The ingress policy has an ALLOW rule for GET /api/public with ${B}no from: block${R}," \
  "so it does not need a requestPrincipal: anyone matches."
snippet k8s/istio/ingress-authorization.yaml "AuthorizationPolicy ingress-authorization (ALLOW)" <<'YAML'
# Public API endpoint
- to:
    - operation:
        hosts: [api.localhost, "api.localhost:*"]
        methods: ["GET"]
        paths: ["/api/public"]
YAML
show_cmd "curl $API/api/public"
pause
run "$API/api/public"
expect 200 "anyone may call it"

# ---------------------------------------------------------------------------
step "2. Protected endpoint, no token" \
  "RequestAuthentication has ${B}nothing to check${R}, so it lets the request pass." \
  "A ${B}requestPrincipal${R} exists only after RequestAuthentication has verified a JWT: it is iss/sub." \
  "${B}requestPrincipals: [\"*\"]${R} means \"any verified token\". No token → no principal → no rule matches."
snippet k8s/istio/ingress-authorization.yaml "AuthorizationPolicy ingress-authorization (ALLOW)" <<'YAML'
# JWT-authenticated API requests
- from:
    - source:
        requestPrincipals: ["*"]
  to:
    - operation:
        hosts: [api.localhost, "api.localhost:*"]
        methods: ["GET"]
        paths: [/api/user, /api/whoami, /api/headers, /api/admin]
YAML
show_cmd "curl $API/api/user"
pause
run "$API/api/user"
expect 403 "no token → no principal → ${B}RBAC: access denied${R}" "RBAC: access denied"

# ---------------------------------------------------------------------------
ALICE="$(token alice)" || exit 1
step "3. Tampered token" \
  "One character changed in alice's token: the signature no longer matches." \
  "The gateway's RequestAuthentication verifies it with the keys from ${B}jwksUri${R}, for the listed ${B}issuer${R}." \
  "A token that is present but invalid is rejected with 401 before any AuthorizationPolicy runs."
snippet k8s/istio/ingress-authorization.yaml "RequestAuthentication demo-jwt-validation" <<'YAML'
jwtRules:
  - issuer: "http://keycloak.localhost:8080/realms/demo"
    jwksUri: "http://keycloak.identity.svc.cluster.local:8080/realms/demo/protocol/openid-connect/certs"
    forwardOriginalToken: true
YAML
show_cmd "ALICE=\$(make -s token-alice)"
show_cmd "curl -H \"Authorization: Bearer \${ALICE}x\" $API/api/user"
pause
run -H "Authorization: Bearer ${ALICE}x" "$API/api/user"
expect 401 "the JWT check rejects it before any policy runs"

# ---------------------------------------------------------------------------
step "4. alice: user yes, admin no" \
  "alice's token is valid, so she has a requestPrincipal and passes the gateway rule from step 2." \
  "At Spring's sidecar each rule needs the principal ${B}and${R} a realm role in the token (${B}when${R})." \
  "alice has ${B}user${R} and ${B}developer${R}, but not ${B}admin${R}."
principal "$ALICE"
claims "$ALICE"
snippet k8s/app/auth-app.yaml "AuthorizationPolicy spring-workload-authorization (ALLOW)" <<'YAML'
# User role
- from:
    - source:
        requestPrincipals: ["*"]
  to:
    - operation:
        methods: ["GET"]
        paths: [/api/user, /api/whoami]
  when:
    - key: request.auth.claims[realm_access][roles]
      values: ["user"]
# Admin role
- from:
    - source:
        requestPrincipals: ["*"]
  to:
    - operation:
        methods: ["GET"]
        paths: ["/api/admin"]
  when:
    - key: request.auth.claims[realm_access][roles]
      values: ["admin"]
YAML
show_cmd "curl -H \"Authorization: Bearer \$ALICE\" $API/api/user"
pause
run -H "Authorization: Bearer $ALICE" "$API/api/user"
expect 200 "role user is enough for /api/user"
show_cmd "curl -H \"Authorization: Bearer \$ALICE\" $API/api/admin"
pause
run -H "Authorization: Bearer $ALICE" "$API/api/admin"
expect 403 "valid token, but no admin role" "RBAC: access denied"

# ---------------------------------------------------------------------------
BOB="$(token bob)" || exit 1
step "5. bob without scope=reports" \
  "bob has the reports viewer role, but this token was ${B}not issued for the reports API${R}:" \
  "aud contains only spring-api."
claims "$BOB"
snippet k8s/reports/auth-reports.yaml "RequestAuthentication reports-jwt" <<'YAML'
jwtRules:
  - issuer: http://keycloak.localhost:8080/realms/demo
    jwksUri: http://keycloak.identity.svc.cluster.local:8080/realms/demo/protocol/openid-connect/certs
    audiences:
      - reports-api
YAML
echo "  The token is signed correctly, but its aud does not contain ${B}reports-api${R}:"
echo "  the sidecar rejects it ${B}before${R} any requestPrincipal is set or any policy runs."
show_cmd "BOB=\$(make -s token-bob)"
show_cmd "curl -H \"Authorization: Bearer \$BOB\" $API/reports"
pause
run -H "Authorization: Bearer $BOB" "$API/reports"
expect 403 "wrong audience → ${B}Audiences in Jwt are not allowed${R}" "Audiences in Jwt are not allowed"

# ---------------------------------------------------------------------------
BOB_R="$(token bob reports)" || exit 1
step "6. bob with scope=reports" \
  "Same user, new token, asked for ${B}scope=reports${R}: aud now includes reports-api."
principal "$BOB_R"
claims "$BOB_R"
echo "  Now the audience matches, the principal is set, and the ${B}client roles${R} of reports-api decide:"
snippet k8s/reports/auth-reports.yaml "AuthorizationPolicy reports-authorization (ALLOW)" <<'YAML'
# Read reports
- from:
    - source:
        requestPrincipals: ["*"]
  to:
    - operation:
        methods: ["GET"]
        paths: ["/reports"]
  when:
    - key: request.auth.claims[resource_access][reports-api][roles]
      values: ["viewer"]
# Create reports
- from:
    - source:
        requestPrincipals: ["*"]
  to:
    - operation:
        methods: ["POST"]
        paths: ["/reports"]
  when:
    - key: request.auth.claims[resource_access][reports-api][roles]
      values: ["editor"]
YAML
show_cmd "BOB_R=\$(make -s token-bob-reports)"
show_cmd "curl -H \"Authorization: Bearer \$BOB_R\" $API/reports"
pause
run -H "Authorization: Bearer $BOB_R" "$API/reports"
expect 200 "viewer may read reports"
show_cmd "curl -X POST -H \"Authorization: Bearer \$BOB_R\" -H 'Content-Type: application/json' -d '{\"title\":\"Q4 forecast\"}' $API/reports"
pause
run -X POST -H "Authorization: Bearer $BOB_R" -H 'Content-Type: application/json' -d '{"title":"Q4 forecast"}' "$API/reports"
expect 403 "creating needs ${B}editor${R}, bob is only a viewer" "RBAC: access denied"

# ---------------------------------------------------------------------------
step "7. Add bob to /finance/managers" \
  "In the admin console: ${B}Users → bob → Groups → Join group → finance/managers${R}." \
  "The script does the same through the Keycloak admin API, then asks for a new token."
ADMIN_AT="$(curl -sS -d client_id=admin-cli -d username=admin -d password=admin -d grant_type=password \
  "$KC/realms/master/protocol/openid-connect/token" | jq -r .access_token)"
BOB_ID="$(curl -sS -H "Authorization: Bearer $ADMIN_AT" "$KC/admin/realms/demo/users?username=bob&exact=true" | jq -r '.[0].id')"
GROUP_ID="$(curl -sS -H "Authorization: Bearer $ADMIN_AT" "$KC/admin/realms/demo/group-by-path/finance/managers" | jq -r .id)"
if [[ -z "$BOB_ID" || "$BOB_ID" == null || -z "$GROUP_ID" || "$GROUP_ID" == null ]]; then
  echo "${RED}${B}Could not look up bob or /finance/managers with the Keycloak admin API.${R}"
  exit 1
fi
show_cmd "PUT $KC/admin/realms/demo/users/<bob>/groups/<finance/managers>"
pause "press Enter to add bob to /finance/managers"
curl -sS -o /dev/null -X PUT -H "Authorization: Bearer $ADMIN_AT" "$KC/admin/realms/demo/users/$BOB_ID/groups/$GROUP_ID"
trap 'curl -sS -o /dev/null -X DELETE -H "Authorization: Bearer $ADMIN_AT" "$KC/admin/realms/demo/users/$BOB_ID/groups/$GROUP_ID"' EXIT
BOB_R2="$(token bob reports)" || exit 1
claims "$BOB_R2"
echo "  Same principal, same policy: the new token now has ${B}editor${R}, so the \"Create reports\" rule matches."
show_cmd "BOB_R=\$(make -s token-bob-reports)"
show_cmd "curl -X POST -H \"Authorization: Bearer \$BOB_R\" -H 'Content-Type: application/json' -d '{\"title\":\"Q4 forecast\"}' $API/reports"
pause
run -X POST -H "Authorization: Bearer $BOB_R2" -H 'Content-Type: application/json' -d '{"title":"Q4 forecast"}' "$API/reports"
expect 201 "the group gave bob ${B}editor${R}: only a claim changed, no code, no redeploy"

# ---------------------------------------------------------------------------
pause "press Enter for the summary"
curl -sS -o /dev/null -X DELETE -H "Authorization: Bearer $ADMIN_AT" "$KC/admin/realms/demo/users/$BOB_ID/groups/$GROUP_ID"
trap - EXIT
echo
echo "${DIM}bob was removed from /finance/managers again, so the demo can be repeated.${R}"
echo
if [[ "$FAILED" -eq 0 ]]; then
  echo "${GREEN}${B}All $PASSED checks behaved as expected.${R}"
else
  echo "${RED}${B}$FAILED of $((PASSED + FAILED)) checks did not behave as expected.${R}"
  exit 1
fi

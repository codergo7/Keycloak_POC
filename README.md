# Kind + Istio + Keycloak + oauth2-proxy + Spring Boot + FastAPI IAM POC

A local IAM playground for learning Keycloak, OAuth 2.0/OIDC, oauth2-proxy, JWT validation,
Istio authorization and application-facing identity headers.

## Architecture

```text
                          kind cluster
Browser / curl  ──►  Istio ingress gateway (Envoy, istio-system)
                       │
  keycloak.localhost   ├──► Keycloak ──► PostgreSQL                      (identity)
                       │
  app.localhost        ├── ext_authz (AuthorizationPolicy CUSTOM) ──► OAuth2-Proxy  (identity)
  (browser, cookie)    │     no session  → 302 to the Keycloak login
                       │     session ok  → 200 + X-Auth-Request-* headers and the access token
                       ├──► /oauth2/*  ──► OAuth2-Proxy (login callback, sign-out)
                       ├──► /reports   ──► FastAPI reports API           (reports-api)
                       └──► /*         ──► Spring Boot                   (spring-api)
                       │
  api.localhost        ├── jwt_authn (RequestAuthentication): validates the Bearer JWT
  (script, Bearer JWT) ├── rbac (AuthorizationPolicy ALLOW): requires a valid token
                       ├──► /reports   ──► FastAPI reports API
                       └──► /*         ──► Spring Boot

Each app pod has an Envoy sidecar with its own pair of resources:
  RequestAuthentication  checks the token again, including the audience (spring-api / reports-api)
  AuthorizationPolicy    checks the roles in the token (realm roles / reports-api client roles)

istiod turns all these resources into Envoy config, and fetches Keycloak's JWKS for every
RequestAuthentication.
```

OAuth2-Proxy is not in the request path: it runs with `--upstream=static://200` and only answers the
gateway's ext_authz check. The gateway removes the session cookie before Spring, and the sidecars
write `x-auth-request-user` / `x-auth-request-email` from the verified token.

Namespaces:
- `istio-system`: Istio control plane, ingress gateway, the gateway's RequestAuthentication and AuthorizationPolicies
- `identity`: Keycloak, PostgreSQL, oauth2-proxy
- `spring-api`: Spring Boot test application
- `reports-api`: FastAPI reports API (`reports/`)

Each app namespace has the same name as the app's Keycloak client and token audience.

More detail:
- `doc/istio-request-flow.md`: every Envoy filter, in order, at the gateway and in the sidecars
- `doc/request-authentication-scenarios.md`: what RequestAuthentication does and does not do, scenario by scenario
- `doc/auth-code-flow.md`: the browser login (authorization code flow) step by step
- `presentation/slidev/`: the talk (Slidev), with speaker notes and backup slides

## Requirements

- Docker
- kind
- kubectl
- curl
- jq
- make

`istioctl` is optional. If it is missing, the helper script downloads the pinned Istio version.

## Start

```bash
make up
```

Then:

- Keycloak Admin Console: `http://keycloak.localhost:8080`
  - admin / admin
- OAuth2 browser flow: `http://app.localhost:8080`
  - alice / alice
  - bob / bob
  - admin / admin
- Public direct API: `http://api.localhost:8080/api/public`

Modern browsers resolve `*.localhost` to loopback. For CLI examples the Makefile also sends explicit Host headers.

## Test JWT authentication and authorization

```bash
make smoke
make demo-api          # guided API access demo, seven steps: why, command and result per check (AUTO=1: no pauses)
```

After the laptop sleeps, requests can fail with 503 (expired workload certificates): run `make wake`.

Get a token:

```bash
TOKEN="$(make -s token-alice)"
make decode TOKEN="$TOKEN"

curl -H 'Host: api.localhost' \
     -H "Authorization: Bearer $TOKEN" \
     http://localhost:8080/api/whoami
```

Try Alice against the admin endpoint:

```bash
curl -i -H 'Host: api.localhost' \
  -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/api/admin
```

Expected: `403`.

Admin succeeds:

```bash
TOKEN="$(make -s token-admin)"
curl -H 'Host: api.localhost' \
  -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/api/admin
```

## Test from inside the Spring Boot container

The application image intentionally contains `curl` and `jq`.

```bash
make shell-app
```

Inside it:

```bash
curl -s http://keycloak.identity.svc.cluster.local:8080/realms/demo/.well-known/openid-configuration | jq .
curl -s http://keycloak.identity.svc.cluster.local:8080/realms/demo/protocol/openid-connect/certs | jq .
```

This is useful for understanding front-channel vs back-channel URLs and checking service-mesh connectivity.

## Preconfigured Keycloak concepts

The imported `demo` realm gives you material to inspect immediately:

- Realm: `demo`
- Realm roles: `user`, `developer`, `admin`
- Client roles of `reports-api`: `viewer`, `editor` (composite: `editor` contains `viewer`)
- Groups: `/engineering` (developer), `/finance` (reports viewer), `/finance/managers` (reports editor), `/admins` (admin)
- Users: `alice` (`/engineering`), `bob` (`/finance`), `admin` (`/admins`)
- Client scope: `groups`
- Client scope: `app-audience` (default, adds `spring-api` to `aud`)
- Client scope: `reports` (optional on `cli-client`, adds `reports-api` to `aud`)
- Protocol mapper: group-membership mapper
- Protocol mapper: audience mapper
- Confidential client: `cli-client`
- Service account enabled on `cli-client`
- Browser/OIDC client: `oauth2-proxy`
- Bearer-only resource clients: `spring-api`, `reports-api`
- Direct Access Grant enabled only for the CLI lab client

Inspect Alice's JWT and find:
- `iss`
- `aud`
- `azp`
- `scope`
- `realm_access.roles`
- `resource_access.reports-api.roles` (bob)
- `groups`
- `preferred_username`
- token timestamps (`iat`, `exp`)

Compare `aud` with and without the reports scope:

```bash
./scripts/get-token.sh bob bob            # aud: spring-api
./scripts/get-token.sh bob bob reports    # aud: spring-api, reports-api  (or: make token-bob-reports)
```

The `audience resolve` mapper is removed from the `roles` scope on purpose: it would add
`reports-api` to `aud` for anyone who has a `reports-api` role, and the audience must come
only from the `reports` scope.

## Useful Keycloak endpoint experiments

Discovery:

```bash
curl -s -H 'Host: keycloak.localhost' \
  http://localhost:8080/realms/demo/.well-known/openid-configuration | jq .
```

JWKS:

```bash
curl -s -H 'Host: keycloak.localhost' \
  http://localhost:8080/realms/demo/protocol/openid-connect/certs | jq .
```

Password grant (lab only):

```bash
curl -s -H 'Host: keycloak.localhost' \
  -d client_id=cli-client \
  -d client_secret=cli-secret \
  -d username=alice \
  -d password=alice \
  -d grant_type=password \
  http://localhost:8080/realms/demo/protocol/openid-connect/token | jq .
```

Client credentials / service account:

```bash
curl -s -H 'Host: keycloak.localhost' \
  -d client_id=cli-client \
  -d client_secret=cli-secret \
  -d grant_type=client_credentials \
  http://localhost:8080/realms/demo/protocol/openid-connect/token | jq .
```

UserInfo:

```bash
TOKEN="$(make -s token-alice)"
curl -s -H 'Host: keycloak.localhost' \
  -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/realms/demo/protocol/openid-connect/userinfo | jq .
```

Token introspection:

```bash
TOKEN="$(make -s token-alice)"
curl -s -H 'Host: keycloak.localhost' \
  -u cli-client:cli-secret \
  -d token="$TOKEN" \
  http://localhost:8080/realms/demo/protocol/openid-connect/token/introspect | jq .
```

Logout, refresh tokens, offline tokens, consent, required actions, OTP/WebAuthn,
identity brokering, LDAP federation, fine-grained admin permissions, authorization
services (UMA), token exchange and client policies are good next labs.

## oauth2-proxy flow

Open:

`http://app.localhost:8080/api/whoami`

Flow:

1. The gateway's CUSTOM AuthorizationPolicy sends the request to oauth2-proxy (ext_authz check).
2. oauth2-proxy sees no session cookie and answers 302 to Keycloak's authorization endpoint.
3. Keycloak authenticates the user and redirects the browser to `/oauth2/callback` with a code.
4. oauth2-proxy exchanges the code for tokens at the internal Keycloak service (back channel).
5. oauth2-proxy encrypts the tokens into its session cookie and redirects back to `/api/whoami`.
6. On the next request, ext_authz asks oauth2-proxy again: the session is valid, so it answers 200 with
   `X-Auth-Request-User`, `X-Auth-Request-Email` and `X-Auth-Request-Access-Token`.
7. The gateway adds those headers, removes the cookie and routes the request to Spring Boot.
8. Spring's sidecar validates the access token from `X-Auth-Request-Access-Token` (audience
   `spring-api`), checks the roles and overwrites the user/email headers from the verified token.

oauth2-proxy refreshes the access token every 4 minutes (`--cookie-refresh=4m`) while the Keycloak
session is alive.

Compare `/api/headers` through:
- `app.localhost` after browser login
- `api.localhost` with a raw Bearer token

That makes the oauth2-proxy session-cookie model vs direct JWT model visible.

## Istio JWT flow

The checks are split between the ingress gateway and each app's sidecar.

Ingress gateway (`k8s/istio/ingress-authorization.yaml`):

- `RequestAuthentication` `demo-jwt-validation`: validates the JWT signature (Keycloak JWKS), issuer and
  expiry. No audience check here.
- `AuthorizationPolicy` `oauth2-external-auth` (CUSTOM): sends app.localhost requests to oauth2-proxy.
- `AuthorizationPolicy` `ingress-authorization` (ALLOW): keycloak.localhost and app.localhost are allowed
  (app.localhost is protected by the CUSTOM policy); on api.localhost, `GET /api/public` is open and
  everything else listed needs a valid token (`requestPrincipals: ["*"]`).

Spring sidecar (`k8s/app/auth-app.yaml`): token audience must contain `spring-api`, then:

- `/api/public`: anonymous allowed.
- `/api/user`, `/api/whoami`: valid JWT plus `user` in `realm_access.roles`.
- `/api/headers`: valid JWT plus `developer`.
- `/api/admin`: valid JWT plus `admin`.

Reports sidecar (`k8s/reports/auth-reports.yaml`): token audience must contain `reports-api`, then
`viewer` in `resource_access.reports-api.roles` for `GET /reports` and `editor` for `POST /reports`.

In the browser, `app.localhost/reports` works too: oauth2-proxy asks Keycloak for the `reports`
scope at login, and the reports sidecar reads the token from `X-Auth-Request-Access-Token`.

On `api.localhost` there is no ext_authz, so nothing would overwrite an `X-Auth-Request-*` header a
client sends itself. The `api.localhost` routes therefore remove those headers
(`k8s/app/app.yaml`), and the sidecars write `x-auth-request-user` / `x-auth-request-email` from the
verified token (`outputClaimToHeaders`).

A token without `aud: reports-api` is rejected by the reports sidecar with
`403 Audiences in Jwt are not allowed`. Envoy answers a wrong audience with 403, not 401.

Status codes in short: `302` = no browser session (oauth2-proxy), `401` = a token was sent but is
invalid, `403` = a rule said no (missing token, wrong audience, or missing role).

This deliberately separates authentication (is the JWT valid?) from authorization
(is this identity allowed to call this endpoint?).

## Inspecting the sidecars

The `identity`, `spring-api` and `reports-api` namespaces have sidecar injection enabled.
In `identity`, only Keycloak may connect to PostgreSQL (`k8s/keycloak/postgres-authorization.yaml`).

```bash
kubectl get pods -n identity
kubectl get pods -n spring-api
kubectl get pods -n reports-api
istioctl proxy-status
istioctl proxy-config clusters deploy/spring-app.spring-api
```

## Suggested Keycloak learning progression

1. Realm/users/passwords
2. Realm roles vs client roles
3. Composite roles
4. Groups and inherited role mappings
5. Client scopes
6. Protocol mappers and custom token claims
7. Authorization Code flow
8. Client Credentials flow
9. Refresh/offline tokens
10. Service accounts
11. Audience (`aud`) and authorized party (`azp`)
12. Consent
13. Required actions
14. OTP and WebAuthn
15. Sessions and logout
16. Token introspection and revocation
17. Key rotation/JWKS behavior
18. Identity brokering with a second Keycloak realm
19. LDAP federation
20. Authorization Services / UMA
21. Token exchange
22. Fine-grained admin permissions
23. Client policies/profiles
24. Events/audit
25. Keycloak HA and database behavior

## Reset

```bash
make clean
make up
```

PostgreSQL uses `emptyDir` intentionally: deleting the Kind cluster gives you a clean lab.
This repo is a learning POC, not a production deployment.

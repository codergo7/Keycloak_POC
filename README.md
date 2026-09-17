# Kind + Istio + Keycloak + oauth2-proxy + Spring Boot IAM POC

A local IAM playground for learning Keycloak, OAuth 2.0/OIDC, oauth2-proxy, JWT validation,
Istio authorization and application-facing identity headers.

## Architecture

```text
Browser
   |
   | http://keycloak.localhost:8080
   +-----------------------> Istio Ingress ---> Keycloak ---> PostgreSQL
   |
   | http://app.localhost:8080
   +-----------------------> Istio Ingress ---> oauth2-proxy ---> Spring Boot
   |                                               |
   |                                               +--> Keycloak OIDC
   |
   | http://api.localhost:8080 + Bearer JWT
   +-----------------------> Istio Ingress
                                |
                                + RequestAuthentication (JWKS from Keycloak)
                                + AuthorizationPolicy (claims/roles)
                                |
                                +------------------------> Spring Boot
```

Namespaces:
- `iam`: Keycloak, PostgreSQL, oauth2-proxy, Istio Gateway/VirtualServices
- `demo`: Spring Boot test application
- `istio-system`: Istio control plane + ingress gateway + JWT policy

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
```

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
curl -s http://keycloak.iam.svc.cluster.local:8080/realms/poc/.well-known/openid-configuration | jq .
curl -s http://keycloak.iam.svc.cluster.local:8080/realms/poc/protocol/openid-connect/certs | jq .
```

This is useful for understanding front-channel vs back-channel URLs and checking service-mesh connectivity.

## Preconfigured Keycloak concepts

The imported `poc` realm gives you material to inspect immediately:

- Realm: `poc`
- Realm roles: `user`, `developer`, `premium`, `admin`
- Composite realm role: `power-user` = `developer` + `premium`
- Groups: `/engineering`, `/engineering/platform`, `/admins`
- Users: `alice`, `bob`, `admin`
- Client scope: `groups`
- Client scope: `app-audience`
- Protocol mapper: group-membership mapper
- Protocol mapper: audience mapper
- Confidential client: `cli-client`
- Service account enabled on `cli-client`
- Browser/OIDC client: `oauth2-proxy`
- Bearer-only resource client: `spring-api`
- Direct Access Grant enabled only for the CLI lab client

Inspect Alice's JWT and find:
- `iss`
- `aud`
- `azp`
- `scope`
- `realm_access.roles`
- `groups`
- `preferred_username`
- token timestamps (`iat`, `exp`)

## Useful Keycloak endpoint experiments

Discovery:

```bash
curl -s -H 'Host: keycloak.localhost' \
  http://localhost:8080/realms/poc/.well-known/openid-configuration | jq .
```

JWKS:

```bash
curl -s -H 'Host: keycloak.localhost' \
  http://localhost:8080/realms/poc/protocol/openid-connect/certs | jq .
```

Password grant (lab only):

```bash
curl -s -H 'Host: keycloak.localhost' \
  -d client_id=cli-client \
  -d client_secret=cli-secret \
  -d username=alice \
  -d password=alice \
  -d grant_type=password \
  http://localhost:8080/realms/poc/protocol/openid-connect/token | jq .
```

Client credentials / service account:

```bash
curl -s -H 'Host: keycloak.localhost' \
  -d client_id=cli-client \
  -d client_secret=cli-secret \
  -d grant_type=client_credentials \
  http://localhost:8080/realms/poc/protocol/openid-connect/token | jq .
```

UserInfo:

```bash
TOKEN="$(make -s token-alice)"
curl -s -H 'Host: keycloak.localhost' \
  -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/realms/poc/protocol/openid-connect/userinfo | jq .
```

Token introspection:

```bash
TOKEN="$(make -s token-alice)"
curl -s -H 'Host: keycloak.localhost' \
  -u cli-client:cli-secret \
  -d token="$TOKEN" \
  http://localhost:8080/realms/poc/protocol/openid-connect/token/introspect | jq .
```

Logout, refresh tokens, offline tokens, consent, required actions, OTP/WebAuthn,
identity brokering, LDAP federation, fine-grained admin permissions, authorization
services (UMA), token exchange and client policies are good next labs.

## oauth2-proxy flow

Open:

`http://app.localhost:8080/api/whoami`

Flow:

1. Istio routes `app.localhost` to oauth2-proxy.
2. oauth2-proxy sees no session cookie.
3. It redirects the browser to Keycloak's authorization endpoint.
4. Keycloak authenticates the user.
5. Browser returns to `/oauth2/callback`.
6. oauth2-proxy exchanges the authorization code using the internal Keycloak service.
7. oauth2-proxy creates its session cookie.
8. It forwards the request to Spring Boot and supplies identity/token-related headers.

Compare `/api/headers` through:
- `app.localhost` after browser login
- `api.localhost` with a raw Bearer token

That makes the oauth2-proxy session-cookie model vs direct JWT model visible.

## Istio JWT flow

The ingress gateway has:

- `RequestAuthentication`: validates JWT signature via Keycloak JWKS and checks issuer.
- `AuthorizationPolicy`: decides which paths/claims are allowed.

Current rules:

- `/api/public`: anonymous allowed.
- `/api/user`, `/api/whoami`, `/api/headers`: any valid JWT.
- `/api/admin`: valid JWT plus `admin` in `realm_access.roles`.

This deliberately separates authentication (is the JWT valid?) from authorization
(is this identity allowed to call this endpoint?).

## mTLS experiments

Both `iam` and `demo` namespaces have sidecar injection enabled.

Check sidecars:

```bash
kubectl get pods -n iam
kubectl get pods -n demo
```

Then add a namespace-wide `PeerAuthentication` with `STRICT` mode and verify traffic.
You can also inspect Envoy config with:

```bash
istioctl proxy-status
istioctl proxy-config clusters deploy/spring-app.demo
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

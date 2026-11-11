# How a request moves through Istio in this POC

This document explains, in evaluation order, what each Istio resource in this
repo does to a request and how it decides. Everything here was checked against
the running cluster (Istio 1.31) with `pilot-agent request GET config_dump`.

Contents

1. Big picture: which resource becomes which Envoy filter
2. Order of evaluation at the ingress gateway
3. Order of evaluation at the Spring sidecar
4. Algorithm of each step
5. Response path
6. End-to-end flows (browser, API)
7. Status code cheat sheet
8. Gotchas
9. How to inspect it yourself


## 1. Big picture

Istio resources are not executed directly. istiod translates them into Envoy
configuration and pushes it to the ingress gateway and to every sidecar.

| Istio resource | Becomes (Envoy) | Runs on | File |
|---|---|---|---|
| Gateway `poc-gateway` | listener `0.0.0.0_8080` + accepted hosts | ingress gateway | `k8s/istio/gateway.yaml` |
| VirtualService `api`, `oauth2-proxy`, `keycloak` | route table `http.8080` (virtual hosts, routes, header rules) | ingress gateway | `k8s/app/app.yaml`, `k8s/oauth2-proxy/oauth2-proxy.yaml`, `k8s/keycloak/keycloak.yaml` |
| AuthorizationPolicy `oauth2-external-auth` (CUSTOM) | `rbac` shadow filter + `ext_authz` filter | ingress gateway | `k8s/istio/ingress-authorization.yaml` |
| mesh config `extensionProviders.oauth2-proxy` | `ext_authz` settings (which headers go where) | ingress gateway | `k8s/istio/istio-cm.yaml` |
| RequestAuthentication `demo-jwt-validation` | `jwt_authn` filter | ingress gateway | `k8s/istio/ingress-authorization.yaml` |
| AuthorizationPolicy `ingress-authorization` (ALLOW) | `rbac` filter | ingress gateway | `k8s/istio/ingress-authorization.yaml` |
| RequestAuthentication `keycloak-jwt` | `jwt_authn` filter | Spring sidecar | `k8s/app/auth-app.yaml` |
| AuthorizationPolicy `spring-workload-authorization` (ALLOW) | `rbac` filter | Spring sidecar | `k8s/app/auth-app.yaml` |

A request from outside therefore passes **two** Envoy proxies, each with its
own chain of checks:

```
Browser / curl
     │  http://<host>.localhost:8080
     ▼
kind node port 30080  ──►  istio-ingressgateway Service :80  ──►  gateway pod :8080
     │
     ▼
┌──────────────────────── INGRESS GATEWAY (Envoy) ────────────────────────┐
│ Gateway → VirtualService route → CUSTOM authz (oauth2-proxy) →          │
│ RequestAuthentication → ALLOW AuthorizationPolicy → router              │
└──────────────────────────────────────────────────────────────────────────┘
     │  to the Spring pod
     ▼
┌──────────────────────── SPRING SIDECAR (Envoy) ─────────────────────────┐
│ RequestAuthentication → ALLOW AuthorizationPolicy → router              │
└──────────────────────────────────────────────────────────────────────────┘
     │  plain HTTP on localhost
     ▼
Spring Boot app :8080
```


## 2. Order of evaluation at the ingress gateway

This is the actual HTTP filter chain of the gateway listener `0.0.0.0_8080`,
in order:

```
istio.metadata_exchange
envoy.filters.http.rbac        (shadow)   ◄── CUSTOM policy: "does oauth2-proxy need to be asked?"
envoy.filters.http.ext_authz              ◄── CUSTOM policy: ask oauth2-proxy
envoy.filters.http.jwt_authn              ◄── RequestAuthentication demo-jwt-validation
envoy.filters.http.rbac        (ALLOW)    ◄── AuthorizationPolicy ingress-authorization
grpc_stats, istio.alpn, fault, cors, istio.stats
envoy.filters.http.router                 ◄── VirtualService route: destination + header rules
```

Important consequences of this order:

- **CUSTOM authorization runs before JWT validation.** oauth2-proxy is asked
  first, and headers it returns (`x-auth-request-access-token`, ...) are already
  on the request when `jwt_authn` and the sidecar look at it.
- **The route is picked before the filters run, but its header rules are
  applied last**, by the router. So `headers.request.remove: [cookie]` on the
  Spring route removes the cookie *after* `ext_authz` has already sent it to
  oauth2-proxy.

The full decision sequence at the gateway:

```
                         Request arrives at gateway :8080
                                      │
                                      ▼
                   ┌──────────────────────────────────────┐
              [1]  │ Gateway: is Host one of               │
                   │ keycloak/app/api.localhost?           │
                   └──────────────────────────────────────┘
                          │ no                    │ yes
                          ▼                       ▼
                      404 (no route)   ┌──────────────────────────────┐
                                  [2]  │ VirtualService: pick route    │
                                       │ by host + path prefix         │
                                       └──────────────────────────────┘
                                                  │
                                                  ▼
                                  ┌──────────────────────────────────┐
                             [3]  │ CUSTOM policy rules match?        │
                                  │ (host app.localhost, path not     │
                                  │  /oauth2/* /api/public /actuator/ │
                                  │  health, no "Bearer", UA Mozilla) │
                                  └──────────────────────────────────┘
                                     │ no                   │ yes
                                     │                      ▼
                                     │      ┌────────────────────────────────┐
                                     │ [4]  │ ext_authz: send check request   │
                                     │      │ (cookie, authorization) to      │
                                     │      │ oauth2-proxy:4180               │
                                     │      └────────────────────────────────┘
                                     │          │ 2xx               │ not 2xx
                                     │          ▼                   ▼
                                     │   add allowed headers   return oauth2-proxy's
                                     │   to the request        response to client
                                     │   (x-auth-request-*,    (302 → Keycloak login)
                                     │   authorization)              STOP
                                     │          │
                                     ▼          ▼
                                  ┌──────────────────────────────────┐
                             [5]  │ RequestAuthentication:            │
                                  │ JWT in Authorization: Bearer ?    │
                                  └──────────────────────────────────┘
                                   │ none        │ valid      │ invalid
                                   ▼             ▼            ▼
                              no principal   principal =   401 "Jwt verification
                                   │         iss/sub       fails" (or similar)
                                   │             │                 STOP
                                   ▼             ▼
                                  ┌──────────────────────────────────┐
                             [6]  │ ALLOW policy ingress-authorization│
                                  │ does any rule match?              │
                                  └──────────────────────────────────┘
                                     │ yes                  │ no
                                     ▼                      ▼
                                  ┌───────────────┐   403 "RBAC: access denied"
                             [7]  │ Router:        │          STOP
                                  │ apply route    │
                                  │ header rules,  │
                                  │ send upstream  │
                                  └───────────────┘
```


## 3. Order of evaluation at the Spring sidecar

HTTP filter chain of the sidecar's inbound listener for port 8080:

```
istio.metadata_exchange
envoy.filters.http.jwt_authn           ◄── RequestAuthentication keycloak-jwt
envoy.filters.http.rbac (ALLOW)        ◄── AuthorizationPolicy spring-workload-authorization
grpc_stats, fault, cors, istio.stats
envoy.filters.http.router              ◄── forwards to the app on localhost:8080
```

```
                  Request arrives at Spring pod :8080 (intercepted by sidecar)
                                      │
                                      ▼
                   ┌──────────────────────────────────────┐
              [1]  │ RequestAuthentication keycloak-jwt:   │
                   │ token in Authorization: Bearer or     │
                   │ X-Auth-Request-Access-Token?          │
                   └──────────────────────────────────────┘
                     │ none          │ valid           │ invalid / wrong audience
                     ▼               ▼                 ▼
                no principal    principal +        401 "Jwt verification fails"
                     │          claims available   / "Audiences in Jwt are not
                     │               │              allowed"          STOP
                     ▼               ▼
                   ┌──────────────────────────────────────┐
              [2]  │ ALLOW policy spring-workload-         │
                   │ authorization: does any rule match?   │
                   │ (path + method + role claim)          │
                   └──────────────────────────────────────┘
                          │ yes                   │ no
                          ▼                       ▼
                   forward to Spring       403 "RBAC: access denied"
                   on localhost:8080              STOP
```


## 4. Algorithm of each step

### 4.1 Gateway (`k8s/istio/gateway.yaml`)

Decides **whether the ingress gateway listens for a host at all**.

```
selector istio=ingressgateway  → configure only the ingress gateway pod
server port 80, protocol HTTP  → Envoy listener 0.0.0.0_8080
                                 (Service port 80 → container port 8080;
                                  kind maps host :8080 → node :30080 → port 80)
hosts [keycloak, app, api].localhost
    → only VirtualServices bound to this Gateway AND matching one of these
      hosts are added to the listener's route table.
```

A Gateway has no routing logic. It only opens the port and lists accepted hosts.

### 4.2 VirtualService (route selection)

Decides **where the request goes** and **which headers to change**.
Algorithm (per request):

```
1. Take the Host header (port stripped) → find the virtual host.
      api.localhost      → VirtualService spring-api/api
      app.localhost      → VirtualService identity/oauth2-proxy
      keycloak.localhost → VirtualService identity/keycloak
   No match → 404.
2. Walk the http[] routes of that VirtualService top to bottom.
   The FIRST route whose match[] matches (uri prefix, headers, method...) wins.
   A route with no match[] matches everything (catch-all; keep it last).
3. Remember the destination and the route's header rules.
   (Applied later, by the router, after all security filters have passed.)
```

Live route table `http.8080`:

| Virtual host | Match | Destination | Header rules |
|---|---|---|---|
| `api.localhost` | exact `/reports` | reports-api.reports-api:8080 | request: remove client-sent `x-auth-request-*` |
| `api.localhost` | `/` | spring-app.spring-api:8080 | request: remove client-sent `x-auth-request-*` |
| `app.localhost` | prefix `/oauth2/` | oauth2-proxy.identity:4180 | response: remove `x-auth-request-*`, `authorization` |
| `app.localhost` | exact `/reports` | reports-api.reports-api:8080 | request: remove `cookie` |
| `app.localhost` | `/` | spring-app.spring-api:8080 | request: remove `cookie` |
| `keycloak.localhost` | `/` | keycloak.identity:8080 | — |

### 4.3 AuthorizationPolicy — general evaluation rules

All AuthorizationPolicies that select a workload are combined and evaluated in
this fixed order, regardless of file or creation order:

```
                         ┌───────────────────────────────┐
                    [A]  │ Any CUSTOM policy rule matches?│
                         └───────────────────────────────┘
                           │ yes                      │ no
                           ▼                          │
                  ask the external authorizer         │
                    │ deny         │ allow            │
                    ▼              ▼                  ▼
                  DENY        ┌───────────────────────────────┐
                         [B]  │ Any DENY policy rule matches?  │
                              └───────────────────────────────┘
                                │ yes                  │ no
                                ▼                      ▼
                              DENY     ┌───────────────────────────────────┐
                                  [C]  │ Does any ALLOW policy exist for    │
                                       │ this workload?                     │
                                       └───────────────────────────────────┘
                                         │ no                  │ yes
                                         ▼                     ▼
                                       ALLOW   ┌───────────────────────────────┐
                                          [D]  │ Any ALLOW policy rule matches? │
                                               └───────────────────────────────┘
                                                 │ yes                │ no
                                                 ▼                    ▼
                                               ALLOW                DENY (403)
```

How a single rule matches:

```
rule matches  ⇔  (from[] is empty  OR  any from.source matches)
             AND (to[]   is empty  OR  any to.operation matches)
             AND (every when[] condition matches)

Inside one source / operation / condition, all listed fields must match (AND).
Inside one field's list of values, any value may match (OR).
"notX" fields (notPaths, notValues, ...) mean "must not match any of these".
```

Note: there is no DENY policy in this repo, so step [B] never denies.

### 4.4 CUSTOM policy `oauth2-external-auth` + ext_authz (gateway)

Istio splits a CUSTOM policy into two Envoy filters:

1. a **shadow `rbac` filter** that only *evaluates* the rules and marks the
   request (metadata `istio-ext-authz-oauth2-proxy...`) if they match, and
2. the **`ext_authz` filter**, which only runs for marked requests.

Rule logic of this policy:

```
ask oauth2-proxy  ⇔  host ∈ {app.localhost, app.localhost:*}
                 AND path ∉ {/oauth2/*, /api/public, /actuator/health}
                 AND Authorization header does NOT start with "Bearer "
                 AND User-Agent starts with "Mozilla/"
```

So only real browser requests to the app are sent to oauth2-proxy. API clients
with a bearer token, and non-browser clients such as curl, skip it.

The ext_authz call (settings from the mesh config in `istio-cm.yaml`):

```
1. Build a check request to oauth2-proxy.identity:4180 with the same method/path
   and only these request headers:  cookie, authorization
                                    (includeRequestHeadersInCheck)
2. oauth2-proxy (upstream static://200) decides:
      valid session cookie  → 200 + X-Auth-Request-User/Email/Groups/
                              Preferred-Username/Access-Token headers
                              (+ Set-Cookie if --cookie-refresh renewed it)
      no / expired session  → 302 Location: Keycloak /auth  (+ CSRF Set-Cookie)
3. Envoy acts on the answer:
      2xx  → copy ONLY the headersToUpstreamOnAllow headers into the original
             request:  authorization, x-auth-request-user,
                       x-auth-request-email, x-auth-request-access-token
             remember headersToDownstreamOnAllow (set-cookie) to add to the
             response later
             → continue to the next filter
      else → send oauth2-proxy's response to the client, keeping only
             headersToDownstreamOnDeny (content-type, set-cookie, location)
             → STOP
```

### 4.5 RequestAuthentication (JWT validation)

RequestAuthentication only **validates** tokens. It never rejects a request
that has no token. Requiring a token is the job of an AuthorizationPolicy
(`requestPrincipals: ["*"]`).

```
                 ┌─────────────────────────────────────────────┐
            [1]  │ Look for a token in the configured places    │
                 │ (default: Authorization: Bearer <t>,         │
                 │  ?access_token=<t>; or jwtRules.fromHeaders) │
                 └─────────────────────────────────────────────┘
                    │ not found                      │ found
                    ▼                                ▼
          continue, request has      ┌───────────────────────────────────┐
          NO principal          [2]  │ Is there a jwtRule whose issuer    │
                                     │ equals the token's "iss"?          │
                                     └───────────────────────────────────┘
                                       │ no                     │ yes
                                       ▼                        ▼
                             401 "Jwt issuer is      ┌─────────────────────────┐
                             not configured"    [3]  │ Verify signature with    │
                                                     │ the rule's JWKS (fetched │
                                                     │ by istiod, sent to Envoy │
                                                     │ inline)                  │
                                                     └─────────────────────────┘
                                                       │ bad          │ ok
                                                       ▼              ▼
                                             401 "Jwt verification  ┌────────────────────┐
                                             fails"            [4]  │ exp / nbf valid?    │
                                                                    │ audiences (if set)  │
                                                                    │ contain token "aud"?│
                                                                    └────────────────────┘
                                                                      │ no        │ yes
                                                                      ▼           ▼
                                                              401 "Jwt is   principal = iss/sub
                                                              expired" /    claims available as
                                                              "Audiences    request.auth.claims[...]
                                                              in Jwt are    token kept in header
                                                              not allowed"  (forwardOriginalToken)
```

The two RequestAuthentications in this repo:

| | `istio-system/demo-jwt-validation` | `spring-api/keycloak-jwt` |
|---|---|---|
| Applies to | ingress gateway (`app: istio-ingressgateway`) | Spring sidecar (`app: spring-app`) |
| Issuers | realms `demo` and `master` | realm `demo` |
| Audience check | none | must contain `spring-api` |
| Token read from | `Authorization: Bearer` (default) | `Authorization: Bearer` **and** `X-Auth-Request-Access-Token` |
| Used by | `requestPrincipals` in `ingress-authorization` | `requestPrincipals` and `request.auth.claims[realm_access][roles]` in `spring-workload-authorization` |

The second header is what makes browser requests work: oauth2-proxy's access
token arrives at the sidecar as `X-Auth-Request-Access-Token`, the sidecar
validates it, and the role claims become usable in the AuthorizationPolicy.

### 4.6 ALLOW policy `ingress-authorization` (gateway)

Because this ALLOW policy exists, every gateway request must match one of its
rules ([D] in 4.3):

| # | Allows | Needs JWT at gateway? |
|---|---|---|
| 1 | any request to `keycloak.localhost` | no |
| 2 | any request to `app.localhost` (protected by the CUSTOM policy instead) | no |
| 3 | `GET /api/public` on `api.localhost` | no |
| 4 | `GET /api/user`, `/api/whoami`, `/api/headers`, `/api/admin` on `api.localhost` | yes (`requestPrincipals: ["*"]`) |

Anything else, e.g. `api.localhost/api/internal` from outside, gets 403 at the gateway.

### 4.7 ALLOW policy `spring-workload-authorization` (sidecar)

| Path (GET) | Rule |
|---|---|
| `/api/public` | anyone |
| `/api/user`, `/api/whoami` | valid JWT **and** realm role `user` |
| `/api/headers` | valid JWT **and** realm role `developer` |
| `/api/admin` | valid JWT **and** realm role `admin` |
| anything else (e.g. `/`) | no rule matches → 403 |

### 4.8 Router (gateway)

```
1. Apply the chosen route's request header rules
      e.g. app.localhost "/" → remove "cookie"
2. Open (or reuse) a connection to the destination pod's sidecar
3. Send the request
```


## 5. Response path

Responses go back through the same filters in **reverse** order. Only a few of
them change anything:

```
Spring app
   │
   ▼
Spring sidecar ── (no response changes in this POC)
   │
   ▼
Gateway router ── apply route response header rules
   │               e.g. /oauth2/* → remove x-auth-request-*, authorization
   ▼
Gateway ext_authz ── if oauth2-proxy returned Set-Cookie on an allowed
   │                 request (cookie refresh), add it to the response
   ▼
Browser
```

So the session cookie is set on the browser only by oauth2-proxy (on
`/oauth2/callback`, or renewed via ext_authz). The browser stores it and sends
it back. The gateway passes it to oauth2-proxy and removes it before Spring.


## 6. End-to-end flows

### 6.1 Browser, first visit (no session)

```
Browser ── GET app.localhost/api/whoami (no cookie, UA Mozilla) ──► Gateway
  [2] route: app.localhost "/" → spring-app
  [3] CUSTOM rules match
  [4] ext_authz → oauth2-proxy: no session → 302 to Keycloak
◄── 302 Location: keycloak.localhost/realms/demo/protocol/openid-connect/auth
    Set-Cookie: _oauth2_proxy_csrf=...

Browser ── GET keycloak.localhost/.../auth ──► Gateway
  [2] route: keycloak.localhost → keycloak
  [3] CUSTOM rules do not match (host)
  [5] no JWT  → no principal
  [6] ALLOW rule 1 (keycloak host) matches
◄── login page;  user posts credentials;  Keycloak redirects to
    app.localhost/oauth2/callback?code=...

Browser ── GET app.localhost/oauth2/callback?code=... ──► Gateway
  [2] route: app.localhost "/oauth2/" → oauth2-proxy
  [3] CUSTOM rules do not match (notPaths /oauth2/*)
  [6] ALLOW rule 2 (app host) matches
  oauth2-proxy exchanges the code for tokens at Keycloak (in-cluster)
◄── 302 back to /api/whoami
    Set-Cookie: _oauth2_proxy=<encrypted session>
```

### 6.2 Browser, with session

```
Browser ── GET app.localhost/api/whoami  Cookie: _oauth2_proxy=... ──► Gateway
  [2] route: app.localhost "/" → spring-app   (header rule: remove cookie)
  [3] CUSTOM rules match
  [4] ext_authz → oauth2-proxy: session valid → 200
        request now has x-auth-request-user/email/access-token
  [5] gateway JWT: no Authorization: Bearer → no principal (fine)
  [6] ALLOW rule 2 (app host) matches
  [7] router removes "cookie", forwards to the Spring pod

Spring sidecar
  [1] jwt_authn reads X-Auth-Request-Access-Token → valid, aud spring-api
  [2] ALLOW: /api/whoami + role "user" → ok
Spring app sees x-auth-request-user/email and the token header, but no cookie.
◄── 200 JSON
```

### 6.3 API client with bearer token (`api.localhost`)

```
curl ── GET api.localhost/api/admin  Authorization: Bearer <alice token> ──► Gateway
  [2] route: api.localhost → spring-app
  [3] CUSTOM rules do not match (host api.localhost)
  [5] jwt_authn validates the token (demo realm) → principal set
  [6] ALLOW rule 4 (requestPrincipals) matches
  [7] forward to the Spring pod

Spring sidecar
  [1] valid token, audience spring-api
  [2] /api/admin needs role "admin"; alice has none → no rule matches
◄── 403 RBAC: access denied

Same call without a token:
  gateway [5] no principal → [6] rule 4 needs a principal → 403 at the gateway
With a corrupted token:
  gateway [5] signature check fails → 401 at the gateway
```

## 7. Status code cheat sheet

| What you see | Who answered | Meaning |
|---|---|---|
| `302` to Keycloak | oauth2-proxy via ext_authz | browser has no valid session |
| `401 Jwt verification fails` | gateway or sidecar `jwt_authn` | bad signature, or Istio has stale/placeholder JWKS (see 8) |
| `401 Jwt is expired` | `jwt_authn` | token `exp` passed |
| `401 Jwt issuer is not configured` | `jwt_authn` | token issuer not in any jwtRule |
| `403 Audiences in Jwt are not allowed` | sidecar `jwt_authn` | token lacks the audience the sidecar requires (`spring-api`, or `reports-api` for the reports API). Envoy answers this with 403, not 401 |
| `403 RBAC: access denied` | gateway or sidecar `rbac` | no ALLOW rule matched |
| `404` | gateway | Host/path has no route |

The access log shows which proxy answered and why, in `details=`. Examples:
`ext_authz_denied`, `jwt_authn_access_denied{Jwt_verification_fails}`,
`rbac_access_denied_matched_policy[none]`, `via_upstream`.


## 8. Gotchas

- **JWKS fetch race.** istiod downloads the JWKS and sends it to the proxies
  inline. If Keycloak is not up yet (fresh `make up`, or Keycloak restarted
  with new keys), istiod uses a placeholder key and only retries after about
  20 minutes. Every JWT then fails with `Jwt verification fails`. Fix:
  `kubectl -n istio-system rollout restart deploy/istiod`. The Makefile does
  this after Keycloak is ready.
- **CUSTOM only triggers for browsers.** Because of the `User-Agent: Mozilla/*`
  condition, `curl app.localhost/` without `-A 'Mozilla/5.0'` skips oauth2-proxy
  and gets 403 from the Spring sidecar.
- **VirtualService header rules are per route.** A rule on the Spring route
  does nothing for `/oauth2/*` responses, and the reverse is also true.
- **VirtualService can only remove a whole header.** `remove: [cookie]` drops
  every cookie, not only `_oauth2_proxy`. Removing a single cookie would need
  an EnvoyFilter or WasmPlugin.
- **RequestAuthentication alone does not protect anything.** It only rejects
  *invalid* tokens. Missing tokens must be rejected with an AuthorizationPolicy
  rule that requires `requestPrincipals`.


## 9. How to inspect it yourself

```bash
# Access logs (format set in istio-cm.yaml: status, details, user, jwt_subject)
kubectl -n istio-system logs deploy/istio-ingressgateway --tail=20
kubectl -n spring-api logs deploy/spring-app -c istio-proxy --tail=20

# Filter chain, routes, JWKS as Envoy really sees them
kubectl -n istio-system exec deploy/istio-ingressgateway -- \
  pilot-agent request GET config_dump > gw.json
istioctl proxy-config listeners deploy/istio-ingressgateway -n istio-system
istioctl proxy-config routes    deploy/istio-ingressgateway -n istio-system -o json

# Which policies apply to a pod
istioctl x describe pod "$(kubectl -n spring-api get pod -l app=spring-app \
  -o jsonpath='{.items[0].metadata.name}')" -n spring-api

# JWKS fetch problems
kubectl -n istio-system logs deploy/istiod | grep -i jwks
```

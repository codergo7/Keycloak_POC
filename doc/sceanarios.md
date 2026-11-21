# Scenarios: the two access paths side by side

Short notes. The full versions are in `doc/auth-code-flow.md` (browser login),
`doc/request-authentication-scenarios.md` (token scenarios) and `doc/istio-request-flow.md`
(every Envoy filter in order).

## FLOW 1: Browser (app.localhost)

```
Browser ──► Ingress gateway ── ext_authz ──► OAuth2-Proxy
                 │                 no session → 302 to Keycloak login
                 │                 session ok → 200 + X-Auth-Request-* + access token
                 ▼
            Spring sidecar ──► Spring
```

### First visit, no session

```
Browser
   │ no cookie, no JWT
   ▼
Ingress Envoy
   │
   ├─ ext_authz (AuthorizationPolicy CUSTOM, runs first)
   │      asks OAuth2-Proxy: session?
   │      └─ NO → 302 to Keycloak
   ▼
Redirect → Keycloak login
```

### With a session cookie

```
Browser
   │ Cookie: _oauth2_proxy=...
   ▼
Ingress Envoy
   │
   ├─ ext_authz → OAuth2-Proxy: session valid → 200 + identity headers + access token
   ├─ RequestAuthentication: no Bearer token → nothing to check
   ├─ AuthorizationPolicy ALLOW: app.localhost allowed
   ├─ router: removes the cookie
   ▼
Spring sidecar
   │
   ├─ RequestAuthentication: validates X-Auth-Request-Access-Token (aud spring-api)
   ├─ AuthorizationPolicy: checks the realm roles
   ▼
Spring
```

RequestAuthentication doesn't validate the oauth2-proxy session cookie. OAuth2-Proxy owns the session;
the sidecar validates the access token OAuth2-Proxy hands over.

## FLOW 2: API (api.localhost)

This is where RequestAuthentication is central.

```bash
curl -H "Authorization: Bearer $TOKEN" http://api.localhost:8080/api/user
```

```
curl
 │ Authorization: Bearer <Keycloak JWT>
 ▼
Ingress Envoy
 │
 ├── RequestAuthentication
 │      issuer? signature? expiry?  → JWT valid ✓  (no audience check here)
 │
 ├── AuthorizationPolicy
 │      requestPrincipals: ["*"]  → a valid token exists → ALLOW
 ▼
Spring sidecar
 │
 ├── RequestAuthentication
 │      same checks + aud contains spring-api ✓
 │
 ├── AuthorizationPolicy
 │      /api/user needs realm role "user" → ALLOW
 ▼
Spring
```

## Side by side

```
app.localhost                              api.localhost
────────────────────────────               ────────────────────────────
Authentication: OAuth2-Proxy session        Authentication: Bearer JWT
Checked by: ext_authz at the gateway        Checked by: RequestAuthentication
No session → 302 to the login               No token → 403, bad token → 401
Roles: checked in the sidecar               Roles: checked in the sidecar
```

Both paths end the same way: claims signed by Keycloak, checked by Istio, before any application sees
the request.

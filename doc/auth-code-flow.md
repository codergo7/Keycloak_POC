# Browser login: the authorization code flow in this POC

OAuth2-Proxy is the OIDC client for the browser, but it is **not in the request path**. It runs with
`--upstream=static://200` and only answers the ingress gateway's ext_authz check (AuthorizationPolicy
CUSTOM). The gateway routes the request to Spring itself.

## Who talks to whom

```
                         KEYCLOAK (identity)
                    ┌──────────────────────────┐
                    │ OIDC provider             │
                    └───▲──────────────▲───────┘
      front channel     │              │   back channel (in the cluster)
      keycloak.localhost│              │   keycloak.identity.svc.cluster.local
      (login page)      │              │   POST /token (code + client secret)
                        │              │
┌─────────┐       ┌─────┴──────────────┴──┐   ext_authz check    ┌──────────────┐
│ Browser │──────►│ Istio ingress gateway │─────────────────────►│ OAuth2-Proxy │
└─────────┘       │ (Envoy)               │◄─────────────────────│ (identity)   │
                  └──────────┬────────────┘ 302 / 200 + headers  └──────────────┘
                             │
                             │ request + X-Auth-Request-* headers, cookie removed
                             ▼
                  Spring sidecar (Envoy) ──► Spring Boot
```

## Step by step (first visit)

1. The browser opens `app.localhost/api/whoami`. It has no cookie yet.
2. The gateway's CUSTOM policy matches, so ext_authz asks OAuth2-Proxy.
3. OAuth2-Proxy finds no session and answers 302 to Keycloak's `/auth` endpoint
   (plus a CSRF cookie). The gateway returns that 302 to the browser.
4. The browser opens the Keycloak login page on `keycloak.localhost`, through the gateway.
   The application never sees the password.
5. Alice types her password. This is the only moment she really authenticates.
6. Keycloak redirects the browser to `app.localhost/oauth2/callback?code=...`.
7. The gateway routes `/oauth2/*` to OAuth2-Proxy (no ext_authz on these paths).
8. OAuth2-Proxy sends the code and its client secret to Keycloak's `/token` endpoint,
   server to server, on the internal service name.
9. Keycloak returns the ID, access and refresh tokens to OAuth2-Proxy. The browser never sees them.
10. OAuth2-Proxy encrypts the tokens into the `_oauth2_proxy` cookie and redirects the browser
    back to `/api/whoami`.
11. The browser sends the request again, now with the cookie.
12. ext_authz asks OAuth2-Proxy again. It decrypts the cookie and answers 200 with
    `X-Auth-Request-User`, `X-Auth-Request-Email` and `X-Auth-Request-Access-Token`,
    without calling Keycloak.
13. The gateway adds those headers, removes the cookie and routes the request to Spring.
    Spring's sidecar validates the access token (audience `spring-api`) and checks the roles.

## Later requests

- Every request repeats steps 11–13.
- After 4 minutes (`--cookie-refresh=4m`), OAuth2-Proxy uses the refresh token on the back channel
  to get new tokens, and sets a new cookie. The user notices nothing.
- If the Keycloak session has ended (30 minutes idle, or 10 hours in total), the refresh fails,
  OAuth2-Proxy clears its cookie and the browser goes back to the Keycloak login.

## Responsibilities

| Component | Responsibility |
| --- | --- |
| **Browser** | Follows redirects, shows the Keycloak login page, stores the cookie |
| **Istio ingress gateway** | Asks OAuth2-Proxy (ext_authz), routes the request, removes the cookie |
| **OAuth2-Proxy** | OIDC client: redirects to login, exchanges the code, keeps the session, answers the check |
| **Keycloak** | Authenticates the user, issues the tokens |
| **Spring sidecar** | Validates the access token, checks the roles |
| **Spring** | Business logic only |

## The two access paths

```
app.localhost (browser, session cookie)
──────────────────────────────────────────
Browser → Ingress ── ext_authz ──► OAuth2-Proxy (session check, login redirect)
             │
             ▼
        Spring sidecar (token from X-Auth-Request-Access-Token) → Spring

api.localhost (script, Bearer JWT)
──────────────────────────────────────────
Client → Ingress
           │ RequestAuthentication: validate the JWT
           │ AuthorizationPolicy: a valid token is required
           ▼
        Spring sidecar (audience + roles) → Spring
```

More detail: `doc/istio-request-flow.md` (every Envoy filter in order) and the slides
"Authorization code flow" in `presentation/slidev/slides.md`.

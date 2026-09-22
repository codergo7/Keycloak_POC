Browser
   │
   │ no JWT
   ▼
Ingress Envoy
   │
   ├─ RequestAuthentication
   │      no JWT → nothing to validate
   │
   ├─ AuthorizationPolicy
   │      app.localhost → ALLOW
   │
   ▼
OAuth2-Proxy
   │
   ├─ session?
   │
   └─ NO
   │
   ▼
Redirect → Keycloak


========================


Browser
   │
   │ Cookie: _oauth2_proxy=...
   ▼
Ingress Envoy
   │
   │ AuthorizationPolicy allows app.localhost
   ▼
OAuth2-Proxy
   │
   │ validates/loads session
   ▼
Spring

===

RequestAuthentication isn't validating that oauth2-proxy session cookie. OAuth2-Proxy owns the session.

Compare that with api.localhost

This is where RequestAuthentication becomes central:


curl \
  -H "Authorization: Bearer $TOKEN" \
  http://api.localhost:8080/api/user


curl
 │
 │ Authorization: Bearer <Keycloak JWT>
 ▼
Ingress Envoy
 │
 ├── RequestAuthentication
 │      │
 │      ├─ issuer?
 │      ├─ signature?
 │      ├─ expiry?
 │      └─ JWT valid ✓
 │
 │    JWT claims available
 │           ↓
 ├── AuthorizationPolicy
 │      requestPrincipals: ["*"]
 │           ↓
 │         ALLOW
 │
 ▼
Spring

=============================


That's why these two parts of your POC are useful together:

app.localhost
────────────────────────────
Authentication mechanism:
OAuth2-Proxy session

Browser → Ingress → OAuth2-Proxy
                        │
                   session check
                        │
                   Keycloak login
                        │
                      Spring


api.localhost
────────────────────────────
Authentication mechanism:
Bearer JWT

Client → Ingress
            │
      RequestAuthentication
            │
       validate JWT
            │
      AuthorizationPolicy
            │
          Spring
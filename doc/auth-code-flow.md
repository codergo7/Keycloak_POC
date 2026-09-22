Browser
  ↓
Istio Ingress
  ↓
OAuth2-Proxy
  ↓ no session
Redirect → Keycloak /auth
  ↓
User authenticates
  ↓
Keycloak returns authorization code
  ↓
OAuth2-Proxy /callback
  ↓
OAuth2-Proxy → Keycloak /token
  ↓
access token + ID token (+ possibly refresh token)
  ↓
OAuth2-Proxy creates session
  ↓
Browser gets session cookie
  ↓
Next request
  ↓
OAuth2-Proxy recognizes session
  ↓
Upstream Spring service


===========================================


                       KEYCLOAK
                    ┌─────────────┐
                    │ OIDC Server │
                    └──────▲──────┘
                           │
                3. Login   │ 4. Authorization code
                           │
                           ▼
┌─────────┐        ┌───────────────┐
│ Browser │───────►│ Istio Ingress │
└────▲────┘        └───────┬───────┘
     │                     │
     │                     ▼
     │              ┌──────────────┐
     │              │ OAuth2-Proxy │
     │              └──────┬───────┘
     │                     │
     │                     │ 5. POST /token
     │                     ├──────────────► Keycloak
     │                     │
     │                     │◄──────────────
     │                     │ access/id tokens
     │                     │
     │ 6. Session cookie   │
     │◄────────────────────┘
     │
     │ 7. GET / + cookie
     ▼
 Istio Ingress
     │
     ▼
 OAuth2-Proxy
     │
     │ Session valid
     │ Optional identity/token headers
     ▼
 Spring Boot



 1. Browser → app.localhost

2. Istio routes request → OAuth2-Proxy

3. No session
   OAuth2-Proxy redirects browser → Keycloak /auth

4. User authenticates
   Keycloak redirects browser →
   /oauth2/callback?code=...

5. OAuth2-Proxy exchanges code with Keycloak /token

6. OAuth2-Proxy establishes session
   Browser receives session cookie

7. Browser requests app again with cookie

8. OAuth2-Proxy validates session

9. OAuth2-Proxy forwards authenticated request → Spring

10. Spring response → OAuth2-Proxy → Browser


==============================

| Component         | Responsibility                                         |
| ----------------- | ------------------------------------------------------ |
| **Browser**       | Follows redirects, presents login UI, stores cookie    |
| **Istio Ingress** | Routes traffic                                         |
| **OAuth2-Proxy**  | OIDC client, redirect handling, code exchange, session |
| **Keycloak**      | Authentication, OIDC provider, token issuance          |
| **Spring**        | Application/business logic                             |



===================================



FLOW 1 — Browser
Browser → OAuth2-Proxy → Keycloak
                    ↓
                 Spring


FLOW 2 — API
curl + Bearer JWT
        ↓
Istio JWT validation
        ↓
AuthorizationPolicy
        ↓
Spring


FLOW 3 — Internal service
Service A
   ↓
Istio mTLS
   ↓
ServiceAccount authorization
   ↓
Spring

================================


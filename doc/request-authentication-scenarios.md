What is RequestAuthentication responsible for?

In Istio, RequestAuthentication is responsible for JWT authentication.

Its job is essentially:

If this request contains a JWT, validate the JWT and make the authenticated identity and claims available to Istio.

Request reaches Istio Ingress
             │
             ▼
     Is a JWT presented?
          /       \
        NO         YES
        │           │
        │           ▼
        │      Extract JWT
        │           │
        │           ▼
        │      Check issuer
        │           │
        │           ▼
        │      Get/use JWKS
        │           │
        │           ▼
        │      Verify signature
        │           │
        │      Check exp etc.
        │           │
        │      ┌────┴────┐
        │    INVALID    VALID
        │       │         │
        │      401        ▼
        │             Create authenticated
        │             request identity
        │             + expose claims
        │                 │
        └─────────────────┤
                          ▼
                AuthorizationPolicy



RequestAuthentication authenticates a JWT. It does not, by itself, require authentication or decide whether the authenticated identity is allowed to access an endpoint.


1. No JWT at all

```bash
curl http://api.localhost:8080/api/public

---
Authorization: Bearer ...
```

Client
  │
  │ GET /api/public
  │ NO JWT
  ▼
Istio Ingress
  │
  ▼
RequestAuthentication
  │
  │ No JWT found
  │
  │ Nothing to authenticate
  │
  │ RequestAuthentication
  │ does NOT reject it merely
  │ because JWT is absent
  ▼
AuthorizationPolicy
  │
  │ /api/public is public
  ▼
ALLOW
  │
  ▼
Spring
  │
  ▼
200


2. No JWT, but protected endpoint

```bash
curl http://api.localhost:8080/api/user

---
No JWT
```

RequestAuthentication itself still doesn't reject it just because the token is absent.

But your AuthorizationPolicy says:

from:
- source:
    requestPrincipals:
    - "*"
to:
- operation:
    paths:
    - /api/user


That means:

/api/user requires an authenticated request principal.


Client
  │
  │ GET /api/user
  │ NO JWT
  ▼
RequestAuthentication
  │
  │ No JWT
  │ therefore no
  │ requestPrincipal
  ▼
AuthorizationPolicy
  │
  │ requires:
  │ requestPrincipals: ["*"]
  │
  │ Does authenticated
  │ principal exist?
  │
  └── NO
       │
       ▼
      403


This is an important distinction:

RequestAuthentication
    "Can I authenticate this JWT?"

AuthorizationPolicy
    "Must this endpoint have an authenticated identity?"


3. JWT exists but is invalid

You already tested this:

```bash
curl \
  -H "Authorization: Bearer ${TOKEN}BROKEN" \
  http://api.localhost:8080/api/user
  
```

Flow:

Client
  │
  │ Authorization:
  │ Bearer eyJ...BROKEN
  ▼
Ingress
  │
  ▼
RequestAuthentication
  │
  ├── JWT found
  │
  ├── parse JWT
  │
  ├── issuer
  │
  ├── signature
  │
  ├── expiration
  │
  └── verification FAILS
          │
          ▼
        401


You observed exactly this:

401 Unauthorized
Jwt verification fails


4. Valid JWT

For example:

TOKEN=$(./scripts/get-token.sh alice)

curl \
  -H "Authorization: Bearer $TOKEN" \
  http://api.localhost:8080/api/user

Now:

Client
 │
 │ Authorization:
 │ Bearer <Alice JWT>
 ▼
Ingress Envoy
 │
 ▼
RequestAuthentication
 │
 ├── JWT exists
 │
 ├── issuer ✓
 │
 ├── signature ✓
 │
 ├── expiration ✓
 │
 └── VALID
 │
 ▼
Authenticated identity created
 │
 ├── request.auth.principal
 │
 └── claims available:
 │
 │   preferred_username = alice
 │   groups = [...]
 │   realm_access.roles = [...]
 │   aud = spring-api
 │
 ▼
AuthorizationPolicy
 │
 │ requestPrincipals: ["*"]
 │
 └── MATCH
      │
      ▼
     ALLOW
      │
      ▼
    Spring
      │
      ▼
     200

That's your:

/api/user + Alice JWT → 200


5. Valid JWT but insufficient role

This is your /api/admin case.

Alice's JWT is perfectly valid.

But she doesn't have:

admin

So authentication succeeds while authorization fails.

Alice
 │
 │ Valid JWT
 ▼
RequestAuthentication
 │
 │ signature ✓
 │ issuer ✓
 │ expiration ✓
 │
 ▼
AUTHENTICATED ✓
 │
 │ roles:
 │ developer
 │ user
 ▼
AuthorizationPolicy
 │
 │ Requirement:
 │ realm_access.roles
 │ contains "admin"
 │
 │ NO MATCH
 ▼
403 Forbidden

This is probably the best example for explaining:

Authenticated does not mean authorized.

Alice is:

Authenticated: YES
Authorized:    NO


6. Valid Admin JWT

Now:

Admin JWT
     │
     ▼
RequestAuthentication
     │
     │ JWT valid
     ▼
Authenticated
     │
     │ realm_access.roles:
     │ - user
     │ - admin
     ▼
AuthorizationPolicy
     │
     │ requires admin
     │
     │ MATCH ✓
     ▼
Spring
     │
     ▼
200


Therefore:

/api/admin + Alice JWT → 403
/api/admin + Admin JWT → 200

Authentication succeeds in both cases.

The difference is authorization



7. Browser → oauth2-proxy with no session

Now we get to your other flow:


```bash
curl http://app.localhost:8080/

No JWT
No oauth2-proxy session
```

Browser
 │
 │ GET app.localhost
 ▼
Istio Ingress
 │
 ▼
RequestAuthentication
 │
 │ no JWT
 │
 │ nothing to validate
 ▼
AuthorizationPolicy
 │
 │ app.localhost allowed
 ▼
OAuth2-Proxy
 │
 │ session cookie?
 │
 └── NO
      │
      ▼
302 Redirect
      │
      ▼
Keycloak /auth

Therefore:

RequestAuthentication does not initiate the Keycloak login.

OAuth2-Proxy does.


8. Browser after Keycloak login

After authentication:

Browser
 │
 │ Cookie:
 │ _oauth2_proxy=...
 ▼
Ingress
 │
 ▼
RequestAuthentication
 │
 │ Usually no Bearer JWT
 │ from browser
 │
 │ nothing to validate
 ▼
AuthorizationPolicy
 │
 │ app.localhost allowed
 ▼
OAuth2-Proxy
 │
 │ session valid? ✓
 ▼
Forward request
 │
 ▼
Spring

Again:

RequestAuthentication ≠ session authentication

OAuth2-Proxy owns that session.


9. Browser sends a broken oauth2-proxy cookie

Suppose:

Cookie: _oauth2_proxy=INVALID

The flow is:

Browser
 │
 │ invalid session cookie
 ▼
Ingress
 │
 ▼
RequestAuthentication
 │
 │ doesn't care about
 │ oauth2-proxy cookie
 ▼
AuthorizationPolicy
 │
 │ app.localhost allowed
 ▼
OAuth2-Proxy
 │
 │ validate session
 │
 └── INVALID
      │
      ▼
Keycloak login / authentication flow

That's another good example of responsibility separation.


The complete picture

This is the diagram I'd put in the presentation:

                         REQUEST
                            │
                            ▼
                    ┌───────────────┐
                    │     Envoy     │
                    └───────┬───────┘
                            │
                            ▼
                  RequestAuthentication
                            │
                            │ JWT
                            ▼
                    Request identity
                            │
                    Keycloak subject
                    roles
                    groups
                    claims
                            │
                            ▼
                  AuthorizationPolicy
                            │
                  "Do the claims allow it?"
                            │
                    ┌───────┴───────┐
                    │               │
                  ALLOW            DENY
                    │               │
                    ▼               ▼
               Application         403

And oauth2-proxy sits alongside this for the browser use case:

Browser authentication
────────────────────────

Browser
   │
   ▼
Ingress
   │
   ▼
OAuth2-Proxy
   │
   │ session missing
   ▼
Keycloak login
   │
   ▼
OAuth2-Proxy session
   │
   ▼
Spring
The responsibilities to remember
Istio / Keycloak component	Main responsibility
Keycloak	Authenticate users/clients and issue tokens
OAuth2-Proxy	Browser OIDC flow and session management
RequestAuthentication	Validate JWTs and expose authenticated JWT identity/claims
AuthorizationPolicy	Decide whether the authenticated/request identity may access something
VirtualService	Route traffic
Spring Boot	Business logic and business-level authorization

The shortest presentation version is:

RequestAuthentication validates the JWT and exposes its claims. AuthorizationPolicy decides from those claims whether the request is allowed. OAuth2-Proxy handles the browser login/session flow, while Keycloak authenticates identities and issues tokens.

That separation of responsibilities is really the central architecture lesson of your whole POC.


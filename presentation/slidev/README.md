# Keycloak, OAuth2-Proxy & Istio — Slidev deck

Animated version of `../Keycloak, OAuth2-Proxy & Istio (1).pptx`.

```bash
npm install
npm run dev        # http://localhost:3030, presenter view at /presenter
npm run build      # static site in dist/
npm run export -- --executable-path /usr/bin/google-chrome   # PDF
```

Press `→` / space to step through clicks; `o` shows the slide overview.

## Animated components

| Component | Slide | What it shows |
|---|---|---|
| `components/ArchDiagram.vue` | 4 | The POC architecture: kind cluster, the istio-system, identity, spring-api and reports-api namespaces, and the links between them (ingress, ext_authz, back channel, routes, istiod config and JWKS) |
| `components/ComponentsFlow.vue` | 5 | The four components, one per click, with what each hands to the next (signed tokens, identity headers + token, a checked request); click 5 shows the one-line summary |
| `components/KeycloakTerms.vue` | 6 | The Keycloak terms as one picture of realm demo (values from `k8s/keycloak/realm-configmap.yaml`): clients that ask for tokens and the APIs, users and their groups, realm roles and the client roles of reports-api (editor is a composite containing viewer), client scopes (app-audience and groups by default, reports optional), then groups carrying roles and alice's access token showing where each claim comes from |
| `components/TokenCookie.vue` | 7 (clicks 1–3) | OAuth2-Proxy turns Keycloak's three tokens (ID, access, refresh) into one `_oauth2_proxy` cookie: pack, LZ4, AES-GCM with the cookie-secret, HMAC; then the cookie's three parts and flags, measured on the cluster. Fades out at click 4 for the four cards |
| `components/CarryIdentity.vue` | 13 | The two ways to carry identity: a browser request with the encrypted session cookie, checked by OAuth2-Proxy; a script's bearer JWT, readable by anyone and verified by RequestAuthentication; a changed role breaks the signature (401); then scope, claim and role from alice's real token |
| `components/BackupIndex.vue` | 20 (backup) | Index of the backup slides by topic; each entry links to its slide by `routeAlias` and shows its current number |
| `components/LoginPaths.vue` | 27 (backup) | Who talks to Keycloak during login: the browser via the gateway (front channel), OAuth2-Proxy pod to pod (back channel), and Keycloak's two names |
| `components/DbPolicy.vue` | 33 (backup) | Who can log in to Postgres, before and after `postgres-allow-keycloak`: service-account identities, the TCP (network rbac) filter, and next steps |
| `components/KeycloakDown.vue` | 37 (backup) | What keeps working while Keycloak is down, measured on the cluster |
| `components/JwksFlow.vue` | 38 (backup) | How both RequestAuthentications get Keycloak's keys: issuer vs jwksUri, a zoom into jwt_authn (`JwtAuthnZoom.vue`: decode, verify, claims into dynamic metadata, who reads them), istiod fetches and inlines the JWKS, refresh interval, failed fetch, key rotation, and the settings |
| `components/EnvoyFilters.vue` | 23 (backup) | What istiod turns each Istio resource into: the real `envoy.filters.http.*` chain and generated config, gateway then sidecar |
| `components/AuthzDecision.vue` | 25 (backup) | How the rbac filter decides: CUSTOM → DENY → ALLOW, each rule of spring-workload-authorization as permissions (to) and principals (from, when), where the values come from, alice allowed on /api/user and denied on /api/admin with the real rbac debug log lines, and the defaults |
| `components/DebugTree.vue` | 26 (backup) | Which filter produced a 302, 401, 403 or 503, the resource to look at, and the tools |
| `components/SeqFlow.vue` | 10, 11 | Authorization code flow: draws all 13 messages (`mode="overview"`), or one per click with a moving packet and the HTTP detail (`mode="steps"`). Steps 4 and 5 show the real Keycloak login page (`public/keycloak-login.png`) being filled in |
| `components/FilterChain.vue` | not in the deck | The real Envoy filter order at the ingress gateway and the Spring sidecar |
| `components/EnvoyInside.vue` | 14, 24 (backup) | One browser request through the ingress gateway and the Spring sidecar, filter by filter: ext_authz (AuthorizationPolicy CUSTOM), jwt_authn (RequestAuthentication) decoding the token and storing `request.auth.claims`, rbac (AuthorizationPolicy ALLOW) reading them, the router (VirtualService); then the same request as bob, denied with 403; how the setup grows is on backup slide 39 (`GrowMesh.vue`). With `mode="api"` (backup slide 24, 10 clicks) it follows a script's request to api.localhost/api/user with a Bearer token: ext_authz not called, the gateway validates the token and requires a principal, the router sends it to Spring, the sidecar checks the audience and the role; then no token (403 at the gateway), a tampered token (401 at the gateway) and /api/admin (403 at the sidecar) |
| `components/GrowMesh.vue` | 39 (backup) | Adding a backend (x-api, any language) in four steps: a Keycloak client and audience, a namespace with sidecar injection, istiod sending the RequestAuthentication + AuthorizationPolicy pair to the new sidecar, then a route and a gateway ALLOW rule; the last click shows what was added and what stayed the same |
| `components/TwoHosts.vue` | 31 (backup) | Why two host names: a browser without a cookie gets a 302 to the login, a script gets 403 / 401; the host-only cookie never reaches api.localhost (no CSRF there); the same split at GitHub, Stripe, Slack; the one-host, split-by-path alternative and its trade-off; and the BFF pattern in production |
| `components/RequestLanes.vue` | 22, 29 (backup) | Requests race through the same checkpoints until the one that stops them. Props `cols`, `groups`, `lanes` (a lane’s `from` starts it past the gateway); slide 30 reuses it for the identity-spoofing attempts |
| `components/CookieJourney.vue` | not in the deck | The session cookie goes to oauth2-proxy and is stripped before Spring |
| `components/HeaderGates.vue` | 32 (backup) | Every sensitive header, hop by hop, against the rule that lets it through or stops it (ext_authz header lists, VirtualService header rules, RequestAuthentication `fromHeaders`) |
| `components/LifetimeBars.vue` | 34 (backup) | Lifetimes of the ID, access and refresh tokens, the Keycloak SSO session and the cookies, on a log time axis |
| `components/RefreshLoop.vue` | 12 | The token refresh after `--cookie-refresh=4m`, then the same request after the session idled out |
| `components/SessionTimeline.vue` | 35 (backup) | A working day on a 0–12 h axis: the 10 h hard stop, and a lunch break that hits the 30 min idle timeout |
| `components/AudFlow.vue` | not in the deck | How client scopes and audience mappers fill `aud`, and how each sidecar checks it |
| `components/QaFlow.vue` | 36, 41 (backup) | Generic sequence diagram for Q&A slides; the steps live in `flows/qa-flows.ts` (`logout`, `s2s`) |

A slide that uses one of these declares its click count in its frontmatter (`clicks: 13` and so on).

Running order: theory (1–9), the login flow (10–11), the token refresh after the login (12), the two access paths (13), inside Envoy for browser access (14), a live demo of browser access (15), a live demo of API access (16), wrap-up (17–18), then backup slides (19–42): an index with links (20), claims per endpoint (21), six requests (22), Istio resources as Envoy filters (23), inside Envoy for API access (24), how an AuthorizationPolicy decides (25), debugging a 401 or 403 (26), who talks to Keycloak during login (27), what the browser sees after the login (28), faking an identity (29), the browser access policy (30), why two host names (31), every sensitive header (32), who can reach the database (33), token and session lifetimes (34–35), logout (36), Keycloak down (37), where the JWT keys come from (38), adding a backend (39), audience and scopes Q&A (40), service to service (41), and six issues from building the POC (42).

Every slide has speaker notes written to be read aloud (the HTML comment at the end of the slide), in full sentences per click. The talk opens and closes with one message: security out of the application. The main slides (1–22) are planned for a 30-minute slot including both demos (estimate, not rehearsed; the claims table moved to backup to make room). `[click]` markers in the notes highlight the current sentence in the presenter view.

## Notes

- `uno.config.ts` registers the Carbon icon set explicitly, because Slidev's built-in icon loader does not find it in this setup.
- `setup/shiki.ts` uses a dark code theme to match the navy code blocks.
- Lifetimes on slide 12 and the backup slides 34–35 are the live realm values (Keycloak defaults: access token 300 s, SSO idle 1800 s, SSO max 36000 s) and the oauth2-proxy flags `--cookie-refresh=4m` / `--cookie-expire=8h`. The refresh and failed-refresh behaviour was checked against the running cluster.
- Content is the original deck with fixes: no EnvoyFilter (VirtualService header rules instead), the cookie is removed before Spring, and alice gets `developer` from the `/engineering` group, so `/api/headers` is 200 for her.
- Wording: the deck uses the terms from the OAuth 2.0, OIDC, Keycloak and Istio docs (browser access and API access, ext_authz, external authorizer, policy enforcement, claims), not metaphors. Keycloak's own setting names (SSO Session Idle / Max) are kept where they are shown.

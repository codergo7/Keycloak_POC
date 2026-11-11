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
| `components/BackupIndex.vue` | 23 (backup) | Index of the backup slides by topic; each entry links to its slide by `routeAlias` and shows its current number |
| `components/KeycloakDown.vue` | 32 (backup) | What keeps working while Keycloak is down, measured on the cluster |
| `components/EnvoyFilters.vue` | 35 (backup) | What istiod turns each Istio resource into: the real `envoy.filters.http.*` chain and generated config, gateway then sidecar |
| `components/DebugTree.vue` | 36 (backup) | Which filter produced a 302, 401, 403 or 503, the resource to look at, and the tools |
| `components/SeqFlow.vue` | 11, 12 | Authorization code flow: draws all 13 messages (`mode="overview"`), or one per click with a moving packet and the HTTP detail (`mode="steps"`). Steps 4 and 5 show the real Keycloak login page (`public/keycloak-login.png`) being filled in |
| `components/FilterChain.vue` | not in the deck | The real Envoy filter order at the ingress gateway and the Spring sidecar |
| `components/EnvoyInside.vue` | 16, 18 | One browser request through the ingress gateway and the Spring sidecar, filter by filter: ext_authz (AuthorizationPolicy CUSTOM), jwt_authn (RequestAuthentication) decoding the token and storing `request.auth.claims`, rbac (AuthorizationPolicy ALLOW) reading them, the router (VirtualService); then the same request as bob, denied with 403; the last click adds more backends (reports-api, a new x-api, …), each with its own sidecar and RequestAuthentication + AuthorizationPolicy pair behind the same gateway. With `mode="api"` (slide 18, 10 clicks) it follows a script's request to api.localhost/api/user with a Bearer token: ext_authz not called, the gateway validates the token and requires a principal, the router removes a fake `X-Auth-Request-User`, the sidecar checks the audience and the role; then no token (403 at the gateway), a tampered token (401 at the gateway) and /api/admin (403 at the sidecar) |
| `components/RequestLanes.vue` | 25, 26 (backup) | Requests race through the same checkpoints until the one that stops them. Props `cols`, `groups`, `lanes` (a lane’s `from` starts it past the gateway); slide 26 reuses it for the identity-spoofing attempts |
| `components/CookieJourney.vue` | not in the deck | The session cookie goes to oauth2-proxy and is stripped before Spring |
| `components/HeaderGates.vue` | 28 (backup) | Every sensitive header, hop by hop, against the rule that lets it through or stops it (ext_authz header lists, VirtualService header rules, RequestAuthentication `fromHeaders`) |
| `components/LifetimeBars.vue` | 29 (backup) | Lifetimes of the ID, access and refresh tokens, the Keycloak SSO session and the cookies, on a log time axis |
| `components/RefreshLoop.vue` | 14 | The token refresh after `--cookie-refresh=4m`, then the same request after the session idled out |
| `components/SessionTimeline.vue` | 30 (backup) | A working day on a 0–12 h axis: the 10 h hard stop, and a lunch break that hits the 30 min idle timeout |
| `components/AudFlow.vue` | not in the deck | How client scopes and audience mappers fill `aud`, and how each sidecar checks it |
| `components/QaFlow.vue` | 31, 34 (backup) | Generic sequence diagram for Q&A slides; the steps live in `flows/qa-flows.ts` (`logout`, `s2s`) |

A slide that uses one of these declares its click count in its frontmatter (`clicks: 13` and so on).

Running order: theory (1–13), the token refresh after the login (14), the two access paths (15), inside Envoy for browser access (16), a live demo of browser access (17), inside Envoy for API access (18), a live demo of API access (19), wrap-up (20–21), then backup slides (22–37): an index with links (23), claims per endpoint (24), six requests (25), faking an identity (26), the browser access policy (27), every sensitive header (28), token and session lifetimes (29–30), logout (31), Keycloak down (32), audience and scopes Q&A (33), service to service (34), Istio resources as Envoy filters (35), debugging a 401 or 403 (36), and six issues from building the POC (37).

Every slide has speaker notes written to be read aloud (the HTML comment at the end of the slide), in full sentences per click. The talk opens and closes with one message: security out of the application. The main slides (1–21) are planned for a 30-minute slot including both demos (estimate, not rehearsed; the claims table moved to backup to make room). `[click]` markers in the notes highlight the current sentence in the presenter view.

## Notes

- `uno.config.ts` registers the Carbon icon set explicitly, because Slidev's built-in icon loader does not find it in this setup.
- `setup/shiki.ts` uses a dark code theme to match the navy code blocks.
- Lifetimes on slide 14 and the backup slides 29–30 are the live realm values (Keycloak defaults: access token 300 s, SSO idle 1800 s, SSO max 36000 s) and the oauth2-proxy flags `--cookie-refresh=4m` / `--cookie-expire=8h`. The refresh and failed-refresh behaviour was checked against the running cluster.
- Content is the original deck with fixes: no EnvoyFilter (VirtualService header rules instead), the cookie is removed before Spring, and alice gets `developer` from the `/engineering` group, so `/api/headers` is 200 for her.
- Wording: the deck uses the terms from the OAuth 2.0, OIDC, Keycloak and Istio docs (browser access and API access, ext_authz, external authorizer, policy enforcement, claims), not metaphors. Keycloak's own setting names (SSO Session Idle / Max) are kept where they are shown.

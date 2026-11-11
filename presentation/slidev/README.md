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
| `components/SeqFlow.vue` | 11, 12 | Authorization code flow: draws all 13 messages (`mode="overview"`), or one per click with a moving packet and the HTTP detail (`mode="steps"`). Steps 4 and 5 show the real Keycloak login page (`public/keycloak-login.png`) being filled in |
| `components/FilterChain.vue` | 24 (backup) | The real Envoy filter order at the ingress gateway and the Spring sidecar |
| `components/RequestLanes.vue` | 16 | Six requests race through the same checkpoints until the one that stops them |
| `components/CookieJourney.vue` | 29 (backup) | The session cookie goes to oauth2-proxy and is stripped before Spring |
| `components/HeaderGates.vue` | 26 (backup) | Every sensitive header, hop by hop, against the rule that lets it through or stops it (ext_authz header lists, VirtualService header rules, RequestAuthentication `fromHeaders`) |
| `components/LifetimeBars.vue` | 27 (backup) | Lifetimes of the ID, access and refresh tokens, the Keycloak SSO session and the cookies, on a log time axis |
| `components/RefreshLoop.vue` | 14 | The silent refresh after `--cookie-refresh=4m`, then the same request after the session idled out |
| `components/SessionTimeline.vue` | 28 (backup) | A working day on a 0–12 h axis: the 10 h hard stop, and a lunch break that hits the 30 min idle timeout |
| `components/AudFlow.vue` | not in the deck | How client scopes and audience mappers fill `aud`, and how each sidecar checks it |
| `components/QaFlow.vue` | not in the deck | Generic sequence diagram for Q&A slides; the steps live in `flows/qa-flows.ts` (`logout`, `spoof`) |

A slide that uses one of these declares its click count in its frontmatter (`clicks: 13` and so on).

Running order: theory (1–13), the silent refresh after the login (14), the two doors and six requests (15–16), a live demo of Door 1 (17), Door 2 (18–19), a live demo of Door 2 (20), wrap-up (21–22), then backup slides (23–31): the Envoy filter order (24), the Door 1 policy (25), every sensitive header (26), token and session lifetimes (27–28), the cookie's trip (29), audience and scopes Q&A (30), and lessons from building the POC (31).

Every slide has speaker notes written to be read aloud (the HTML comment at the end of the slide), in full sentences per click. The talk opens and closes with one message: security out of the application. The main slides (1–22) come to about 29.5 minutes including both demos (estimate, not rehearsed). `[click]` markers in the notes highlight the current sentence in the presenter view.

## Notes

- `uno.config.ts` registers the Carbon icon set explicitly, because Slidev's built-in icon loader does not find it in this setup.
- `setup/shiki.ts` uses a dark code theme to match the navy code blocks.
- Lifetimes on slide 14 and the backup slides 27–28 are the live realm values (Keycloak defaults: access token 300 s, SSO idle 1800 s, SSO max 36000 s) and the oauth2-proxy flags `--cookie-refresh=4m` / `--cookie-expire=8h`. The refresh and failed-refresh behaviour was checked against the running cluster.
- Content is the original deck with fixes: no EnvoyFilter (VirtualService header rules instead), the cookie is removed before Spring, and alice gets `developer` from the `/engineering` group, so `/api/headers` is 200 for her.

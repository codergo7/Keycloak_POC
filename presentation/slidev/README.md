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
| `components/SeqFlow.vue` | 11, 12 | Authorization code flow: draws all 13 messages (`mode="overview"`), or one per click with a moving packet and the HTTP detail (`mode="steps"`) |
| `components/FilterChain.vue` | 15 | The real Envoy filter order at the ingress gateway and the Spring sidecar |
| `components/RequestLanes.vue` | 16 | Six requests race through the same checkpoints until the one that stops them |
| `components/CookieJourney.vue` | 30 (backup) | The session cookie goes to oauth2-proxy and is stripped before Spring |
| `components/HeaderGates.vue` | 18 | Every sensitive header, hop by hop, against the rule that lets it through or stops it (ext_authz header lists, VirtualService header rules, RequestAuthentication `fromHeaders`) |
| `components/LifetimeBars.vue` | 27 (backup) | Lifetimes of the ID, access and refresh tokens, the Keycloak SSO session and the cookies, on a log time axis |
| `components/RefreshLoop.vue` | 28 (backup) | The silent refresh after `--cookie-refresh=4m`, then the same request after the session idled out |
| `components/SessionTimeline.vue` | 29 (backup) | A working day on a 0–12 h axis: the 10 h hard stop, and a lunch break that hits the 30 min idle timeout |
| `components/AudFlow.vue` | 31 (backup) | How client scopes and audience mappers fill `aud` (without and with `scope=reports`), and how each sidecar checks it |

A slide that uses one of these declares its click count in its frontmatter (`clicks: 13` and so on).

Running order: theory (1–13), the two doors and the proxies (14–18), a live demo of Door 1 (19), Door 2 (20–21), a live demo of Door 2 (22), wrap-up (23–25), then backup slides (26–32): session lifetimes, the cookie's trip, how the audience gets into the token (31), and audience and scopes Q&A (32).

Every slide has speaker notes written to be read aloud (the HTML comment at the end of the slide), in full sentences per click. The main slides (1–25) come to about 32 minutes including both demos (estimate, not rehearsed). `[click]` markers in the notes highlight the current sentence in the presenter view.

## Notes

- `uno.config.ts` registers the Carbon icon set explicitly, because Slidev's built-in icon loader does not find it in this setup.
- `setup/shiki.ts` uses a dark code theme to match the navy code blocks.
- Lifetimes on the backup slides 27–29 are the live realm values (Keycloak defaults: access token 300 s, SSO idle 1800 s, SSO max 36000 s) and the oauth2-proxy flags `--cookie-refresh=4m` / `--cookie-expire=8h`. The refresh and failed-refresh behaviour was checked against the running cluster.
- Content is the original deck with fixes: no EnvoyFilter (VirtualService header rules instead), the cookie is removed before Spring, and alice gets `developer` from the `/engineering` group, so `/api/headers` is 200 for her.

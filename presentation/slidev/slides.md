---
theme: default
title: Keycloak, OAuth2-Proxy & Istio
info: |
  Who are you, and what may you do?
  Authentication and authorization on Kubernetes with Keycloak, OAuth2-Proxy and Istio.
colorSchema: light
transition: slide-left
canvasWidth: 980
mdc: true
fonts:
  sans: IBM Plex Sans
  mono: JetBrains Mono
  weights: '400,500,600,700'
layout: default
class: navy
---

<div class="h-full flex flex-col justify-center">
  <div class="kicker" v-motion :initial="{ opacity: 0, y: -10 }" :enter="{ opacity: 1, y: 0 }">Identity on Kubernetes · POC</div>

  <h1 class="!text-6xl !leading-tight !mb-6">
    <span class="inline-block" v-motion :initial="{ opacity: 0, x: -40 }" :enter="{ opacity: 1, x: 0, transition: { delay: 150 } }">Who are you,</span><br>
    <span class="inline-block" v-motion :initial="{ opacity: 0, x: -40 }" :enter="{ opacity: 1, x: 0, transition: { delay: 450 } }">and what may you do?</span>
  </h1>

  <p class="text-lg max-w-2xl muted" v-motion :initial="{ opacity: 0 }" :enter="{ opacity: 1, transition: { delay: 900 } }">
    Authentication and authorization with <span class="kc">Keycloak</span>, <span class="op">OAuth2-Proxy</span>
    and <span class="is">Istio</span>: the theory, the story, then a live demo
  </p>

  <div class="mt-14 text-sm muted" v-motion :initial="{ opacity: 0 }" :enter="{ opacity: 1, transition: { delay: 1200 } }">
    [Presenter name] · [Date / event]
  </div>
</div>

<!--
I am not going to deep dive into each technology one by one. I will summarize each one and show how they handle authentication and authorization together.
-->

---

<div class="kicker">The road for today</div>

# From theory to a story to proof

<div class="grid grid-cols-3 gap-5 mt-6">
  <div v-click class="card !p-5">
    <div class="text-5xl font-bold text-[var(--blue)] mb-2">1</div>
    <h3>Theory</h3>
    <p>Design principles<br>AuthN vs AuthZ<br>The four players<br>JWTs, cookies, scopes<br>Authorization code flow</p>
  </div>
  <div v-click class="card !p-5">
    <div class="text-5xl font-bold text-[var(--orange)] mb-2">2</div>
    <h3>The story</h3>
    <p>Inside the proxies<br>Three doors, one identity<br>Browser · API · service-to-service<br>Layers of defense</p>
  </div>
  <div v-click class="card !p-5">
    <div class="text-5xl font-bold text-[var(--navy)] mb-2">3</div>
    <h3>The proof</h3>
    <p>Live demo on kind<br>Expected vs actual<br>Takeaways and Q&amp;A</p>
  </div>
</div>

---

<div class="kicker">Ground rules</div>

# Four ideas behind the whole design

<div class="grid grid-cols-2 gap-4 mt-6">
  <div v-for="(r, i) in [
      { icon: 'i-carbon-settings-adjust', t: 'Separation of concerns', d: 'Identity, login sessions, enforcement and business logic each live in a different place.' },
      { icon: 'i-carbon-cube', t: 'Single responsibility', d: 'Each component does one job well and has only one reason to change.' },
      { icon: 'i-carbon-security', t: 'Zero trust, defense in depth', d: 'Never trust the network. Check at the edge and again at the workload.' },
      { icon: 'i-carbon-certificate', t: 'Don’t build your own auth', d: 'Use open standards (OAuth 2.0, OIDC, JWT, mTLS) and proven tools.' },
    ]" :key="r.t" class="card flex gap-3 items-start"
    v-motion :initial="{ opacity: 0, y: 30, scale: 0.96 }" :enter="{ opacity: 1, y: 0, scale: 1, transition: { delay: 150 + i * 140 } }">
    <span class="icon-dot"><span :class="r.icon" /></span>
    <div><h3>{{ r.t }}</h3><p>{{ r.d }}</p></div>
  </div>
</div>

---

<div class="kicker">Two questions, always in this order</div>

# Authentication comes before authorization

<div class="grid grid-cols-2 gap-6 mt-5">
  <div class="card !p-5" v-motion :initial="{ opacity: 0, x: -40 }" :enter="{ opacity: 1, x: 0 }">
    <div class="flex items-center gap-3 mb-2">
      <span class="icon-dot"><span class="i-carbon-identification" /></span>
      <div><div class="font-bold text-2xl text-[var(--navy)]">AuthN</div><div class="muted text-sm">Who are you?</div></div>
    </div>
    <p><b>Identification:</b> you claim an identity (“I am alice”)<br>
    <b>Verification:</b> you prove it (password, OTP, certificate)<br>
    <b>Result:</b> a trusted identity, carried in a token or session</p>
    <div class="mt-3 text-sm italic text-[var(--blue)]">Airport: showing your passport</div>
    <div class="mt-3"><span class="chip orange">401 = who are you?</span></div>
  </div>
  <div v-click class="card !p-5">
    <div class="flex items-center gap-3 mb-2">
      <span class="icon-dot orange"><span class="i-carbon-locked" /></span>
      <div><div class="font-bold text-2xl text-[var(--navy)]">AuthZ</div><div class="muted text-sm">What may you do?</div></div>
    </div>
    <p><b>Roles &amp; groups:</b> admin, developer, /engineering<br>
    <b>Scopes:</b> what a client may ask on your behalf<br>
    <b>Claims:</b> the facts in the token that rules check</p>
    <div class="mt-3 text-sm italic text-[var(--orange)]">Airport: your boarding pass and gate</div>
    <div class="mt-3"><span class="chip red">403 = I know you, and no</span></div>
  </div>
</div>

---

<div class="kicker">The cast</div>

# Four components, four jobs

<div class="grid grid-cols-4 gap-4 mt-5">
  <div v-for="(c, i) in [
      { icon: 'i-carbon-password', n: 'Keycloak', r: 'Identity provider', d: 'Knows the users, checks passwords, issues signed tokens.', cls: '' },
      { icon: 'i-carbon-earth', n: 'OAuth2-Proxy', r: 'Browser login', d: 'Runs the login flow for browsers and keeps the session cookie.', cls: '' },
      { icon: 'i-carbon-security', n: 'Istio', r: 'Enforcer', d: 'Validates tokens and applies access rules at the edge and at each pod.', cls: 'orange' },
      { icon: 'i-carbon-code', n: 'Spring Boot', r: 'Business logic', d: 'Does its real job. No login code, no token parsing.', cls: 'navy' },
    ]" :key="c.n" class="card !p-4"
    v-motion :initial="{ opacity: 0, y: 50, rotateX: 40 }" :enter="{ opacity: 1, y: 0, rotateX: 0, transition: { delay: 120 + i * 160, type: 'spring', stiffness: 120, damping: 14 } }">
    <span class="icon-dot mb-3" :class="c.cls"><span :class="c.icon" /></span>
    <h3>{{ c.n }}</h3>
    <div class="mono text-xs mb-2" :class="i === 2 ? 'text-[var(--orange)]' : 'text-[var(--blue)]'">{{ c.r }}</div>
    <p>{{ c.d }}</p>
  </div>
</div>

<p v-click class="remember"><b>One line to remember:</b> Keycloak <i>decides who you are</i>, OAuth2-Proxy <i>remembers you</i>, Istio <i>checks you</i>.</p>

---

<div class="kicker">Keycloak · the identity provider</div>

# Six terms you need for Keycloak

<div class="tbl-card mt-3">
<table class="tbl">
  <thead><tr><th>Term</th><th>In plain words</th><th>In our POC</th></tr></thead>
  <tbody>
    <tr v-click><td class="strong">Realm</td><td>An isolated space with its own users, roles and clients</td><td><code>poc</code></td></tr>
    <tr v-click><td class="strong">Client</td><td>An application that asks Keycloak to log users in or for tokens</td><td><code>oauth2-proxy</code> <code>cli-client</code> <code>spring-api</code></td></tr>
    <tr v-click><td class="strong">User &amp; group</td><td>A person, and a team they belong to</td><td>alice, bob, admin · <code>/engineering</code> <code>/admins</code></td></tr>
    <tr v-click><td class="strong">Realm role</td><td>A permission label; a composite role bundles others</td><td>user, developer, premium, admin · <code>power-user</code></td></tr>
    <tr v-click><td class="strong">Client scope</td><td>A named bundle of claims a client can request</td><td><code>groups</code> <code>app-audience</code></td></tr>
    <tr v-click><td class="strong">Protocol mapper</td><td>Rule that writes a fact into the token</td><td>group membership, audience</td></tr>
  </tbody>
</table>
</div>

<p v-click class="remember text-sm muted">Groups carry roles too: alice is only <code>user</code> directly, but gets <code>developer</code> from <code>/engineering</code> and <code>premium</code> from <code>/engineering/platform</code>.</p>

---

<div class="kicker">OAuth2-Proxy · the browser’s login helper</div>

# It turns a login into a session cookie

<div class="grid grid-cols-[1.25fr_1fr] gap-6 mt-4">
<div class="grid grid-cols-2 gap-3">
  <div v-click="1" class="card"><h3>OIDC client</h3><p>Registered in Keycloak as the <code>oauth2-proxy</code> client, with a client secret.</p></div>
  <div v-click="2" class="card"><h3>Session cookie</h3><p><code>_oauth2_proxy</code>, encrypted. Refreshed every 4 minutes, expires after 8 hours.</p></div>
  <div v-click="3" class="card"><h3>External authorizer</h3><p>Istio asks it “is this request logged in?” It answers yes, or redirects to login.</p></div>
  <div v-click="4" class="card"><h3>Identity headers</h3><p>Returns X-Auth-Request-User, -Email and the access token, for Istio to copy into the request.</p></div>
</div>

```yaml {all|1-2|3-4|5-6|7-9}{at:1}
--provider=keycloak-oidc
--client-id=oauth2-proxy
--cookie-refresh=4m
--cookie-expire=8h
--upstream=static://200   # auth check only
--scope=openid profile email groups app-audience
--set-xauthrequest=true   # X-Auth-Request-* headers
--pass-access-token=true  # …incl. the access token
--pass-authorization-header=true
```
</div>

<!--
Without set-xauthrequest + pass-access-token the access token never reaches Spring, because with static://200 oauth2-proxy never talks to Spring itself. We learned that the hard way: RBAC access denied.
-->

---

<div class="kicker">Istio · the enforcer</div>

# Five resources do all the enforcing

<div class="tbl-card mt-3">
<table class="tbl">
  <thead><tr><th>Resource</th><th>Kind of job</th><th>What it does for us</th></tr></thead>
  <tbody>
    <tr v-click><td class="strong">Gateway + VirtualService</td><td><span class="chip">Routing</span></td><td>Routes our three hosts to the right service, and adds or removes headers per route</td></tr>
    <tr v-click><td class="strong">RequestAuthentication</td><td><span class="chip orange">AuthN · user</span></td><td>Validates a JWT: issuer, signature, expiry, audience</td></tr>
    <tr v-click><td class="strong">PeerAuthentication</td><td><span class="chip orange">AuthN · workload</span></td><td>Forces mTLS between pods: every caller has an ID</td></tr>
    <tr v-click><td class="strong">AuthorizationPolicy</td><td><span class="chip red">AuthZ</span></td><td>ALLOW / DENY / CUSTOM on paths, claims, callers</td></tr>
    <tr v-click><td class="strong">Mesh config <code>extensionProviders</code></td><td><span class="chip green">Integration</span></td><td>Plugs OAuth2-Proxy in as the CUSTOM authorizer and lists which headers may pass</td></tr>
  </tbody>
</table>
</div>

<p v-click class="remember">Every pod gets an Envoy sidecar; the ingress gateway is an Envoy too. <b>The rules run there, not in your code.</b> No EnvoyFilter needed.</p>

---

<div class="kicker">Tokens</div>

# A JWT is a signed note of facts about you

<div class="grid grid-cols-[1fr_1fr] gap-6 mt-3">
<div>
  <div class="mono text-sm mb-3" v-motion :initial="{ opacity: 0 }" :enter="{ opacity: 1 }">
    <span class="text-[var(--orange)] font-bold">header</span> .
    <span class="text-[var(--blue)] font-bold">payload</span> .
    <span class="text-[var(--green)] font-bold">signature</span>
  </div>

```json {all|2-4|6-8|9|all}
{
  "iss": ".../realms/poc",
  "aud": "spring-api",
  "azp": "oauth2-proxy",
  "preferred_username": "alice",
  "scope": "openid email groups",
  "realm_access": { "roles": ["user"] },
  "groups": ["/engineering"],
  "exp": 1793000000
}
```
</div>
<div class="flex flex-col gap-3">
  <div v-click="1" class="card"><h3>iss · aud · azp</h3><p>Who issued it, who it is for, which client asked for it</p></div>
  <div v-click="2" class="card"><h3>realm_access.roles · groups</h3><p>The claims our access rules check</p></div>
  <div v-click="3" class="card"><h3>exp · signature</h3><p>Short-lived and tamper-proof: verified with Keycloak’s public keys (JWKS)</p></div>
  <div v-click="4" class="card"><h3>Access · ID · refresh token</h3><p>Access = for APIs. ID = for the login client. Refresh = to get new ones.</p></div>
</div>
</div>

---

<div class="kicker">Carrying identity</div>

# Session cookies for people, bearer JWTs for machines

<div class="grid grid-cols-[1fr_1fr] gap-5 mt-4">
  <div class="card !p-5" v-motion :initial="{ opacity: 0, y: 30 }" :enter="{ opacity: 1, y: 0 }">
    <div class="flex items-center gap-3 mb-3"><span class="icon-dot orange"><span class="i-carbon-user" /></span><h3 class="!m-0 !text-lg">Session cookie</h3></div>
    <table class="tbl">
      <tbody>
      <tr><td class="muted">Who uses it</td><td>A person in a browser</td></tr>
      <tr><td class="muted">Sent as</td><td><code>Cookie: _oauth2_proxy=…</code></td></tr>
      <tr><td class="muted">Readable?</td><td>No, encrypted and HttpOnly</td></tr>
      <tr><td class="muted">Checked by</td><td>OAuth2-Proxy</td></tr>
      <tr><td class="muted">Our host</td><td><code>app.localhost</code></td></tr>
      </tbody>
    </table>
  </div>
  <div class="card !p-5" v-motion :initial="{ opacity: 0, y: 30 }" :enter="{ opacity: 1, y: 0, transition: { delay: 250 } }">
    <div class="flex items-center gap-3 mb-3"><span class="icon-dot"><span class="i-carbon-terminal" /></span><h3 class="!m-0 !text-lg">Bearer JWT</h3></div>
    <table class="tbl">
      <tbody>
      <tr><td class="muted">Who uses it</td><td>A script, CLI or service</td></tr>
      <tr><td class="muted">Sent as</td><td><code>Authorization: Bearer eyJ…</code></td></tr>
      <tr><td class="muted">Readable?</td><td>Yes, anyone can decode it</td></tr>
      <tr><td class="muted">Checked by</td><td>Istio RequestAuthentication</td></tr>
      <tr><td class="muted">Our host</td><td><code>api.localhost</code></td></tr>
      </tbody>
    </table>
  </div>
</div>

<div class="flex gap-6 mt-5 text-sm">
  <div v-click><span class="chip">Scope</span> what the client asked for</div>
  <div v-click><span class="chip orange">Claim</span> a fact written in the token</div>
  <div v-click><span class="chip red">Role</span> what the user is allowed</div>
</div>

---

<div class="kicker">Authorization code flow · first, a story</div>

# Getting into a concert with a wristband

<div class="grid grid-cols-4 gap-3 mt-6 relative">
  <div v-for="(s, i) in [
      { t: 'At the door', d: 'The bouncer asks the wristband desk. No wristband? Go to the ticket office.', w: 'Istio + OAuth2-Proxy' },
      { t: 'Ticket office', d: 'You show your ID. You get a one-time voucher, not the ticket itself.', w: 'Keycloak + code' },
      { t: 'Wristband desk', d: 'Staff swap the voucher for the ticket on a private phone, and lock it away.', w: 'Back channel + tokens' },
      { t: 'Back at the door', d: 'You wear a wristband. The bouncer sees it and lets you in, every time.', w: 'Session cookie' },
    ]" :key="s.t" v-click class="card !p-4">
    <div class="w-8 h-8 rounded-full bg-[var(--navy)] text-white font-bold flex items-center justify-center mb-3">{{ i + 1 }}</div>
    <h3>{{ s.t }}</h3>
    <p>{{ s.d }}</p>
    <div class="mono text-xs text-[var(--orange)] mt-3">{{ s.w }}</div>
  </div>
</div>

<p v-click class="remember"><b>The trick:</b> you never hold the real ticket. You carry a voucher once, and a wristband after that.</p>

---

<div class="kicker">Authorization code flow · the big picture</div>

# 13 messages, 5 actors, 1 login

<div class="text-xs mb-1 flex gap-4 mono">
  <span class="text-[var(--blue)]">● via the browser</span>
  <span class="text-[var(--orange)]">● back channel</span>
  <span class="text-[var(--muted)]">● inside the mesh</span>
</div>

<SeqFlow mode="overview" />

---
clicks: 13
---

<div class="kicker">Authorization code flow · step by step</div>

# Follow Alice’s first request

<SeqFlow mode="steps" />

---

<div class="kicker">Authorization code flow · recap</div>

# What the browser saw, and what it never saw

<div class="grid grid-cols-2 gap-5 mt-4">
  <div class="card !p-5" v-motion :initial="{ opacity: 0, x: -30 }" :enter="{ opacity: 1, x: 0 }">
    <div class="flex items-center gap-2 mb-2"><span class="icon-dot"><span class="i-carbon-view" /></span><h3 class="!m-0">Front channel · seen</h3></div>
    <p>Redirects (302) and the login page<br>A one-time code and a state value<br>An encrypted session cookie</p>
  </div>
  <div class="card !p-5" v-motion :initial="{ opacity: 0, x: 30 }" :enter="{ opacity: 1, x: 0, transition: { delay: 200 } }">
    <div class="flex items-center gap-2 mb-2"><span class="icon-dot orange"><span class="i-carbon-view-off" /></span><h3 class="!m-0">Back channel · never seen</h3></div>
    <p>Access, ID and refresh tokens<br>The client secret<br>Any call between pods</p>
  </div>
</div>

<div class="grid grid-cols-3 gap-4 mt-5">
  <div v-click class="card"><h3 class="kc !text-[var(--orange)]">Keycloak</h3><p>Checks the password, issues code and tokens</p></div>
  <div v-click class="card"><h3>OAuth2-Proxy</h3><p>Swaps the code, keeps the session</p></div>
  <div v-click class="card"><h3 class="!text-[var(--blue)]">Istio</h3><p>Asks at the door, re-checks at the pod</p></div>
</div>

---
clicks: 10
---

<div class="kicker">Inside the proxies · real Envoy filter order</div>

# One request, ten checkpoints

<FilterChain />

<!--
Taken from the running cluster's config_dump. Surprise: at the gateway the CUSTOM check (oauth2-proxy) runs BEFORE RequestAuthentication. And the VirtualService header rules are applied last, by the router — that is why removing the cookie on the route does not hide it from oauth2-proxy.
-->

---
clicks: 6
---

<div class="kicker">Inside the proxies · same checkpoints, different requests</div>

# Six requests, six outcomes

<RequestLanes />

---

<div class="kicker">The Istio pair you must use together</div>

# One checks the ID, the other checks the list

<div class="grid grid-cols-2 gap-4 mt-3">
  <div class="card" v-motion :initial="{ opacity: 0, y: 20 }" :enter="{ opacity: 1, y: 0 }"><h3>RequestAuthentication</h3><p>“Is this token real?” Rejects bad tokens. <b>Lets no-token requests pass.</b></p></div>
  <div class="card" v-motion :initial="{ opacity: 0, y: 20 }" :enter="{ opacity: 1, y: 0, transition: { delay: 200 } }"><h3>AuthorizationPolicy</h3><p>“Is this caller allowed here?” requestPrincipals, roles, paths.</p></div>
</div>

<div class="tbl-card mt-4">
<table class="tbl">
  <thead><tr><th>Request to api.localhost</th><th>RequestAuthn</th><th>AuthorizationPolicy</th><th>Result</th></tr></thead>
  <tbody>
    <tr v-click><td class="strong">No token</td><td>Nothing to check</td><td>No principal: deny</td><td class="code-403">403</td></tr>
    <tr v-click><td class="strong">Forged or expired token</td><td>Rejected</td><td class="faint">Not reached</td><td class="code-401">401</td></tr>
    <tr v-click><td class="strong">alice → /api/user</td><td>Valid</td><td>Role user: allow</td><td class="code-200">200</td></tr>
    <tr v-click><td class="strong">alice → /api/admin</td><td>Valid</td><td>No admin role: deny</td><td class="code-403">403</td></tr>
  </tbody>
</table>
</div>

---
class: navy
---

<div class="kicker">The POC story</div>

# Three doors, one identity

<div class="flex flex-col gap-3 mt-5">
  <div v-for="(d, i) in [
      { door: 'Door 1 · app.localhost', who: 'Person in a browser', via: 'Ingress: CUSTOM policy', how: 'OAuth2-Proxy session cookie' },
      { door: 'Door 2 · api.localhost', who: 'Script with a JWT', via: 'Ingress and sidecar', how: 'RequestAuthn + role-based policy' },
      { door: 'Door 3 · in-cluster', who: 'Pod service-a', via: 'Sidecar only', how: 'mTLS identity + principal policy' },
    ]" :key="d.door" v-click class="flex items-center gap-3">
    <div class="card !py-2 w-56 flex-none"><div class="mono text-[0.62rem] text-[var(--sky)]">{{ d.door }}</div><h3 class="!m-0 !text-sm">{{ d.who }}</h3></div>
    <div class="arrow-run text-[var(--sky)]">➜</div>
    <div class="card !py-2 flex-1"><div class="mono text-[0.62rem] text-[#aeb7cc]">{{ d.via }}</div><h3 class="!m-0 !text-sm">{{ d.how }}</h3></div>
    <div class="arrow-run text-[var(--sky)]">➜</div>
    <div class="rounded-lg bg-[var(--amber)] text-[var(--navy)] font-bold px-6 py-3 flex-none">Spring</div>
  </div>
</div>

<p v-click class="remember muted">Users get their identity from <span class="kc">Keycloak realm poc</span>; workloads get theirs from <span class="is">Istio mTLS</span>.</p>

<style>
.arrow-run { animation: nudge 1.4s ease-in-out infinite; }
@keyframes nudge { 50% { transform: translateX(5px); opacity: 0.6; } }
</style>

---

<div class="kicker">Door 1 · app.localhost · people</div>

# Istio asks OAuth2-Proxy at every request

<div class="grid grid-cols-[1fr_1.1fr] gap-6 mt-3">
<div class="flex flex-col gap-3">
  <div v-click="1" class="card"><h3>CUSTOM policy at the ingress</h3><p>The decision is delegated to OAuth2-Proxy (Envoy ext_authz).</p></div>
  <div v-click="2" class="card"><h3>Only real browser traffic</h3><p>Skips <code>/oauth2/*</code>, <code>/api/public</code>, health checks, requests with a Bearer token, and non-Mozilla user agents.</p></div>
  <div v-click="3" class="card"><h3>Nothing leaks back</h3><p>Route rules strip <code>x-auth-request-*</code> from oauth2-proxy’s responses. No EnvoyFilter.</p></div>
  <div v-click="4" class="card"><h3>Spring never sees the session</h3><p>The cookie is removed from the request after ext_authz has used it.</p></div>
</div>

````md magic-move {at:1}
```yaml
# ingress-authorization.yaml
kind: AuthorizationPolicy
spec:
  action: CUSTOM
  provider:
    name: oauth2-proxy
  rules:
  - to:
    - operation:
        hosts: [app.localhost]
```
```yaml
# ingress-authorization.yaml
kind: AuthorizationPolicy
spec:
  action: CUSTOM
  provider:
    name: oauth2-proxy
  rules:
  - to:
    - operation:
        hosts: [app.localhost]
        notPaths: [/oauth2/*, /api/public,
                   /actuator/health]
    when:
    - key: request.headers[Authorization]
      notValues: ["Bearer *"]
    - key: request.headers[User-Agent]
      values: ["Mozilla/*"]
```
```yaml
# oauth2-proxy.yaml · VirtualService
http:
- match:
  - uri: { prefix: /oauth2/ }
  route:
  - destination: { host: oauth2-proxy.iam… }
  headers:
    response:
      remove:
      - x-auth-request-user
      - x-auth-request-email
      - x-auth-request-groups
      - x-auth-request-preferred-username
      - x-auth-request-access-token
      - authorization
```
```yaml
# oauth2-proxy.yaml · VirtualService
http:
- match:
  - uri: { prefix: /oauth2/ }
  route:
  - destination: { host: oauth2-proxy.iam… }
  headers:
    response:
      remove: [x-auth-request-*, authorization]
- route:
  - destination: { host: spring-app.demo… }
  headers:
    request:
      remove: [cookie]   # ext_authz already used it
```
````
</div>

---
clicks: 5
---

<div class="kicker">Door 1 · follow the cookie</div>

# The cookie goes to the checker, not to the app

<CookieJourney />

---
clicks: 5
---

<div class="kicker">Door 1 · how long things live</div>

# Three tokens, one session, three cookies

<LifetimeBars class="mt-2" />

---
clicks: 8
---

<div class="kicker">Door 1 · the silent refresh</div>

# Tokens die every 5 minutes, Alice doesn’t notice

<RefreshLoop />

---
clicks: 3
---

<div class="kicker">Door 1 · no password, how long?</div>

# At most 10 hours, and never 30 idle minutes

<SessionTimeline class="mt-1" />

<div class="grid grid-cols-3 gap-3 mt-3">
  <div v-click="3" class="card !p-3"><h3>Longest: 10 h</h3><p>From login, if a request reaches oauth2-proxy at least every ~30 min. <code>ssoSessionMaxLifespan</code> never resets.</p></div>
  <div v-click="3" class="card !p-3"><h3>Shortest: 30 min idle</h3><p>The refresh token and the SSO session die together. The 8 h cookie never decides.</p></div>
  <div v-click="3" class="card !p-3"><h3>Want longer?</h3><p>Raise the Remember-me timeouts, or use offline tokens (30 days idle). Longer sessions, bigger stolen-cookie window.</p></div>
</div>

---

<div class="kicker">Door 2 · api.localhost · scripts and apps</div>

# Roles in the token decide every endpoint

<div class="tbl-card mt-3">
<table class="tbl text-center">
  <thead><tr><th class="!text-left">Endpoint</th><th class="!text-left">Requires</th><th>alice<br><span class="normal-case">user · developer · premium</span></th><th>bob<br><span class="normal-case">user · premium</span></th><th>admin<br><span class="normal-case">user · admin</span></th></tr></thead>
  <tbody>
    <tr v-click><td class="strong !text-left">/api/public</td><td class="!text-left muted">nothing</td><td class="code-200">200</td><td class="code-200">200</td><td class="code-200">200</td></tr>
    <tr v-click><td class="strong !text-left">/api/user</td><td class="!text-left muted">role user</td><td class="code-200">200</td><td class="code-200">200</td><td class="code-200">200</td></tr>
    <tr v-click><td class="strong !text-left">/api/headers</td><td class="!text-left muted">role developer</td><td class="code-200">200</td><td class="code-403">403</td><td class="code-403">403</td></tr>
    <tr v-click><td class="strong !text-left">/api/admin</td><td class="!text-left muted">role admin</td><td class="code-403">403</td><td class="code-403">403</td><td class="code-200">200</td></tr>
  </tbody>
</table>
</div>

<div class="grid grid-cols-2 gap-4 mt-4">
  <div v-click class="card flex gap-3 items-center"><span class="icon-dot">1</span><div><h3>Ingress</h3><p>Valid Keycloak token, known path</p></div></div>
  <div v-click class="card flex gap-3 items-center"><span class="icon-dot orange">2</span><div><h3>Spring sidecar</h3><p>Audience <code>spring-api</code>, then the role claim</p></div></div>
</div>

<!--
alice gets developer through the /engineering group and premium through /engineering/platform; she has only "user" as a direct realm role.
-->

---

<div class="kicker">Door 3 · inside the cluster · workloads</div>

# The pod itself is the identity

<div class="grid grid-cols-[1.1fr_1fr] gap-6 mt-3">
<div>
  <div class="flex flex-col gap-3">
    <div v-click="1" class="card"><h3>PeerAuthentication: STRICT</h3><p>Plain-text calls into the demo namespace are refused. mTLS only.</p></div>
    <div v-click="2" class="card"><h3>Identity = service account</h3><p>Istio issues each pod a certificate for its service account.</p></div>
  </div>
  <div v-click="3" class="mt-4 flex flex-col gap-2">
    <div class="pod-row ok"><span class="i-carbon-certificate" /> service-a <span class="mono text-xs muted">sa/service-a</span> <span class="path" /> <span class="code-200">200</span></div>
    <div class="pod-row bad"><span class="i-carbon-certificate" /> bad-client <span class="mono text-xs muted">sa/default</span> <span class="path" /> <span class="code-403">403</span></div>
  </div>
</div>

```yaml {all|1-4|6-13}{at:1}
kind: PeerAuthentication
spec:
  mtls:
    mode: STRICT
---
kind: AuthorizationPolicy
spec:
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/service-a/sa/service-a
    to: [ /api/internal ]
```
</div>

<style>
.pod-row { display: flex; align-items: center; gap: 0.5rem; font-weight: 600; color: var(--navy); background: #fff; border: 1px solid var(--card-line); border-radius: 10px; padding: 0.45rem 0.8rem; font-size: 0.85rem; }
.pod-row .path { flex: 1; height: 2px; background: linear-gradient(90deg, var(--line) 50%, transparent 0) 0 0 / 10px 2px; animation: dash 0.8s linear infinite; }
.pod-row.ok .path { background-image: linear-gradient(90deg, var(--green) 50%, transparent 0); }
.pod-row.bad .path { background-image: linear-gradient(90deg, var(--red) 50%, transparent 0); }
@keyframes dash { to { background-position: 10px 0; } }
</style>

---

<div class="kicker">Putting it together</div>

# Six questions, six owners

<div class="tbl-card mt-3">
<table class="tbl">
  <thead><tr><th>#</th><th>Layer</th><th>Question</th><th>Answered by</th></tr></thead>
  <tbody>
    <tr v-click><td class="faint">1</td><td class="strong">User AuthN</td><td>Who is the user?</td><td>Keycloak (+ OAuth2-Proxy)</td></tr>
    <tr v-click><td class="faint">2</td><td class="strong">Token check</td><td>Is the token real and meant for us?</td><td>RequestAuthentication</td></tr>
    <tr v-click><td class="faint">3</td><td class="strong">User AuthZ</td><td>Does the user have the role?</td><td>AuthorizationPolicy</td></tr>
    <tr v-click><td class="faint">4</td><td class="strong">Workload AuthN</td><td>Which pod is calling?</td><td>PeerAuthentication (mTLS)</td></tr>
    <tr v-click><td class="faint">5</td><td class="strong">Workload AuthZ</td><td>May this pod call this path?</td><td>AuthorizationPolicy</td></tr>
    <tr v-click><td class="faint">6</td><td class="strong">Business AuthZ</td><td>Is this action allowed today?</td><td class="font-bold text-[var(--orange)]">Spring Boot</td></tr>
  </tbody>
</table>
</div>

<p v-click class="remember">The platform answers 1 to 5. <b>The application only owns row 6:</b> real business rules.</p>

---

<div class="kicker">Lessons from building the POC</div>

# Three things that bit us

<div class="grid grid-cols-3 gap-4 mt-5">
  <div v-for="(l, i) in [
      { icon: 'i-carbon-time', t: 'The JWKS race', d: 'istiod fetched Keycloak’s keys before Keycloak was up, used a placeholder key, and every JWT failed for ~20 min. Fix: restart istiod once Keycloak is ready.', chip: '401 Jwt verification fails', cls: 'red' },
      { icon: 'i-carbon-flow', t: 'Header rules are per route', d: 'The leaking x-auth-request-* headers came from the /oauth2/ route. A rule on the Spring route could never remove them.', chip: 'no EnvoyFilter needed', cls: 'green' },
      { icon: 'i-carbon-warning', t: 'ext_authz needs response headers', d: 'With upstream static://200, the token reaches Spring only as an oauth2-proxy response header. Turn that off and you get 403.', chip: 'RBAC: access denied', cls: 'red' },
    ]" :key="l.t" class="card !p-4"
    v-motion :initial="{ opacity: 0, y: 40 }" :enter="{ opacity: 1, y: 0, transition: { delay: 150 + i * 180 } }">
    <span class="icon-dot orange mb-3"><span :class="l.icon" /></span>
    <h3>{{ l.t }}</h3>
    <p>{{ l.d }}</p>
    <div class="mt-3"><span class="chip" :class="l.cls">{{ l.chip }}</span></div>
  </div>
</div>

---

<div class="kicker">Demo script · expected results first</div>

# Nine checks, one per claim

<div class="tbl-card mt-2">
<table class="tbl">
  <thead><tr><th>#</th><th>Door</th><th>Action</th><th>Expected</th></tr></thead>
  <tbody>
    <tr><td class="faint">1</td><td><span class="chip orange">Browser</span></td><td>Open app.localhost in a private window</td><td class="code-30x">Keycloak login page</td></tr>
    <tr><td class="faint">2</td><td><span class="chip orange">Browser</span></td><td>Log in as alice, open /api/whoami</td><td>Name from headers, no cookie at Spring</td></tr>
    <tr><td class="faint">3</td><td><span class="chip">API</span></td><td>curl /api/public, no token</td><td class="code-200">200</td></tr>
    <tr><td class="faint">4</td><td><span class="chip">API</span></td><td>curl /api/user, no token</td><td class="code-403">403 access denied</td></tr>
    <tr><td class="faint">5</td><td><span class="chip">API</span></td><td>curl /api/user, tampered token</td><td class="code-401">401 JWT fails</td></tr>
    <tr><td class="faint">6</td><td><span class="chip">API</span></td><td>alice token → /api/user, then /api/admin</td><td><span class="code-200">200</span>, then <span class="code-403">403</span></td></tr>
    <tr><td class="faint">7</td><td><span class="chip">API</span></td><td>admin token → /api/admin</td><td class="code-200">200</td></tr>
    <tr><td class="faint">8</td><td><span class="chip">API</span></td><td>Give bob power-user in Keycloak → /api/headers</td><td><span class="code-403">403</span>, then <span class="code-200">200</span></td></tr>
    <tr><td class="faint">9</td><td><span class="chip green">Internal</span></td><td>service-a vs bad-client → /api/internal</td><td><span class="code-200">200</span> vs <span class="code-403">403</span></td></tr>
  </tbody>
</table>
</div>

---
class: navy
---

<div class="h-full flex flex-col items-center justify-center text-center">
  <div class="kicker">Live demo</div>
  <h1 class="!text-7xl" v-motion :initial="{ scale: 0.6, opacity: 0 }" :enter="{ scale: 1, opacity: 1, transition: { type: 'spring', stiffness: 160, damping: 12 } }">Let’s prove it.</h1>
  <div class="mt-6 flex gap-3 mono text-sm">
    <span v-for="(c, i) in ['make up', 'make token-alice', 'make smoke']" :key="c" class="cmd"
      v-motion :initial="{ opacity: 0, y: 20 }" :enter="{ opacity: 1, y: 0, transition: { delay: 500 + i * 200 } }">$ {{ c }}</span>
  </div>
  <div class="pulse mt-12" />
</div>

<style>
.cmd { background: rgba(255,255,255,0.08); border: 1px solid rgba(255,255,255,0.15); padding: 0.4rem 0.8rem; border-radius: 8px; color: #e3ecfb; }
.pulse { width: 14px; height: 14px; border-radius: 999px; background: var(--amber); animation: ping 1.6s cubic-bezier(0, 0, 0.2, 1) infinite; }
@keyframes ping { 0% { box-shadow: 0 0 0 0 rgba(242,166,90,0.7); } 100% { box-shadow: 0 0 0 28px rgba(242,166,90,0); } }
</style>

---
class: navy
---

<div class="kicker">Takeaways</div>

# What to remember tomorrow

<div class="grid grid-cols-2 gap-4 mt-5">
  <div v-for="(t, i) in [
      { t: 'AuthN, then AuthZ', d: '401 = who are you? 403 = I know you, and no.' },
      { t: 'One job per component', d: 'Keycloak decides, OAuth2-Proxy remembers, Istio checks.' },
      { t: 'Always pair them', d: 'RequestAuthentication alone lets no-token requests through.' },
      { t: 'Trust nothing by location', d: 'Check at the edge, at the pod, and between pods.' },
    ]" :key="t.t" class="card !p-5"
    v-motion :initial="{ opacity: 0, scale: 0.9 }" :enter="{ opacity: 1, scale: 1, transition: { delay: 100 + i * 150 } }">
    <h3 class="!text-lg">{{ t.t }}</h3>
    <p>{{ t.d }}</p>
  </div>
</div>

<div class="mt-8 flex items-end justify-between">
  <div class="text-4xl font-bold text-white" v-click>Questions?</div>
  <div class="mono text-sm muted">github.com/codergo7/Keycloak_POC</div>
</div>

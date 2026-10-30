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
    Gokhan Ozturk · 18/11/2016 - Lunch&Learn
  </div>
</div>

<!--
I am not going to deep dive into each technology one by one. I will summarize each one and show how they handle authentication and authorization together.

As the slide opens, the small label drops in, the two title lines slide in from the left one after the other, and then the subtitle and my name fade in. No clicks needed here.

The question in the title is the whole talk: "who are you" is authentication, "what may you do" is authorization. We will answer both with three tools: Keycloak, OAuth2-Proxy and Istio.
-->

---

<div class="kicker">The road for today</div>

# From theory to a story to proof

<div class="grid grid-cols-3 gap-5 mt-6">
  <div v-click class="card !p-5">
    <div class="text-5xl font-bold text-[var(--blue)] mb-2">1</div>
    <h3>Theory</h3>
    <p>AuthN vs AuthZ<br>The POC architecture<br>The four players<br>JWTs, cookies, scopes<br>Authorization code flow</p>
  </div>
  <div v-click class="card !p-5">
    <div class="text-5xl font-bold text-[var(--orange)] mb-2">2</div>
    <h3>The story</h3>
    <p>Two doors, one identity<br>Inside the proxies<br>Door 1: sessions and headers<br>Door 2: claims decide access</p>
  </div>
  <div v-click class="card !p-5">
    <div class="text-5xl font-bold text-[var(--navy)] mb-2">3</div>
    <h3>The proof</h3>
    <p>A live demo after each door<br>Expected vs actual<br>Takeaways and Q&amp;A</p>
  </div>
</div>

<!--
This is the plan for today, in three parts.

[click] First the theory: the difference between authentication and authorization, what the proof of concept looks like, the four components, tokens and cookies, and the login flow.

[click] Then the story of our proof of concept. There are two doors into the app: one for people in a browser and one for scripts with a token. We look inside the proxies, then at each door. The browser door is about sessions and headers; the API door is about claims in the token.

[click] And the proof: a live demo on a local kind cluster right after each door, where I tell you the expected result before each step. Then the takeaways and your questions.
-->

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

<!--
The AuthN card slides in from the left as the slide opens.

Authentication answers "who are you?". You claim an identity, then you prove it, for example with a password. The result is an identity we trust, carried in a token or a session. Think of showing your passport at the airport. When it fails, the answer is 401.

[click] The AuthZ card appears. Authorization answers "what may you do?". It looks at roles and groups, at scopes, and at claims, which are the facts written in the token. At the airport this is your boarding pass and gate. When it fails, the answer is 403: I know who you are, and the answer is no.

Always in this order: we can only decide what you may do after we know who you are.
-->

---
clicks: 5
---

<div class="kicker">The POC · what runs where</div>

# One cluster, three namespaces, one way in

<ArchDiagram />

<!--
Before we go deeper, here is what we actually built, so every word later has a place on this picture. When the slide opens you only see the empty frame: one kind cluster on my laptop, with three namespaces, istio-system, iam and demo. Each click fills in one layer; the newest boxes turn dark blue and their wires flow, older wires stay faint.

[click] 1. The way in. A person in a browser and a script with curl both go to localhost:8080, which is the Istio ingress gateway. It routes three host names: keycloak.localhost, app.localhost and api.localhost. There is no other way into the cluster.

[click] 2. The iam namespace. Keycloak holds our realm, poc, with users alice, bob and admin, and stores its data in Postgres. Postgres has no volume, so a restart gives a fresh realm. The login page is served at keycloak.localhost.

[click] 3. OAuth2-Proxy, also in iam. For every request to app.localhost the gateway asks it "is this person logged in?". That is called ext_authz. When someone logs in, OAuth2-Proxy swaps the login code for tokens directly with Keycloak, inside the cluster; that is the orange back channel.

[click] 4. The demo namespace: our Spring Boot app, with an Envoy sidecar next to it. Both app.localhost and api.localhost end up here; the app has no login code at all.

[click] 5. istiod, the Istio control plane. The purple lines: it pushes routes and policies to the gateway and to Spring's sidecar, and it downloads Keycloak's public keys, the JWKS, so the proxies can check token signatures. Keep this last line in mind; it bites us later.
-->

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

<!--
Four components, four jobs. The four cards flip up one after another.

Keycloak is the identity provider: it knows the users, checks passwords and issues signed tokens.

OAuth2-Proxy handles login for browsers and keeps the session cookie.

Istio is the enforcer: it checks tokens and applies the access rules, at the edge and in front of each pod.

Spring Boot is our app. It does its real job and has no login code and no token parsing.

[click] One line to remember: Keycloak decides who you are, OAuth2-Proxy remembers you, Istio checks you.
-->

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

<!--
Six Keycloak terms, one row per click.

[click] A realm is an isolated space with its own users, roles and clients. Ours is called poc.

[click] A client is an application that asks Keycloak to log users in or for tokens. We have oauth2-proxy for browsers, cli-client for scripts, and spring-api, which is the audience our API expects.

[click] Users and groups: alice, bob and admin, and groups like engineering and admins.

[click] A realm role is a permission label. A composite role bundles other roles: power-user contains developer and premium.

[click] A client scope is a named bundle of claims a client can ask for. groups and app-audience are ours.

[click] A protocol mapper is a rule that writes a fact into the token, such as group membership or the audience.

[click] Remember this one for later: groups carry roles too. alice only has the user role directly, but gets developer from the engineering group and premium from engineering/platform.
-->

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
OAuth2-Proxy turns a login into a session cookie. Each click shows one card and highlights the matching flags on the right.

[click] It is an OpenID Connect client, registered in Keycloak as oauth2-proxy with a client secret. Highlighted: provider and client-id.

[click] It keeps the session in an encrypted cookie called _oauth2_proxy. It refreshes the tokens every 4 minutes, and the cookie expires after 8 hours. Highlighted: cookie-refresh and cookie-expire.

[click] It is the external authorizer: Istio asks it "is this request logged in?" and it says yes, or redirects to login. upstream static 200 means it only answers that question and never forwards traffic itself.

[click] It returns identity headers, the user, the email and the access token, for Istio to copy into the request. Highlighted: set-xauthrequest and pass-access-token.

Lesson learned: without those last two flags the access token never reaches Spring, because oauth2-proxy never talks to Spring itself. We found that out the hard way, with "RBAC: access denied".
-->

---

<div class="kicker">Istio · the enforcer</div>

# Four resources do all the enforcing

<div class="tbl-card mt-3">
<table class="tbl">
  <thead><tr><th>Resource</th><th>Kind of job</th><th>What it does for us</th></tr></thead>
  <tbody>
    <tr v-click><td class="strong">Gateway + VirtualService</td><td><span class="chip">Routing</span></td><td>Routes our three hosts to the right service, and adds or removes headers per route</td></tr>
    <tr v-click><td class="strong">RequestAuthentication</td><td><span class="chip orange">AuthN</span></td><td>Validates a JWT: issuer, signature, expiry, audience</td></tr>
    <tr v-click><td class="strong">AuthorizationPolicy</td><td><span class="chip red">AuthZ</span></td><td>ALLOW / DENY / CUSTOM on paths and token claims</td></tr>
    <tr v-click><td class="strong">Mesh config <code>extensionProviders</code></td><td><span class="chip green">Integration</span></td><td>Plugs OAuth2-Proxy in as the CUSTOM authorizer and lists which headers may pass</td></tr>
  </tbody>
</table>
</div>

<p v-click class="remember">Every pod gets an Envoy sidecar; the ingress gateway is an Envoy too. <b>The rules run there, not in your code.</b> No EnvoyFilter needed.</p>

<!--
Istio does all the enforcing with four kinds of resources, one row per click.

[click] Gateway and VirtualService route our three hosts to the right service, and can add or remove headers on each route.

[click] RequestAuthentication validates a JWT: who issued it, the signature, the expiry and the audience.

[click] AuthorizationPolicy decides: allow, deny, or ask an external checker, based on paths and token claims.

[click] The mesh config extensionProviders entry plugs OAuth2-Proxy in as that external checker, and lists exactly which headers may pass in each direction. We will look at those lists closely later.

[click] Every pod gets an Envoy sidecar, and the ingress gateway is an Envoy too. The rules run there, not in our code. We did not need any EnvoyFilter.
-->

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

<!--
A JWT is a signed note of facts about you: a header, a payload and a signature. The token on the left is a shortened version of alice's access token.

[click] The first card and highlight: iss, aud and azp. Who issued the token, who it is for, and which client asked for it.

[click] realm_access roles and groups: these are the claims our access rules check.

[click] exp and the signature: the token is short-lived and cannot be changed, because Istio verifies it with Keycloak's public keys, the JWKS.

[click] There are three tokens. The access token is for calling APIs. The ID token tells the login client who logged in. The refresh token is used to get new ones. Their lifetimes are in the backup slides at the end, if anyone asks.
-->

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

<!--
There are two ways to carry identity, and both cards rise in as the slide opens.

People in a browser use a session cookie. It is sent automatically, it is encrypted and HttpOnly so scripts cannot read it, and OAuth2-Proxy checks it. That is our app.localhost door.

Scripts and services use a bearer JWT in the Authorization header. Anyone can decode it, but nobody can change it, and Istio's RequestAuthentication checks it. That is our api.localhost door.

Three words people mix up, one per click:
[click] a scope is what the client asked for,
[click] a claim is a fact written in the token,
[click] and a role is what the user is allowed to do.
-->

---

<div class="kicker">Authorization code flow · the big picture</div>

# 13 messages, 5 actors, 1 login

<div class="text-xs mb-1 flex gap-4 mono">
  <span class="text-[var(--blue)]">● via the browser</span>
  <span class="text-[var(--orange)]">● back channel</span>
  <span class="text-[var(--muted)]">● inside the mesh</span>
</div>

<SeqFlow mode="overview" />

<!--
This is the real flow: 13 messages between 5 actors for one login. The messages draw themselves one after another as the slide opens; no clicks needed.

The colors matter. Blue messages go through the browser, so the user could see them. Orange messages are the back channel, server to server, which the browser never sees. Grey messages stay inside the cluster.

Notice that the tokens only travel on orange lines. The next slide walks through it step by step.
-->

---
clicks: 13
---

<div class="kicker">Authorization code flow · step by step</div>

# Follow Alice’s first request

<SeqFlow mode="steps" />

<!--
Each click draws one message. A dot travels along it, the two actors involved light up, and the panel on the right shows the actual HTTP request or response.

[click] 1. Alice opens the app with no cookie. The CUSTOM policy makes the gateway ask OAuth2-Proxy first.
[click] 2. The gateway asks "is this request logged in?". Only the cookie and authorization headers are sent. There is no session yet.
[click] 3. OAuth2-Proxy answers with a redirect to Keycloak. The URL says who is asking, what it wants and where to come back. It also sets a CSRF cookie.
[click] 4. The browser follows the redirect. Keycloak shows its own login page; our app never sees it.
[click] 5. Alice types her password. This is the only moment real authentication happens. Keycloak also sets its own single sign-on cookie.
[click] 6. Keycloak sends the browser back with a one-time code, valid for about a minute. No tokens go to the browser.
[click] 7. The code lands at OAuth2-Proxy on its callback path. OAuth2-Proxy checks that the state matches its CSRF cookie.
[click] 8. Back channel: OAuth2-Proxy sends the code and its client secret to Keycloak, server to server.
[click] 9. Keycloak returns the signed tokens: access, ID and refresh. Their audience includes spring-api.
[click] 10. OAuth2-Proxy seals the tokens into an encrypted cookie and sends Alice back to the page she asked for.
[click] 11. From now on every request carries that cookie.
[click] 12. OAuth2-Proxy decrypts it and answers 200 with identity headers. No call to Keycloak is needed.
[click] 13. The gateway removes the cookie and forwards the request with the identity headers. Spring's sidecar checks the access token again.
-->

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

<!--
What did the browser see, and what did it never see? Both cards slide in from the sides as the slide opens.

The browser saw the redirects and the login page, a one-time code and a state value, and an encrypted cookie.

The browser never saw the access, ID or refresh tokens, the client secret, or any call between pods.

Who did what, one card per click:
[click] Keycloak checked the password and issued the code and the tokens.
[click] OAuth2-Proxy swapped the code for tokens and keeps the session.
[click] Istio asks at the door, and checks again right in front of the pod.
-->

---
class: navy
---

<div class="kicker">The POC story</div>

# Two doors, one identity

<div class="flex flex-col gap-3 mt-5">
  <div v-for="(d, i) in [
      { door: 'Door 1 · app.localhost', who: 'Person in a browser', via: 'Ingress: CUSTOM policy', how: 'OAuth2-Proxy session cookie' },
      { door: 'Door 2 · api.localhost', who: 'Script with a JWT', via: 'Ingress and sidecar', how: 'RequestAuthn + role-based policy' },
    ]" :key="d.door" v-click class="flex items-center gap-3">
    <div class="card !py-2 w-56 flex-none"><div class="mono text-[0.62rem] text-[var(--sky)]">{{ d.door }}</div><h3 class="!m-0 !text-sm">{{ d.who }}</h3></div>
    <div class="arrow-run text-[var(--sky)]">➜</div>
    <div class="card !py-2 flex-1"><div class="mono text-[0.62rem] text-[#aeb7cc]">{{ d.via }}</div><h3 class="!m-0 !text-sm">{{ d.how }}</h3></div>
    <div class="arrow-run text-[var(--sky)]">➜</div>
    <div class="rounded-lg bg-[var(--amber)] text-[var(--navy)] font-bold px-6 py-3 flex-none">Spring</div>
  </div>
</div>

<p v-click class="remember muted">Both doors end in the same thing: <span class="kc">claims signed by Keycloak realm poc</span>, checked by <span class="is">Istio</span> before Spring sees the request.</p>

<style>
.arrow-run { animation: nudge 1.4s ease-in-out infinite; }
@keyframes nudge { 50% { transform: translateX(5px); opacity: 0.6; } }
</style>

<!--
Now our proof of concept. There are two doors into the same Spring app. Each click brings in one door; the small arrows keep nudging to show the direction of travel.

[click] Door 1 is app.localhost, for a person in a browser. The gateway's CUSTOM policy asks OAuth2-Proxy, and the person is recognised by the session cookie.

[click] Door 2 is api.localhost, for a script that sends a JWT. The gateway and Spring's sidecar both validate the token, and the role claims decide.

[click] Both doors end in the same thing: claims signed by our Keycloak realm, checked by Istio before Spring ever sees the request.
-->

---
clicks: 9
---

<div class="kicker">Inside the proxies · real Envoy filter order</div>

# One request, nine checkpoints

<FilterChain />

<!--
This is the real order of checks, taken from the running cluster's Envoy configuration. Each click moves the request one checkpoint forward. The current stage turns dark and lifts up, finished stages turn light blue, and the possible failure code pops up in the corner.

At the ingress gateway:
[click] 1. Gateway: is this a host we accept? If not, 404.
[click] 2. Route: the VirtualService picks the destination. Its header rules are remembered now and applied at the very end.
[click] 3. CUSTOM: for browser requests to app.localhost, ask OAuth2-Proxy. No session means a 302 to Keycloak.
[click] 4. JWT: RequestAuthentication validates a bearer token if there is one. No token is fine here; a bad token is 401.
[click] 5. ALLOW: does any rule in the gateway's AuthorizationPolicy match? If not, 403.
[click] 6. Router: apply the route's header rules, for example remove the cookie, and send the request to the pod. The pill between the two rows lights up.

At Spring's sidecar:
[click] 7. JWT again: this time the audience must be spring-api. Otherwise 401.
[click] 8. ALLOW: does the role claim match the path? Otherwise 403.
[click] 9. Spring receives the request with identity headers. No login code, no token parsing.

The surprise: at the gateway, the OAuth2-Proxy check runs before the JWT check. And the header rules run last, which is why removing the cookie on the route does not hide it from OAuth2-Proxy.
-->

---
clicks: 6
---

<div class="kicker">Inside the proxies · same checkpoints, different requests</div>

# Six requests, six outcomes

<RequestLanes />

<!--
Same checkpoints, six different requests. Each click starts one lane. A colored dot runs along the checkpoints and stops at the one that ends the request, and the result appears on the right.

[click] A browser with no session stops at the CUSTOM check: 302 to Keycloak.
[click] A browser with a session passes every check: 200. The token came from OAuth2-Proxy's X-Auth-Request-Access-Token header.
[click] curl with no token stops at the gateway's ALLOW check: 403, because there is no authenticated user.
[click] curl with a tampered token stops at the JWT check: 401.
[click] alice's valid token calling the admin endpoint gets all the way to the sidecar's ALLOW check: 403, because she has no admin role.
[click] The admin token passes everything: 200.

Notice: 401 always comes from a JWT check, and 403 always comes from an ALLOW check.
-->

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

<!--
Door 1: for app.localhost, Istio asks OAuth2-Proxy at every request. Each click adds a card on the left, and the code on the right morphs to show the matching configuration.

[click] The CUSTOM AuthorizationPolicy at the ingress hands the decision to OAuth2-Proxy for the app.localhost host.

[click] It only applies to real browser traffic. The code grows the exceptions: the /oauth2 paths, the public endpoint and health checks are skipped, as are requests that already carry a bearer token and anything that is not a Mozilla browser.

[click] Nothing leaks back. The code changes to the VirtualService for the /oauth2 route, which removes the X-Auth-Request headers from OAuth2-Proxy's replies. No EnvoyFilter needed.

[click] Spring never sees the session. The code adds the Spring route, which removes the cookie from the request after OAuth2-Proxy has already checked it.
-->

---
clicks: 5
---

<div class="kicker">Door 1 · follow the cookie</div>

# The cookie goes to the checker, not to the app

<CookieJourney />

<!--
Let's follow the cookie through one request. Each click moves the cookie chip and the header chip to the next place, and the dashed wires light up.

[click] 1. The browser sends Cookie: _oauth2_proxy to the ingress gateway. The cookie chip moves onto the gateway.
[click] 2. The gateway forwards only the cookie and authorization headers to OAuth2-Proxy. The cookie chip goes up to OAuth2-Proxy.
[click] 3. OAuth2-Proxy answers 200 with the identity headers. The blue header chip appears at the gateway, and the cookie chip comes back down.
[click] 4. The router removes the cookie, so the cookie chip is crossed out, and the identity headers move on to Spring.
[click] 5. On the way back no identity header is returned. The browser only gets a Set-Cookie when the session was refreshed.

The next slide shows every header on this trip, and the exact rule that decides each one.
-->

---
clicks: 7
---

<div class="kicker">Door 1 · sensitive headers, hop by hop</div>

# Every sensitive header meets a rule

<HeaderGates />

<!--
Every sensitive header on a browser request, hop by hop, and the rule that decides it. Each click shows one hop: the top diagram lights the wire and sends a dot along it, and below, the headers on the left run into that hop's rule. Green headers slide through to the right; red ones hit the rule, get crossed out and sink. I checked every list on this slide against the running cluster.

[click] 1. The gateway asks OAuth2-Proxy if the user is logged in. The rule is includeRequestHeadersInCheck in the mesh config: only the cookie and Authorization header go along. User-Agent, Accept and the rest stay behind.

[click] 2. OAuth2-Proxy answers 200 with five identity headers. The rule is headersToUpstreamOnAllow: only user, email and the access token are copied into the request. Groups and preferred username are thrown away.

[click] 3. At the router, the Spring route's VirtualService rule removes the cookie. OAuth2-Proxy has already used it. Spring gets identity headers, never the session.

[click] 4. At Spring's sidecar, RequestAuthentication reads the token from the X-Auth-Request-Access-Token header. The token chip gets a green ring because it is verified, not trusted blindly, and two orange chips appear: the audience check passed and the roles are now available to the AuthorizationPolicy.

[click] 5. On the way back, headersToDownstreamOnAllow only lets Set-Cookie join Spring's response, so a refreshed cookie reaches the browser. All identity headers and the token are stopped. Nothing sensitive leaves the cluster.

[click] 6. When there is no session, OAuth2-Proxy answers 302 and two wires light up: OAuth2-Proxy to gateway, then gateway to browser, and Spring is never called. headersToDownstreamOnDeny lets the Location, Set-Cookie and Content-Type headers through, which is exactly what a working redirect to Keycloak needs.

[click] 7. The leak we actually found. On the /oauth2 paths the browser talks to OAuth2-Proxy directly, and it adds identity headers to every reply, including the access token. A response rule on that route's VirtualService strips them; only the cookie gets through. That replaced the EnvoyFilter we started with.
-->

---

<div class="kicker">Live demo · Door 1 · app.localhost</div>

# Prove Door 1: four checks in the browser

<div class="tbl-card mt-3">
<table class="tbl">
  <thead><tr><th>#</th><th>Action</th><th>Expected</th></tr></thead>
  <tbody>
    <tr><td class="faint">1</td><td>Open app.localhost/api/whoami in a private window</td><td class="code-30x">302 to the Keycloak login page</td></tr>
    <tr><td class="faint">2</td><td>Log in as alice</td><td>Spring shows her name from the identity headers, and no cookie</td></tr>
    <tr><td class="faint">3</td><td>DevTools · Network · response headers of /api/whoami</td><td>No <code>X-Auth-Request-*</code>, no token</td></tr>
    <tr><td class="faint">4</td><td>Open app.localhost/oauth2/auth</td><td><span class="code-200">202</span>, identity headers stripped by the route</td></tr>
  </tbody>
</table>
</div>

<p class="remember">Spring knows <b>who</b> alice is, but never sees her session, and nothing sensitive comes back to the browser.</p>

<!--
Time to prove Door 1, while the cookie and header slides are still fresh. The cluster was started before the talk with make up. Expected results first, so you can check me. There are no animations on this slide; I switch to the browser.

1. I open /api/whoami in a private window. There is no session, so OAuth2-Proxy says no, and we land on Keycloak's login page. That is the 302 from the header slide.

2. I log in as alice. Spring shows her name and email, taken from the identity headers, and the cookie list is empty: the route removed it.

3. In DevTools I open the response headers of that request. There are no X-Auth-Request headers and no token. Only Set-Cookie may come back.

4. I open /oauth2/auth, OAuth2-Proxy's own endpoint. It answers 202, and the identity headers it adds are gone, removed by that route's VirtualService. This was the leak we found.
-->

---

<div class="kicker">Door 2 · the Istio pair you must use together</div>

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

<!--
Door 2: scripts calling api.localhost with a bearer token. Here Istio needs two resources working as a pair. The two cards rise in as the slide opens.

RequestAuthentication asks "is this token real?". It rejects bad tokens, but it lets requests without any token pass. That surprises everyone.

AuthorizationPolicy asks "is this caller allowed here?", using the authenticated user, the roles and the path.

Four requests, one row per click:
[click] No token: RequestAuthentication has nothing to check, and the policy finds no authenticated user, so 403.
[click] A forged or expired token: RequestAuthentication rejects it, so 401, and the policy is never reached.
[click] alice calling /api/user: the token is valid and she has the user role, so 200.
[click] alice calling /api/admin: the token is valid, but she has no admin role, so 403.

Use them together. RequestAuthentication alone lets everyone without a token straight through.
-->

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
Roles in the token decide every endpoint. One row per click; the columns are our three users and their roles.

[click] /api/public needs nothing: 200 for everyone.
[click] /api/user needs the user role: all three have it, so 200.
[click] /api/headers needs the developer role. alice gets 200, bob and admin get 403. alice is not a developer directly: she inherits it from the engineering group.
[click] /api/admin needs the admin role: only admin gets 200.

The check happens twice:
[click] At the ingress: is it a valid Keycloak token for a known path?
[click] At Spring's sidecar: is the audience spring-api, and does the role claim match the path?

In the demo we will give bob the power-user role in Keycloak, and /api/headers will change from 403 to 200 without touching any code.
-->

---

<div class="kicker">Live demo · Door 2 · api.localhost</div>

# Prove Door 2: six checks with curl

<div class="tbl-card mt-2">
<table class="tbl">
  <thead><tr><th>#</th><th>Action</th><th>Expected</th></tr></thead>
  <tbody>
    <tr><td class="faint">1</td><td>curl /api/public, no token</td><td class="code-200">200</td></tr>
    <tr><td class="faint">2</td><td>curl /api/user, no token</td><td class="code-403">403 access denied</td></tr>
    <tr><td class="faint">3</td><td>curl /api/user, tampered token</td><td class="code-401">401 JWT fails</td></tr>
    <tr><td class="faint">4</td><td>alice token → /api/user, then /api/admin</td><td><span class="code-200">200</span>, then <span class="code-403">403</span></td></tr>
    <tr><td class="faint">5</td><td>admin token → /api/admin</td><td class="code-200">200</td></tr>
    <tr><td class="faint">6</td><td>Give bob power-user in Keycloak → /api/headers</td><td><span class="code-403">403</span>, then <span class="code-200">200</span></td></tr>
  </tbody>
</table>
</div>

<div class="mt-4 flex gap-3 mono text-sm">
  <span v-for="c in ['make token-alice', 'make token-admin', 'make smoke']" :key="c" class="cmd">$ {{ c }}</span>
</div>

<style>
.cmd { background: var(--navy); padding: 0.35rem 0.75rem; border-radius: 8px; color: #e3ecfb; }
</style>

<!--
Now Door 2, right after the claims slides. Expected results first again. There are no animations on this slide; I switch to the terminal. The commands at the bottom are the ones I use: make token-alice and make token-admin print a token, and make smoke runs every check at once if we are short on time.

1. The public endpoint without a token: 200.

2. /api/user without a token: 403. RequestAuthentication had nothing to check, and the policy found no authenticated user.

3. A tampered token: 401. RequestAuthentication rejects it before any policy runs.

4. alice's token: 200 on /api/user, 403 on /api/admin, because she has no admin role.

5. The admin token on /api/admin: 200.

6. Last, I give bob the power-user role in Keycloak, get a new token, and /api/headers changes from 403 to 200. Only a claim changed, no code and no redeploy.
-->

---

<div class="kicker">Putting it together</div>

# Four questions, four owners

<div class="tbl-card mt-3">
<table class="tbl">
  <thead><tr><th>#</th><th>Layer</th><th>Question</th><th>Answered by</th></tr></thead>
  <tbody>
    <tr v-click><td class="faint">1</td><td class="strong">User AuthN</td><td>Who is the user?</td><td>Keycloak (+ OAuth2-Proxy)</td></tr>
    <tr v-click><td class="faint">2</td><td class="strong">Token check</td><td>Is the token real and meant for us?</td><td>RequestAuthentication</td></tr>
    <tr v-click><td class="faint">3</td><td class="strong">User AuthZ</td><td>Do the token’s claims allow this path?</td><td>AuthorizationPolicy</td></tr>
    <tr v-click><td class="faint">4</td><td class="strong">Business AuthZ</td><td>Is this action allowed today?</td><td class="font-bold text-[var(--orange)]">Spring Boot</td></tr>
  </tbody>
</table>
</div>

<p v-click class="remember">The platform answers 1 to 3. <b>The application only owns row 4:</b> real business rules.</p>

<!--
Putting it together: four questions, and who answers each one. One row per click.

[click] Who is the user? Keycloak, with OAuth2-Proxy for browsers.
[click] Is the token real and meant for us? RequestAuthentication.
[click] Do the token's claims allow this path? AuthorizationPolicy.
[click] Is this action allowed today, for example within a spending limit? That is business logic, so Spring Boot.

[click] The platform answers the first three. The application only owns the last one: the real business rules.
-->

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

<!--
Three things that bit us while building this. The three cards rise in one after another.

The JWKS race. istiod downloads Keycloak's public keys when the policy is applied. If Keycloak is not up yet, it uses a placeholder key and does not try again for about 20 minutes, so every token fails with 401. The fix is to restart istiod once Keycloak is ready; our Makefile does that now.

Header rules are per route. The leaking X-Auth-Request headers came from OAuth2-Proxy's own /oauth2 route. A rule on the Spring route could never remove them. Putting the rule on the right route meant we needed no EnvoyFilter.

ext_authz needs the response headers. Because OAuth2-Proxy only answers the auth question and never forwards traffic, the token reaches Spring only as one of its answer headers. Turn those flags off and every browser request gets 403.
-->

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
      { t: 'Claims, not code', d: 'Roles in the token decide access, checked at the gateway and again at the pod.' },
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

<!--
Four things to remember tomorrow. The four cards grow in one after another.

AuthN, then AuthZ: 401 means "who are you?", 403 means "I know you, and no".

One job per component: Keycloak decides, OAuth2-Proxy remembers, Istio checks.

Always pair them: RequestAuthentication alone lets requests without a token through.

Claims, not code: roles in the token decide access, and they are checked at the gateway and again in front of the pod.

[click] And that's it. Questions?
-->

---
class: navy
---

<div class="h-full flex flex-col justify-center">
  <div class="kicker">Backup</div>
  <h1 class="!text-5xl">How long can alice stay logged in?</h1>
  <p class="text-lg muted max-w-2xl mt-4">Token, session and cookie lifetimes, the silent refresh, and a working day on a timeline. For questions after the talk.</p>
</div>

<!--
Backup slides. I only show these if someone asks how long a login lasts, or how the tokens get refreshed without the user noticing.
-->

---
clicks: 5
---

<div class="kicker">Backup · how long things live</div>

# Three tokens, one session, three cookies

<LifetimeBars class="mt-2" />

<!--
How long does each thing live? The bars grow on a time axis from 1 minute to 24 hours. The axis is logarithmic so that 5 minutes and 10 hours fit on one slide.

[click] The tokens, which all live inside the cookie. The access token and the ID token live 5 minutes. The refresh token lives 30 minutes. The little spinning arrow means its time restarts every time it is used.

[click] Keycloak's own session, kept on the server. It has two clocks. The idle clock is 30 minutes and restarts on every refresh. The maximum is 10 hours, counted from the login, and it never restarts.

[click] The cookies in the browser. Our _oauth2_proxy cookie lasts 8 hours and is issued again on every refresh. KEYCLOAK_IDENTITY lasts 10 hours, but only when the user ticks "Remember me"; otherwise it disappears when the browser closes. KEYCLOAK_REMEMBER_ME lives a year, but it only fills in the username.

[click] The green line: OAuth2-Proxy refreshes the tokens once the cookie is older than 4 minutes, before the 5-minute access token can expire.

[click] The red pulsing line: the 10-hour hard stop. Nothing on this slide can go past it.

All these numbers are Keycloak's defaults plus our two OAuth2-Proxy flags.
-->

---
clicks: 8
---

<div class="kicker">Backup · the silent refresh</div>

# Tokens die every 5 minutes, Alice doesn’t notice

<RefreshLoop />

<!--
Tokens die every 5 minutes, yet Alice doesn't notice. Here is why. Each click draws one message with a moving dot, like the login flow, and the panel shows the real request.

[click] 1. Alice clicks something more than 4 minutes after the last refresh. The browser sends the same request with the same cookie.

[click] 2. A small green loop: OAuth2-Proxy checks the cookie's age. Under 4 minutes it answers from the cookie alone, even if Keycloak has already ended the session, so a logout can take up to 4 minutes to bite. Older than that, it refreshes first.

[click] 3. Back channel: OAuth2-Proxy sends the refresh token and its client secret to Keycloak. The browser never sees this.

[click] 4. A green badge appears at Keycloak: the session is alive, idle under 30 minutes and younger than 10 hours. Keycloak resets the idle clock and returns three fresh tokens.

[click] 5. OAuth2-Proxy seals them into a new cookie with a new 8-hour lifetime, and the request continues to Spring. Alice saw nothing.

Now the same request after a 45-minute lunch.

[click] 6. The last two answers fade out and are replaced in red. The badge turns red: Keycloak dropped the session after 30 idle minutes, so it refuses the refresh token with invalid_grant.

[click] 7. OAuth2-Proxy deletes its cookie and redirects to Keycloak, the same 302 as the very first visit.

[click] 8. Keycloak's own cookie points to the same dead session, so there is no silent single sign-on. Alice has to type her password again.

We tested both paths on the live cluster.
-->

---
clicks: 3
---

<div class="kicker">Backup · no password, how long?</div>

# At most 10 hours, and never 30 idle minutes

<SessionTimeline class="mt-1" />

<div class="grid grid-cols-3 gap-3 mt-3">
  <div v-click="3" class="card !p-3"><h3>Longest: 10 h</h3><p>From login, if a request reaches oauth2-proxy at least every ~30 min. <code>ssoSessionMaxLifespan</code> never resets.</p></div>
  <div v-click="3" class="card !p-3"><h3>Shortest: 30 min idle</h3><p>The refresh token and the SSO session die together. The 8 h cookie never decides.</p></div>
  <div v-click="3" class="card !p-3"><h3>Want longer?</h3><p>Raise the Remember-me timeouts, or use offline tokens (30 days idle). Longer sessions, bigger stolen-cookie window.</p></div>
</div>

<!--
So how long can Alice stay logged in without typing her password? Each scenario plays as an animation: a dark playhead runs across a 12-hour day, blue dots are her requests, the orange bar is Keycloak's 30-minute idle window, the light orange bar is the 8-hour cookie, and the striped bar is the 10-hour clock.

[click] Scenario 1: Alice keeps working and clicks every 20 minutes. Every click refreshes, so the idle window and the cookie keep moving along with her and never run out. But the striped 10-hour clock never resets. At 10 hours the playhead hits the red line and she gets the login form.

[click] Scenario 2: Alice takes a 45-minute lunch at 3 hours. Her last refresh was at 3:00, so the idle window stops there and turns red at 3:30: Keycloak dropped the session. The cookie is still valid until 11 hours, but it cannot be refreshed any more. Her first click after lunch, at 3:45, shows the login form.

[click] The three cards sum it up. The longest is 10 hours, if she makes a request at least every 30 minutes. The shortest is 30 idle minutes; the 8-hour cookie never decides. If you want longer, raise the Remember-me timeouts or use offline tokens, but a longer session also means a stolen cookie works for longer.
-->

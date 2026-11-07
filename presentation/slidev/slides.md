---
theme: default
title: Keycloak, OAuth2-Proxy & Istio
info: |
  Claims-based Authorization
  Using Keycloak, OAuth2-Proxy and Istio on Kubernetes
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
    <span class="inline-block" v-motion :initial="{ opacity: 0, x: -40 }" :enter="{ opacity: 1, x: 0, transition: { delay: 150 } }">Claims-based Authorization</span><br>
  </h1>

  <p class="text-lg max-w-2xl muted" v-motion :initial="{ opacity: 0 }" :enter="{ opacity: 1, transition: { delay: 900 } }">
    Using <span class="kc">Keycloak</span>, <span class="op">OAuth2-Proxy</span>
    and <span class="is">Istio on Kubernetes</span>: the theory, the story, then a live demo
  </p>

  <div class="mt-14 text-sm muted" v-motion :initial="{ opacity: 0 }" :enter="{ opacity: 1, transition: { delay: 1200 } }">
    Gokhan Ozturk · 18/11/2016 - Lunch&Learn - Klarrio
  </div>
</div>

<!--
Welcome to the presenation about Claims-based Authorizatoon using Keyclaok, Oauth2Proxy and Istio

I am not going to deep dive into each technology. I will summarize each one and show how they handle authentication and authorization together.

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
The talk has three parts.

[click] First is the theory, from authentication and authorization to tokens and the login flow.

[click] Then we look at the two doors into our application: one for people in a browser and one for scripts that send a token.

[click] Finally the proof, with a live demo after each door.
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
Authentication answers the question "who are you?". You claim an identity and then prove it, for example with a password. When authentication fails, the answer is 401.

[click] Authorization answers the next question, "what may you do?". The decision is based on roles, scopes and claims, and claims are simply the facts written in the token. When authorization fails, the answer is 403, which means we know who you are but you are not allowed to do this.

The order never changes, because we cannot decide what you may do until we know who you are.
-->

---
clicks: 5
---

<div class="kicker">The POC · what runs where</div>

# One cluster, three namespaces, one way in

<ArchDiagram />

<!--
This is what I built: one kind cluster on my laptop, with three namespaces.

[click] Browsers and scripts both enter through the Istio ingress gateway on localhost port 8080. The gateway routes three host names, and there is no other way into the cluster.

[click] The iam namespace contains Keycloak, which holds our realm, called poc, and its users. Keycloak stores its data in Postgres.

[click] OAuth2-Proxy runs in the same namespace. The gateway asks it whether a browser request to app.localhost is logged in, and this check is called ext_authz. During login, OAuth2-Proxy also talks directly to Keycloak over a private connection that we call the back channel.

[click] The demo namespace contains our Spring Boot application with an Envoy sidecar next to it. Both the app host and the api host end up here.

[click] Finally, istiod is the Istio control plane. It sends routes and policies to the gateway and to the sidecar, and it fetches Keycloak's public keys so that the proxies can verify tokens.
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
Each of the four components has one job. Keycloak knows the users, checks their passwords and issues signed tokens. OAuth2-Proxy handles the login for browsers and keeps the session in a cookie. Istio verifies tokens and enforces the access rules. Spring Boot does the business work and contains no login code.

[click] You can remember it in one sentence: Keycloak decides who you are, OAuth2-Proxy remembers you, and Istio checks you.
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
These are the Keycloak terms that I will use during the talk.

[click] A realm is an isolated space with its own users, roles and clients. Ours is called poc.

[click] A client is an application that asks Keycloak to log users in or to issue tokens. We use oauth2-proxy for browsers and cli-client for scripts, and spring-api is the audience that our API expects.

[click] Our users are alice, bob and admin, and they belong to groups such as engineering.

[click] A realm role is a permission label. A composite role bundles other roles, so our power-user role contains developer and premium.

[click] A client scope is a named set of claims that a client can request.

[click] A protocol mapper is a rule that writes a fact into the token.

[click] Groups can also carry roles, which is how alice gets the developer role from the engineering group.
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
OAuth2-Proxy turns a login into a session cookie, and it has four responsibilities.

[click] First, it is an OpenID Connect client that is registered in Keycloak.

[click] Second, it keeps the session in an encrypted cookie. It refreshes the tokens once the cookie is older than 4 minutes.

[click] Third, it is the external authorizer. Istio asks it whether a request is logged in, and it either says yes or redirects the user to the login page. It never forwards traffic itself.

[click] Fourth, it returns identity headers, including the access token, and Istio copies them into the request. This is the only way the token reaches Spring, so without these flags every browser request ends in a 403.
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
Istio enforces everything with four kinds of resources.

[click] Gateway and VirtualService route our hosts to the right service, and they can add or remove headers on each route.

[click] RequestAuthentication validates a JWT by checking its issuer, signature, expiry and audience.

[click] AuthorizationPolicy makes the decision. It can allow a request, deny it, or ask an external checker.

[click] The mesh configuration registers OAuth2-Proxy as that external checker, and it lists exactly which headers may pass in each direction.

[click] All of these rules run in Envoy, both at the gateway and in each sidecar. None of them run in our application code.
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
A JWT has three parts: a header, a payload and a signature. This is a shortened version of alice's access token.

[click] The iss, aud and azp claims tell us who issued the token, who it is for, and which client asked for it.

[click] The roles and groups are the claims that our access rules check.

[click] The exp claim makes the token short-lived, and the signature means nobody can change it, because Istio verifies it with Keycloak's public keys.

[click] A login actually produces three tokens. The access token is used to call APIs, the ID token says who logged in, and the refresh token is used to get new tokens.
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
There are two ways to carry identity, and each one belongs to one door.

People in a browser use a session cookie, which is encrypted and checked by OAuth2-Proxy. That is how app.localhost works.

Scripts send a bearer JWT in the Authorization header. Anyone can decode this token, but nobody can change it, and Istio verifies it. That is how api.localhost works.

Three words are often confused, so let me separate them.
[click] A scope is what the client asked for.
[click] A claim is a fact written in the token.
[click] A role is what the user is allowed to do.
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
This is the real login flow, which takes 13 messages between 5 actors.

The colors show who can see each message. Blue messages go through the browser, orange messages go directly from server to server, and grey messages stay inside the cluster.

Notice that the tokens only travel on the orange lines, so the browser never receives them. Let's go through it step by step.
-->

---
clicks: 13
---

<div class="kicker">Authorization code flow · step by step</div>

# Follow Alice’s first request

<SeqFlow mode="steps" />

<!--
[click] 1. Alice opens the application, and her browser has no cookie yet.
[click] 2. The gateway asks OAuth2-Proxy whether this request is logged in, and there is no session.
[click] 3. OAuth2-Proxy redirects the browser to Keycloak and sets a CSRF cookie.
[click] 4. Keycloak shows its own login page, so our application never sees the password.
[click] 5. Alice types her password. This is the only moment when she really authenticates.
[click] 6. Keycloak sends the browser back with a one-time code. It does not send any tokens to the browser.
[click] 7. The code arrives at OAuth2-Proxy, which checks that the state value matches its CSRF cookie.
[click] 8. OAuth2-Proxy then sends the code and its client secret directly to Keycloak, server to server.
[click] 9. Keycloak answers with the access token, the ID token and the refresh token.
[click] 10. OAuth2-Proxy seals the tokens into an encrypted cookie and redirects Alice back.
[click] 11. From now on, every request from Alice carries this cookie.
[click] 12. OAuth2-Proxy decrypts the cookie and answers 200 with the identity headers, without calling Keycloak.
[click] 13. The gateway removes the cookie and forwards the request with the identity headers, and Spring's sidecar checks the access token again.
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
Let's summarize what the browser saw. It saw the redirects, the login page, a one-time code and an encrypted cookie. It never saw the tokens, the client secret, or any call between the pods.

[click] Keycloak checked the password and issued the tokens.
[click] OAuth2-Proxy exchanged the code for the tokens and now keeps the session.
[click] Istio checks the request at the gateway and again right in front of the pod.
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
Now let's look at our proof of concept, which has two doors into the same application.

[click] Door 1 is app.localhost, for a person in a browser. OAuth2-Proxy recognizes the person by the session cookie.

[click] Door 2 is api.localhost, for a script that sends a JWT. The gateway and Spring's sidecar both validate the token, and the role claims decide what the caller may do.

[click] Both doors lead to the same result: claims signed by Keycloak and checked by Istio before Spring sees the request.
-->

---
clicks: 9
---

<div class="kicker">Inside the proxies · real Envoy filter order</div>

# One request, nine checkpoints

<FilterChain />

<!--
This is the real order of the checks, which I took from the running Envoy configuration. The first six happen at the ingress gateway.

[click] 1. The gateway checks whether it accepts this host, and if not, it returns 404.
[click] 2. The VirtualService picks the destination. Its header rules are applied at the end.
[click] 3. For browser requests, the CUSTOM policy asks OAuth2-Proxy, and without a session the user is redirected to Keycloak with a 302.
[click] 4. RequestAuthentication checks the bearer token if there is one. A bad token gets a 401, but a request with no token can continue.
[click] 5. The ALLOW policy looks for a matching rule, and if there is none, the answer is 403.
[click] 6. The router applies the header rules, for example removing the cookie, and sends the request to the pod.

Now the request arrives at Spring's sidecar.
[click] 7. The JWT is validated again, and this time the audience must be spring-api, otherwise the answer is 401.
[click] 8. The ALLOW policy checks whether the role claim matches the path, otherwise the answer is 403.
[click] 9. Finally, Spring receives the request with the identity headers.

Remember that OAuth2-Proxy runs before the JWT check, and that the header rules run last.
-->

---
clicks: 6
---

<div class="kicker">Inside the proxies · same checkpoints, different requests</div>

# Six requests, six outcomes

<RequestLanes />

<div class="mt-3 flex gap-6 text-sm">
  <span><b class="code-30x">302</b> go log in</span>
  <span><b class="code-401">401</b> bad token · a JWT check</span>
  <span><b class="code-403">403</b> not allowed · an ALLOW check</span>
  <span><b class="code-200">200</b> OK</span>
</div>

<!--
Now we send six different requests through the same checkpoints and see where each one stops.

[click] A browser with no session stops at the CUSTOM check and gets a 302 to Keycloak.
[click] A browser with a session passes every check and gets a 200.
[click] A curl request with no token stops at the gateway's ALLOW check and gets a 403.
[click] A curl request with a tampered token stops at the JWT check and gets a 401.
[click] alice's valid token on the admin endpoint reaches the sidecar's ALLOW check and gets a 403, because she has no admin role.
[click] The admin token passes every check and gets a 200.

The legend at the bottom sums up the codes. A 302 sends you to log in, and a 200 means OK. A 401 means the token is bad, and it always comes from a JWT check. A 403 means you are not allowed, and it always comes from an ALLOW check.
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
Let's start with Door 1. For app.localhost, Istio asks OAuth2-Proxy on every request.

[click] A CUSTOM AuthorizationPolicy at the ingress hands this decision to OAuth2-Proxy.

[click] The policy only applies to real browser traffic. It skips the /oauth2 paths, the public endpoint and the health check, and it also skips requests that carry a bearer token or that do not come from a browser.

[click] This VirtualService is for the /oauth2 route. It removes the identity headers from OAuth2-Proxy's replies, so they do not leak back to the browser.

[click] The Spring route removes the cookie after OAuth2-Proxy has checked it, so Spring never sees the session.
-->

---
clicks: 7
---

<div class="kicker">Door 1 · sensitive headers, hop by hop</div>

# Every sensitive header meets a rule

<HeaderGates />

<!--
Now let's follow one browser request and look at every sensitive header on the way, and the rule that decides what happens to it. Green headers pass, and red headers are stopped.

[click] 1. When the gateway asks OAuth2-Proxy, the includeRequestHeadersInCheck rule sends only the cookie and the Authorization header.

[click] 2. OAuth2-Proxy answers with five identity headers, and the headersToUpstreamOnAllow rule copies only the user, the email and the access token into the request.

[click] 3. At the router, the Spring route removes the cookie, because OAuth2-Proxy has already used it.

[click] 4. At the sidecar, RequestAuthentication verifies the token from the header, and its roles then become available to the AuthorizationPolicy.

[click] 5. On the way back, the headersToDownstreamOnAllow rule lets only Set-Cookie through, so the identity headers stay inside the cluster.

[click] 6. When there is no session, the headersToDownstreamOnDeny rule lets through only what the redirect needs: Location, Set-Cookie and Content-Type.

[click] 7. This is the leak we actually found. On the /oauth2 paths, OAuth2-Proxy adds the identity headers to its replies, including the access token, so a response rule on that route removes them.
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
Now I will prove Door 1 in the browser, and I will tell you the expected result before each step.

1. I open /api/whoami in a private window. There is no session, so I should land on the Keycloak login page.

2. I log in as alice. Spring should show her name from the identity headers, and it should not receive any cookie.

3. In DevTools I open the response headers of that request. There should be no X-Auth-Request headers and no token.

4. I open /oauth2/auth, which is OAuth2-Proxy's own endpoint. It should answer 202, and the identity headers should be gone.
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
Now let's move to Door 2, where scripts call api.localhost with a bearer token. Here two Istio resources must work as a pair.

RequestAuthentication asks whether the token is real. It rejects bad tokens, but it lets a request with no token pass.

AuthorizationPolicy asks whether this caller is allowed to make this request.

[click] With no token, the policy finds no authenticated user, so the answer is 403.
[click] With a forged or expired token, RequestAuthentication answers 401, and the policy is never reached.
[click] When alice calls /api/user, her token is valid and she has the user role, so the answer is 200.
[click] When alice calls /api/admin, her token is valid but she has no admin role, so the answer is 403.

That is why you must always use the two resources together.
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
The roles in the token decide access to each endpoint.

[click] /api/public needs no role, so everyone gets a 200.
[click] /api/user needs the user role, and all three users have it.
[click] /api/headers needs the developer role, so only alice gets a 200, and she has this role through her engineering group.
[click] /api/admin needs the admin role, so only the admin user gets a 200.

These rules are checked in two places.
[click] The ingress gateway requires a valid Keycloak token for a known path.
[click] Spring's sidecar requires the audience spring-api and the right role for the path.
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
Now I will prove Door 2 in the terminal, again with the expected results first. If we are short on time, I will run make smoke, which runs the automated checks.

1. I call /api/public without a token, and I expect a 200.

2. I call /api/user without a token, and I expect a 403.

3. I call /api/user with a tampered token, and I expect a 401.

4. I call with alice's token. I expect a 200 on /api/user and a 403 on /api/admin.

5. I call /api/admin with the admin token, and I expect a 200.

6. Finally, I give bob the power-user role in Keycloak and get a new token. His call to /api/headers should change from 403 to 200. Only a claim changed, with no code change and no redeploy.
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
To put it all together, there are four questions, and each one has an owner.

[click] Who is the user? Keycloak answers this, with help from OAuth2-Proxy for browsers.
[click] Is the token real and meant for us? RequestAuthentication answers this.
[click] Do the token's claims allow this path? AuthorizationPolicy answers this.
[click] Is this action allowed today? This is a business rule, so Spring Boot answers it.

[click] The platform answers the first three questions, and the application only owns the business rules.
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
We ran into three problems while building this.

The first is the JWKS race. If Keycloak is not ready when istiod fetches its public keys, istiod uses a placeholder key for about 20 minutes, and every token fails with a 401. The fix is to restart istiod once Keycloak is ready.

The second is that header rules belong to a single route. The leaking headers came from the /oauth2 route, so a rule on the Spring route could never remove them.

The third is that the token reaches Spring only as a header in OAuth2-Proxy's answer. If you turn off those response headers, every browser request gets a 403.
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
Here are four things to remember from this talk.

A 401 means we do not know who you are, and a 403 means we know you but the answer is no.

Keycloak decides who you are, OAuth2-Proxy remembers you, and Istio checks you.

Always pair RequestAuthentication with an AuthorizationPolicy, because otherwise requests with no token get through.

Roles in the token decide access, so we can change access without changing code.

[click] That is all from me. Do you have any questions?
-->

---
class: navy
---

<div class="h-full flex flex-col justify-center">
  <div class="kicker">Backup</div>
  <h1 class="!text-5xl">How long can alice stay logged in?</h1>
  <p class="text-lg muted max-w-2xl mt-4">Token, session and cookie lifetimes, the silent refresh, a working day on a timeline, and the cookie's trip through one request. For questions after the talk.</p>
</div>

<!--
These are backup slides. I only show them if someone asks how long a login lasts, or where the session cookie goes.
-->

---
clicks: 5
---

<div class="kicker">Backup · how long things live</div>

# Three tokens, one session, three cookies

<LifetimeBars class="mt-2" />

<!--
This slide shows how long each thing lives. The time axis is logarithmic, so that 5 minutes and 10 hours fit on one slide.

[click] The access token and the ID token live for 5 minutes. The refresh token lives for 30 minutes, and its time restarts each time it is used.

[click] The Keycloak session has two limits. It ends after 30 idle minutes, and it always ends 10 hours after login.

[click] Our _oauth2_proxy cookie lasts 8 hours and is issued again on each refresh. KEYCLOAK_IDENTITY lasts 10 hours with Remember me, and otherwise it disappears when the browser closes. KEYCLOAK_REMEMBER_ME lasts a year, but it only fills in the username.

[click] The green line shows that OAuth2-Proxy refreshes the tokens once the cookie is older than 4 minutes, which is before the 5-minute access token expires.

[click] The red line is the 10-hour limit, and nothing on this slide can go past it.
-->

---
clicks: 8
---

<div class="kicker">Backup · the silent refresh</div>

# Tokens die every 5 minutes, Alice doesn’t notice

<RefreshLoop />

<!--
The tokens expire every 5 minutes, yet Alice notices nothing. This is how that works.

[click] 1. Alice clicks something more than 4 minutes after the last refresh.
[click] 2. OAuth2-Proxy checks the age of the cookie. If it is younger than 4 minutes, OAuth2-Proxy answers from the cookie alone, so a logout can take up to 4 minutes to take effect. Here it is older, so OAuth2-Proxy refreshes first.
[click] 3. OAuth2-Proxy sends the refresh token to Keycloak on the back channel, so the browser never sees it.
[click] 4. The session is still alive, so Keycloak resets the idle clock and returns fresh tokens.
[click] 5. OAuth2-Proxy issues a new cookie and the request continues to Spring, so Alice notices nothing.

Now let's look at the same request after 45 idle minutes.
[click] 6. Keycloak ended the session after 30 idle minutes, so it refuses the refresh token with invalid_grant.
[click] 7. OAuth2-Proxy deletes its cookie and redirects the browser to Keycloak.
[click] 8. The Keycloak session is also gone, so Alice has to type her password again.
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
So how long can Alice stay logged in without typing her password?

[click] In the first scenario, Alice clicks every 20 minutes. Each refresh extends the idle window and the cookie, but the 10-hour limit never moves, so she sees the login form at 10 hours.

[click] In the second scenario, Alice takes a 45-minute lunch at 3 hours. Keycloak ends the session at 3:30. The cookie is still valid but can no longer be refreshed, so her first click at 3:45 shows the login form.

[click] The longest possible session is 10 hours, and 30 idle minutes end it sooner. The 8-hour cookie never decides.
-->

---
clicks: 5
---

<div class="kicker">Backup · follow the cookie</div>

# The cookie goes to the checker, not to the app

<CookieJourney />

<!--
Let's follow the session cookie through one request.

[click] 1. The browser sends the session cookie to the gateway.
[click] 2. The gateway passes the cookie to OAuth2-Proxy, which uses it to check the session.
[click] 3. OAuth2-Proxy answers 200 and returns the identity headers to the gateway.
[click] 4. The router removes the cookie, and only the identity headers continue to Spring.
[click] 5. On the way back, no identity header is returned to the browser. The browser only gets a new cookie when the session was refreshed.
-->

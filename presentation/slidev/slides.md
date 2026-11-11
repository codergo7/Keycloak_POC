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

  <p class="text-2xl max-w-3xl !mb-3" v-motion :initial="{ opacity: 0, y: 10 }" :enter="{ opacity: 1, y: 0, transition: { delay: 550 } }">
    How we take security out of the application
  </p>

  <p class="text-lg max-w-2xl muted" v-motion :initial="{ opacity: 0 }" :enter="{ opacity: 1, transition: { delay: 900 } }">
    Using <span class="kc">Keycloak</span>, <span class="op">OAuth2-Proxy</span>
    and <span class="is">Istio on Kubernetes</span>: the theory, the POC, then a live demo
  </p>

  <div class="mt-14 text-sm muted" v-motion :initial="{ opacity: 0 }" :enter="{ opacity: 1, transition: { delay: 1200 } }">
    Gokhan Ozturk · 18/11/2026 · Lunch &amp; Learn · Klarrio
  </div>
</div>

<!--
Welcome, everyone, and thanks for coming. Today's topic is a small proof of concept I built with Keycloak, OAuth2-Proxy and Istio.

Here's the question behind it: what if our applications had no login code and no role checks at all, and we could still change what a user may do just by changing a group in Keycloak? At the end of this talk, I'll show exactly that, live.

I prepared more slides than fit in our time, so I left some out. They're at the end as backup, so if you have a question about something I skip, just ask, and I can show them.
-->

---

<div class="kicker">Agenda</div>

# Theory, the POC, then a live demo

<div class="grid grid-cols-3 gap-5 mt-6">
  <div v-click class="card !p-5">
    <div class="text-5xl font-bold text-[var(--blue)] mb-2">1</div>
    <h3>Theory</h3>
    <p>AuthN vs AuthZ<br>The POC architecture<br>The components<br>JWTs, cookies, scopes<br>Authorization code flow</p>
  </div>
  <div v-click class="card !p-5">
    <div class="text-5xl font-bold text-[var(--orange)] mb-2">2</div>
    <h3>The POC</h3>
    <p>Two access paths, one identity provider<br>Inside Envoy, filter by filter<br>Browser access: session cookie<br>API access: claims decide</p>
  </div>
  <div v-click class="card !p-5">
    <div class="text-5xl font-bold text-[var(--navy)] mb-2">3</div>
    <h3>The live demo</h3>
    <p>A demo after each access path<br>Expected vs actual<br>Takeaways and Q&amp;A</p>
  </div>
</div>

<p class="remember mt-6">The goal: <b>security out of the application.</b> The platform decides who you are and which endpoints you may call; the app keeps the rules that need its own data.</p>

<!--
The goal is the line at the bottom: security out of the application. The platform decides who you are and which endpoints you may call. Not everything moves out, though. A rule like "only the owner may edit this report" needs the application's data, so it stays in the app. We'll come back to that at the end.

I won't go deep into each tool. I'll summarize each one, and then show how they work together.

[click] First, the theory, from authentication and authorization to tokens and the login flow.

[click] Then our POC, with its two ways in: browser access for people, and API access for scripts that send a bearer token.

[click] And finally the live demo.
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
    <div class="mt-3"><span class="chip red">403 = I know you, and no</span></div>
  </div>
</div>

<!--
Authentication answers one question: who are you? You claim an identity, and then you prove it, for example with a password. If that fails, the answer is 401: please log in first.

[click] Authorization comes next: what are you allowed to do? The answer depends on your roles, scopes and claims. Claims are simply facts written in the token. If authorization fails, the answer is 403: we know who you are, but you can't do this.

The order never changes. We can't decide what you may do before we know who you are.
-->

---
clicks: 5
---

<div class="kicker">The POC · what runs where</div>

# One cluster, four namespaces, one way in

<ArchDiagram />

<!--
This is what I built: one kind cluster on my laptop, with four namespaces.

[click] Browsers and scripts both enter through the Istio ingress gateway on localhost port 8080. The gateway routes three host names, and there is no other way into the cluster.

[click] The identity namespace contains Keycloak, which holds our realm, called demo, and its users. Keycloak stores its data in Postgres.

[click] OAuth2-Proxy runs in the same namespace. The gateway asks it whether a browser request to app.localhost is logged in, and this check is called ext_authz. During login, OAuth2-Proxy also talks directly to Keycloak over a private connection that we call the back channel.

[click] Each application has its own namespace, with an Envoy sidecar next to it. Spring Boot serves the /api paths, and a small FastAPI service serves /reports. Each namespace is named after its Keycloak client, which is also the audience in the token: spring-api and reports-api. Both apps can be reached through the app host and the api host.

[click] Finally, istiod is the Istio control plane. It sends routes and policies to the gateway and to both sidecars, and it fetches Keycloak's public keys so that the proxies can verify tokens.
-->

---
clicks: 5
---

<div class="kicker">Components</div>

# Four components, four jobs

<ComponentsFlow />

<p v-click="5" class="remember"><b>One line to remember:</b> Keycloak <i>authenticates the user</i>, OAuth2-Proxy <i>keeps the browser session</i>, Istio <i>enforces the policies</i>.</p>

<!--
Each of the four components has one job.

[click] Keycloak is the identity provider. It knows the users, checks their passwords, and issues signed tokens.

[click] OAuth2-Proxy runs the login for browsers. It gets the tokens from Keycloak and keeps the session in a cookie.

[click] Istio enforces the rules. OAuth2-Proxy hands it the identity headers and the token, and Istio checks them at the gateway and again at each pod.

[click] And the applications, Spring Boot and FastAPI, just do their business job. They get a request that has already been checked, so they need no login code and no token code.

[click] So, in one sentence: Keycloak authenticates the user, OAuth2-Proxy keeps the browser session, and Istio enforces the policies.
-->

---

<div class="kicker">Keycloak · the identity provider</div>

# Five terms you need for Keycloak

<div class="tbl-card mt-3">
<table class="tbl">
  <thead><tr><th>Term</th><th>In plain words</th><th>In our POC</th></tr></thead>
  <tbody>
    <tr v-click><td class="strong">Realm</td><td>An isolated space with its own users, roles and clients</td><td><code>demo</code></td></tr>
    <tr v-click><td class="strong">Client</td><td>An application registered in Keycloak: one that asks for tokens, or an API that receives them</td><td>asks: <code>oauth2-proxy</code> <code>cli-client</code><br>APIs: <code>spring-api</code> <code class="whitespace-nowrap">reports-api</code></td></tr>
    <tr v-click><td class="strong">User &amp; group</td><td>A person, and a team they belong to</td><td>alice, bob, admin · <code>/engineering</code> <code>/finance</code> <code>/finance/managers</code> <code>/admins</code></td></tr>
    <tr v-click><td class="strong">Realm &amp; client role</td><td>A permission label: realm roles are shared, client roles belong to one API. A composite role contains others</td><td>user, developer, admin · <code>reports-api</code>: viewer, editor (editor contains viewer)</td></tr>
    <tr v-click><td class="strong">Client scope</td><td>A named bundle of claims a client can request</td><td><code>groups</code> <code>app-audience</code> <code>reports</code></td></tr>
  </tbody>
</table>
</div>

<p v-click class="remember text-sm muted">Groups carry roles: <code>/engineering</code> gives alice <code>developer</code>, and <code>/finance</code> gives bob the <code>reports-api</code> role <code>viewer</code>.</p>

<!--
These are the Keycloak terms that I will use during the talk.

[click] A realm is an isolated space with its own users, roles and clients. Ours is called demo.

[click] A client is an application that is registered in Keycloak. Some clients ask for tokens: oauth2-proxy for browsers and cli-client for scripts. The other clients are the APIs that the tokens are for: spring-api and reports-api. They never log anyone in. They give the token its audience, and reports-api also holds its own roles.

[click] Our users are alice, bob and admin. alice is in engineering, bob is in finance, and admin is in admins.

[click] A role is a permission label. Realm roles such as developer and admin are shared by every application, while client roles belong to one API, like viewer and editor of reports-api. A composite role contains other roles, so editor also includes viewer.

[click] A client scope is a named set of claims that a client can request. When a client asks for the reports scope, the token gets reports-api in its audience.

[click] Groups can also carry roles. alice gets the developer role from the engineering group, and bob gets the reports viewer role from the finance group.
-->

---

<div class="kicker">OAuth2-Proxy · OIDC client for the browser</div>

# It turns a login into a session cookie

<div class="grid grid-cols-[1.25fr_1fr] gap-6 mt-4">
<div class="grid grid-cols-2 gap-3">
  <div v-click="1" class="card"><h3>OIDC client</h3><p>Registered in Keycloak as the <code>oauth2-proxy</code> client, with a client secret.</p></div>
  <div v-click="2" class="card"><h3>Session cookie</h3><p><code>_oauth2_proxy</code>, encrypted. Refreshed on the first request after 4 minutes, expires after 8 hours.</p></div>
  <div v-click="3" class="card"><h3>External authorizer</h3><p>Istio asks it “is this request logged in?” It answers yes, or redirects to login.</p></div>
  <div v-click="4" class="card"><h3>Identity headers</h3><p>Returns X-Auth-Request-User, -Email and the access token, for Istio to copy into the request.</p></div>
</div>

```yaml {all|1-2|3-4|5-6|7-9}{at:1}
--provider=keycloak-oidc
--client-id=oauth2-proxy
--cookie-refresh=4m
--cookie-expire=8h
--upstream=static://200   # auth check only
--scope=openid profile email groups app-audience reports
--set-xauthrequest=true   # X-Auth-Request-* headers
--pass-access-token=true  # …incl. the access token
--pass-authorization-header=true
```
</div>

<!--
OAuth2-Proxy turns a login into a session cookie. It has four jobs.

[click] First, it is an OpenID Connect client, registered in Keycloak.

[click] Second, it keeps the session in an encrypted cookie. When the cookie is older than 4 minutes, it refreshes the tokens on the next request.

[click] Third, it is the external authorizer. For every browser request, Istio asks it: is this user logged in? It answers yes, or it sends the browser to the login page.

[click] Fourth, it returns identity headers, including the access token, and Istio copies them into the request. That's how the applications learn who the user is.
-->

---

<div class="kicker">Istio · policy enforcement</div>

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

[click] AuthorizationPolicy makes the decision. It can allow a request, deny it, or delegate the decision to an external authorizer with the CUSTOM action.

[click] The mesh configuration registers OAuth2-Proxy as that external authorizer, called an extension provider, and it lists exactly which headers may pass in each direction.

[click] All of these rules run in Envoy, both at the gateway and in each sidecar. None of them run in our application code.
-->

---

<div class="kicker">Tokens</div>

# A JWT is a signed set of claims about the user

<div class="grid grid-cols-[1fr_1fr] gap-6 mt-3">
<div>
  <div class="mono text-sm mb-3" v-motion :initial="{ opacity: 0 }" :enter="{ opacity: 1 }">
    <span class="text-[var(--orange)] font-bold">header</span> .
    <span class="text-[var(--blue)] font-bold">payload</span> .
    <span class="text-[var(--green)] font-bold">signature</span>
  </div>

```json {all|2-4|6-8|9|all}
{
  "iss": ".../realms/demo",
  "aud": "spring-api",
  "azp": "oauth2-proxy",
  "preferred_username": "alice",
  "scope": "openid email groups",
  "realm_access": { "roles": ["developer", "user"] },
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

[click] iss, aud and azp tell us who issued the token, who it is for, and which client asked for it.

[click] The roles and groups are the claims that our access rules check.

[click] exp makes the token short-lived. The signature means nobody can change it: Istio verifies it with Keycloak's public keys.

[click] One login actually gives three tokens. The access token is for calling APIs, the ID token says who logged in, and the refresh token gets new tokens.
-->

---

<div class="kicker">Carrying identity</div>

# Session cookies for browsers, bearer JWTs for scripts

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
There are two ways to carry identity, one for each access path.

People in a browser get a session cookie. It's encrypted, and only OAuth2-Proxy can read it. That's app.localhost.

Scripts send a bearer token in the Authorization header. Anyone can decode it, but nobody can change it, and Istio verifies it. That's api.localhost.

Three words are often mixed up, so let me separate them.
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

Notice that the tokens are only sent in readable form on the orange lines. The browser only gets them encrypted, inside the cookie. Let's go through it step by step.
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

[click] 6. Keycloak sends the browser back to OAuth2-Proxy with a one-time code.

[click] 7. The code arrives at OAuth2-Proxy, which checks that the state value matches its CSRF cookie.

[click] 8. OAuth2-Proxy then sends the code and its client secret directly to Keycloak, server to server.

[click] 9. Keycloak answers with the access token, the ID token and the refresh token, directly to OAuth2-Proxy, on the back channel.

[click] 10. OAuth2-Proxy encrypts the tokens into a cookie and sends Alice back to her page.

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
    <div class="flex items-center gap-2 mb-2"><span class="icon-dot orange"><span class="i-carbon-view-off" /></span><h3 class="!m-0">Back channel · never readable by the browser</h3></div>
    <p>Access, ID and refresh tokens<br>The client secret<br>Any call between pods</p>
  </div>
</div>

<div class="grid grid-cols-3 gap-4 mt-5">
  <div v-click class="card"><h3 class="kc !text-[var(--orange)]">Keycloak</h3><p>Checks the password, issues code and tokens</p></div>
  <div v-click class="card"><h3>OAuth2-Proxy</h3><p>Swaps the code, keeps the session</p></div>
  <div v-click class="card"><h3 class="!text-[var(--blue)]">Istio</h3><p>Checks at the ingress gateway, again at the sidecar</p></div>
</div>

<!--
Let's summarize what the browser saw. It saw the redirects, the login page, a one-time code and an encrypted cookie. It never saw the client secret or any call between the pods, and it only holds the tokens encrypted, inside the cookie.

[click] Keycloak checked the password and issued the tokens.
[click] OAuth2-Proxy exchanged the code for the tokens and now keeps the session.
[click] Istio checks the request at the gateway and again right in front of the pod.

So Alice is logged in. But her token only lives 5 minutes, so what happens next?
-->

---
clicks: 8
---

<div class="kicker">Authorization code flow · token refresh</div>

# OAuth2-Proxy refreshes the 5-minute access token

<RefreshLoop />

<!--
Alice's access token lives only 5 minutes, and her Keycloak session ends after 30 idle minutes. Still, she notices nothing while she keeps working. Here's why.

[click] 1. Alice clicks something, more than 4 minutes after the last refresh.
[click] 2. OAuth2-Proxy sees that the cookie is older than 4 minutes, so it refreshes first.
[click] 3. It sends the refresh token to Keycloak on the back channel. The browser never sees it.
[click] 4. The session is still alive, so Keycloak returns fresh tokens and resets the idle timer.
[click] 5. OAuth2-Proxy sets a new cookie, and the request continues. Alice notices nothing.

Now the same request after 45 idle minutes.
[click] 6. Keycloak ended the session after 30 idle minutes, so it refuses the refresh token.
[click] 7. OAuth2-Proxy deletes its cookie and sends the browser to Keycloak.
[click] 8. The Keycloak session is gone too, so Alice has to log in again.
-->

---
class: navy
---

<div class="kicker">The POC · two access paths</div>

# Two access paths, one identity provider

<div class="flex flex-col gap-3 mt-5">
  <div v-for="(d, i) in [
      { path: 'Browser access · app.localhost', who: 'Person in a browser', via: 'Ingress gateway: ext_authz (CUSTOM)', how: 'OAuth2-Proxy session cookie' },
      { path: 'API access · api.localhost', who: 'Script with a bearer JWT', via: 'Ingress gateway and sidecar', how: 'RequestAuthentication + AuthorizationPolicy' },
    ]" :key="d.path" v-click class="flex items-center gap-3">
    <div class="card !py-2 w-56 flex-none"><div class="mono text-[0.62rem] text-[var(--sky)]">{{ d.path }}</div><h3 class="!m-0 !text-sm">{{ d.who }}</h3></div>
    <div class="arrow-run text-[var(--sky)]">➜</div>
    <div class="card !py-2 flex-1"><div class="mono text-[0.62rem] text-[#aeb7cc]">{{ d.via }}</div><h3 class="!m-0 !text-sm">{{ d.how }}</h3></div>
    <div class="arrow-run text-[var(--sky)]">➜</div>
    <div class="rounded-lg bg-[var(--amber)] text-[var(--navy)] font-bold text-sm leading-tight text-center px-4 py-2 flex-none">Spring Boot<br>FastAPI</div>
  </div>
</div>

<p v-click class="remember muted">Both paths end in the same thing: <span class="kc">claims signed by Keycloak realm demo</span>, checked by <span class="is">Istio</span> before any application sees the request.</p>

<style>
.arrow-run { animation: nudge 1.4s ease-in-out infinite; }
@keyframes nudge { 50% { transform: translateX(5px); opacity: 0.6; } }
</style>

<!--
Now our POC. It has two ways in, to the same applications.

[click] Browser access, on app.localhost, is for people. The gateway asks OAuth2-Proxy, and OAuth2-Proxy recognizes the person by the session cookie.

[click] API access, on api.localhost, is for scripts that send a bearer token. The gateway and the app's sidecar both check the token, and the roles in it decide what the caller may do.

[click] Both paths end the same way: claims signed by Keycloak, checked by Istio, before any application sees the request.
-->

---
clicks: 12
---

<div class="kicker">Istio · ingress gateway and sidecar</div>

# Inside Envoy: one request, filter by filter

<EnvoyInside />

<!--
Istio doesn't run our rules itself. Each Istio resource becomes a filter in Envoy, and the filters always run in the same order. Let's follow alice's browser request to /api/headers through both proxies.

[click] 1. The first filter at the gateway is ext_authz. It comes from the AuthorizationPolicy with action CUSTOM. Envoy pauses the request and asks OAuth2-Proxy. OAuth2-Proxy checks the cookie, says yes, and adds the identity headers, including the access token.

[click] 2. Next is jwt_authn, from RequestAuthentication. At the gateway it only looks at the Authorization header, and a browser doesn't send one. A missing token is not an error, so the request simply continues.

[click] 3. Then rbac, from the ALLOW policy. There's a rule for app.localhost, so the request may pass. OAuth2-Proxy has already checked the user.

[click] 4. The router applies the VirtualService. It removes the cookie and sends the request over mTLS to the Spring pod.

[click] 5. Now we're in Spring's sidecar. Its jwt_authn filter, from the RequestAuthentication keycloak-jwt, finds the token in the X-Auth-Request-Access-Token header.

[click] 6. It reads the key ID from the token header, takes the matching key from Keycloak's public keys, and checks the signature.

[click] 7. Then it reads the payload and checks the issuer, the expiry, and the audience: spring-api.

[click] 8. The token is valid, so the filter stores the result for the next filter: who the user is, and all the claims. This is the key point: RequestAuthentication reads the token, and the AuthorizationPolicy only uses the result.

[click] 9. Now rbac checks the ALLOW policy. /api/headers needs the role developer. alice has it, so the request is allowed.

[click] 10. Spring gets the request with the identity headers and answers 200. Spring never parsed a token or checked a role.

[click] 11. Now the same request from bob. His token is valid, and he passes every filter until the last one. He doesn't have the developer role, so the sidecar answers 403, and Spring never sees the request.

[click] 12. And this is how it grows. Each backend gets its own namespace and sidecar, and one pair of resources: a RequestAuthentication for its audience, and an AuthorizationPolicy for its roles. The reports API already works this way. To add a new API, in any language, we do four things: add a client in Keycloak, create a namespace with sidecar injection, add the two resources, and add a route. The gateway and Keycloak stay the same, and the new app has no security code.
-->

---

<div class="kicker">Live demo · browser access · app.localhost</div>

# Demo: browser access, three checks

<div class="tbl-card mt-3">
<table class="tbl">
  <thead><tr><th>#</th><th>Action</th><th>Expected</th></tr></thead>
  <tbody>
    <tr><td class="faint">1</td><td>Open app.localhost/api/whoami in a private window</td><td class="code-30x">302 to the Keycloak login page</td></tr>
    <tr><td class="faint">2</td><td>Log in as alice, then open /api/headers</td><td>Spring shows her user ID and email from the identity headers, and gets no cookie</td></tr>
    <tr><td class="faint">3</td><td>Still as alice, open /api/admin</td><td><span class="code-403">403</span> RBAC: access denied, from Spring’s sidecar</td></tr>
  </tbody>
</table>
</div>

<p class="remember">Spring knows <b>who</b> alice is and never sees her session. Her roles decide what she may open, before Spring sees the request.</p>

<!--
Now let's see browser access live. I'll use a private window, so there are no old cookies. For each step, I'll say what I expect first.

**1 · No session: the login page**

*Do: open a private window and go to app.localhost:8080/api/whoami.*

I have no session cookie yet, so I expect to land on Keycloak, not on Spring.

*Result: Keycloak's "Sign in to Demo" page.*

The gateway asked OAuth2-Proxy, OAuth2-Proxy found no session, and it sent me to Keycloak. Spring wasn't called at all. In the address bar you can see client_id=oauth2-proxy.

**2 · Log in as alice**

*Do: log in as alice, password alice.*

The password goes only to Keycloak. Our application never sees it.

*Result: the JSON from /api/whoami.*

Now Spring answers, with alice's user ID and email. Spring didn't read a token or a cookie: OAuth2-Proxy put them in headers at the gateway.

*Do: open app.localhost:8080/api/headers.*

This page lists every header Spring received. There's no cookie: the gateway removed it. But the access token is there, and Spring's sidecar already checked it, including her developer role. So Spring knows who alice is, but never sees her session.

**3 · Logged in, but not allowed**

*Do: in the same window, open app.localhost:8080/api/admin.*

alice is logged in, but /api/admin needs the admin role, and she doesn't have it. So I expect a 403.

*Result: 403, RBAC: access denied.*

Her session is valid, so the gateway let the request through. Then Spring's sidecar checked the roles in her token, found no admin, and stopped the request. Spring never saw it. Being logged in tells us who you are; the roles decide what you may open.

So: alice logs in once at Keycloak, Spring gets her identity in headers without seeing her session, and her roles decide what she may open.
-->

---
clicks: 10
---

<div class="kicker">API access · a script with a user token · api.localhost</div>

# Inside Envoy: the same filters, the API path

<EnvoyInside mode="api" />

<!--
Now the same view for API access. A script calls api.localhost with alice's token in the Authorization header. No browser, no cookie. The script also adds an X-Auth-Request-User header that says admin. Nobody sets that header on this path, so it's fake: the script is trying to fool the application.

[click] 1. ext_authz first. The CUSTOM policy only matches app.localhost, so OAuth2-Proxy isn't called. An API client brings its own token.

[click] 2. Now jwt_authn at the gateway has real work. It finds the bearer token and checks the signature, the issuer and the expiry, but not the audience. The result is a principal: who the token belongs to.

[click] 3. rbac at the gateway. For api.localhost, the rule needs a principal, so any valid token is enough. Roles come later.

[click] 4. The router removes every X-Auth-Request header, because on this path they can only come from the client. Our fake admin header is gone. We'll try this live in the demo.

[click] 5. In Spring's sidecar, keycloak-jwt checks the same token again, and this time also the audience: it must be issued for spring-api. Then it writes alice's real ID from the token into X-Auth-Request-User.

[click] 6. rbac at the sidecar. /api/user needs the role user, and alice has it.

[click] 7. Spring answers 200. It never checked the token, and the only X-Auth-Request-User it saw came from the token.

Now three requests that fail, each at a different filter.

[click] 8. No token at all. RequestAuthentication lets it pass, because there's nothing to check. But there's no principal, so the gateway's rule doesn't match: 403. That's why we always use the two resources together.

[click] 9. A tampered token, with one character changed. The signature check fails, so the gateway answers 401.

[click] 10. alice calls /api/admin. Her token is valid, so the gateway lets her in. But she has no admin role, so the Spring sidecar answers 403.

In short: the gateway checks that there's a valid token. The sidecar checks that the token is meant for this API and has the right role.
-->


---

<div class="kicker">Live demo · API access · api.localhost</div>

# Demo: API access, eight checks with curl

<div class="tbl-card mt-2">
<table class="tbl">
  <thead><tr><th>#</th><th>Action</th><th>Expected</th></tr></thead>
  <tbody>
    <tr><td class="faint">1</td><td>curl /api/public, no token</td><td class="code-200">200</td></tr>
    <tr><td class="faint">2</td><td>curl /api/user, no token</td><td class="code-403">403 access denied</td></tr>
    <tr><td class="faint">3</td><td>curl /api/user, tampered token</td><td class="code-401">401 JWT fails</td></tr>
    <tr><td class="faint">4</td><td>alice token → /api/user, then /api/admin</td><td><span class="code-200">200</span>, then <span class="code-403">403</span></td></tr>
    <tr><td class="faint">5</td><td>alice token + fake <code>X-Auth-Request-User: admin</code> → /api/headers</td><td><span class="code-200">200</span>, Spring sees alice’s real ID</td></tr>
    <tr><td class="faint">6</td><td>bob token without scope=reports → GET /reports</td><td class="code-403">403 wrong audience</td></tr>
    <tr><td class="faint">7</td><td>bob token with scope=reports → GET, then POST /reports</td><td><span class="code-200">200</span>, then <span class="code-403">403</span></td></tr>
    <tr><td class="faint">8</td><td>Add bob to <code>/finance/managers</code> in Keycloak → POST /reports</td><td><span class="code-403">403</span>, then <span class="code-200">201</span></td></tr>
  </tbody>
</table>
</div>

<div class="mt-3 flex gap-3 mono text-sm">
  <span v-for="c in ['make token-alice', 'make token-bob', 'make token-bob-reports', 'make demo-api']" :key="c" class="cmd">$ {{ c }}</span>
</div>

<style>
.cmd { background: var(--navy); padding: 0.35rem 0.75rem; border-radius: 8px; color: #e3ecfb; }
</style>

<!--
Now API access, in the terminal. For each check, the script shows the rule and the curl command, and then waits. I say what I expect, press Enter, and we see the real answer.

*Do: run make demo-api.*

**1 · Public endpoint, no token**

*On screen: the ALLOW rule for GET /api/public.*

This rule doesn't ask for a token, so I expect 200.

*Enter. Result: 200.*

Public endpoints are declared in the policy, not in the code.

**2 · Protected endpoint, no token**

*On screen: the rule with requestPrincipals ["*"].*

/api/user needs a principal, which means a valid token. I send none, so I expect 403.

*Enter. Result: 403, RBAC: access denied.*

RequestAuthentication checks tokens, but only the AuthorizationPolicy requires one.

**3 · Tampered token**

*On screen: RequestAuthentication demo-jwt-validation.*

I take alice's real token and add one character. The signature breaks, so I expect 401.

*Enter. Result: 401, Jwt verification fails.*

A 401 means: I don't know who you are.

**4 · alice: user yes, admin no**

*On screen: alice's roles, user and developer, and the Spring rules.*

/api/user needs the role user. I expect 200.

*Enter. Result: 200.*

/api/admin needs admin, which she doesn't have. I expect 403.

*Enter. Result: 403, RBAC: access denied.*

A 403 means: I know who you are, and the answer is no.

**5 · A fake identity header**

*On screen: keycloak-jwt, with outputClaimToHeaders: the user ID comes from the token's sub claim.*

Spring learns who the caller is from the X-Auth-Request-User header. What if a script just sends one itself? alice sends X-Auth-Request-User: admin. I expect 200, and Spring should see alice's real ID, not admin.

*Enter. Result: 200, and X-Auth-Request-User at Spring is alice's user ID.*

The gateway removed the fake header, and Spring's sidecar wrote the real one from the verified token. So Spring can trust this header: it always comes from the token, never from the client.

**6 · bob without the reports scope**

*On screen: bob's token, with aud only spring-api.*

bob has the reports viewer role, but this token wasn't issued for the reports API. I expect 403.

*Enter. Result: 403, Audiences in Jwt are not allowed.*

Right user, right role, wrong audience.

**7 · bob with the reports scope**

*On screen: the new token, with reports-api in aud and the viewer role.*

Same user, new token, with scope=reports. Reading needs viewer, so I expect 200.

*Enter. Result: 200 and the list of reports.*

Creating needs editor, and bob is only a viewer. I expect 403.

*Enter. Result: 403, RBAC: access denied.*

The reports API is Python, and it has no security code. The same Istio resources protect both apps.

**8 · Add bob to the managers group**

*On screen: the admin console path and the admin API call.*

In the admin console I'd open Users, then bob, then Groups, and join finance managers. The script does the same through the admin API.

*Enter: bob joins the group, and the script gets a new token.*

The new token now has the editor role. I expect 201.

*Enter. Result: 201 Created.*

No code, no policy, no deployment changed. Only a group in Keycloak, and the claim in the token did the rest.

*Enter for the summary: the script removes bob from the group again, and all ten checks passed.*
-->

---

<div class="kicker">Putting it together</div>

# Who decides what: one layer per question

<div class="tbl-card mt-3">
<table class="tbl">
  <thead><tr><th>#</th><th>Layer</th><th>Question</th><th>Answered by</th></tr></thead>
  <tbody>
    <tr v-click><td class="faint">1</td><td class="strong">User AuthN</td><td>Who is the user?</td><td>Keycloak (+ OAuth2-Proxy)</td></tr>
    <tr v-click><td class="faint">2</td><td class="strong">Token check</td><td>Is the token real and meant for us?</td><td>RequestAuthentication</td></tr>
    <tr v-click><td class="faint">3</td><td class="strong">User AuthZ</td><td>Do the token’s claims allow this path?</td><td>AuthorizationPolicy</td></tr>
    <tr v-click><td class="faint">4</td><td class="strong">Business AuthZ</td><td>May alice edit <i>this</i> report?</td><td class="font-bold text-[var(--orange)]">The application (Spring Boot, FastAPI)</td></tr>
  </tbody>
</table>
</div>

<p v-click class="remember">The platform answers 1 to 3. <b>The application owns row 4:</b> rules that need its own data.</p>

<!--
To put it all together, there are four questions, and each one is answered by one layer.

[click] Who is the user? Keycloak answers this, with help from OAuth2-Proxy for browsers.
[click] Is the token real and meant for us? RequestAuthentication answers this.
[click] Do the token's claims allow this path? AuthorizationPolicy answers this.
[click] May alice edit this report? Istio only sees the request and the token. It doesn't know who owns report 42, so the application answers this one, with its own data.

[click] The platform answers the first three questions. The application keeps only the rules that need its data, like ownership or amount limits.
-->

---
class: navy
---

<div class="kicker">Takeaways</div>

# What to remember in the future

<div class="grid grid-cols-2 gap-4 mt-5">
  <div v-for="(t, i) in [
      { t: 'AuthN, then AuthZ', d: '401 = who are you? 403 = I know you, and no.' },
      { t: 'One job per component', d: 'Keycloak authenticates, OAuth2-Proxy keeps the session, Istio enforces.' },
      { t: 'Always pair them', d: 'RequestAuthentication alone lets no-token requests through.' },
      { t: 'Claims, not code', d: 'Roles in the token decide access: the gateway checks the token, the sidecar checks the claims.' },
    ]" :key="t.t" class="card !p-5"
    v-motion :initial="{ opacity: 0, scale: 0.9 }" :enter="{ opacity: 1, scale: 1, transition: { delay: 100 + i * 150 } }">
    <h3 class="!text-lg">{{ t.t }}</h3>
    <p>{{ t.d }}</p>
  </div>
</div>

<p class="mt-5 text-lg text-white">Security is out of the application: the platform decides <b>who</b> you are and <b>which endpoints</b> you may call, and the app keeps the rules that need its data.</p>

<div class="mt-5 flex items-end justify-between">
  <div class="text-4xl font-bold text-white" v-click>Questions?</div>
</div>

<!--
Here are four things to remember.

A 401 means we don't know who you are. A 403 means we know you, and the answer is no.

Keycloak authenticates, OAuth2-Proxy keeps the browser session, and Istio enforces the policies.

Always pair RequestAuthentication with an AuthorizationPolicy. Otherwise, requests without a token get through.

And claims, not code: the gateway checks the token, and the sidecar checks the claims. We changed bob's access without touching any code, in two apps written in two languages.

So we're back where we started: security is out of the application. The platform decides who you are and which endpoints you may call, and the app keeps only the rules that need its own data.

[click] That's all from me. Any questions?
-->

---
class: navy
---

<div class="h-full flex flex-col justify-center">
  <div class="kicker">Backup</div>
  <h1 class="!text-5xl">For possible questions</h1>
  <p class="text-lg muted max-w-2xl mt-4"></p>
</div>

<!--
These are the backup slides. I only show them if someone asks. The next slide is an index: I click a topic to jump to it.
-->

---
routeAlias: backup-index
---

<div class="kicker">Backup · index</div>

# Backup slides by topic

<BackupIndex />

<!--
This is the index of the backup slides. When someone asks a question, I click the topic here and jump straight to that slide.
-->

---
routeAlias: b-claims
---

<div class="kicker">Backup · API access · every endpoint and its claim</div>

# Claims in the token decide every endpoint

<div class="tbl-card mt-2">
<table class="tbl text-center">
  <thead><tr><th class="!text-left">Endpoint</th><th class="!text-left">Claim it needs</th><th>alice<br><span class="normal-case">user · developer</span></th><th>bob<br><span class="normal-case">user · reports viewer</span></th><th>admin<br><span class="normal-case">user · admin</span></th></tr></thead>
  <tbody>
    <tr v-click><td class="strong !text-left">/api/public</td><td class="!text-left muted">nothing</td><td class="code-200">200</td><td class="code-200">200</td><td class="code-200">200</td></tr>
    <tr v-click><td class="strong !text-left">/api/user</td><td class="!text-left muted">realm role user</td><td class="code-200">200</td><td class="code-200">200</td><td class="code-200">200</td></tr>
    <tr v-click><td class="strong !text-left">/api/headers</td><td class="!text-left muted">realm role developer</td><td class="code-200">200</td><td class="code-403">403</td><td class="code-403">403</td></tr>
    <tr v-click><td class="strong !text-left">/api/admin</td><td class="!text-left muted">realm role admin</td><td class="code-403">403</td><td class="code-403">403</td><td class="code-200">200</td></tr>
    <tr v-click><td class="strong !text-left">GET /reports</td><td class="!text-left muted"><code>reports-api</code> role viewer</td><td class="code-403">403</td><td class="code-200">200</td><td class="code-403">403</td></tr>
    <tr v-click><td class="strong !text-left">POST /reports</td><td class="!text-left muted"><code>reports-api</code> role editor</td><td class="code-403">403</td><td class="code-403">403</td><td class="code-403">403</td></tr>
  </tbody>
</table>
</div>

<p v-click class="remember text-sm">/reports also needs <code>aud: reports-api</code>, which the token only gets when the client asks for <code>scope=reports</code>. Without it: <span class="code-403">403</span> <span class="mono">Audiences in Jwt are not allowed</span>, even for bob.</p>

<!--
Every endpoint asks for a claim in the token. Spring checks realm roles, and the reports API checks its own client roles. Two apps, two languages, and no security code in either.

[click] /api/public needs nothing, so everyone gets 200.

[click] /api/user needs the role user, and all three users have it.

[click] /api/headers needs developer, so only alice gets in. She gets that role from her engineering group.

[click] /api/admin needs admin, so only the admin user gets in.

[click] Reading reports needs the reports viewer role. Only bob has it, from his finance group.

[click] Creating a report needs editor, and nobody has it, until bob joins the managers group, as we saw in the demo.

[click] The reports API also checks the audience. A token only has reports-api in its audience if the client asks for the reports scope. Without it, even bob gets a 403. This stops a token made for one API from being used against another.
-->


---
clicks: 6
routeAlias: b-six
---

<div class="kicker">Backup · Inside Envoy · same checks, different requests</div>

# Six requests, six outcomes

<RequestLanes />

<div class="mt-3 flex gap-6 text-sm">
  <span><b class="code-30x">302</b> go log in</span>
  <span><b class="code-401">401</b> bad token · a JWT check</span>
  <span><b class="code-403">403</b> not allowed · an ALLOW check, or wrong audience</span>
  <span><b class="code-200">200</b> OK</span>
</div>

<!--
Every request passes the same checks in Envoy: at the ingress gateway the route, the OAuth2-Proxy check, the JWT check and the ALLOW policy, and then the JWT check and the ALLOW policy again at Spring's sidecar. Now we send six different requests and see where each one stops.

[click] A browser with no session stops at the CUSTOM check and gets a 302 to Keycloak.

[click] A browser with a session passes every check and gets a 200.

[click] A curl request with no token stops at the gateway's ALLOW check and gets a 403.

[click] A curl request with a tampered token stops at the JWT check and gets a 401.

[click] alice's valid token on the admin endpoint reaches the sidecar's ALLOW check and gets a 403, because she has no admin role.

[click] The admin token passes every check and gets a 200.

The legend at the bottom sums up the codes. A 302 sends you to log in, and a 200 means OK. A 401 means the token is bad, and it always comes from a JWT check. A 403 means you are not allowed, and it usually comes from an ALLOW check. The one exception is a token issued for another audience, which the JWT check answers with a 403.
-->

---
clicks: 6
routeAlias: b-filters
---

<div class="kicker">Backup · inside Envoy</div>

# From Istio YAML to envoy.filters.http.*

<EnvoyFilters />

<!--
Envoy handles every request with a chain of HTTP filters. Each one has a name like envoy.filters.http.jwt_authn. Envoy has never heard of a RequestAuthentication or an AuthorizationPolicy.

[click] istiod is the translator. It reads our YAML, turns it into Envoy configuration, and pushes it to every proxy. Istio itself is never in the request path. This command shows the real chain on our gateway, in this order.

[click] The CUSTOM policy becomes two filters. A shadow rbac filter only marks the requests that match its rules, and ext_authz calls OAuth2-Proxy for those. A 302 to the login page comes from here.

[click] RequestAuthentication becomes jwt_authn. It checks the signature, the issuer and the expiry, and writes the claims into the request's metadata. Notice the keys are inline: istiod fetched them from Keycloak. A request without a token passes; a bad token gets a 401.

[click] The ALLOW policy becomes rbac. rbac never sees the token, it only reads what jwt_authn wrote. "Any request principal" turns into "iss and sub are set". That's why a token without a sub gets a 403.

[click] The VirtualService becomes the route table, and the router filter is always last. It's not a check, it just sends the request on. A 503 comes from here.

[click] The sidecar runs the same filters, minus ext_authz, because there's no CUSTOM policy there. Its jwt_authn also checks the audience and writes the identity headers, and its rbac checks the roles.
-->

---
clicks: 9
routeAlias: b-debug
---

<div class="kicker">Backup · troubleshooting</div>

# How do I debug a 401 or 403?

<DebugTree />

<!--
When something is denied, the first question is: which filter said no? The status code and the short body text tell you, and every message here came from our cluster.

[click] A 302 to Keycloak comes from ext_authz: OAuth2-Proxy found no session. For a new browser that's normal.

[click] 401, "Jwt verification fails": the signature doesn't match Keycloak's keys. Either the token was changed, or istiod still has old keys.

[click] 401, "Jwt is expired": the token is older than 5 minutes. Get a new one.

[click] 401, "Jwt issuer is not configured": the token comes from an issuer that RequestAuthentication doesn't list, for example another realm.

[click] 403, "Audiences in Jwt are not allowed": the token is valid, but it was issued for another API. Ask for the right scope.

[click] 403, "RBAC: access denied", and the response has no upstream time header: the gateway denied it, so there was no token, or the path isn't in the gateway's rules.

[click] The same 403, but with the upstream time header: the gateway let it through, and the sidecar found no matching role. Decode the token and compare its roles with the policy.

[click] And a 503 isn't a policy at all: the pod is down, or the mesh certificates expired, which happens after the laptop sleeps.

[click] These four tools answer almost every case: curl with -i, Envoy debug logging, the sidecar's logs, and decoding the token.
-->

---
clicks: 4
routeAlias: b-spoof
---

<div class="kicker">Backup · security · identity headers</div>

# Can someone fake who they are?

<RequestLanes
  :cols="['Route', 'CUSTOM', 'JWT', 'ALLOW', 'Router', 'JWT', 'ALLOW', 'Spring']"
  :groups="[{ label: 'ingress gateway', span: 5 }, { label: 'spring sidecar', span: 3 }]"
  :lanes="[
    { who: 'Script · api.localhost', req: 'alice token + User: admin', stop: 7, code: '200 · alice', cls: 'code-200', why: 'router drops it, sidecar writes alice' },
    { who: 'Script · app.localhost', req: 'bob token + User: alice', stop: 1, code: '302 → login', cls: 'code-30x', why: 'browser only, no exceptions' },
    { who: 'Pod in the cluster', req: 'no token + User: admin', from: 5, stop: 6, code: '403', cls: 'code-403', why: 'no token, no principal' },
    { who: 'Pod in the cluster', req: 'alice token + User: admin', from: 5, stop: 7, code: '200 · alice', cls: 'code-200', why: 'sidecar overwrites it from the token' },
  ]" />

<p class="remember text-sm mt-4">Spring reads <code>X-Auth-Request-User</code>, so only the platform may set it: <b>the sidecar always writes it from the verified token.</b></p>

<!--
Spring learns who the caller is from the X-Auth-Request-User header. So the obvious question is: can a client just send that header itself? Here are four attempts, all measured on the cluster.

[click] A script on api.localhost sends alice's token and claims to be admin. The gateway route removes the fake header, and Spring's sidecar writes alice's real ID from her token. Spring sees alice.

[click] A script on app.localhost sends bob's token and claims to be alice. app.localhost is for browsers only, so OAuth2-Proxy is asked, finds no session, and sends the script to the login page. Before our fix, this request got a 200 and Spring believed it was alice. That was the gap we found.

[click] A pod inside the cluster skips the gateway and calls Spring directly, with a fake header and no token. The sidecar finds no token and no principal, so the answer is 403.

[click] The same pod, now with alice's token and a fake admin header. The sidecar overwrites the header from the token, so Spring sees alice, not admin.

So the rule is: the identity header always comes from the verified token, never from the client.
-->

---
routeAlias: b-policy
---

<div class="kicker">Backup · browser access · app.localhost</div>

# Istio asks OAuth2-Proxy at every request

<div class="grid grid-cols-[1fr_1.1fr] gap-6 mt-3">
<div class="flex flex-col gap-3">
  <div v-click="1" class="card"><h3>CUSTOM policy at the ingress</h3><p>The decision is delegated to OAuth2-Proxy (Envoy ext_authz).</p></div>
  <div v-click="2" class="card"><h3>Browser only, no exceptions</h3><p>Every request except <code>/oauth2/*</code>, <code>/api/public</code> and the health check. Scripts use <code>api.localhost</code>.</p></div>
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
    # no exceptions for Bearer tokens
    # or user agents: browser only
```
```yaml
# oauth2-proxy.yaml · VirtualService
http:
- match:
  - uri: { prefix: /oauth2/ }
  route:
  - destination: { host: oauth2-proxy.identity… }
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
  - destination: { host: oauth2-proxy.identity… }
  headers:
    response:
      remove: [x-auth-request-*, authorization]
- route:
  - destination: { host: spring-app.spring-api… }
  headers:
    request:
      remove: [cookie]   # ext_authz already used it
```
````
</div>

<!--
This is the policy for browser access. For app.localhost, Istio asks OAuth2-Proxy on every request.

[click] A CUSTOM AuthorizationPolicy at the ingress hands this decision to OAuth2-Proxy.

[click] Every request to app.localhost goes through this check, except the /oauth2 paths, the public endpoint and the health check. There are no exceptions for bearer tokens or for scripts: app.localhost is for browsers, and scripts use api.localhost. We used to have those exceptions, and they opened a gap that I'll show on the lessons slide.

[click] This VirtualService is for the /oauth2 route. It removes the identity headers from OAuth2-Proxy's replies, so they do not leak back to the browser.

[click] The Spring route removes the cookie after OAuth2-Proxy has checked it, so Spring never sees the session.
-->

---
clicks: 7
routeAlias: b-headers
---

<div class="kicker">Backup · browser access · sensitive headers per hop</div>

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
clicks: 6
routeAlias: b-db
---

<div class="kicker">Backup · inside the cluster</div>

# Who can reach the database?

<DbPolicy />

<!--
Keycloak keeps everything in Postgres: users, password hashes, sessions, its signing keys. So who in the cluster can log in to it?

[click] Before, the answer was: everyone. We tried psql from three other places: OAuth2-Proxy, a pod in another namespace, and a pod outside the mesh. All three could read Keycloak's user table. Only the password stood in the way.

[click] Every pod with a sidecar already has an identity: a certificate for its service account. Keycloak was using the namespace's default account, the same one as Postgres, so we gave it its own.

[click] Then one ALLOW rule: only Keycloak's identity, only on port 5432. Everything that's not on the list is denied.

[click] Now only Keycloak gets in. The others get their connection closed. There's no 403 here, because this isn't HTTP. And the smoke test checks this from now on.

[click] Under the hood, it's a different Envoy filter: network rbac, for TCP. It only knows who is calling and on which port. No paths, no tokens.

[click] It doesn't cover everything. Whoever can create a pod with Keycloak's service account gets its identity. And Keycloak and OAuth2-Proxy still accept anyone in the mesh. The next steps would be a deny-all policy for the namespace, and strict mTLS.
-->

---
clicks: 5
routeAlias: b-lifetimes
---

<div class="kicker">Backup · token and session lifetimes</div>

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
clicks: 3
routeAlias: b-limits
---

<div class="kicker">Backup · Keycloak session limits</div>

# At most 10 hours, and never 30 idle minutes

<SessionTimeline class="mt-1" />

<div class="grid grid-cols-3 gap-3 mt-3">
  <div v-click="3" class="card !p-3"><h3>Longest: 10 h</h3><p>From login, if a request reaches oauth2-proxy at least every ~30 min. <code>ssoSessionMaxLifespan</code> never resets.</p></div>
  <div v-click="3" class="card !p-3"><h3>Shortest: 30 min idle</h3><p>The refresh token and the Keycloak session expire together. The 8 h cookie never decides.</p></div>
  <div v-click="3" class="card !p-3"><h3>Want longer?</h3><p>Raise the Remember-me timeouts, or use offline tokens (30 days idle). Longer sessions, bigger stolen-cookie window.</p></div>
</div>

<!--
So how long can Alice stay logged in without typing her password?

[click] In the first scenario, Alice clicks every 20 minutes. Each refresh extends the idle window and the cookie, but the 10-hour limit never moves, so she sees the login form at 10 hours.

[click] In the second scenario, Alice takes a 45-minute lunch at 3 hours. Keycloak ends the session at 3:30. The cookie is still valid but can no longer be refreshed, so her first click at 3:45 shows the login form.

[click] The longest possible session is 10 hours, and 30 idle minutes end it sooner. The 8-hour cookie never decides.
-->

---
clicks: 7
routeAlias: b-logout
---

<div class="kicker">Backup · tokens and sessions · logout</div>

# What does signing out really end?

<QaFlow flow="logout" />

<!--
People often ask what happens when a user signs out. Three things hold the login: the OAuth2-Proxy cookie, the Keycloak session, and tokens that were already issued. All of this was measured on the cluster.

[click] bob signs out of the app. OAuth2-Proxy deletes its cookie, and that's all it does.

[click] His next click goes to Keycloak, like the first visit.

[click] But Keycloak's own session is still alive, so it logs him straight back in, without a password.

[click] And a copy of the old cookie still works, because the cookie is the session, and OAuth2-Proxy keeps no list of signed-out sessions.

[click] An admin can end bob's Keycloak session. Then his refresh token is refused, and the browser session ends at the next refresh.

[click] But tokens already issued still work until they expire, at most 5 minutes, because Istio checks them offline.

[click] To make logout complete: also end the Keycloak session, keep access tokens short, and if you need revocable sessions, keep them on the server instead of in the cookie.
-->

---
clicks: 5
routeAlias: b-kcdown
---

<div class="kicker">Backup · tokens and sessions · availability</div>

# What if Keycloak goes down?

<KeycloakDown />

<!--
What happens when Keycloak stops? I measured it: I logged in, took a token, and then scaled Keycloak to zero.

[click] A script with a token from before keeps working. Istio checks the token with keys it already has, so it never needs Keycloak for a request. It works until the token expires: after 5 minutes, plus Envoy's 60 seconds of clock skew, the answer is 401, "Jwt is expired".

[click] A browser that was already logged in keeps working too. After 4 minutes OAuth2-Proxy tries to refresh and fails, but it keeps using the token it has. Once that token expires, the browser is sent to the Keycloak login page, and that's a 503. I measured a 200 at 4 and a half minutes, and the login redirect at 6 and a half.

[click] A new browser login fails at once, with a 503, because the login page is Keycloak.

[click] And a script can't get a new token either.

[click] So, already-issued tokens keep working, but everything new stops at once, and every existing session within about 5 minutes. Keycloak needs to be highly available, but a short restart doesn't take down the APIs.
-->


---
clicks: 9
routeAlias: b-jwks
---

<div class="kicker">Backup · RequestAuthentication</div>

# Where do the keys come from?

<JwksFlow />

<!--
We have two RequestAuthentications, one at the gateway and one at the sidecar. Both check Keycloak's signature, and neither of them ever talks to Keycloak. Here's how.

[click] Keycloak signs every token with the realm's private key. The token's header says which key: the kid. The private key never leaves Keycloak.

[click] The token also says who issued it: iss. Each RequestAuthentication rule has an issuer, and Envoy uses the rule whose issuer matches exactly, with that rule's keys. If none matches, that's a 401. Keycloak puts its public hostname in iss, and inside a pod that name points to the pod itself. That's why the keys are fetched from the internal service name instead.

[click] istiod, not Envoy, fetches the public keys from the jwksUri. Both of our rules use the same URI, so it's one fetch, not one per proxy.

[click] istiod copies the keys into each proxy's config and pushes it. The keys live inside Envoy.

[click] So every request is checked offline: find the key by kid, check the signature, issuer, expiry, and at the sidecar the audience. That's why tokens kept working while Keycloak was down.

[click] istiod fetches the keys again every 20 minutes. That's PILOT_JWT_PUB_KEY_REFRESH_INTERVAL. If they changed, it pushes the new ones.

[click] If the fetch fails, for example Keycloak wasn't ready when istiod started, istiod fails closed. It pushes a key nobody can sign for, and every token gets a 401. We hit this: about 20 minutes. The fix is to restart istiod once Keycloak is up.

[click] The same timer matters when you rotate keys. A new key is unknown to the proxies until the next refresh. So add it as passive first, wait the 20 minutes, then make it active, and keep the old one around until its tokens have expired.

[click] These are the settings that decide how fast things change: five minutes for a token, twenty minutes for keys.
-->

---
routeAlias: b-audience
---

<div class="kicker">Backup · audience and scopes</div>

# Audience and scopes: likely questions

<div class="tbl-card mt-2">
<table class="tbl text-sm">
  <thead><tr><th>Question</th><th>Answer</th></tr></thead>
  <tbody>
    <tr><td class="strong">Why check the audience if roles already decide?</td><td>Roles say what the user may do. <code>aud</code> says which API the token was issued for. Without it, a token leaked from one service works against every other one.</td></tr>
    <tr><td class="strong">Why 403 and not 401?</td><td>Envoy answers a wrong audience with <span class="code-403">403</span> <span class="mono">Audiences in Jwt are not allowed</span>. A bad signature or an expired token is <span class="code-401">401</span>.</td></tr>
    <tr><td class="strong">Why not always put <code>reports-api</code> in the token?</td><td>Least privilege: a client gets a token only for the APIs it asks for, with <code>scope=reports</code>.</td></tr>
    <tr><td class="strong">The browser token has both audiences. Too broad?</td><td>A little. One browser session serves both APIs. The stricter setup is one login client per API.</td></tr>
    <tr><td class="strong">One service calling another with the user's token?</td><td>Token exchange (RFC 8693): swap it for a token issued for the next API. Out of scope here.</td></tr>
    <tr><td class="strong">Realm roles or client roles?</td><td>Realm roles for what means the same everywhere (<code>admin</code>). Client roles for permissions owned by one API (<code>reports-api</code>: editor).</td></tr>
  </tbody>
</table>
</div>

<p class="text-xs muted mt-2">Same idea in Entra ID (<code>api://reports/.default</code>), Auth0 (<code>audience</code>) and RFC 8707 · RFC 9068 requires <code>aud</code></p>

<!--
These are the questions people usually ask about audiences and scopes.

Why check the audience if roles already decide? Roles say what the user may do, and the audience says which API the token was issued for. Without the audience check, a token that leaks from one service can be replayed against every other service.

Why 403 and not 401? Envoy answers a wrong audience with a 403 and the message "Audiences in Jwt are not allowed". A bad signature or an expired token gets a 401.

Why not always put reports-api in the token? Because of least privilege. A client only gets a token for the APIs it asks for, and it asks with scope=reports.

The browser token has both audiences, so is it too broad? A little. One browser session serves both APIs. The stricter setup is a separate login client for each API, which is more work.

What about one service calling another with the user's token? That is called token exchange, RFC 8693. The service swaps the token for a new one issued for the next API. It is out of scope for this talk.

Realm roles or client roles? Realm roles are for permissions that mean the same everywhere, like admin. Client roles are for permissions that belong to one API, like the editor role of reports-api.

The same idea exists in every major identity provider: Entra ID uses api://reports/.default, Auth0 has an audience parameter, and RFC 8707 standardizes it as resource indicators. RFC 9068 requires the aud claim in JWT access tokens.
-->

---
clicks: 7
routeAlias: b-s2s
---

<div class="kicker">Backup · service to service</div>

# What about one service calling another?

<QaFlow flow="s2s" />

<!--
A common question: what if one service calls another? Which token does it send? This isn't set up in the POC, but the same checks apply.

[click] Option 1: just forward the user's token. It was issued for service A, so service B's sidecar rejects it: wrong audience, 403. That's the audience check doing its job.

[click] Option 2: A gets its own token, with client credentials: its own client ID and secret.

[click] That token has no user in it. The subject is A's service account, the audience is B, and the roles are the service's roles.

[click] B's sidecar checks it like any other token. This fits jobs that act for themselves.

[click] Option 3: A acts on behalf of alice. It exchanges her token at Keycloak for a new one issued for B. That's OAuth token exchange.

[click] The new token is still alice, but now with B as the audience.

[click] So: acting for itself, use client credentials. Acting for a user, use token exchange. And never widen a token's audience just to make a call work.
-->

---
routeAlias: b-lessons
---

<div class="kicker">Backup · lessons from building the POC</div>

# Six issues we found

<div class="grid grid-cols-3 gap-3 mt-3 lessons">
  <div v-for="(l, i) in [
      { icon: 'i-carbon-time', t: 'JWKS race condition', d: 'istiod fetched Keycloak’s keys before Keycloak was up, used a placeholder key, and every JWT failed for ~20 min. Fix: restart istiod once Keycloak is ready.', chip: '401 Jwt verification fails', cls: 'red' },
      { icon: 'i-carbon-flow', t: 'Header rules are per route', d: 'The leaking x-auth-request-* headers came from the /oauth2/ route. A rule on the Spring route could never remove them.', chip: 'no EnvoyFilter needed', cls: 'green' },
      { icon: 'i-carbon-warning', t: 'ext_authz needs response headers', d: 'With upstream static://200, the token reaches Spring only as an oauth2-proxy response header. Turn that off and you get 403.', chip: 'RBAC: access denied', cls: 'red' },
      { icon: 'i-carbon-user-identification', t: 'Exceptions opened a spoofing gap', d: 'The CUSTOM policy skipped Bearer and non-browser requests, so a valid token plus a fake X-Auth-Request-User fooled Spring. Fix: no exceptions, and the sidecar writes identity from the token.', chip: 'outputClaimToHeaders', cls: 'green' },
      { icon: 'i-carbon-moon', t: 'The laptop slept, the mesh broke', d: 'Workload certificates expired during sleep, and every request got 503. Fix: make wake restarts them in order: gateways, Postgres’s sidecar, Keycloak, istiod, then the apps.', chip: 'make wake', cls: 'green' },
      { icon: 'i-carbon-password', t: 'The admin console needs the master realm', d: 'The gateway checks every Bearer token, even on keycloak.localhost. Admin tokens come from the master realm, so its issuer must be listed too.', chip: '401 Jwt issuer is not configured', cls: 'red' },
    ]" :key="l.t" class="card !p-4"
    v-motion :initial="{ opacity: 0, y: 40 }" :enter="{ opacity: 1, y: 0, transition: { delay: 150 + i * 180 } }">
    <span class="icon-dot orange mb-3"><span :class="l.icon" /></span>
    <h3>{{ l.t }}</h3>
    <p>{{ l.d }}</p>
    <div class="mt-3"><span class="chip" :class="l.cls">{{ l.chip }}</span></div>
  </div>
</div>

<style>
.lessons .card p { font-size: 0.68rem; line-height: 1.4; }
.lessons .card h3 { font-size: 0.9rem; }
</style>

<!--
We ran into six problems while building this.

The JWKS race: if Keycloak isn't ready when istiod fetches its keys, every token fails for about 20 minutes. We restart istiod once Keycloak is ready.

Header rules belong to one route. The leaking headers came from the /oauth2 route, so a rule on the Spring route could never remove them.

The token reaches Spring only as a header in OAuth2-Proxy's answer. Turn those headers off, and every browser request gets a 403.

The spoofing gap: our CUSTOM policy skipped requests with a bearer token. Anyone with a valid token could then send a fake X-Auth-Request-User, and Spring believed it. Now app.localhost has no exceptions, and the sidecar writes the identity headers from the verified token.

When the laptop sleeps, the mesh certificates expire, and every request gets a 503. One command fixes it: make wake restarts the pods in the right order.

And the Keycloak admin console sends master-realm tokens through the same gateway, so the gateway has to trust that issuer too, or the console gets a 401.
-->

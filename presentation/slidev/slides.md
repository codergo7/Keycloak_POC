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
    Gokhan Ozturk · 18/11/2016 - Lunch&Learn - Klarrio
  </div>
</div>

<!--
Welcome to the presentation about claims-based authorization using Keycloak, OAuth2-Proxy and Istio.

With this presentation I want to show you how we take security out of the application. Keycloak, OAuth2-Proxy and Istio decide who you are and what you may do, and the application keeps only its business rules. At the end I will change a user's access live, without touching any code.

I am not going to deep dive into each technology. I will summarize each one and show how they handle authentication and authorization together.

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

<p class="remember mt-6">The goal: <b>security out of the application.</b> The platform decides who you are and what you may do; the app keeps its business rules.</p>

<!--
The goal of this talk is in the line at the bottom: security out of the application. The platform decides who you are and what you may do, and the app keeps only its business rules. To get there, the talk has three parts.

[click] First is the theory, from authentication and authorization to tokens and the login flow.

[click] Then we look at the two ways into our POC: browser access for people, and API access for scripts that send a bearer token.

[click] Finally the live demo, one after each access path.
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
Authentication answers the question "who are you?". You claim an identity and then prove it, for example with a password. When authentication fails, the answer is 401, meaning the client must authenticate or log in to get the requested response

[click] Authorization answers the next question, "what are you allowed to do?". The decision is based on roles, scopes and claims, and Claims are simply the facts written in the token. When authorization fails, the answer is 403, which means we know who you are but you are not allowed to do this.

The order never changes, because we cannot decide what you may do until we know who you are.
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

<div class="kicker">Components</div>

# Four components, four jobs

<div class="grid grid-cols-4 gap-4 mt-5">
  <div v-for="(c, i) in [
      { icon: 'i-carbon-password', n: 'Keycloak', r: 'Identity provider', d: 'Knows the users, checks passwords, issues signed tokens.', cls: '' },
      { icon: 'i-carbon-earth', n: 'OAuth2-Proxy', r: 'Browser login', d: 'Runs the login flow for browsers and keeps the session cookie.', cls: '' },
      { icon: 'i-carbon-security', n: 'Istio', r: 'Policy enforcement', d: 'Validates tokens and applies access rules at the edge and at each pod.', cls: 'orange' },
      { icon: 'i-carbon-code', n: 'Spring Boot · FastAPI', r: 'Applications', d: 'Do their business job. No login code, no token parsing.', cls: 'navy' },
    ]" :key="c.n" class="card !p-4"
    v-motion :initial="{ opacity: 0, y: 50, rotateX: 40 }" :enter="{ opacity: 1, y: 0, rotateX: 0, transition: { delay: 120 + i * 160, type: 'spring', stiffness: 120, damping: 14 } }">
    <span class="icon-dot mb-3" :class="c.cls"><span :class="c.icon" /></span>
    <h3>{{ c.n }}</h3>
    <div class="mono text-xs mb-2" :class="i === 2 ? 'text-[var(--orange)]' : 'text-[var(--blue)]'">{{ c.r }}</div>
    <p>{{ c.d }}</p>
  </div>
</div>

<p v-click class="remember"><b>One line to remember:</b> Keycloak <i>authenticates the user</i>, OAuth2-Proxy <i>keeps the browser session</i>, Istio <i>enforces the policies</i>.</p>

<!--
Each of the four components has one job. Keycloak knows the users, checks their passwords and issues signed tokens. OAuth2-Proxy handles the login for browsers and keeps the session in a cookie. Istio verifies tokens and enforces the access rules. The applications, Spring Boot and FastAPI, do the business work. They are written in two languages, and neither contains any login or token code.

[click] You can remember it in one sentence: Keycloak authenticates the user, OAuth2-Proxy keeps the browser session, and Istio enforces the policies.
-->

---

<div class="kicker">Keycloak · the identity provider</div>

# Six terms you need for Keycloak

<div class="tbl-card mt-3">
<table class="tbl">
  <thead><tr><th>Term</th><th>In plain words</th><th>In our POC</th></tr></thead>
  <tbody>
    <tr v-click><td class="strong">Realm</td><td>An isolated space with its own users, roles and clients</td><td><code>demo</code></td></tr>
    <tr v-click><td class="strong">Client</td><td>An application registered in Keycloak: one that asks for tokens, or an API that receives them</td><td>asks: <code>oauth2-proxy</code> <code>cli-client</code><br>APIs: <code>spring-api</code> <code class="whitespace-nowrap">reports-api</code></td></tr>
    <tr v-click><td class="strong">User &amp; group</td><td>A person, and a team they belong to</td><td>alice, bob, admin · <code>/engineering</code> <code>/finance</code> <code>/finance/managers</code> <code>/admins</code></td></tr>
    <tr v-click><td class="strong">Realm &amp; client role</td><td>A permission label: realm roles are shared, client roles belong to one API. A composite role contains others</td><td>user, developer, admin · <code>reports-api</code>: viewer, editor (editor contains viewer)</td></tr>
    <tr v-click><td class="strong">Client scope</td><td>A named bundle of claims a client can request</td><td><code>groups</code> <code>app-audience</code> <code>reports</code></td></tr>
    <tr v-click><td class="strong">Protocol mapper</td><td>Rule that writes a fact into the token</td><td>groups, roles, audience</td></tr>
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

[click] A protocol mapper is a rule that writes a fact into the token.

[click] Groups can also carry roles. alice gets the developer role from the engineering group, and bob gets the reports viewer role from the finance group.
-->

---

<div class="kicker">OAuth2-Proxy · OIDC client for the browser</div>

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

[click] Fourth, it returns identity headers, including the access token, and Istio copies them into the request. This is the only way the token reaches the applications, so without these flags every browser request ends in a 403.
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
There are two ways to carry identity, and each one belongs to one access path.

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
  <div v-click class="card"><h3 class="!text-[var(--blue)]">Istio</h3><p>Checks at the ingress gateway, again at the sidecar</p></div>
</div>

<!--
Let's summarize what the browser saw. It saw the redirects, the login page, a one-time code and an encrypted cookie. It never saw the tokens, the client secret, or any call between the pods.

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
Alice is now logged in, but her access token only lives 5 minutes, and her Keycloak session ends after 30 idle minutes. Yet she notices nothing while she keeps working. This is how that works.

[click] 1. Alice clicks something more than 4 minutes after the last refresh.
[click] 2. OAuth2-Proxy checks the age of the cookie. If it is younger than 4 minutes, OAuth2-Proxy answers from the cookie alone, so a logout can take up to 4 minutes to take effect. Here it is older, so OAuth2-Proxy refreshes first.
[click] 3. OAuth2-Proxy sends the refresh token to Keycloak on the back channel, so the browser never sees it.
[click] 4. The session is still alive, so Keycloak resets the idle clock and returns fresh tokens.
[click] 5. OAuth2-Proxy issues a new cookie and the request continues to the application, so Alice notices nothing.

Now let's look at the same request after 45 idle minutes.
[click] 6. Keycloak ended the session after 30 idle minutes, so it refuses the refresh token with invalid_grant.
[click] 7. OAuth2-Proxy deletes its cookie and redirects the browser to Keycloak.
[click] 8. The Keycloak session is also gone, so Alice has to type her password again.
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
Now let's look at our proof of concept, which has two access paths to the same applications.

[click] Browser access goes through app.localhost, for a person in a browser. The gateway asks OAuth2-Proxy through ext_authz, and OAuth2-Proxy recognizes the person by the session cookie.

[click] API access goes through api.localhost, for a script that sends a bearer JWT. The gateway and the application's sidecar both validate the token, and the role claims decide what the caller may do.

[click] Both paths lead to the same result: claims signed by Keycloak and checked by Istio before any application sees the request.
-->

---
clicks: 12
---

<div class="kicker">Istio · ingress gateway and sidecar</div>

# Inside Envoy: one request, filter by filter

<EnvoyInside />

<!--
Istio does not run our rules itself. istiod turns each Istio resource into an Envoy filter, and the filters run in a fixed order. Let's follow alice's browser request to /api/headers through both proxies.

[click] 1. The first filter at the ingress gateway is ext_authz, configured by the AuthorizationPolicy with action CUSTOM. Envoy pauses the request and asks OAuth2-Proxy. OAuth2-Proxy checks the session cookie, answers 200, and adds the identity headers, including the access token.

[click] 2. The next filter is jwt_authn, configured by RequestAuthentication. At the gateway it only looks at the Authorization header, and a browser request has none. A missing token is not an error, so the request continues without a principal.

[click] 3. Then the rbac filter, configured by the AuthorizationPolicy with action ALLOW. It has a rule for app.localhost, so the request may pass. The gateway does not check claims here, because the CUSTOM check has already authenticated the user.

[click] 4. The router applies the VirtualService header rules, so the cookie is removed, and sends the request over mTLS to the Spring pod.

[click] 5. Now we are in the sidecar. Its jwt_authn filter is configured by the RequestAuthentication called keycloak-jwt. It finds the token in the X-Auth-Request-Access-Token header, because that header is listed under fromHeaders.

[click] 6. It decodes the token header and reads the key ID. It takes the key with the same ID from Keycloak's JWKS, which istiod fetched, and verifies the RS256 signature.

[click] 7. Then it decodes the payload and checks the claims: the issuer must be our realm, the token must not be expired, and the audience must be spring-api.

[click] 8. The token is valid, so the filter stores the result for the next filter: the principal, which is the issuer and the subject, and all claims as request.auth.claims. This is the key point: RequestAuthentication decodes the token, and the AuthorizationPolicy only reads the result.

[click] 9. The rbac filter now checks the ALLOW policy. The rule for /api/headers needs a principal, which we have, and a claim: realm_access.roles must contain developer. alice has it, so the request is allowed.

[click] 10. Spring receives the request with the identity headers and answers 200. Spring did not parse a token or check a role.

[click] 11. Now the same request from bob. His token is valid and passes every filter until the last one. His roles are only user, so no ALLOW rule matches, and the sidecar answers 403 before Spring sees the request.

[click] 12. And this is how the setup grows. The gateway stays the same, and its router sends each path to its backend. Every backend runs in its own namespace with its own sidecar, and next to it sits one pair of resources: a RequestAuthentication that accepts only tokens for that backend's audience, and an AuthorizationPolicy that says which claims each endpoint needs. The reports API in FastAPI already works this way. To add x-api, in any language, we do four things: register a client with its roles and an audience scope in Keycloak, create a namespace with sidecar injection, add the two resources, and add a route. The new application contains no security code, and the next backend follows the same steps.
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
    <tr><td class="faint">3</td><td>Open app.localhost/oauth2/auth</td><td><span class="code-200">202</span>, identity headers stripped by the route</td></tr>
  </tbody>
</table>
</div>

<p class="remember">Spring knows <b>who</b> alice is, but never sees her session, and nothing sensitive comes back to the browser.</p>

<!--
Now I will show browser access live. I use a private window, so the browser has no cookies from earlier. Before each step I will say what I expect, and then we check it.

**1 · No session: the login page**

*Do: open a private window and go to app.localhost:8080/api/whoami.*

The browser has no session cookie yet, so I expect the gateway to send me to Keycloak instead of to Spring.

*Result: the Keycloak page "Sign in to Demo".*

The gateway's CUSTOM policy asked OAuth2-Proxy whether this request is logged in. OAuth2-Proxy found no session and answered with a 302 to Keycloak. In the address bar you can see client_id=oauth2-proxy, and a redirect_uri that points back to /oauth2/callback. Spring has not been called at all.

**2 · Log in as alice: Spring knows who she is**

*Do: log in as alice, password alice.*

The password goes only to Keycloak. Our application never sees it.

*Result: the JSON from /api/whoami.*

The browser is back on /api/whoami, and this time Spring answers. xAuthRequestUser is alice's user ID in Keycloak, and xAuthRequestEmail is her email. Spring did not read a token or a cookie to get them: OAuth2-Proxy put them in identity headers at the gateway.

*Do: open app.localhost:8080/api/headers.*

This endpoint lists every header that Spring received, and alice may call it because she has the developer role. There is no cookie header: the gateway removed the session cookie after OAuth2-Proxy had checked it. There is an x-auth-request-access-token header, and Spring's sidecar validated that token and checked her role before the request arrived. So Spring knows who alice is, but it never sees her session.

**3 · Nothing sensitive goes back to the browser**

*Do: open the developer tools on the Network tab, then go to app.localhost:8080/oauth2/auth and click the request to see its response headers.*

This is OAuth2-Proxy's own check endpoint. It answers 202 when the session is valid. Without our route rule, it would also send the identity headers and the access token back to the browser.

*Result: 202, and no X-Auth-Request headers in the response.*

A response rule on the /oauth2 route removes them. The only identity header left is GAP-Auth, OAuth2-Proxy's own header with alice's user ID, and that is not a secret.

To sum up: the browser only holds an encrypted cookie, Spring gets the identity in headers, and the tokens stay inside the cluster.
-->

---
clicks: 10
---

<div class="kicker">API access · a script with a user token · api.localhost</div>

# Inside Envoy: the same filters, the API path

<EnvoyInside mode="api" />

<!--
Now the same view for API access. A script, in our demo plain curl, calls api.localhost with alice's access token in the Authorization header. There is no browser and no cookie. The script also sends its own X-Auth-Request-User header that claims to be admin. On the browser path OAuth2-Proxy sets that header, but here nobody does, so this one is fake: the script is trying to fool the application.

[click] 1. The first filter is ext_authz again. But the CUSTOM policy only matches app.localhost, so Envoy skips it and OAuth2-Proxy is not called. OAuth2-Proxy is for browsers; an API client brings its own token.

[click] 2. Now jwt_authn at the gateway has real work to do. The RequestAuthentication demo-jwt-validation finds the bearer token, takes the key with the same key ID from Keycloak's JWKS, and verifies the signature. It checks the issuer and the expiry, but not the audience. The result is the principal: the issuer and the subject of the token.

[click] 3. rbac at the gateway. For api.localhost, the ALLOW rule needs a principal, which means any valid token. It does not look at roles yet. So the gateway answers the question: is there a valid token from our Keycloak?

[click] 4. The router. api.localhost has no ext_authz, so an X-Auth-Request header can only come from the client. The VirtualService removes all of them, so our fake admin header is gone before it reaches Spring. The Authorization header stays. We will try exactly this in check 5 of the demo.

[click] 5. In the Spring sidecar, the RequestAuthentication keycloak-jwt reads the same token from the Authorization header and verifies it again. This time it also checks the audience: the token must be issued for spring-api. Then it stores the claims for the next filter.

[click] 6. rbac at the sidecar. The rule for /api/user needs the realm role user, and alice has it.

[click] 7. Spring receives the request and answers 200. It did not verify the token, and it never saw the fake header.

Now three requests that fail, each at a different filter.

[click] 8. No token at all. RequestAuthentication lets the request pass, because a missing token is not a bad token. But there is no principal, so the gateway's ALLOW rule does not match: 403 at the gateway. This is why RequestAuthentication and AuthorizationPolicy always come as a pair.

[click] 9. A tampered token: I change one character. The signature no longer matches, so the gateway's jwt_authn answers 401, and no AuthorizationPolicy is reached.

[click] 10. alice calls /api/admin. Her token is valid, so the gateway lets the request in. The role check happens next to the API: alice has no admin role, so the Spring sidecar answers 403.

So the gateway asks whether there is a valid token, and the sidecar asks whether this token is meant for this API and has the right role. We will see all of this live in the demo.
-->

---

<div class="kicker">API access · api.localhost · Spring Boot and FastAPI</div>

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
Every endpoint asks for a claim in the token. The Spring endpoints check realm roles, and the reports API checks its own client roles. These are two applications in two languages, and neither contains any security code: the same Istio resources protect both.

[click] /api/public needs no claim, so everyone gets a 200.
[click] /api/user needs the realm role user, and all three users have it.
[click] /api/headers needs the realm role developer, so only alice gets a 200. She has this role through her engineering group.
[click] /api/admin needs the realm role admin, so only the admin user gets a 200.
[click] Reading reports needs the viewer role of reports-api. Only bob gets a 200, through his finance group. alice is a developer, but that realm role means nothing to the reports API.
[click] Creating a report needs the editor role, and nobody has it yet. We will change that in the demo.

[click] The reports API also checks the audience. A token only contains reports-api in its audience when the client asks for the reports scope. Without it, the reports sidecar rejects the token with a 403, even for bob. The audience check stops a token issued for one API from being replayed against another, even when the token is valid and the user has the right roles.
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
    <tr><td class="faint">5</td><td>alice token + fake <code>X-Auth-Request-User: admin</code> → /api/headers</td><td><span class="code-200">200</span>, header removed</td></tr>
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
Now API access, in the terminal. For each check, the script shows a short explanation, the policy snippet and the curl command, and then it waits. I say what I expect, press Enter, and the real answer from the cluster appears. Then I press Enter again for the next check.

*Do: run make demo-api.*

**1 · Public endpoint, no token**

*On screen: the ALLOW rule for GET /api/public.*

This rule has no from block, so it does not ask for a principal, and anyone matches it. I expect a 200.

*Enter. Result: 200.*

Public endpoints are declared in the policy, not in the application.

**2 · Protected endpoint, no token**

*On screen: the ALLOW rule with requestPrincipals ["*"].*

Now /api/user, again without a token. RequestAuthentication has nothing to check, so it lets the request continue. But this rule needs requestPrincipals star, which means any verified token. A principal is the issuer and the subject of a verified token, so without a token there is no principal, and no rule matches. I expect a 403.

*Enter. Result: 403, RBAC: access denied.*

This is why we always pair the two resources: RequestAuthentication checks tokens, but only the AuthorizationPolicy requires one.

**3 · Tampered token**

*On screen: RequestAuthentication demo-jwt-validation, with the issuer and the jwksUri.*

I take a real token for alice and add one character at the end, so the signature no longer matches. The gateway verifies the signature with Keycloak's public keys from the jwksUri. I expect a 401.

*Enter. Result: 401, Jwt verification fails.*

A token that is present but invalid is rejected before any policy runs. A 401 means: I don't know who you are.

**4 · alice: user yes, admin no**

*On screen: alice's principal, her claims with the realm roles user and developer, and the Spring ALLOW rules.*

Now alice's real token. The script shows her principal, which is the issuer and her subject, and her realm roles, user and developer. At the Spring sidecar, every rule needs the principal and a role in the token. First /api/user, which needs the role user. I expect a 200.

*Enter. Result: 200.*

Next /api/admin, which needs the role admin. Her token is valid, but she does not have that role. I expect a 403.

*Enter. Result: 403, RBAC: access denied.*

The token is fine, but the claim is missing. A 403 means: I know who you are, and the answer is no.

**5 · A fake identity header**

*On screen: the VirtualService api, with the list of X-Auth-Request headers it removes.*

In the browser demo, Spring got alice's identity from X-Auth-Request headers that OAuth2-Proxy added. What if a script simply sends such a header itself? alice now sends X-Auth-Request-User: admin to /api/headers, which lists every header that Spring receives. On api.localhost there is no ext_authz, so this header can only come from the client, and the VirtualService removes it. I expect a 200, and no X-Auth-Request header at Spring.

*Enter. Result: 200, and "X-Auth-Request headers that Spring received: none".*

Spring can trust these headers because only OAuth2-Proxy can set them: anything a client sends is removed at the gateway. This is click 4 of the Inside Envoy slide for API access, live.

**6 · bob without the reports scope**

*On screen: bob's claims, with aud only spring-api, and the reports RequestAuthentication with audiences reports-api.*

bob is in the finance group, so he has the viewer role of the reports API. But this token was requested without the reports scope, so its audience is only spring-api. The reports sidecar only accepts tokens that were issued for reports-api. I expect a 403 with the message "Audiences in Jwt are not allowed".

*Enter. Result: 403, Audiences in Jwt are not allowed.*

The token is correctly signed and bob has the right role, but the token was not issued for this API. The audience check stops a token for one API from being used against another.

**7 · bob with the reports scope**

*On screen: the new token, with reports-api in aud and viewer in the reports-api roles, and the reports ALLOW rules.*

Same user, but a new token, requested with scope=reports. Now the audience contains reports-api, and the token carries bob's client role viewer. Reading reports needs viewer, so I expect a 200.

*Enter. Result: 200 and the list of reports.*

Creating a report needs the editor role, and bob is only a viewer. I expect a 403.

*Enter. Result: 403, RBAC: access denied.*

The reports API is written in Python with FastAPI, and it has no security code at all. The same Istio resources protect the Java app and the Python app.

**8 · Add bob to the managers group**

*On screen: the admin console path, and the admin API call.*

In Keycloak's admin console, I would open Users, then bob, then Groups, and join finance managers. The script does the same through the Keycloak admin API.

*Enter: bob joins /finance/managers, and the script gets a new token.*

The new token now has editor in bob's reports-api roles, because the managers group gives editor. The user is the same and the policy is the same. I expect the POST to give a 201 now.

*Enter. Result: 201 Created.*

Nothing changed in the code, in the policy, or in the deployment. Only a group membership in Keycloak changed, and the claim in the token did the rest.

*Enter for the summary.*

The script removes bob from the group again, so the demo can be repeated, and all ten checks behaved as expected.
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
    <tr v-click><td class="faint">4</td><td class="strong">Business AuthZ</td><td>Is this action allowed today?</td><td class="font-bold text-[var(--orange)]">The application (Spring Boot, FastAPI)</td></tr>
  </tbody>
</table>
</div>

<p v-click class="remember">The platform answers 1 to 3. <b>The application only owns row 4:</b> real business rules.</p>

<!--
To put it all together, there are four questions, and each one is answered by one layer.

[click] Who is the user? Keycloak answers this, with help from OAuth2-Proxy for browsers.
[click] Is the token real and meant for us? RequestAuthentication answers this.
[click] Do the token's claims allow this path? AuthorizationPolicy answers this.
[click] Is this action allowed today? This is a business rule, so the application answers it, in Spring Boot or FastAPI.

[click] The platform answers the first three questions, and the application only owns the business rules.
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
      { t: 'Claims, not code', d: 'Roles in the token decide access, checked at the gateway and again at the pod.' },
    ]" :key="t.t" class="card !p-5"
    v-motion :initial="{ opacity: 0, scale: 0.9 }" :enter="{ opacity: 1, scale: 1, transition: { delay: 100 + i * 150 } }">
    <h3 class="!text-lg">{{ t.t }}</h3>
    <p>{{ t.d }}</p>
  </div>
</div>

<p class="mt-5 text-lg text-white">Security is out of the application: the platform decides <b>who</b> and <b>what</b>, the app keeps its business rules.</p>

<div class="mt-5 flex items-end justify-between">
  <div class="text-4xl font-bold text-white" v-click>Questions?</div>
</div>

<!--
Here are four things to remember from this talk.

A 401 means we do not know who you are, and a 403 means we know you but the answer is no.

Keycloak authenticates the user, OAuth2-Proxy keeps the browser session, and Istio enforces the policies.

Always pair RequestAuthentication with an AuthorizationPolicy, because otherwise requests with no token get through.

Roles in the token decide access, so we can change access without changing code. We saw it with two applications in two languages, and neither contains a single line of security code.

And that brings us back to where we started: security is out of the application. The platform decides who you are and what you may do, and the application keeps only its business rules.

[click] That is all from me. Do you have any questions?
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
These are backup slides. I only show them if someone asks about one of these topics: the exact order of checks inside Envoy, where six different requests stop, the browser access policy, the sensitive headers, how long a login lasts, where the session cookie goes, how audiences and scopes work, the issues we found while building the POC, what logout ends, what happens when Keycloak is down, whether headers can be faked, how to debug a 401 or 403, or whether authorization belongs in the mesh or the app.
-->

---
clicks: 9
---

<div class="kicker">Backup · Inside Envoy · real filter order</div>

# One request, nine checks in Envoy

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
[click] 7. The JWT is validated again, and this time the audience must be spring-api. A bad token gets a 401, and a token issued for another audience gets a 403.
[click] 8. The ALLOW policy checks whether the role claim matches the path, otherwise the answer is 403.
[click] 9. Finally, Spring receives the request with the identity headers.

Remember that OAuth2-Proxy runs before the JWT check, and that the header rules run last.
-->

---
clicks: 6
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

<div class="kicker">Backup · browser access · app.localhost</div>

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

[click] The policy only applies to real browser traffic. It skips the /oauth2 paths, the public endpoint and the health check, and it also skips requests that carry a bearer token or that do not come from a browser.

[click] This VirtualService is for the /oauth2 route. It removes the identity headers from OAuth2-Proxy's replies, so they do not leak back to the browser.

[click] The Spring route removes the cookie after OAuth2-Proxy has checked it, so Spring never sees the session.
-->

---
clicks: 7
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
clicks: 5
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
clicks: 5
---

<div class="kicker">Backup · session cookie path</div>

# The session cookie goes to ext_authz, not to the app

<CookieJourney />

<!--
Let's follow the session cookie through one request.

[click] 1. The browser sends the session cookie to the gateway.
[click] 2. The gateway passes the cookie to OAuth2-Proxy, which uses it to check the session.
[click] 3. OAuth2-Proxy answers 200 and returns the identity headers to the gateway.
[click] 4. The router removes the cookie, and only the identity headers continue to Spring.
[click] 5. On the way back, no identity header is returned to the browser. The browser only gets a new cookie when the session was refreshed.
-->

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
This backup slide answers the questions people usually ask about audiences and scopes. I only show it if one of them comes up. There are no animations.

Why check the audience if roles already decide? Roles say what the user may do, and the audience says which API the token was issued for. Without the audience check, a token that leaks from one service can be replayed against every other service.

Why 403 and not 401? Envoy answers a wrong audience with a 403 and the message "Audiences in Jwt are not allowed". A bad signature or an expired token gets a 401.

Why not always put reports-api in the token? Because of least privilege. A client only gets a token for the APIs it asks for, and it asks with scope=reports.

The browser token has both audiences, so is it too broad? A little. One browser session serves both APIs. The stricter setup is a separate login client for each API, which is more work.

What about one service calling another with the user's token? That is called token exchange, RFC 8693. The service swaps the token for a new one issued for the next API. It is out of scope for this talk.

Realm roles or client roles? Realm roles are for permissions that mean the same everywhere, like admin. Client roles are for permissions that belong to one API, like the editor role of reports-api.

The same idea exists in every major identity provider: Entra ID uses api://reports/.default, Auth0 has an audience parameter, and RFC 8707 standardizes it as resource indicators. RFC 9068 requires the aud claim in JWT access tokens.
-->

---

<div class="kicker">Backup · lessons from building the POC</div>

# Three issues we found

<div class="grid grid-cols-3 gap-4 mt-5">
  <div v-for="(l, i) in [
      { icon: 'i-carbon-time', t: 'JWKS race condition', d: 'istiod fetched Keycloak’s keys before Keycloak was up, used a placeholder key, and every JWT failed for ~20 min. Fix: restart istiod once Keycloak is ready.', chip: '401 Jwt verification fails', cls: 'red' },
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

The first is a race condition with the JWKS. If Keycloak is not ready when istiod fetches its public keys, istiod uses a placeholder key for about 20 minutes, and every token fails with a 401. The fix is to restart istiod once Keycloak is ready.

The second is that header rules belong to a single route. The leaking headers came from the /oauth2 route, so a rule on the Spring route could never remove them.

The third is that the token reaches Spring only as a header in OAuth2-Proxy's answer. If you turn off those response headers, every browser request gets a 403.
-->

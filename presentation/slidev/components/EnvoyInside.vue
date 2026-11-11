<script setup lang="ts">
// One browser request (alice → app.localhost/api/headers) through the ingress gateway
// and the Spring sidecar, filter by filter: ext_authz (AuthorizationPolicy CUSTOM),
// jwt_authn (RequestAuthentication), rbac (AuthorizationPolicy ALLOW), router (VirtualService).
// The sidecar's jwt_authn decodes the token and stores its claims; rbac then reads them.
// Click 11 repeats the request as bob, who has no developer role. The slide needs `clicks: 11`.
// Token values (alg, kid, roles, aud) were taken from a real token of the running POC.
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $clicks } = useSlideContext()
const s = computed(() => Math.min(Math.max($clicks.value, 0), 11))
const bob = computed(() => s.value === 11)

interface Filter { f: string; res: string; act?: string; ok: string }
const ingress: Filter[] = [
  { f: 'ext_authz', res: 'AuthorizationPolicy', act: 'CUSTOM', ok: '200 ✓' },
  { f: 'jwt_authn', res: 'RequestAuthentication', ok: 'no token' },
  { f: 'rbac', res: 'AuthorizationPolicy', act: 'ALLOW', ok: 'ALLOW ✓' },
  { f: 'router', res: 'VirtualService', ok: '− cookie' },
]
const sidecar: Filter[] = [
  { f: 'jwt_authn', res: 'RequestAuthentication', ok: 'valid ✓' },
  { f: 'rbac', res: 'AuthorizationPolicy', act: 'ALLOW', ok: 'ALLOW ✓' },
]
// which stage is active at each click (0–3 ingress, 4–5 sidecar, 6 the app)
const ACTIVE = [-1, 0, 1, 2, 3, 4, 4, 4, 4, 5, 6, 5]

function state(i: number) {
  if (bob.value) return i < 5 ? 'done' : i === 5 ? 'fail' : 'todo'
  const a = ACTIVE[s.value]
  if (a < 0 || i > a) return 'todo'
  return i === a ? 'on' : 'done'
}
function verdict(i: number, f: Filter) {
  if (state(i) === 'fail') return '✕ 403'
  if (i === 4 && s.value >= 5 && s.value <= 7) return 'decoding…'
  return f.ok
}

const user = computed(() => (bob.value ? 'bob' : 'alice'))
const sub = computed(() => (bob.value ? 'b774…' : '44554fc9…'))
const roles = computed(() => (bob.value ? ['user'] : ['developer', 'user']))

const headers = computed(() => [
  { k: 'GET', v: '/api/headers', show: true },
  { k: 'Host', v: 'app.localhost', show: true },
  { k: 'Cookie', v: '_oauth2_proxy=…', show: true, gone: s.value >= 4 },
  { k: 'X-Auth-Request-User', v: user.value, show: s.value >= 1, fresh: s.value === 1 },
  { k: 'X-Auth-Request-Access-Token', v: 'eyJhbGciOiJSUzI1NiIs…', show: s.value >= 1, fresh: s.value === 1, hl: s.value === 5 },
])

// col 2: what happens inside the filter
const view = computed(() => {
  const v = s.value
  if (v === 0) return 'intro'
  if (v === 1) return 'ext'
  if (v === 2) return 'nojwt'
  if (v === 3) return 'rbacin'
  if (v === 4) return 'router'
  if (v <= 8) return 'decode'
  return 'claims'
})

// col 3: the Istio resource that configures the active filter
type Line = { t: string; hl?: boolean; mark?: '✓' | '✕' }
const yaml = computed<{ file: string; lines: Line[] } | null>(() => {
  const v = s.value
  if (v === 1) return { file: 'ingress-authorization.yaml', lines: [
    { t: 'kind: AuthorizationPolicy' },
    { t: 'metadata: { name: oauth2-external-auth }' },
    { t: 'spec:' },
    { t: '  action: CUSTOM', hl: true },
    { t: '  provider: { name: oauth2-proxy }', hl: true },
    { t: '  rules:' },
    { t: '  - to:' },
    { t: '    - operation:' },
    { t: '        hosts: [app.localhost]', hl: true, mark: '✓' },
    { t: '        notPaths: [/oauth2/*, /api/public, …]' },
  ] }
  if (v === 2) return { file: 'ingress-authorization.yaml', lines: [
    { t: 'kind: RequestAuthentication' },
    { t: 'metadata: { name: demo-jwt-validation }' },
    { t: 'spec:' },
    { t: '  jwtRules:' },
    { t: '  - issuer: http://keycloak.localhost:8080/realms/demo' },
    { t: '    jwksUri: …/realms/demo/protocol/openid-connect/certs' },
    { t: '    # no fromHeaders: only Authorization: Bearer', hl: true },
  ] }
  if (v === 3) return { file: 'ingress-authorization.yaml', lines: [
    { t: 'kind: AuthorizationPolicy' },
    { t: 'metadata: { name: ingress-authorization }' },
    { t: 'spec:' },
    { t: '  action: ALLOW', hl: true },
    { t: '  rules:' },
    { t: '  - to: [{ operation: { hosts: [keycloak.localhost] } }]' },
    { t: '  - to: [{ operation: { hosts: [app.localhost] } }]', hl: true, mark: '✓' },
    { t: '  - from: [{ source: { requestPrincipals: ["*"] } }]' },
    { t: '    to: [{ operation: { hosts: [api.localhost], … } }]' },
  ] }
  if (v === 4) return { file: 'oauth2-proxy.yaml', lines: [
    { t: 'kind: VirtualService' },
    { t: 'spec:' },
    { t: '  hosts: [app.localhost]' },
    { t: '  http:' },
    { t: '  - route:' },
    { t: '    - destination: { host: spring-app.spring-api… }' },
    { t: '    headers:' },
    { t: '      request:' },
    { t: '        remove: [cookie]', hl: true, mark: '✓' },
  ] }
  if (v >= 5 && v <= 8) return { file: 'auth-app.yaml', lines: [
    { t: 'kind: RequestAuthentication' },
    { t: 'metadata: { name: keycloak-jwt }' },
    { t: 'spec:' },
    { t: '  selector: { matchLabels: { app: spring-app } }' },
    { t: '  jwtRules:' },
    { t: '  - issuer: http://keycloak.localhost:8080/realms/demo', hl: v === 7, mark: v >= 7 ? '✓' : undefined },
    { t: '    jwksUri: …/realms/demo/protocol/openid-connect/certs', hl: v === 6, mark: v >= 6 ? '✓' : undefined },
    { t: '    audiences: [spring-api]', hl: v === 7, mark: v >= 7 ? '✓' : undefined },
    { t: '    fromHeaders:', hl: v === 5 },
    { t: '    - name: Authorization   # prefix "Bearer "', hl: v === 5 },
    { t: '    - name: X-Auth-Request-Access-Token', hl: v === 5, mark: '✓' },
  ] }
  if (v === 9 || v === 11) return { file: 'auth-app.yaml', lines: [
    { t: 'kind: AuthorizationPolicy' },
    { t: 'metadata: { name: spring-workload-authorization }' },
    { t: 'spec:' },
    { t: '  action: ALLOW' },
    { t: '  rules:' },
    { t: '  - from:' },
    { t: '    - source:' },
    { t: '        requestPrincipals: ["*"]', hl: true, mark: '✓' },
    { t: '    to:' },
    { t: '    - operation: { methods: [GET], paths: [/api/headers] }', hl: true, mark: '✓' },
    { t: '    when:' },
    { t: '    - key: request.auth.claims[realm_access][roles]', hl: true },
    { t: '      values: ["developer"]', hl: true, mark: v === 11 ? '✕' : '✓' },
  ] }
  return null
})

const caption = computed(() => [
  'alice’s browser sends GET app.localhost/api/headers with her session cookie. Two Envoy proxies check it before Spring sees it.',
  'ext_authz: the CUSTOM policy makes Envoy pause the request and ask OAuth2-Proxy. It answers 200 and adds the identity headers.',
  'jwt_authn at the gateway: no Authorization: Bearer header, so there is nothing to validate. A missing token is not an error.',
  'rbac at the gateway: the ALLOW policy has a rule for app.localhost, so the request may pass. OAuth2-Proxy already checked the user.',
  'router: the VirtualService removes the cookie and the request goes over mTLS to the Spring pod.',
  'jwt_authn at the sidecar: RequestAuthentication finds the token in X-Auth-Request-Access-Token.',
  'It decodes the header, finds the key with the same kid in Keycloak’s JWKS, and verifies the RS256 signature.',
  'It decodes the payload and checks the issuer, the expiry and the audience spring-api.',
  'It stores the result for the next filter: the principal (iss/sub) and the claims, as request.auth.claims.',
  'rbac at the sidecar: the ALLOW policy reads request.auth.claims. The rule for /api/headers needs the role developer, and alice has it.',
  'Spring receives the request with the identity headers and answers 200. It contains no token or login code.',
  'Same request as bob: the token is valid, but his roles are only ["user"]. No ALLOW rule matches, so the sidecar answers 403.',
][s.value])
</script>

<template>
  <div class="ei">
    <!-- the pipeline -->
    <div class="pipe">
      <div class="end" :class="{ on: s === 0 }">
        <div class="end-name">Browser</div><small>{{ user }}</small>
      </div>
      <div class="link" :class="{ lit: s >= 1 }"><span /></div>

      <div class="proxy gw">
        <div class="proxy-label">Ingress gateway <span>· Envoy · istio-system</span></div>
        <div class="filters">
          <div v-for="(f, i) in ingress" :key="'g' + i" class="pill" :class="state(i)">
            <i v-if="state(i) === 'on'" :key="'p' + s" class="packet" />
            <div class="f">{{ f.f }}<b v-if="f.act" class="act">{{ f.act }}</b></div>
            <div class="res">{{ f.res }}</div>
            <div class="verdict">{{ verdict(i, f) }}</div>
          </div>
        </div>
        <div class="ext" :class="{ on: s === 1, done: s > 1 }">
          <span class="ext-arrow">⇅</span> OAuth2-Proxy <small>external authorizer</small>
        </div>
      </div>

      <div class="link" :class="{ lit: s >= 5 }"><span /><em>mTLS</em></div>

      <div class="proxy sc">
        <div class="proxy-label">Sidecar <span>· Envoy · spring-api</span></div>
        <div class="filters">
          <div v-for="(f, i) in sidecar" :key="'s' + i" class="pill" :class="state(i + 4)">
            <i v-if="state(i + 4) === 'on'" :key="'p' + s" class="packet" />
            <div class="f">{{ f.f }}<b v-if="f.act" class="act">{{ f.act }}</b></div>
            <div class="res">{{ f.res }}</div>
            <div class="verdict">{{ verdict(i + 4, f) }}</div>
          </div>
        </div>
        <div class="ext" :class="{ on: s === 6, done: s > 6 }">
          <span class="ext-arrow">⤓</span> JWKS <small>public keys, via istiod</small>
        </div>
      </div>

      <div class="link" :class="{ lit: s === 10 }"><span /></div>
      <div class="end app" :class="{ on: s === 10, off: bob }">
        <div class="end-name">Spring</div><small>{{ s === 10 ? '200 OK' : bob ? 'not reached' : ':8080' }}</small>
      </div>
    </div>

    <!-- the detail -->
    <div class="detail">
      <!-- col 1: the request -->
      <div class="col">
        <div class="col-title">The request</div>
        <div class="req">
          <TransitionGroup name="hdr">
            <div v-for="h in headers.filter(h => h.show)" :key="h.k" class="hdr"
              :class="{ gone: h.gone, fresh: h.fresh, hl: h.hl }">
              <span class="k">{{ h.k }}:</span> <span class="v">{{ h.v }}</span>
            </div>
          </TransitionGroup>
        </div>
      </div>

      <!-- col 2: inside the filter -->
      <div class="col">
        <div class="col-title">Inside the filter</div>
        <Transition name="view" mode="out-in">
          <div v-if="view === 'intro'" key="intro" class="hint">
            Each Istio resource becomes an Envoy filter. Click to follow the request through every filter.
          </div>

          <div v-else-if="view === 'ext'" key="ext" class="box">
            <div class="call out">→ OAuth2-Proxy: GET /api/headers + Cookie</div>
            <div class="call back">← <b>200</b> + X-Auth-Request-User, -Email, -Access-Token</div>
            <p>OAuth2-Proxy decrypts the cookie; it does not call Keycloak. Envoy copies the allowed headers into the request (<span class="mono">headersToUpstreamOnAllow</span>).</p>
          </div>

          <div v-else-if="view === 'nojwt'" key="nojwt" class="box">
            <div class="call muted">Authorization: <i>(none)</i></div>
            <p>Nothing to validate, so no principal is set and the request continues. RequestAuthentication only <b>rejects bad tokens</b>; it never requires one.</p>
          </div>

          <div v-else-if="view === 'rbacin'" key="rbacin" class="box">
            <div class="call ok">rule 2 matches · ALLOW</div>
            <p>The gateway does not look at claims for app.localhost. The CUSTOM check has already authenticated the browser.</p>
          </div>

          <div v-else-if="view === 'router'" key="router" class="box">
            <div class="call ok">Cookie removed · → spring-app:8080</div>
            <p>The VirtualService header rules run last, in the router. Spring never sees the session cookie.</p>
          </div>

          <div v-else-if="view === 'decode'" key="decode" class="box decode">
            <div class="jwt" :class="{ split: s >= 6, scan: s === 5 }">
              <span class="seg h">eyJhbGciOiJSUzI1NiIs…</span><span class="dot">.</span><span class="seg p">eyJleHAiOjE3OTQz…</span><span class="dot">.</span><span class="seg sig">QtWjd_fIzyiPmkBe…</span>
            </div>
            <div v-if="s >= 6" class="part h">
              <span class="tag">header</span> alg: RS256 · kid: hNUlgCrX…
              <div class="match">kid = JWKS key hNUlgCrX… → <b>signature ✓</b></div>
            </div>
            <div v-if="s >= 7" class="part p">
              <span class="tag">payload</span>
              <div class="claim"><span>iss</span> …/realms/demo <b>✓</b></div>
              <div class="claim"><span>aud</span> spring-api <b>✓</b></div>
              <div class="claim"><span>exp</span> 12:15:25, not expired <b>✓</b></div>
              <div class="claim"><span>realm_access.roles</span> ["developer", "user"]</div>
            </div>
            <div v-if="s >= 8" class="part out">
              <span class="tag">stored for rbac</span>
              <div class="claim"><span>principal</span> …/realms/demo/44554fc9…</div>
              <div class="claim"><span>request.auth.claims</span> the payload above</div>
            </div>
          </div>

          <div v-else key="claims" class="box decode">
            <div class="part out">
              <span class="tag">from jwt_authn</span>
              <div class="claim"><span>principal</span> …/realms/demo/{{ sub }} <b class="okc">✓</b></div>
              <div class="claim"><span>claims.preferred_username</span> {{ user }}</div>
              <div class="claim"><span>claims.aud</span> spring-api</div>
              <div class="claim roles"><span>claims.realm_access.roles</span>
                [<template v-for="(r, i) in roles" :key="r"><em :class="{ hit: r === 'developer' && s === 9 }">"{{ r }}"</em><template v-if="i < roles.length - 1">, </template></template>]
                <b v-if="s === 9" class="okc">developer ✓</b>
                <b v-if="bob" class="bad">no developer ✕</b>
              </div>
            </div>
            <p v-if="s === 10">Spring reads <span class="mono">X-Auth-Request-User</span>. It never parses the token.</p>
            <p v-if="bob" class="badp">403 RBAC: access denied, from the sidecar. The token was valid; the claim was missing.</p>
          </div>
        </Transition>
      </div>

      <!-- col 3: the Istio resource -->
      <div class="col">
        <div class="col-title">The Istio resource <span v-if="yaml" class="file">{{ yaml.file }}</span></div>
        <Transition name="view" mode="out-in">
          <div v-if="yaml" :key="yaml.lines[1].t" class="yaml">
            <div v-for="(l, i) in yaml.lines" :key="i" class="yl" :class="{ hl: l.hl }">
              <span>{{ l.t }}</span><b v-if="l.mark" :class="l.mark === '✕' ? 'bad' : 'okc'">{{ l.mark }}</b>
            </div>
          </div>
          <div v-else-if="s === 10" key="app" class="hint">
            No Istio resource here: the request has passed every filter. <b>200 OK.</b>
          </div>
          <div v-else key="none" class="hint">The resource that configures the active filter appears here.</div>
        </Transition>
      </div>
    </div>

    <Transition name="cap" mode="out-in">
      <div :key="s" class="caption" :class="{ bad: bob }"><b>{{ s }}</b> {{ caption }}</div>
    </Transition>
  </div>
</template>

<style scoped>
.ei { --navy: #14213d; --blue: #2459c9; --orange: #c2570c; --green: #1f8a5b; --red: #c0352b; --muted: #7a8496; }
.mono { font-family: 'JetBrains Mono', monospace; }

/* pipeline */
.pipe { display: flex; align-items: stretch; gap: 0; }
.end {
  flex: none; width: 70px; border-radius: 10px; background: #e6eaf2; display: flex; flex-direction: column;
  justify-content: center; align-items: center; transition: all 0.4s;
}
.end-name { font-weight: 700; font-size: 0.8rem; color: var(--navy); }
.end small { font: 500 0.55rem 'JetBrains Mono', monospace; color: var(--muted); }
.end.on { background: var(--navy); box-shadow: 0 0 0 4px rgba(36, 89, 201, 0.25); }
.end.on .end-name, .end.on small { color: #fff; }
.end.app.on { background: var(--green); box-shadow: 0 0 0 4px rgba(31, 138, 91, 0.25); }
.end.off { opacity: 0.35; }

.link { flex: none; width: 26px; position: relative; display: flex; align-items: center; }
.link span { display: block; width: 100%; height: 2px; background: #d5d9e2; position: relative; overflow: hidden; }
.link span::after {
  content: ''; position: absolute; inset: 0; background: var(--blue); transform: translateX(-100%);
  transition: transform 0.5s ease-out;
}
.link.lit span::after { transform: translateX(0); }
.link em { position: absolute; top: 34%; left: 50%; transform: translateX(-50%); font: 600 0.45rem 'JetBrains Mono', monospace; color: var(--muted); font-style: normal; }

.proxy { flex: 1; min-width: 0; border: 1.5px dashed #b8c3d8; border-radius: 12px; padding: 0.3rem 0.4rem 0.35rem; background: rgba(255, 255, 255, 0.55); }
.proxy.gw { flex: 2.2; }
.proxy.sc { flex: 1.25; }
.proxy-label { font: 700 0.58rem 'JetBrains Mono', monospace; text-transform: uppercase; letter-spacing: 0.06em; color: var(--navy); margin-bottom: 0.25rem; }
.proxy-label span { color: var(--muted); font-weight: 500; text-transform: none; letter-spacing: 0; }
.filters { display: flex; gap: 0.3rem; }

.pill {
  position: relative; flex: 1; min-width: 0; border-radius: 9px; padding: 0.3rem 0.35rem 0.25rem;
  background: #fff; border: 1px solid #e6eaf2; transition: all 0.45s cubic-bezier(0.2, 0.7, 0.2, 1);
}
.pill .f { font: 700 0.7rem 'JetBrains Mono', monospace; color: var(--navy); }
.pill .res { font-size: 0.5rem; color: var(--muted); line-height: 1.25; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.pill .f { display: flex; align-items: center; justify-content: space-between; gap: 0.2rem; }
.pill .act { font: 700 0.46rem 'JetBrains Mono', monospace; color: #fff; background: var(--orange); border-radius: 4px; padding: 0.05rem 0.25rem; }
.pill .verdict {
  margin-top: 0.15rem; font: 700 0.52rem 'JetBrains Mono', monospace; color: var(--green);
  opacity: 0; transform: scale(0.6); transform-origin: left; transition: all 0.3s 0.35s;
}
.pill.todo { opacity: 0.45; }
.pill.on {
  background: var(--navy); border-color: var(--navy); transform: translateY(-3px);
  box-shadow: 0 10px 22px -10px rgba(20, 33, 61, 0.7);
  animation: ring 1.6s ease-out 0.5s infinite;
}
.pill.on .f { color: #fff; }
.pill.on .res { color: #aebbd6; }
.pill.on .verdict { color: #8de0b5; }
.pill.done { background: #e3ecfb; border-color: #e3ecfb; }
.pill.on .verdict, .pill.done .verdict, .pill.fail .verdict { opacity: 1; transform: scale(1); }
.pill.fail { background: #fbe4e1; border-color: var(--red); animation: shake 0.5s 0.2s; }
.pill.fail .verdict { color: var(--red); }
.packet {
  position: absolute; top: -5px; left: 0; width: 10px; height: 10px; border-radius: 50%; background: #f2a65a;
  box-shadow: 0 0 10px 3px rgba(242, 166, 90, 0.8); animation: enter 0.6s cubic-bezier(0.3, 0, 0.2, 1) forwards;
}
@keyframes enter { from { left: -30px; opacity: 0; } to { left: calc(50% - 5px); opacity: 1; } }
@keyframes ring { 0% { box-shadow: 0 0 0 0 rgba(36, 89, 201, 0.45); } 100% { box-shadow: 0 0 0 10px rgba(36, 89, 201, 0); } }
@keyframes shake { 25% { transform: translateX(-4px); } 50% { transform: translateX(4px); } 75% { transform: translateX(-2px); } }

.ext {
  margin-top: 0.3rem; font: 600 0.55rem 'JetBrains Mono', monospace; color: var(--muted); border-radius: 6px;
  padding: 0.1rem 0.4rem; border: 1px dashed #c5c4c1; display: inline-block; transition: all 0.4s; opacity: 0.6;
}
.ext small { font-weight: 400; }
.ext.on { background: var(--orange); border-color: var(--orange); color: #fff; opacity: 1; }
.ext.on .ext-arrow { display: inline-block; animation: bob 0.8s ease-in-out infinite; }
.ext.done { opacity: 0.8; border-style: solid; color: var(--orange); }
@keyframes bob { 50% { transform: translateY(-2px); } }

/* detail */
.detail { display: grid; grid-template-columns: 0.95fr 1.2fr 1.25fr; gap: 0.6rem; margin-top: 0.6rem; height: 208px; }
.col { min-width: 0; background: #fff; border: 1px solid #e6eaf2; border-radius: 10px; padding: 0.4rem 0.5rem; overflow: hidden; }
.col-title { font: 700 0.55rem 'JetBrains Mono', monospace; text-transform: uppercase; letter-spacing: 0.08em; color: var(--muted); margin-bottom: 0.3rem; }
.col-title .file { text-transform: none; letter-spacing: 0; color: var(--blue); font-weight: 500; margin-left: 0.3rem; }

.req { font: 0.56rem/1.45 'JetBrains Mono', monospace; }
.hdr { position: relative; padding: 0.12rem 0.25rem; border-radius: 4px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; transition: all 0.4s; }
.hdr .k { color: var(--navy); font-weight: 700; }
.hdr .v { color: #4a5568; }
.hdr.fresh { animation: flash 1.2s ease-out; }
.hdr.hl { background: #fde7cf; }
.hdr.gone { opacity: 0.45; }
.hdr.gone::after { content: ''; position: absolute; left: 0.25rem; right: 0.25rem; top: 50%; height: 1.5px; background: var(--red); animation: strike 0.5s ease-out both; }
@keyframes strike { from { right: 100%; } }
@keyframes flash { 0% { background: #c9f0dc; } 100% { background: transparent; } }
.hdr-enter-active { transition: all 0.45s ease-out; }
.hdr-enter-from { opacity: 0; transform: translateX(-16px); }

.hint { font-size: 0.68rem; color: var(--muted); line-height: 1.45; padding-top: 0.4rem; }
.box p { font-size: 0.62rem; line-height: 1.45; color: #4a5568; margin: 0.35rem 0 0; }
.call { font: 0.56rem/1.4 'JetBrains Mono', monospace; padding: 0.2rem 0.35rem; border-radius: 5px; margin-bottom: 0.2rem; }
.call.out { background: #fbe9dc; color: var(--orange); animation: slidein 0.45s ease-out both; }
.call.back { background: #e1f4ea; color: var(--green); animation: slidein 0.45s 0.5s ease-out both; }
.call.muted { background: #eef0f4; color: var(--muted); }
.call.ok { background: #e1f4ea; color: var(--green); font-weight: 700; }
@keyframes slidein { from { opacity: 0; transform: translateX(-12px); } }

.jwt { font: 600 0.55rem 'JetBrains Mono', monospace; white-space: nowrap; overflow: hidden; display: flex; align-items: center; }
.jwt .seg { padding: 0.12rem 0.2rem; border-radius: 4px; transition: all 0.5s; overflow: hidden; text-overflow: ellipsis; }
.jwt .seg.h { color: var(--orange); }
.jwt .seg.p { color: var(--blue); }
.jwt .seg.sig { color: var(--green); }
.jwt .dot { color: var(--muted); transition: margin 0.5s; }
.jwt.split .dot { margin: 0 0.25rem; }
.jwt.split .seg.h { background: #fbe9dc; }
.jwt.split .seg.p { background: #e3ecfb; }
.jwt.split .seg.sig { background: #e1f4ea; }
.jwt.scan { background: linear-gradient(90deg, transparent 0%, rgba(242, 166, 90, 0.35) 50%, transparent 100%) no-repeat; background-size: 30% 100%; animation: scan 1.2s linear infinite; }
@keyframes scan { from { background-position: -30% 0; } to { background-position: 130% 0; } }

.part { margin-top: 0.3rem; border-radius: 6px; padding: 0.2rem 0.35rem; font: 0.54rem/1.45 'JetBrains Mono', monospace; color: var(--navy); animation: drop 0.5s ease-out both; }
.part.h { background: #fbe9dc; }
.part.p { background: #e3ecfb; }
.part.out { background: #e1f4ea; }
.part .tag { display: inline-block; font-weight: 700; text-transform: uppercase; font-size: 0.48rem; letter-spacing: 0.06em; color: var(--muted); margin-right: 0.3rem; }
.match { color: var(--green); }
.claim span { color: var(--muted); margin-right: 0.3rem; }
.claim b, .okc { color: var(--green); }
.claim em { font-style: normal; transition: all 0.4s; border-radius: 3px; }
.claim em.hit { background: var(--green); color: #fff; padding: 0 0.15rem; animation: pop 0.5s 0.3s both; }
.bad { color: var(--red); }
.badp { color: var(--red) !important; font-weight: 600; }
@keyframes drop { from { opacity: 0; transform: translateY(-8px); } }
@keyframes pop { 0% { transform: scale(1); } 50% { transform: scale(1.25); } 100% { transform: scale(1); } }

.yaml { background: var(--navy); border-radius: 8px; padding: 0.35rem 0.2rem; font: 0.52rem/1.5 'JetBrains Mono', monospace; color: #c7d3ea; }
.yl { display: flex; justify-content: space-between; gap: 0.3rem; padding: 0 0.3rem; border-radius: 3px; white-space: pre; transition: background 0.4s; }
.yl span { overflow: hidden; text-overflow: ellipsis; }
.yl.hl { background: rgba(242, 166, 90, 0.22); color: #fff; }
.yl b { flex: none; animation: pop 0.5s 0.4s both; }
.yl b.okc { color: #8de0b5; }
.yl b.bad { color: #ff9c92; }

.caption { margin-top: 0.5rem; font-size: 0.72rem; line-height: 1.4; color: #1b2433; min-height: 2rem; }
.caption b { display: inline-block; min-width: 1.3rem; height: 1.3rem; line-height: 1.3rem; text-align: center; border-radius: 50%; background: var(--navy); color: #fff; font-size: 0.6rem; margin-right: 0.35rem; }
.caption.bad b { background: var(--red); }

.view-enter-active, .view-leave-active { transition: all 0.25s ease; }
.view-enter-from { opacity: 0; transform: translateY(8px); }
.view-leave-to { opacity: 0; }
.cap-enter-active, .cap-leave-active { transition: opacity 0.2s; }
.cap-enter-from, .cap-leave-to { opacity: 0; }
</style>

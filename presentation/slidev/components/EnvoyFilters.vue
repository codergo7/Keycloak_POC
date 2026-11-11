<script setup lang="ts">
// "From Istio YAML to envoy.filters.http.*": what istiod turns each Istio resource into.
// Top row: the POC's Istio resources. Bottom row: the gateway's HTTP filter chain, in the
// real order from its config_dump. One mapping per click; every snippet is an excerpt of
// the generated config on the running POC (shortened, same keys and values).
// Click 6 switches to the spring-app sidecar. The slide needs `clicks: 6`.
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $clicks } = useSlideContext()
const s = computed(() => Math.min(Math.max($clicks.value, 0), 6))
const sc = computed(() => s.value === 6)

// columns: 0 shadow rbac · 1 ext_authz · 2 jwt_authn · 3 rbac · 4 router
const res = [
  { cols: [0, 1], kind: 'AuthorizationPolicy', act: 'CUSTOM', gw: 'oauth2-external-auth', sc: '' },
  { cols: [2], kind: 'RequestAuthentication', act: '', gw: 'demo-jwt-validation', sc: 'keycloak-jwt' },
  { cols: [3], kind: 'AuthorizationPolicy', act: 'ALLOW', gw: 'ingress-authorization', sc: 'spring-workload-authorization' },
  { cols: [4], kind: 'VirtualService', act: '', gw: 'api, oauth2-proxy, keycloak', sc: '' },
]
const filters = [
  { n: 'rbac', sub: 'shadow: marks the request', scSub: '', onSc: false },
  { n: 'ext_authz', sub: 'asks OAuth2-Proxy', onSc: false },
  { n: 'jwt_authn', sub: 'verifies the token', onSc: true },
  { n: 'rbac', sub: 'allows or denies', onSc: true },
  { n: 'router', sub: 'sends it upstream', scSub: 'sends it to the app', onSc: true },
]
// which columns are active on each click
const active: Record<number, number[]> = { 1: [0, 1, 2, 3, 4], 2: [0, 1], 3: [2], 4: [3], 5: [4], 6: [2, 3, 4] }
const isOn = (c: number) => (active[s.value] ?? []).includes(c)
// on the sidecar, the router runs but no VirtualService feeds it (inbound goes to the app)
const wireOn = (c: number) => isOn(c) && !(sc.value && c === 4)
const resOn = (i: number) => res[i].cols.some(isOn) && (!sc.value || res[i].sc)
const resOff = (i: number) => sc.value && !res[i].sc

interface Panel { t: string; p: string; chips: string[]; code: string }
const panels: Record<number, Panel> = {
  1: { t: 'istiod compiles, Envoy runs',
    p: 'istiod watches the YAML, writes Envoy configuration and pushes it to every proxy over xDS. Istio itself is never in the request path. It even fetches Keycloak’s keys and puts them inline.',
    chips: ['xDS push', 'no Istio in the request path'],
    code: `$ istioctl proxy-config listener <gateway-pod> -n istio-system \\
    -o json | jq -r '..|.httpFilters?[]?.name'

envoy.filters.http.rbac        ← CUSTOM (shadow)
envoy.filters.http.ext_authz   ← CUSTOM
envoy.filters.http.jwt_authn   ← RequestAuthentication
envoy.filters.http.rbac        ← AuthorizationPolicy ALLOW
envoy.filters.http.router      ← VirtualService routes
# plus Istio's own: metadata_exchange, stats, fault, cors …` },
  2: { t: 'CUSTOM becomes two filters',
    p: 'A shadow rbac filter only marks requests that match the CUSTOM rules. ext_authz then calls OAuth2-Proxy for marked requests only, and copies the allowed headers from its answer.',
    chips: ['302 to login comes from here'],
    code: `envoy.filters.http.ext_authz:
  http_service:
    server_uri: outbound|4180||oauth2-proxy.identity.svc…
    allowed_upstream_headers: authorization, x-auth-request-user,
      x-auth-request-email, x-auth-request-access-token
  allowed_headers: authorization, cookie   # sent to the check
  filter_enabled_metadata:                 # only if marked
    filter: envoy.filters.http.rbac
    path: istio_ext_authz_shadow_effective_policy_id` },
  3: { t: 'RequestAuthentication becomes jwt_authn',
    p: 'Finds the token, checks signature, issuer and expiry, then writes the claims into request metadata. No token is fine here (allow_missing); a bad token is a 401.',
    chips: ['401 comes from here', 'writes claims to metadata'],
    code: `envoy.filters.http.jwt_authn:
  providers:
    origins-0:
      issuer: http://keycloak.localhost:8080/realms/demo
      local_jwks: {"keys":[{"kid":"UHlGaDFC…"}]}   # inlined by istiod
      forward: true                # forwardOriginalToken
      payload_in_metadata: payload
    origins-1: …/realms/master
  rules: [ prefix "/": origins-0 OR origins-1 OR allow_missing ]` },
  4: { t: 'ALLOW becomes rbac',
    p: 'rbac never sees the token. It reads what jwt_authn wrote. requestPrincipals: ["*"] becomes “iss and sub are set”, which is why a token without sub gets 403.',
    chips: ['403 RBAC comes from here', 'reads metadata'],
    code: `# ingress-authorization, rule 3: requestPrincipals: ["*"]
policy: ns[istio-system]-policy[ingress-authorization]-rule[3]
  principals:
    metadata: { filter: envoy.filters.http.jwt_authn,
                path: payload.iss, value: regex ".+" }
    metadata: { filter: envoy.filters.http.jwt_authn,
                path: payload.sub, value: regex ".+" }` },
  5: { t: 'VirtualService becomes the route table',
    p: 'router is not a check. It is always the last filter: it picks a route from the table the VirtualServices became, and sends the request to that cluster.',
    chips: ['503 no healthy upstream comes from here'],
    code: `virtual_host: api.localhost:80
  match path   "/reports" → outbound|8080||reports-api.reports-api.svc…
  match prefix "/"        → outbound|8080||spring-app.spring-api.svc…` },
  6: { t: 'The sidecar: same filters, no ext_authz',
    p: 'No CUSTOM policy on the workload, so no ext_authz. jwt_authn adds the audience check, reads the second header, and writes the identity headers. rbac reads the roles.',
    chips: ['audience 403', 'outputClaimToHeaders'],
    code: `envoy.filters.http.jwt_authn:       # keycloak-jwt
  origins-0:
    audiences: [spring-api]
    from_headers: Authorization "Bearer ", X-Auth-Request-Access-Token
    claim_to_headers: sub → x-auth-request-user, email → x-auth-request-email
envoy.filters.http.rbac:             # spring-workload-authorization
  metadata: jwt_authn payload.realm_access.roles  one_of "user"` },
}
const cur = computed(() => panels[s.value])
</script>

<template>
  <div class="ef">
    <div class="rowlbl">What you write <span>Istio resources</span></div>
    <div class="grid res">
      <div v-for="(r, i) in res" :key="i" class="rc" :class="{ on: resOn(i), off: resOff(i) }"
        :style="{ gridColumn: `${r.cols[0] + 1} / ${r.cols[r.cols.length - 1] + 2}` }">
        <b>{{ r.kind }}<em v-if="r.act">{{ r.act }}</em></b>
        <small class="mono">{{ sc ? (r.sc || 'not on the sidecar') : r.gw }}</small>
      </div>
    </div>

    <div class="grid wires">
      <div v-for="c in 5" :key="c" class="wire" :class="{ on: wireOn(c - 1) }"><i /></div>
    </div>
    <div class="istiod" :class="{ on: s >= 1 }">
      <b>istiod</b> translates the YAML into Envoy config and pushes it over <b>xDS</b>
    </div>
    <div class="grid wires">
      <div v-for="c in 5" :key="c" class="wire" :class="{ on: wireOn(c - 1) }"><i /></div>
    </div>

    <div class="rowlbl">What Envoy runs <span>{{ sc ? 'spring-app sidecar' : 'ingress gateway' }}, in this order</span></div>
    <div class="grid chain">
      <div v-for="(f, i) in filters" :key="i" class="fc"
        :class="{ on: isOn(i), off: sc && !f.onSc }">
        <small class="mono">envoy.filters.http.</small>
        <b class="mono">{{ f.n }}</b>
        <span>{{ sc ? (f.onSc ? (f.scSub || f.sub) : 'not on the sidecar') : f.sub }}</span>
        <i v-if="i < 4" class="arrow">→</i>
      </div>
    </div>

    <Transition name="sw" mode="out-in">
      <div v-if="cur" :key="s" class="panel">
        <div class="txt">
          <h4>{{ cur.t }}</h4>
          <p>{{ cur.p }}</p>
          <div class="chips"><span v-for="c in cur.chips" :key="c">{{ c }}</span></div>
        </div>
        <pre class="code mono">{{ cur.code }}</pre>
      </div>
      <div v-else key="intro" class="intro">
        Envoy handles each request with a chain of HTTP filters, each named <code>envoy.filters.http.&lt;name&gt;</code>.
        Envoy knows nothing about Istio’s resources: click to see what each one becomes.
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.ef { --navy: #14213d; --blue: #2459c9; --orange: #c2570c; --green: #1f8a5b; --muted: #7a8496; margin-top: -0.2rem; }
.mono { font-family: 'JetBrains Mono', monospace; }
.grid { display: grid; grid-template-columns: repeat(5, 1fr); gap: 0.7rem; }
.rowlbl { font: 700 0.55rem 'JetBrains Mono', monospace; text-transform: uppercase; letter-spacing: 0.08em; color: var(--navy); margin: 0.15rem 0 0.25rem; }
.rowlbl span { color: var(--muted); font-weight: 600; margin-left: 0.4rem; text-transform: none; letter-spacing: 0; }

.rc, .fc { background: #fff; border: 1px solid #e6eaf2; border-radius: 9px; padding: 0.3rem 0.5rem; transition: all 0.45s cubic-bezier(0.2, 0.7, 0.2, 1); min-width: 0; }
.rc b { display: block; font-size: 0.68rem; color: var(--navy); }
.rc b em { font-style: normal; color: var(--orange); margin-left: 0.3em; }
.rc small { display: block; font-size: 0.5rem; color: var(--muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.rc.on { border-color: var(--blue); box-shadow: 0 0 0 3px rgba(36, 89, 201, 0.15); }
.rc.off, .fc.off { opacity: 0.3; }

.wires { height: 0.75rem; }
.wire { display: flex; justify-content: center; }
.wire i { width: 2px; height: 100%; background: #d5d9e2; position: relative; overflow: hidden; }
.wire.on i { background: var(--blue); }
.wire.on i::after { content: ''; position: absolute; left: -2px; width: 6px; height: 6px; border-radius: 50%; background: #fff; box-shadow: 0 0 0 1.5px var(--blue); animation: drop 1.1s linear infinite; }
@keyframes drop { from { top: -6px; } to { top: 100%; } }

.istiod { border: 1.5px dashed #b8c3d8; border-radius: 9px; padding: 0.2rem 0.6rem; text-align: center; font-size: 0.62rem; color: var(--muted); background: rgba(255, 255, 255, 0.55); transition: all 0.4s; }
.istiod b { color: var(--navy); font-family: 'JetBrains Mono', monospace; }
.istiod.on { border-color: var(--blue); border-style: solid; background: #eef3fc; }

.fc { position: relative; }
.fc small { display: block; font-size: 0.46rem; color: var(--muted); }
.fc b { display: block; font-size: 0.78rem; color: var(--navy); }
.fc span { display: block; font-size: 0.52rem; color: var(--muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.fc .arrow { position: absolute; right: -0.65rem; top: 50%; transform: translateY(-50%); font-style: normal; font-size: 0.7rem; color: #b8c3d8; z-index: 1; }
.fc.on { background: var(--navy); border-color: var(--navy); transform: translateY(-3px); box-shadow: 0 10px 22px -12px rgba(20, 33, 61, 0.7); }
.fc.on small, .fc.on span { color: #aebbd6; }
.fc.on b { color: #fff; }

.panel { display: grid; grid-template-columns: 0.85fr 1.5fr; gap: 0.8rem; margin-top: 0.7rem; }
.txt, .intro { background: #fff; border: 1px solid #e6eaf2; border-radius: 12px; padding: 0.6rem 0.8rem; }
.txt h4 { margin: 0 0 0.3rem; line-height: 1.3; font-size: 0.85rem; font-weight: 700; color: var(--navy); }
.txt p { margin: 0; font-size: 0.72rem; line-height: 1.5; color: #4a5568; }
.chips { margin-top: 0.45rem; display: flex; flex-wrap: wrap; gap: 0.3rem; }
.chips span { font: 600 0.5rem 'JetBrains Mono', monospace; color: var(--green); background: #def3e8; border-radius: 99px; padding: 0.1rem 0.45rem; }
.code { margin: 0; background: #14213d; color: #dbe4f5; border-radius: 12px; padding: 0.6rem 0.8rem; font-size: 0.56rem; line-height: 1.6; white-space: pre; overflow: hidden; }
.intro { margin-top: 0.7rem; font-size: 0.8rem; line-height: 1.5; color: #4a5568; }
.intro code { font-size: 0.72rem; }
.sw-enter-active, .sw-leave-active { transition: all 0.25s ease; }
.sw-enter-from { opacity: 0; transform: translateY(8px); }
.sw-leave-to { opacity: 0; }
</style>

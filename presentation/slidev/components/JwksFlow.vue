<script setup lang="ts">
// "Where do the keys come from?": how both RequestAuthentications (gateway + sidecar) get
// Keycloak's public keys. Keycloak signs, istiod fetches the JWKS and inlines it into the
// Envoy config, and the proxies verify offline. Then the refresh timer, a failed fetch and
// key rotation. Values measured on the POC (Istio 1.31, Keycloak realm "demo"); the
// failure intervals are constants in istiod's jwks_resolver.go. Click 2 (issuer) keeps the
// click-1 stage and adds the issuer match. The slide needs `clicks: 9`.
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $clicks } = useSlideContext()
const raw = computed(() => Math.min(Math.max($clicks.value, 0), 9))
const iss = computed(() => raw.value === 2)
// s = the stage without the issuer click: 0 1 [1] 2 3 4 5 6 7 8
const s = computed(() => (raw.value <= 1 ? raw.value : raw.value === 2 ? 1 : raw.value - 1))
const at = (...n: number[]) => n.includes(s.value)

const kcOn = computed(() => at(1, 2, 5, 7))
const kiState = computed(() => (iss.value ? 'idle' : at(2, 5) ? 'go' : at(6) ? 'fail' : at(4) ? 'idle' : ''))
const idOn = computed(() => !iss.value && at(2, 3, 5, 7))
const ieState = computed(() => (at(3, 5) ? 'go' : at(6) ? 'fail' : ''))
const pxOn = computed(() => iss.value || at(3, 4))
const pxBad = computed(() => at(6, 7))
const proxyKey = computed(() => (s.value === 6 ? 'placeholder' : s.value >= 3 ? 'UHlGaDFC…' : '—'))
const cacheTxt = computed(() =>
  s.value === 6 ? 'fetch failed → placeholder' : s.value === 7 ? 'old key only, until refresh' : s.value >= 2 ? 'demo/…/certs → UHlGaDFC…' : 'empty')

interface Row { k: string; v: string; m: string }
interface Panel { t: string; p: string; rows: Row[] }
const panels: Record<number, Panel> = {
  1: { t: '1 · Keycloak signs the token',
    p: 'Every access token is signed with the realm’s private RS256 key. The token header names that key (kid). The private key never leaves Keycloak; the public half is published at /certs.',
    rows: [
      { k: 'kid', v: 'UHlGaDFC…', m: 'which key signed this token' },
      { k: 'accessTokenLifespan', v: '300 s', m: 'Keycloak realm: how long a token is valid' },
    ] },
  2: { t: '3 · istiod fetches the public keys',
    p: 'istiod reads jwksUri from every RequestAuthentication and fetches it, once per URI. The gateway and the sidecar use the same URI, so it is one fetch, not one per proxy.',
    rows: [
      { k: 'jwksUri', v: '…/realms/demo/…/certs', m: 'in both RequestAuthentications' },
      { k: 'PILOT_JWT_ENABLE_REMOTE_JWKS', v: 'false (default)', m: 'istiod fetches. envoy / hybrid: the proxies fetch it themselves' },
    ] },
  3: { t: '4 · istiod pushes the keys into Envoy',
    p: 'The keys are copied into each proxy’s jwt_authn config and pushed over xDS. Neither the gateway nor the sidecar ever calls Keycloak.',
    rows: [
      { k: 'local_jwks', v: 'inline_string: {"keys":[…]}', m: 'the keys, inside the Envoy config' },
    ] },
  4: { t: '5 · Every request is checked offline',
    p: 'jwt_authn finds the key by kid, checks the signature, the issuer and the expiry, and at the sidecar the audience. Keycloak is not asked, which is why tokens kept working while it was down.',
    rows: [
      { k: 'clock_skew_seconds', v: '60 (Envoy default)', m: 'a token still passes up to 60 s after exp' },
      { k: 'audiences', v: 'spring-api', m: 'sidecar only (keycloak-jwt)' },
    ] },
  5: { t: '6 · istiod refreshes on a timer',
    p: 'istiod fetches every JWKS again on a fixed interval. If the keys changed, it pushes new config to every proxy that uses them.',
    rows: [
      { k: 'PILOT_JWT_PUB_KEY_REFRESH_INTERVAL', v: '20m (default)', m: 'istiod env var: how often it fetches again' },
      { k: 'cache eviction', v: '7 days', m: 'keys not used or not refreshed for 7 days are dropped (fixed)' },
    ] },
  6: { t: '7 · If the fetch fails, istiod fails closed',
    p: 'Keycloak not ready when istiod starts: istiod pushes a placeholder public key that nobody can sign for, so every token gets 401 “Jwt verification fails”, until a refresh works. We hit this: about 20 minutes. Fix: restart istiod once Keycloak is up.',
    rows: [
      { k: 'background retry', v: '7 × 1 s', m: 'right after the failure' },
      { k: 'next tries', v: '20m, then 1m → ×2 → 60m', m: 'normal timer, then backoff (fixed in istiod)' },
    ] },
  7: { t: '8 · Rotating Keycloak’s key',
    p: 'A new active key signs tokens with a kid the proxies don’t have until the next refresh: up to 20 minutes of 401s. Safe order: add the new key as passive, wait more than 20 minutes, make it active, keep the old one passive for at least 5 min + 60 s, then remove it.',
    rows: [
      { k: 'ACTIVE', v: 'signs + published', m: 'Keycloak key status' },
      { k: 'PASSIVE', v: 'published only', m: 'still verifies old tokens, signs nothing' },
    ] },
}
const summary: Row[] = [
  { k: 'accessTokenLifespan', v: '300 s', m: 'Keycloak · token validity' },
  { k: 'PILOT_JWT_PUB_KEY_REFRESH_INTERVAL', v: '20m', m: 'istiod · normal refresh' },
  { k: 'PILOT_JWT_ENABLE_REMOTE_JWKS', v: 'false', m: 'istiod · who fetches the keys' },
  { k: 'refresh after a failure', v: '1m ×2, max 60m', m: 'istiod · fixed' },
  { k: 'cache eviction', v: '7 days', m: 'istiod · fixed' },
  { k: 'clock_skew_seconds', v: '60', m: 'Envoy · grace after exp' },
]
const issPanel: Panel = { t: '2 · The issuer picks the rule',
  p: 'jwt_authn reads the token’s iss and uses the jwtRule with exactly that issuer, and that rule’s keys. Keycloak builds iss from its public hostname, which is ::1 inside a pod, so jwksUri uses the internal service name.',
  rows: [
    { k: 'token iss = issuer', v: 'http://keycloak.localhost:8080/realms/demo', m: 'compared character for character: http/https, :8080, trailing /' },
    { k: 'jwksUri', v: 'keycloak.identity.svc.cluster.local:8080/…', m: 'where the keys are fetched; without it, istiod tries <issuer>/.well-known' },
    { k: 'no rule matches', v: '401 Jwt issuer is not configured', m: 'e.g. a master-realm token at the sidecar' },
  ] }
const cur = computed(() => (iss.value ? issPanel : panels[s.value]))
</script>

<template>
  <div class="jf">
    <div class="stage">
      <!-- Keycloak -->
      <div class="box kc" :class="{ on: kcOn }">
        <div class="hd">Keycloak <small>realm demo</small></div>
        <div class="key" :class="{ dim: s === 7 }"><span class="i-carbon-locked" /> RS256 <b class="mono">UHlGaDFC…</b>
          <em>{{ s === 7 ? 'passive' : 'signs' }}</em></div>
        <div v-if="s === 7" class="key new"><span class="i-carbon-locked" /> RS256 <b class="mono">new kid</b><em>active</em></div>
        <div class="pub mono">GET /realms/demo/…/certs</div>
        <div class="tok mono" :class="{ show: s >= 1 }">{{ iss ? 'iss: keycloak.localhost:8080/realms/demo' : s === 7 ? 'new token · kid new' : 'token · kid UHlGaDFC… · 300 s' }}</div>
      </div>

      <!-- Keycloak → istiod -->
      <div class="wire" :class="kiState">
        <div class="wl">{{ iss ? 'jwksUri: keycloak.identity.svc' : s === 4 ? 'not called per request' : s === 6 ? 'no answer' : 'jwksUri fetch' }}</div>
        <div class="line"><i /></div>
      </div>

      <!-- istiod -->
      <div class="box id" :class="{ on: idOn, bad: s === 6 }">
        <div class="hd">istiod <small>control plane</small></div>
        <div v-if="iss" class="cache warn"><small>the issuer URL, inside a pod</small><span class="mono">keycloak.localhost → ::1 ✕</span></div>
        <div v-else class="cache"><small>JWKS cache</small><span class="mono">{{ cacheTxt }}</span></div>
        <div class="timer" :class="{ show: s >= 5, spin: s === 5 }">
          <div class="ring" /><span class="mono">refresh every 20m</span>
        </div>
      </div>

      <!-- istiod → proxies -->
      <div class="wire" :class="ieState">
        <div class="wl">{{ s === 6 ? 'placeholder pushed' : 'xDS · local_jwks' }}</div>
        <div class="line"><i /></div>
      </div>

      <!-- proxies -->
      <div class="px">
        <div v-for="p in [{ n: 'Ingress gateway', r: 'demo-jwt-validation', aud: false }, { n: 'spring-app sidecar', r: 'keycloak-jwt', aud: true }]"
          :key="p.n" class="box pr" :class="{ on: pxOn, bad: pxBad }">
          <div class="hd">{{ p.n }} <small class="mono">jwt_authn</small></div>
          <div class="rk mono">{{ p.r }} · keys: <b :class="{ red: s === 6 }">{{ proxyKey }}</b></div>
          <div class="checks" :class="{ show: iss }">
            <span>demo ✓</span><span v-if="!p.aud" class="no">master</span>
          </div>
          <div class="checks" :class="{ show: s === 4 && !iss }">
            <span>kid ✓</span><span>signature ✓</span><span>iss ✓</span><span>exp ✓</span><span v-if="p.aud">aud ✓</span>
          </div>
          <div v-if="s === 6 || s === 7" class="err mono">401 {{ s === 6 ? 'Jwt verification fails' : 'unknown kid → verification fails' }}</div>
        </div>
      </div>
    </div>

    <Transition name="sw" mode="out-in">
      <div v-if="cur" :key="s" class="panel">
        <div class="txt"><h4>{{ cur.t }}</h4><p>{{ cur.p }}</p></div>
        <div class="kv">
          <div v-for="r in cur.rows" :key="r.k" class="row"><b class="mono">{{ r.k }}</b><span class="mono v">{{ r.v }}</span><small>{{ r.m }}</small></div>
        </div>
      </div>
      <div v-else-if="s === 8" key="sum" class="sum">
        <div class="label">The settings that decide how fast keys and tokens change</div>
        <div v-for="r in summary" :key="r.k" class="row"><b class="mono">{{ r.k }}</b><span class="mono v">{{ r.v }}</span><small>{{ r.m }}</small></div>
      </div>
      <div v-else key="intro" class="intro">
        Two RequestAuthentications, one at the gateway and one at the sidecar, both check Keycloak’s signature.
        Neither one talks to Keycloak. Click to follow the keys.
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.jf { --navy: #14213d; --blue: #2459c9; --orange: #c2570c; --green: #1f8a5b; --red: #c0352b; --muted: #7a8496; margin-top: 0.2rem; }
.mono { font-family: 'JetBrains Mono', monospace; }
.stage { display: grid; grid-template-columns: 1.25fr 0.7fr 1fr 0.7fr 1.35fr; align-items: center; min-height: 11.5rem; }
.box { background: #fff; border: 1px solid #e6eaf2; border-radius: 12px; padding: 0.5rem 0.65rem; transition: all 0.45s cubic-bezier(0.2, 0.7, 0.2, 1); min-width: 0; }
.box.on { border-color: var(--blue); box-shadow: 0 0 0 3px rgba(36, 89, 201, 0.15); }
.box.bad { border-color: var(--red); box-shadow: 0 0 0 3px rgba(192, 53, 43, 0.15); }
.hd { font-weight: 700; font-size: 0.78rem; color: var(--navy); margin-bottom: 0.3rem; }
.hd small { font-weight: 500; font-size: 0.55rem; color: var(--muted); margin-left: 0.25rem; }

.key { display: flex; align-items: center; gap: 0.3rem; font-size: 0.6rem; color: var(--navy); background: #f4f6fa; border-radius: 6px; padding: 0.15rem 0.35rem; margin-bottom: 0.2rem; transition: all 0.4s; }
.key b { font-size: 0.58rem; }
.key em { margin-left: auto; font-style: normal; font: 600 0.5rem 'JetBrains Mono', monospace; color: var(--green); }
.key.dim em { color: var(--muted); }
.key.new { background: #fdf0e6; animation: pop 0.5s ease-out; }
.key.new em { color: var(--orange); }
.pub { font-size: 0.5rem; color: var(--muted); margin-top: 0.15rem; }
.tok { margin-top: 0.35rem; font-size: 0.5rem; color: var(--orange); background: #fdf0e6; border-radius: 99px; padding: 0.1rem 0.4rem; display: inline-block; opacity: 0; transform: translateY(4px); transition: all 0.4s; }
.tok.show { opacity: 1; transform: none; }

.wire { padding: 0 0.35rem; }
.wl { font: 600 0.48rem 'JetBrains Mono', monospace; color: var(--muted); text-align: center; margin-bottom: 0.2rem; min-height: 1.3em; }
.line { height: 2px; background: #d5d9e2; position: relative; }
.line::after { content: '›'; position: absolute; right: -2px; top: -0.62rem; font-size: 0.8rem; color: #b8c3d8; }
.wire.go .line { background: var(--blue); }
.wire.go .line i { position: absolute; top: -3px; width: 8px; height: 8px; border-radius: 50%; background: var(--blue); animation: run 1.2s ease-in-out infinite; }
.wire.go .wl { color: var(--blue); }
.wire.fail .line { background: repeating-linear-gradient(90deg, var(--red) 0 5px, transparent 5px 9px); }
.wire.fail .line i { position: absolute; top: -3px; width: 8px; height: 8px; border-radius: 50%; background: var(--red); animation: halt 1.4s ease-out infinite; }
.wire.fail .wl { color: var(--red); }
.wire.idle .line { background: repeating-linear-gradient(90deg, #c5c4c1 0 4px, transparent 4px 8px); }
.wire.idle .wl { color: var(--green); }
@keyframes run { from { left: 0; } to { left: calc(100% - 8px); } }
@keyframes halt { 0% { left: 0; opacity: 1; } 60% { left: 45%; opacity: 1; } 100% { left: 45%; opacity: 0; } }
@keyframes pop { from { transform: scale(0.9); opacity: 0; } to { transform: none; opacity: 1; } }

.cache { background: #f4f6fa; border-radius: 6px; padding: 0.2rem 0.4rem; }
.cache small { display: block; font-size: 0.48rem; color: var(--muted); }
.cache span { font-size: 0.52rem; color: var(--navy); }
.box.bad .cache span { color: var(--red); }
.timer { display: flex; align-items: center; gap: 0.4rem; margin-top: 0.35rem; opacity: 0; transition: opacity 0.4s; }
.timer.show { opacity: 1; }
.ring { width: 1.3rem; height: 1.3rem; border-radius: 50%; -webkit-mask: radial-gradient(circle, transparent 52%, #000 54%); mask: radial-gradient(circle, transparent 52%, #000 54%); background: conic-gradient(var(--blue) 0deg, #e6eaf2 0deg); --a: 0deg; }
.timer.show .ring { background: conic-gradient(var(--blue) 360deg, #e6eaf2 0deg); }
.timer.spin .ring { animation: sweep 3s linear infinite; }
@property --deg { syntax: '<angle>'; inherits: false; initial-value: 0deg; }
.timer.spin .ring { background: conic-gradient(var(--blue) var(--deg), #e6eaf2 var(--deg)); }
@keyframes sweep { from { --deg: 0deg; } to { --deg: 360deg; } }
.timer span { font-size: 0.6rem; font-weight: 700; color: var(--navy); }

.px { display: flex; flex-direction: column; gap: 0.45rem; }
.pr .hd { margin-bottom: 0.15rem; }
.rk { font-size: 0.5rem; color: var(--muted); }
.rk b { color: var(--navy); }
.rk b.red { color: var(--red); }
.checks { display: flex; flex-wrap: wrap; gap: 0.2rem; max-height: 0; overflow: hidden; opacity: 0; transition: all 0.4s; }
.checks.show { max-height: 2rem; opacity: 1; margin-top: 0.25rem; }
.checks span { font: 600 0.48rem 'JetBrains Mono', monospace; color: var(--green); background: #def3e8; border-radius: 99px; padding: 0.05rem 0.35rem; }
.checks span.no { color: var(--muted); background: #eef0f4; }
.cache.warn span { color: var(--red); }
.err { margin-top: 0.25rem; font-size: 0.5rem; font-weight: 700; color: var(--red); }

.panel { display: grid; grid-template-columns: 1fr 1.15fr; gap: 0.8rem; margin-top: 0.7rem; }
.txt, .kv, .sum, .intro { background: #fff; border: 1px solid #e6eaf2; border-radius: 12px; padding: 0.6rem 0.8rem; }
.txt h4 { margin: 0 0 0.3rem; font-size: 0.85rem; line-height: 1.3; font-weight: 700; color: var(--navy); }
.txt p { margin: 0; font-size: 0.68rem; line-height: 1.5; color: #4a5568; }
.row { display: grid; grid-template-columns: 1.35fr 1fr; column-gap: 0.6rem; padding: 0.3rem 0; border-bottom: 1px solid #eef0f4; }
.row:last-child { border-bottom: 0; }
.row b { font-size: 0.58rem; color: var(--blue); word-break: break-all; }
.row .v { font-size: 0.58rem; font-weight: 700; color: var(--navy); word-break: break-all; }
.row small { grid-column: 1 / -1; font-size: 0.56rem; color: var(--muted); }
.sum { margin-top: 0.7rem; display: grid; grid-template-columns: 1fr 1fr; column-gap: 1.4rem; }
.sum .label { grid-column: 1 / -1; font: 700 0.55rem 'JetBrains Mono', monospace; text-transform: uppercase; letter-spacing: 0.08em; color: var(--muted); margin-bottom: 0.2rem; }
.intro { margin-top: 0.7rem; font-size: 0.8rem; line-height: 1.5; color: #4a5568; }
.sw-enter-active, .sw-leave-active { transition: all 0.25s ease; }
.sw-enter-from { opacity: 0; transform: translateY(8px); }
.sw-leave-to { opacity: 0; }
</style>

<script setup lang="ts">
// Every sensitive header on a browser request, hop by hop, and the rule that lets it
// through or stops it (slide needs `clicks: 7`). Header lists were checked against the
// running cluster: what oauth2-proxy answers, what Spring receives, what the browser gets.
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $clicks } = useSlideContext()

type Fate = 'pass' | 'drop' | 'add' | 'check'
interface Chip { t: string; fate: Fate }
interface Step {
  hops: string[] // wire ids lit for this step, in travel order
  from: string
  to: string
  gate: string
  file: string
  chips: Chip[]
  note: string
}

// node centres in the 900×150 diagram
const N = {
  browser: { x: 90, y: 75, label: 'Browser' },
  gateway: { x: 400, y: 75, label: 'Ingress gateway' },
  proxy: { x: 720, y: 30, label: 'OAuth2-Proxy' },
  spring: { x: 720, y: 120, label: 'Spring + sidecar' },
}
const wires: Record<string, string> = {
  'gw-proxy': `M${N.gateway.x + 70} ${N.gateway.y - 8} L${N.proxy.x - 70} ${N.proxy.y + 4}`,
  'proxy-gw': `M${N.proxy.x - 70} ${N.proxy.y + 4} L${N.gateway.x + 70} ${N.gateway.y - 8}`,
  'gw-spring': `M${N.gateway.x + 70} ${N.gateway.y + 8} L${N.spring.x - 70} ${N.spring.y - 4}`,
  'spring-self': `M${N.spring.x - 40} ${N.spring.y + 17} h80`,
  'gw-browser': `M${N.gateway.x - 70} ${N.gateway.y} L${N.browser.x + 62} ${N.browser.y}`,
}

const steps: Step[] = [
  {
    hops: ['gw-proxy'], from: 'Browser request', to: 'Check request to oauth2-proxy',
    gate: 'includeRequestHeadersInCheck: [authorization, cookie]', file: 'istio-cm.yaml · extensionProviders',
    chips: [
      { t: 'Cookie: _oauth2_proxy=…', fate: 'pass' },
      { t: 'User-Agent: Mozilla/5.0', fate: 'drop' },
      { t: 'Accept: text/html', fate: 'drop' },
      { t: 'Accept-Language: en', fate: 'drop' },
    ],
    note: 'The gateway asks oauth2-proxy “is this request logged in?”. Only the cookie and Authorization header go along; everything else stays behind.',
  },
  {
    hops: ['proxy-gw'], from: 'oauth2-proxy answers 200', to: 'Copied into the request for Spring',
    gate: 'headersToUpstreamOnAllow', file: 'istio-cm.yaml · extensionProviders',
    chips: [
      { t: 'X-Auth-Request-User', fate: 'pass' },
      { t: 'X-Auth-Request-Email', fate: 'pass' },
      { t: 'X-Auth-Request-Access-Token', fate: 'pass' },
      { t: 'X-Auth-Request-Groups', fate: 'drop' },
      { t: 'X-Auth-Request-Preferred-Username', fate: 'drop' },
    ],
    note: 'oauth2-proxy answers with five identity headers. Only the three on the allow-list are copied into the request. Groups and username are thrown away.',
  },
  {
    hops: ['gw-spring'], from: 'Request at the router', to: 'What Spring receives',
    gate: 'VirtualService · headers.request.remove: [cookie]', file: 'oauth2-proxy.yaml · app.localhost route',
    chips: [
      { t: 'Cookie: _oauth2_proxy=…', fate: 'drop' },
      { t: 'X-Auth-Request-User', fate: 'pass' },
      { t: 'X-Auth-Request-Email', fate: 'pass' },
      { t: 'X-Auth-Request-Access-Token', fate: 'pass' },
      { t: 'User-Agent, Accept, …', fate: 'pass' },
    ],
    note: 'The router runs last. It removes the session cookie, which oauth2-proxy has already used. Spring gets identity, never the session.',
  },
  {
    hops: ['spring-self'], from: 'At the Spring sidecar', to: 'What the access rules use',
    gate: 'RequestAuthentication · fromHeaders: X-Auth-Request-Access-Token', file: 'auth-app.yaml · keycloak-jwt',
    chips: [
      { t: 'X-Auth-Request-Access-Token', fate: 'check' },
      { t: 'X-Auth-Request-User', fate: 'pass' },
      { t: 'X-Auth-Request-Email', fate: 'pass' },
      { t: 'aud: spring-api ✓', fate: 'add' },
      { t: 'roles: user, developer', fate: 'add' },
    ],
    note: 'The sidecar does not trust the header blindly: it verifies the token’s signature and audience, then hands its claims to the AuthorizationPolicy.',
  },
  {
    hops: ['gw-browser'], from: 'oauth2-proxy’s answer', to: 'Added to the response to the browser',
    gate: 'headersToDownstreamOnAllow: [set-cookie]', file: 'istio-cm.yaml · extensionProviders',
    chips: [
      { t: 'Set-Cookie: _oauth2_proxy=… (on refresh)', fate: 'pass' },
      { t: 'X-Auth-Request-User', fate: 'drop' },
      { t: 'X-Auth-Request-Email', fate: 'drop' },
      { t: 'X-Auth-Request-Access-Token', fate: 'drop' },
      { t: 'X-Auth-Request-Groups', fate: 'drop' },
    ],
    note: 'On the way back only Set-Cookie may join Spring’s response, so a refreshed cookie reaches the browser. No identity header and no token leave the cluster.',
  },
  {
    hops: ['proxy-gw', 'gw-browser'], from: 'oauth2-proxy answers 302 (no session)', to: 'The redirect the browser gets',
    gate: 'headersToDownstreamOnDeny: [content-type, set-cookie, location]', file: 'istio-cm.yaml · extensionProviders',
    chips: [
      { t: 'Location: keycloak.localhost/…/auth', fate: 'pass' },
      { t: 'Set-Cookie: _oauth2_proxy_csrf=…', fate: 'pass' },
      { t: 'Content-Type: text/html', fate: 'pass' },
    ],
    note: 'When the answer is “no”, the gateway sends oauth2-proxy’s reply to the browser instead of calling Spring. These three headers turn it into a working redirect to Keycloak.',
  },
  {
    hops: ['proxy-gw', 'gw-browser'], from: 'oauth2-proxy on its own /oauth2/ route', to: 'What the browser gets',
    gate: 'VirtualService /oauth2/ · headers.response.remove', file: 'oauth2-proxy.yaml · /oauth2/ route',
    chips: [
      { t: 'Set-Cookie: _oauth2_proxy=…', fate: 'pass' },
      { t: 'X-Auth-Request-User', fate: 'drop' },
      { t: 'X-Auth-Request-Email', fate: 'drop' },
      { t: 'X-Auth-Request-Access-Token', fate: 'drop' },
      { t: 'X-Auth-Request-Groups', fate: 'drop' },
    ],
    note: 'The leak we found: on /oauth2/* the browser talks to oauth2-proxy directly, and it adds identity headers to every reply. A response rule on that route strips them.',
  },
]

const step = computed(() => Math.min($clicks.value, steps.length))
const s = computed(() => (step.value > 0 ? steps[step.value - 1] : null))
const lit = (id: string) => !!s.value?.hops.includes(id)
const nodeOn = (k: string) => {
  const h = s.value?.hops ?? []
  if (k === 'gateway') return h.some(w => w.includes('gw'))
  if (k === 'proxy') return h.some(w => w.includes('proxy'))
  if (k === 'spring') return h.some(w => w.includes('spring'))
  return h.includes('gw-browser')
}
</script>

<template>
  <div class="hg">
    <div class="mapwrap">
    <svg viewBox="0 0 900 150" class="map">
      <path v-for="(d, id) in wires" :key="id" :d="d" class="wire" :class="{ lit: lit(id as string) }" />
      <g v-for="(n, k) in N" :key="k">
        <rect :x="n.x - 70" :y="n.y - 17" width="140" height="34" rx="8" class="node" :class="{ on: nodeOn(k as string) }" />
        <text :x="n.x" :y="n.y + 4.5" class="node-label" :class="{ on: nodeOn(k as string) }">{{ n.label }}</text>
      </g>
    </svg>
    <!-- packets: one per lit wire, the second one starts when the first arrives -->
    <template v-if="s">
      <div v-for="(id, i) in s.hops" :key="`${step}-${id}`" class="packet"
        :style="{ offsetPath: `path('${wires[id]}')`, animationDelay: i * 0.7 + 's' }" />
    </template>
    </div>

    <div class="gatebox">
      <template v-if="s">
        <div :key="step" class="run">
          <div class="titles">
            <span>{{ s.from }}</span>
            <span>{{ s.to }}</span>
          </div>
          <div class="gate">
            <div class="gate-label mono">{{ s.gate }}</div>
            <div class="gate-file mono">{{ s.file }}</div>
          </div>
          <div class="chips">
            <div v-for="(c, i) in s.chips" :key="c.t" class="row">
              <span class="hchip mono" :class="c.fate" :style="{ animationDelay: 0.25 + i * 0.12 + 's' }">{{ c.t }}</span>
            </div>
          </div>
        </div>
      </template>
      <div v-else class="intro">
        Click to follow one browser request. Each click is one hop: the headers on the left meet the rule that guards that hop.
        <span class="ok">Green</span> gets through, <span class="no">red</span> is stopped.
      </div>
    </div>

    <Transition name="n" mode="out-in">
      <p v-if="s" :key="step" class="note"><b>{{ step }}.</b> {{ s.note }}</p>
    </Transition>
  </div>
</template>

<style scoped>
.mapwrap { position: relative; width: 900px; max-width: 100%; height: 150px; margin: -0.4rem auto 0; }
.map { position: absolute; inset: 0; width: 900px; height: 150px; }
.wire { fill: none; stroke: #d6d8dc; stroke-width: 2; stroke-dasharray: 5 6; transition: stroke 0.4s; }
.wire.lit { stroke: #2459c9; animation: flow 0.8s linear infinite; }
@keyframes flow { to { stroke-dashoffset: -11; } }
.node { fill: #fff; stroke: #e6eaf2; transition: fill 0.4s; }
.node.on { fill: #14213d; stroke: #14213d; }
.node-label { font: 600 12px 'IBM Plex Sans', sans-serif; text-anchor: middle; fill: #14213d; transition: fill 0.4s; }
.node-label.on { fill: #fff; }
.packet { position: absolute; left: 0; top: 0; width: 12px; height: 12px; border-radius: 99px; background: #f2a65a; offset-rotate: 0deg; offset-distance: 0%; opacity: 0; box-shadow: 0 0 10px #f2a65a; animation: travel 0.7s cubic-bezier(0.5, 0, 0.3, 1) forwards; }
@keyframes travel { 0% { offset-distance: 0%; opacity: 1; } 99% { opacity: 1; } 100% { offset-distance: 100%; opacity: 0; } }

.gatebox { position: relative; height: 188px; margin-top: 0.2rem; background: #fff; border: 1px solid #e6eaf2; border-radius: 12px; overflow: hidden; }
.run { position: absolute; inset: 0; }
.titles { display: flex; justify-content: space-between; padding: 0.45rem 0.9rem 0; font: 600 0.58rem 'JetBrains Mono', monospace; letter-spacing: 0.08em; text-transform: uppercase; color: #7a8496; }
.gate {
  position: absolute; left: 44%; top: 0; bottom: 0; width: 4px; background: #14213d;
  animation: gate-in 0.4s ease-out both;
}
.gate::after { content: ''; position: absolute; inset: 0; background: #f2a65a; opacity: 0; animation: flash 0.5s 0.75s; }
.gate-label {
  position: absolute; bottom: 0.4rem; left: 50%; transform: translateX(-50%); white-space: nowrap; background: #14213d; color: #fff;
  font-size: 0.6rem; padding: 0.15rem 0.5rem; border-radius: 6px;
}
.gate-file { position: absolute; bottom: 1.85rem; left: 50%; transform: translateX(-50%); white-space: nowrap; font-size: 0.5rem; color: #7a8496; background: #fff; padding: 0 0.3rem; }
@keyframes gate-in { from { transform: scaleY(0); } }
@keyframes flash { 50% { opacity: 1; } }

.chips { position: absolute; left: 0; right: 0; top: 1.5rem; }
.row { position: relative; height: 1.42rem; }
.hchip {
  position: absolute; top: 0.12rem; left: 0.9rem; white-space: nowrap; font-size: 0.6rem; padding: 0.08rem 0.45rem; border-radius: 6px;
  background: #e3ecfb; color: #14213d; animation-duration: 0.9s; animation-fill-mode: both; animation-timing-function: cubic-bezier(0.5, 0, 0.25, 1);
}
/* pass: slide through the gate to the right-hand side */
.hchip.pass, .hchip.check { animation-name: pass; }
.hchip.check { animation-name: pass, verify; animation-duration: 0.9s, 0.4s; }
@keyframes pass { 0% { left: 0.9rem; } 100% { left: 52%; background: #def3e8; color: #135c3c; } }
@keyframes verify { to { box-shadow: 0 0 0 2px #1f8a5b; } }
/* drop: run into the gate, turn red and sink */
.hchip.drop { animation-name: drop; }
@keyframes drop {
  0% { left: 0.9rem; }
  70% { left: calc(44% - 15rem); transform: none; }
  100% { left: calc(44% - 15.6rem); background: #fbe3e1; color: #c0352b; text-decoration: line-through; opacity: 0.55; transform: translateY(3px); }
}
/* add: produced on the right-hand side, after the gate */
.hchip.add { animation-name: add; left: 52%; background: #fde7cf; color: #8a3b06; }
@keyframes add { 0%, 75% { opacity: 0; transform: scale(0.6); } 100% { opacity: 1; transform: none; } }

.intro { padding: 2.6rem 2rem; font-size: 0.85rem; color: #4a5568; line-height: 1.6; text-align: center; }
.ok { color: #1f8a5b; font-weight: 700; }
.no { color: #c0352b; font-weight: 700; }
.note { font-size: 0.82rem; color: #1b2433; min-height: 2.5rem; margin: 0.55rem 0 0; line-height: 1.45; }
.n-enter-active, .n-leave-active { transition: all 0.25s; }
.n-enter-from { opacity: 0; transform: translateY(6px); }
.n-leave-to { opacity: 0; }
</style>

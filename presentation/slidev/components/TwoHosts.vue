<script setup lang="ts">
// Backup: why two host names (app.localhost, api.localhost). Needs `clicks: 6`.
// 0 one set of apps, two front doors · 1 browser without a cookie → 302 to the Keycloak login
// 2 script without a token → 403 / bad token → 401 · 3 the cookie is host-only (no --cookie-domain),
// so it never reaches api.localhost: no CSRF there · 4 the same split in industry
// 5 the alternative: one host split by path (the cookie now reaches /api) · 6 production often uses a BFF.
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $clicks } = useSlideContext()
const s = computed(() => Math.min(Math.max($clicks.value, 0), 6))
const path = computed(() => s.value === 5)
const bff = computed(() => s.value === 6)

const appHost = computed(() => (path.value ? 'example.com/app' : 'app.localhost'))
const apiHost = computed(() => (path.value ? 'example.com/api' : 'api.localhost'))

const panels = [
  { t: 'One set of apps, two front doors', b: [
    'app.localhost and api.localhost reach the same Spring and FastAPI apps.',
    'The gateway chooses how to check a request by its host.',
  ] },
  { t: 'A person gets the login page', b: [
    'No cookie: ext_authz asks OAuth2-Proxy, which answers 302 to Keycloak.',
    'The browser follows it, and alice logs in.',
  ] },
  { t: 'A script gets a clear error', b: [
    'No token: 403 from the gateway’s rbac. A bad token: 401 from jwt_authn.',
    'A script can’t fill in a login page; an HTML page as the answer would only confuse it.',
  ] },
  { t: 'The cookie stays on its host', b: [
    'OAuth2-Proxy sets no cookie domain, so the cookie belongs to app.localhost only.',
    'api.localhost accepts only Bearer tokens, and the browser never adds one by itself.',
    'So a forged cross-site request (CSRF) can’t carry alice’s identity there.',
  ] },
]
const examples = [
  ['github.com', 'api.github.com'],
  ['dashboard.stripe.com', 'api.stripe.com'],
  ['app.slack.com', 'api.slack.com'],
  ['app.example.com', 'api.example.com'],
]
const reasons = ['cookie vs token', 'redirect vs 401', 'rate limits · WAF', 'CORS · certificates', 'scale and version the API alone']
</script>

<template>
  <div class="th">
    <!-- the stage -->
    <div class="stage" :class="{ bffm: bff }">
      <svg class="wires" viewBox="0 0 540 330">
        <!-- doors → apps -->
        <path d="M300 75 C350 75 350 165 400 165" class="w" :class="{ dim: bff }" />
        <path d="M300 255 C350 255 350 165 400 165" class="w" />
        <!-- click 6: the browser door goes to the BFF -->
        <path d="M300 75 C350 75 350 60 400 60" class="w bffw" :class="{ on: bff }" />
        <!-- actors → doors -->
        <path d="M100 75 H160" class="w b" :class="{ on: s === 1 }" />
        <path d="M100 255 H160" class="w s" :class="{ on: s === 2 }" />
        <!-- click 3/5: the browser tries the API door -->
        <path d="M100 95 C130 95 130 235 160 235" class="w x" :class="{ on: s === 3 || path, sent: path }" />
      </svg>

      <div class="frame"><span>Ingress gateway</span></div>

      <div class="actor br" :class="{ hot: [1, 3, 5].includes(s) }">
        <span class="i-carbon-user" /><b>Browser</b><small>a person</small>
        <div class="jar mono" :class="{ show: s >= 3 }">🍪 _oauth2_proxy<i>host: {{ path ? 'example.com' : 'app.localhost' }}</i></div>
      </div>
      <div class="actor sc" :class="{ hot: s === 2 }">
        <span class="i-carbon-terminal" /><b>Script</b><small>CLI · service</small>
      </div>

      <div class="door app" :class="{ hot: s === 1 }">
        <Transition name="sw" mode="out-in"><b :key="appHost" class="mono">{{ appHost }}</b></Transition>
        <small>ext_authz → OAuth2-Proxy</small>
      </div>
      <div class="door api" :class="{ hot: s === 2 || s === 3 }">
        <Transition name="sw" mode="out-in"><b :key="apiHost" class="mono">{{ apiHost }}</b></Transition>
        <small>jwt_authn + rbac · Bearer only</small>
      </div>

      <div class="apps" :class="{ dim: bff }"><b>Spring · FastAPI</b><small>the same apps</small></div>

      <!-- moving requests and answers -->
      <div v-if="s === 1" key="p1" class="pk go b mono" style="--y: 64px">GET /</div>
      <div v-if="s === 1" class="ans b mono">↩ 302 → Keycloak login</div>
      <div v-if="s === 2" key="p2" class="pk go s mono" style="--y: 244px">GET /api/user</div>
      <div v-if="s === 2" class="ans s mono">↩ 403 no token · 401 bad token</div>
      <div v-if="s === 3" key="p3" class="pk dive mono">no Cookie</div>
      <div v-if="s === 3" class="tag ok mono">cookie not sent ✓ no CSRF</div>
      <div v-if="path" key="p5" class="pk dive red mono">Cookie: _oauth2_proxy</div>
      <div v-if="path" class="tag bad mono">cookie sent to /api too</div>

      <!-- click 6: BFF -->
      <Transition name="sw">
        <div v-if="bff" class="bffbox">
          <b>Web backend (BFF)</b><small>holds the session, calls APIs with a token</small>
          <span class="arr mono">↓ token</span>
        </div>
      </Transition>
    </div>

    <!-- the explanation -->
    <div class="panel">
      <Transition name="sw" mode="out-in">
        <div :key="s">
          <template v-if="s < 4">
            <div class="kick mono">{{ s ? s + ' / 6' : 'why two hosts?' }}</div>
            <h4>{{ panels[s].t }}</h4>
            <p v-for="(l, i) in panels[s].b" :key="i" :style="{ '--i': i }">{{ l }}</p>
          </template>
          <template v-else-if="s === 4">
            <div class="kick mono">4 / 6 · industry</div>
            <h4>A common split</h4>
            <div class="ex mono">
              <div v-for="(e, i) in examples" :key="e[0]" :style="{ '--i': i }"><span>{{ e[0] }}</span><em>→</em><span class="api">{{ e[1] }}</span></div>
            </div>
            <div class="chips"><span v-for="(r, i) in reasons" :key="r" :style="{ '--i': i + 4 }">{{ r }}</span></div>
          </template>
          <template v-else-if="s === 5">
            <div class="kick mono">5 / 6 · alternative</div>
            <h4>One host, split by path</h4>
            <p style="--i: 0">Also common. Two ways in this setup: limit the CUSTOM policy with <code>paths</code> / <code>notPaths</code>, or let OAuth2-Proxy accept JWTs with <code>--skip-jwt-bearer-tokens</code>.</p>
            <p style="--i: 1" class="warn">Trade-off: one host needs more complex policies, and the cookie now reaches <code>/api</code>, so CSRF is back in scope.</p>
          </template>
          <template v-else>
            <div class="kick mono">6 / 6 · production</div>
            <h4>Often a BFF in between</h4>
            <p style="--i: 0">The browser talks only to its own web backend (Backend for Frontend). That backend, and other services, call the API with tokens.</p>
            <p style="--i: 1">The POC sends both hosts to the same apps on purpose: to show both paths side by side.</p>
            <p style="--i: 2" class="ok">Cookie for people, token for machines: standard practice.</p>
          </template>
        </div>
      </Transition>
    </div>
  </div>
</template>

<style scoped>
.th { --navy: #14213d; --blue: #2459c9; --orange: #c2570c; --green: #1f8a5b; --red: #c0392b; --violet: #7b3fbf; --muted: #7a8496;
  display: grid; grid-template-columns: 540px 1fr; gap: 1.2rem; margin-top: 0.8rem; }
.mono { font-family: 'JetBrains Mono', monospace; }

.stage { position: relative; height: 330px; }
.wires { position: absolute; inset: 0; width: 100%; height: 100%; }
.w { fill: none; stroke: #d6dbe5; stroke-width: 2; transition: all 0.4s; }
.w.dim { opacity: 0.25; }
.w.on { stroke-dasharray: 5 6; animation: flow 0.7s linear infinite; }
.w.b.on { stroke: var(--orange); } .w.s.on { stroke: var(--blue); }
.w.x { opacity: 0; }
.w.bffw { opacity: 0; }
.w.bffw.on { opacity: 1; stroke: var(--violet); }
.w.x.on { opacity: 1; stroke: var(--green); }
.w.x.sent { stroke: var(--red); }
@keyframes flow { to { stroke-dashoffset: -11; } }

.frame { position: absolute; left: 140px; top: 0; width: 180px; height: 330px; border: 1.5px dashed #c9d2e3; border-radius: 14px; }
.frame span { position: absolute; top: -0.5rem; left: 0.6rem; background: var(--slidev-theme-background, #f7f5f0); padding: 0 0.3rem; font: 700 0.5rem 'JetBrains Mono', monospace; text-transform: uppercase; letter-spacing: 0.05em; color: var(--navy); }

.actor, .door, .apps, .bffbox {
  position: absolute; display: flex; flex-direction: column; justify-content: center; align-items: center; border-radius: 12px;
  background: #fff; border: 1px solid #e6eaf2; box-shadow: 0 10px 24px -20px rgba(20, 33, 61, 0.6); transition: all 0.4s;
}
.actor { left: 0; width: 100px; height: 80px; }
.actor.br { top: 35px; } .actor.sc { top: 215px; }
.actor span { font-size: 1.1rem; }
.actor.br span { color: var(--orange); } .actor.sc span { color: var(--blue); }
.actor b { font-size: 0.75rem; color: var(--navy); }
.actor small { font-size: 0.48rem; color: var(--muted); }
.actor.hot { border-color: var(--navy); box-shadow: 0 0 0 3px rgba(20, 33, 61, 0.12); }
.jar {
  position: absolute; top: 84px; left: 0; width: 132px; padding: 0.15rem 0.35rem; border-radius: 7px; background: #fbe9dc; color: #8a3d08;
  font-size: 0.48rem; font-weight: 700; opacity: 0; transform: translateY(-6px); transition: all 0.4s 0.2s; z-index: 2;
}
.jar i { display: block; font-style: normal; font-weight: 500; }
.jar.show { opacity: 1; transform: none; }

.door { left: 160px; width: 140px; height: 80px; gap: 0.15rem; }
.door.app { top: 35px; } .door.api { top: 215px; }
.door b { font-size: 0.66rem; color: var(--navy); }
.door small { font-size: 0.46rem; color: var(--muted); text-align: center; }
.door.app { border-top: 4px solid var(--orange); } .door.api { border-top: 4px solid var(--blue); }
.door.hot { box-shadow: 0 0 0 3px rgba(36, 89, 201, 0.15); }

.apps { left: 400px; top: 125px; width: 140px; height: 80px; background: #def3e8; border-color: #def3e8; }
.apps b { font-size: 0.7rem; color: var(--navy); } .apps small { font-size: 0.48rem; color: var(--muted); }
.apps.dim { opacity: 0.35; }

.pk {
  position: absolute; left: 92px; top: var(--y); padding: 0.1rem 0.4rem; border-radius: 99px; color: #fff; font-size: 0.5rem; font-weight: 700; z-index: 3;
}
.pk.b { background: var(--orange); } .pk.s { background: var(--blue); }
.pk.go { animation: go 0.9s cubic-bezier(0.5, 0, 0.3, 1) both; }
@keyframes go { from { left: 92px; opacity: 0; } 20% { opacity: 1; } to { left: 150px; opacity: 0; } }
.pk.dive { background: var(--green); animation: dive 1.4s cubic-bezier(0.5, 0, 0.3, 1) both; }
.pk.dive.red { background: var(--red); }
@keyframes dive { 0% { left: 96px; top: 100px; opacity: 0; } 15% { opacity: 1; } 85% { left: 140px; top: 222px; opacity: 1; } 100% { left: 140px; top: 222px; opacity: 0; } }
.ans {
  position: absolute; left: 0; font-size: 0.5rem; font-weight: 700; padding: 0.12rem 0.4rem; border-radius: 6px; z-index: 3;
  animation: back 0.5s 0.9s both;
}
.ans.b { top: 12px; background: #fbe9dc; color: #8a3d08; }
.ans.s { top: 300px; background: #fdeeec; color: var(--red); }
@keyframes back { from { opacity: 0; transform: translateX(30px); } }
.tag { position: absolute; left: 0; top: 300px; font-size: 0.5rem; font-weight: 700; padding: 0.12rem 0.4rem; border-radius: 6px; animation: back 0.5s 1.3s both; z-index: 3; }
.tag.ok { background: #def3e8; color: var(--green); }
.tag.bad { background: #fdeeec; color: var(--red); }

.bffbox { left: 400px; top: 20px; width: 140px; height: 80px; border: 2px solid var(--violet); background: #f3effa; padding: 0 0.4rem; }
.bffbox b { font-size: 0.66rem; color: var(--violet); } .bffbox small { font-size: 0.45rem; color: #1b2433; text-align: center; }
.bffbox .arr { position: absolute; bottom: -1.4rem; font-size: 0.5rem; font-weight: 700; color: var(--violet); }
.stage.bffm .door.app small { color: var(--violet); }

.panel { background: #fff; border: 1px solid #e6eaf2; border-radius: 14px; padding: 0.8rem 1rem; height: 330px; box-shadow: 0 10px 26px -22px rgba(20, 33, 61, 0.6); }
.kick { font-size: 0.5rem; font-weight: 700; color: var(--blue); text-transform: uppercase; letter-spacing: 0.06em; }
.panel h4 { margin: 0.2rem 0 0.5rem; font-size: 1rem; font-weight: 800; color: var(--navy); }
.panel p { font-size: 0.78rem; line-height: 1.45; color: #1b2433; margin: 0 0 0.5rem; animation: up 0.4s both; animation-delay: calc(var(--i) * 0.15s + 0.1s); }
.panel p.warn { color: var(--red); } .panel p.ok { color: var(--green); font-weight: 700; }
.panel code { font-size: 0.62rem; }
.ex { display: flex; flex-direction: column; gap: 0.3rem; font-size: 0.62rem; }
.ex div { display: grid; grid-template-columns: 1fr auto 1fr; gap: 0.4rem; align-items: center; animation: up 0.4s both; animation-delay: calc(var(--i) * 0.12s); }
.ex span { padding: 0.12rem 0.35rem; border-radius: 6px; background: #fbe9dc; color: #8a3d08; }
.ex span.api { background: #e4ecfb; color: var(--blue); }
.ex em { font-style: normal; color: var(--muted); }
.chips { display: flex; flex-wrap: wrap; gap: 0.25rem; margin-top: 0.7rem; }
.chips span { font-size: 0.55rem; font-weight: 600; padding: 0.12rem 0.45rem; border-radius: 99px; background: #eef2fa; color: var(--navy); animation: up 0.4s both; animation-delay: calc(var(--i) * 0.1s); }
@keyframes up { from { opacity: 0; transform: translateY(6px); } }
.sw-enter-active, .sw-leave-active { transition: all 0.3s; }
.sw-enter-from { opacity: 0; transform: translateY(6px); }
.sw-leave-to { opacity: 0; }
</style>

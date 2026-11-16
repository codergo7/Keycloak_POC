<script setup lang="ts">
// How the setup grows: adding a new API backend (x-api, any language) in four steps.
// Click 1: a Keycloak client and an audience scope, so tokens can carry aud x-api.
// Click 2: a namespace with istio-injection: enabled; the sidecar appears, still without rules.
// Click 3: istiod sends the RequestAuthentication + AuthorizationPolicy pair to that sidecar.
// Click 4: a route in the VirtualService and one ALLOW rule (valid token) in the gateway policy,
//          as /reports has in k8s/istio/ingress-authorization.yaml; a request reaches x-api.
// Click 5: what was added and what stayed the same; the next backend is the same four steps.
// The slide needs `clicks: 5`.
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $clicks } = useSlideContext()
const s = computed(() => Math.min(Math.max($clicks.value, 0), 5))

const steps = [
  'Keycloak client + audience',
  'Namespace with sidecar injection',
  'RequestAuthentication + AuthorizationPolicy',
  'Route + gateway rule',
]
const lanes = [
  { ns: 'spring-api', app: 'Spring', lang: 'Java', aud: 'spring-api', roles: 'realm roles' },
  { ns: 'reports-api', app: 'FastAPI', lang: 'Python', aud: 'reports-api', roles: 'client roles' },
  { ns: 'x-api', app: 'x-api', lang: 'any language', aud: 'x-api', roles: 'its own roles', isNew: true },
]
const laneTop = [0, 74, 148]
const notes = [
  'Today: two backends behind one gateway. Each has its own namespace, its own sidecar and its own pair of resources.',
  'Keycloak gets a client for the new API, and an audience scope, so a token can say it is meant for x-api.',
  'A namespace with sidecar injection. The pod gets an Envoy sidecar automatically, with no rules yet.',
  'istiod sends the pair to the new sidecar: RequestAuthentication checks aud x-api, AuthorizationPolicy checks the roles.',
  'One route in the VirtualService, and one ALLOW rule at the gateway: a valid token is required. The request reaches x-api.',
]
const added = ['1 Keycloak client', '1 namespace', '2 Istio resources', '1 route + 1 gateway rule']
const same = ['the filter chain', 'OAuth2-Proxy', 'istiod', 'Spring and FastAPI']
</script>

<template>
  <div class="gm">
    <!-- the four steps -->
    <div class="track">
      <div v-for="(t, i) in steps" :key="t" class="step" :class="{ on: s === i + 1, done: s > i + 1 }">
        <b>{{ s > i + 1 ? '✓' : i + 1 }}</b><span>{{ t }}</span>
      </div>
    </div>

    <div class="stage">
      <svg class="wires" viewBox="0 0 880 290">
        <!-- gateway → each backend -->
        <path v-for="(t, k) in laneTop" :key="'w' + k" :d="`M390 126 C418 126 412 ${t + 32} 440 ${t + 32}`" pathLength="1"
          class="w" :class="{ fresh: k === 2, drawn: k < 2 || s >= 4, dim: k === 2 && s < 4 }" />
        <!-- istiod → the new sidecar -->
        <path d="M160 206 H190 V272 H414 V180 H452" class="cfg" :class="{ on: s === 3, done: s > 3 }" />
        <text x="300" y="285" class="cfgl" :class="{ on: s >= 3 }">config → new sidecar</text>
      </svg>

      <!-- Keycloak -->
      <div class="box kc" :class="{ hot: s === 1 }">
        <div class="bh">Keycloak <small>realm demo</small></div>
        <div class="cl mono">client spring-api</div>
        <div class="cl mono">client reports-api</div>
        <div class="cl mono new" :class="{ show: s >= 1 }">client x-api <em>+ aud scope</em></div>
        <div class="stamp" :class="{ show: s >= 5 }">+1 client</div>
      </div>

      <!-- istiod -->
      <div class="box ist" :class="{ hot: s === 3 }">
        <div class="bh">istiod <small>control plane</small></div>
        <p>Turns the YAML into Envoy config and sends it to every proxy.</p>
        <div class="stamp same" :class="{ show: s >= 5 }">unchanged</div>
      </div>

      <!-- gateway -->
      <div class="box gw" :class="{ hot: s === 4 }">
        <div class="bh">Ingress gateway</div>
        <div class="chain mono"><span>ext_authz</span><span>jwt_authn</span><span>rbac</span><span>router</span></div>
        <div class="o2p">⇅ OAuth2-Proxy <small>browser sessions</small></div>
        <div class="sub mono">VirtualService routes</div>
        <div class="rt mono">app.localhost → spring</div>
        <div class="rt mono">api…/reports → reports</div>
        <div class="rt mono">api…/* → spring</div>
        <div class="rt mono new" :class="{ show: s >= 4 }">api…/x → x-api</div>
        <div class="rt mono new rule" :class="{ show: s >= 4 }">ALLOW /x · valid token</div>
        <div class="stamp same" :class="{ show: s >= 5 }">same filters</div>
      </div>

      <!-- backends -->
      <div v-for="(l, k) in lanes" :key="l.ns" class="lane"
        :class="{ isnew: l.isNew, show: !l.isNew || s >= 2, live: l.isNew && s >= 4 }" :style="{ top: laneTop[k] + 'px' }">
        <div class="nsl mono">namespace · {{ l.ns }}<b v-if="l.isNew" class="tag">new</b></div>
        <div class="sc" :class="{ pop: l.isNew }">
          <div class="scl mono">sidecar</div>
          <div class="pill" :class="{ wait: l.isNew && s < 3, fill: l.isNew && s >= 3 }" style="--d: 1.15s">
            <b>jwt_authn</b><span>aud {{ l.aud }}</span>
          </div>
          <div class="pill" :class="{ wait: l.isNew && s < 3, fill: l.isNew && s >= 3 }" style="--d: 1.35s">
            <b>rbac</b><span>{{ l.roles }}</span>
          </div>
        </div>
        <div class="arr" />
        <div class="app"><b>{{ l.app }}</b><small>{{ l.isNew && s >= 4 ? '200 OK' : l.lang }}</small></div>
        <div v-if="!l.isNew" class="stamp same in" :class="{ show: s >= 5 }">unchanged</div>
      </div>
      <div class="lane ghost" :class="{ show: s >= 5 }" style="top: 226px">
        <span>⋮</span> the next backend: the same four steps
      </div>

      <!-- click 4: a request travels to x-api, drawn above the boxes -->
      <svg v-if="s === 4" class="wires over" viewBox="0 0 880 290">
        <circle r="5" class="pk">
          <animateMotion dur="1.4s" repeatCount="indefinite" path="M300 126 H390 C418 126 412 180 440 180 H780" />
        </circle>
      </svg>

      <!-- click 3: the two resources fly from istiod to the sidecar -->
      <template v-if="s === 3">
        <div class="card mono" style="--x: 456px; --y: 166px">RequestAuthentication<small>x-jwt · aud x-api</small></div>
        <div class="card mono" style="--x: 566px; --y: 166px; animation-delay: 0.2s">AuthorizationPolicy<small>x-authorization · ALLOW</small></div>
      </template>
    </div>

    <Transition name="n" mode="out-in">
      <p v-if="s < 5" :key="s" class="note"><b v-if="s">{{ s }}.</b> {{ notes[s] }}</p>
      <div v-else key="sum" class="sum">
        <div class="grp add"><b>Added</b><span v-for="(a, i) in added" :key="a" :style="{ '--i': i }">{{ a }}</span></div>
        <div class="grp keep"><b>Unchanged</b><span v-for="(a, i) in same" :key="a" :style="{ '--i': i + 4 }">{{ a }}</span></div>
        <div class="zero">Security code in x-api: <b>none</b></div>
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.gm { --navy: #14213d; --blue: #2459c9; --orange: #c2570c; --green: #1f8a5b; --violet: #7b3fbf; --muted: #7a8496; }
.mono { font-family: 'JetBrains Mono', monospace; }

/* step tracker */
.track { display: grid; grid-template-columns: repeat(4, 1fr); gap: 0.4rem; width: 880px; margin: 0 auto 0.6rem; }
.step {
  display: flex; align-items: center; gap: 0.4rem; padding: 0.3rem 0.5rem; border-radius: 99px; background: #eef1f6;
  font-size: 0.6rem; color: var(--muted); font-weight: 600; transition: all 0.4s;
}
.step b {
  flex: none; width: 1.2rem; height: 1.2rem; border-radius: 50%; display: grid; place-items: center; background: #d6dbe5; color: #fff; font-size: 0.6rem;
  transition: all 0.4s;
}
.step.on { background: var(--orange); color: #fff; box-shadow: 0 6px 18px -8px rgba(194, 87, 12, 0.8); transform: translateY(-2px); }
.step.on b { background: #fff; color: var(--orange); }
.step.done { background: #def3e8; color: var(--green); }
.step.done b { background: var(--green); }

.stage { position: relative; width: 880px; height: 290px; margin: 0 auto; }
.wires { position: absolute; inset: 0; width: 100%; height: 100%; overflow: visible; }
.w { fill: none; stroke: var(--blue); stroke-width: 2; stroke-dasharray: 1; stroke-dashoffset: 1; transition: stroke-dashoffset 0.9s ease-out; }
.w.drawn { stroke-dashoffset: 0; }
.w.fresh { stroke: var(--orange); stroke-width: 2.5; }
.cfg { fill: none; stroke: #d9cdea; stroke-width: 2; stroke-dasharray: 5 6; opacity: 0; transition: opacity 0.4s; }
.cfg.on { opacity: 1; stroke: var(--violet); animation: flow 0.7s linear infinite; }
.cfg.done { opacity: 0.6; }
.cfgl { font: 600 9px 'JetBrains Mono', monospace; fill: var(--violet); opacity: 0; transition: opacity 0.4s; }
.cfgl.on { opacity: 1; }
@keyframes flow { to { stroke-dashoffset: -11; } }
.wires.over { z-index: 2; pointer-events: none; }
.pk { fill: var(--orange); filter: drop-shadow(0 0 4px rgba(194, 87, 12, 0.8)); }

.box {
  position: absolute; background: #fff; border: 1px solid #e6eaf2; border-radius: 12px; padding: 0.4rem 0.55rem;
  box-shadow: 0 10px 26px -20px rgba(20, 33, 61, 0.55); transition: all 0.4s;
}
.box.hot { border-color: var(--orange); box-shadow: 0 0 0 3px rgba(194, 87, 12, 0.18), 0 14px 30px -20px rgba(20, 33, 61, 0.6); }
.bh { font-weight: 800; font-size: 0.78rem; color: var(--navy); margin-bottom: 0.25rem; }
.bh small { font: 500 0.48rem 'JetBrains Mono', monospace; color: var(--muted); margin-left: 0.2rem; }
.kc { left: 0; top: 0; width: 160px; height: 132px; }
.ist { left: 0; top: 160px; width: 160px; height: 92px; }
.ist p { font-size: 0.56rem; color: #1b2433; margin: 0; line-height: 1.35; }
.gw { left: 210px; top: 0; width: 180px; height: 252px; }

.cl, .rt { font-size: 0.5rem; padding: 0.14rem 0.35rem; border-radius: 5px; background: #eef2fa; color: var(--navy); margin-top: 0.2rem; white-space: nowrap; }
.cl em { font-style: normal; color: var(--orange); font-weight: 700; }
.new { opacity: 0; transform: translateX(-10px) scale(0.9); transition: all 0.5s cubic-bezier(0.3, 0.8, 0.2, 1) 0.15s; background: #fbe9dc !important; font-weight: 700; }
.new.show { opacity: 1; transform: none; }
.rt.rule { background: #fdf1e7 !important; }
.chain { display: flex; gap: 0.15rem; flex-wrap: wrap; }
.chain span { font-size: 0.44rem; padding: 0.1rem 0.25rem; border-radius: 4px; background: var(--navy); color: #fff; }
.o2p { margin-top: 0.3rem; font-size: 0.56rem; font-weight: 700; color: var(--navy); }
.o2p small { font-weight: 500; color: var(--muted); font-size: 0.48rem; }
.sub { margin-top: 0.4rem; font-size: 0.46rem; color: var(--muted); text-transform: uppercase; letter-spacing: 0.05em; }

/* stamps at click 5 */
.stamp {
  position: absolute; right: -6px; top: -9px; font: 700 0.46rem 'JetBrains Mono', monospace; padding: 0.12rem 0.4rem; border-radius: 99px;
  background: var(--orange); color: #fff; opacity: 0; transform: scale(1.8) rotate(-8deg); transition: all 0.45s cubic-bezier(0.3, 1.4, 0.5, 1);
}
.stamp.same { background: var(--green); }
.stamp.show { opacity: 1; transform: rotate(-4deg); transition-delay: 0.25s; }
.stamp.in { right: 104px; }

/* backend lanes */
.lane {
  position: absolute; left: 440px; width: 440px; height: 64px; display: flex; align-items: stretch; padding: 0.55rem 0.5rem 0.35rem;
  border: 1.5px dashed #c9d2e3; border-radius: 12px; background: rgba(255, 255, 255, 0.6);
}
.lane.isnew { border-color: var(--orange); background: #fffaf6; clip-path: inset(-14px 100% 0 0 round 12px); opacity: 0; transition: clip-path 0.8s cubic-bezier(0.5, 0, 0.2, 1), opacity 0.2s; }
.lane.isnew.show { clip-path: inset(-14px 0 0 0 round 12px); opacity: 1; }
.lane.live { box-shadow: 0 0 0 3px rgba(31, 138, 91, 0.18); }
.nsl { position: absolute; top: -0.45rem; left: 0.6rem; font-size: 0.46rem; font-weight: 700; color: var(--navy); background: #fff; padding: 0 0.3rem; }
.tag { margin-left: 0.3rem; background: var(--orange); color: #fff; border-radius: 4px; padding: 0 0.25rem; }
.sc { flex: 1; display: flex; gap: 0.3rem; align-items: stretch; border: 1px solid #d5dbe8; border-radius: 9px; padding: 0.2rem 0.3rem; background: #fff; position: relative; }
.scl { writing-mode: vertical-rl; transform: rotate(180deg); font-size: 0.42rem; color: var(--muted); font-weight: 700; text-transform: uppercase; }
.sc.pop { transform: scale(0.6); opacity: 0; transition: all 0.5s cubic-bezier(0.3, 1.4, 0.5, 1) 0.6s; }
.lane.show .sc.pop { transform: none; opacity: 1; }
.pill { flex: 1; display: flex; flex-direction: column; justify-content: center; padding: 0 0.4rem; border-radius: 7px; background: #e7edf8; transition: all 0.4s; }
.pill b { font: 700 0.55rem 'JetBrains Mono', monospace; color: var(--navy); }
.pill span { font-size: 0.48rem; color: #1b2433; }
.pill.wait { background: transparent; border: 1.5px dashed #e5c7ae; }
.pill.wait b, .pill.wait span { opacity: 0; }
.pill.fill { background: #fbe9dc; animation: land 0.5s cubic-bezier(0.3, 1.4, 0.5, 1) both; animation-delay: var(--d); }
.pill.fill b, .pill.fill span { animation: fade 0.3s both; animation-delay: var(--d); }
@keyframes land { from { transform: scale(0.7); background: transparent; } }
@keyframes fade { from { opacity: 0; } }
.arr { flex: none; width: 20px; position: relative; }
.arr::before { content: ''; position: absolute; left: 3px; right: 3px; top: 50%; height: 2px; background: #c9d2e3; }
.app { flex: none; width: 92px; border-radius: 9px; background: #def3e8; display: flex; flex-direction: column; justify-content: center; align-items: center; transition: all 0.4s; }
.app b { font-size: 0.72rem; color: var(--navy); }
.app small { font: 500 0.45rem 'JetBrains Mono', monospace; color: var(--muted); text-align: center; }
.lane.isnew .app { background: #fbe9dc; }
.lane.live .app { background: var(--green); }
.lane.live .app b, .lane.live .app small { color: #fff; }
.lane.ghost {
  height: 30px; align-items: center; gap: 0.4rem; padding: 0 0.8rem; font: 600 0.55rem 'JetBrains Mono', monospace; color: var(--muted);
  border-color: #e5c7ae; opacity: 0; transform: translateY(-10px); transition: all 0.5s 0.5s;
}
.lane.ghost span { color: var(--orange); font-size: 1rem; }
.lane.ghost.show { opacity: 1; transform: none; }

/* click 3: flying resources */
.card {
  position: absolute; left: 14px; top: 196px; width: 104px; padding: 0.2rem 0.35rem; border-radius: 7px; background: var(--violet); color: #fff;
  font-size: 0.48rem; font-weight: 700; box-shadow: 0 10px 22px -10px rgba(123, 63, 191, 0.9); animation: fly 1.2s cubic-bezier(0.5, 0, 0.3, 1) both;
  z-index: 3;
}
.card small { display: block; font-weight: 500; font-size: 0.42rem; opacity: 0.85; }
@keyframes fly {
  0% { left: 14px; top: 196px; opacity: 0; transform: scale(0.8); }
  15% { opacity: 1; transform: none; }
  45% { left: 200px; top: 258px; }
  70% { left: 400px; top: 258px; }
  92% { left: var(--x); top: var(--y); opacity: 1; transform: scale(0.85); }
  100% { left: var(--x); top: var(--y); opacity: 0; transform: scale(0.6); }
}

.note { width: 880px; margin: 0.35rem auto 0; font-size: 0.84rem; color: #1b2433; min-height: 2.4rem; }
.sum { width: 880px; margin: 0.35rem auto 0; display: flex; flex-wrap: wrap; gap: 0.35rem 1rem; align-items: center; font-size: 0.6rem; min-height: 2.4rem; }
.grp { display: flex; gap: 0.25rem; align-items: center; flex-wrap: wrap; }
.grp b { font-size: 0.62rem; margin-right: 0.15rem; }
.grp span { padding: 0.15rem 0.45rem; border-radius: 99px; font-weight: 600; animation: chip 0.4s both; animation-delay: calc(var(--i) * 0.08s + 0.2s); }
.add b { color: var(--orange); } .add span { background: #fbe9dc; color: #8a3d08; }
.keep b { color: var(--green); } .keep span { background: #def3e8; color: #176b47; }
@keyframes chip { from { opacity: 0; transform: translateY(6px); } }
.zero { margin-left: auto; font-weight: 700; color: var(--navy); font-size: 0.7rem; }
.zero b { color: var(--green); font-size: 0.9rem; }
.n-enter-active, .n-leave-active { transition: all 0.25s; }
.n-enter-from { opacity: 0; transform: translateY(6px); }
.n-leave-to { opacity: 0; }
</style>

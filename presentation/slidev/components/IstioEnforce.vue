<script setup lang="ts">
// Three Istio resources and where they run (slide 8). Needs `clicks: 4`.
// Left: the YAML resources. Right: the ingress gateway and the two app pods, each with an Envoy sidecar.
// Click 1: Gateway + VirtualService: routes light up from the gateway to the services.
// Click 2: RequestAuthentication: a JWT check on the gateway and on both sidecars.
// Click 3: AuthorizationPolicy: CUSTOM (to OAuth2-Proxy) and ALLOW at the gateway, ALLOW on roles in the sidecars.
// Click 4: istiod turns the YAML into Envoy config for every proxy; the apps have no security code.
// Resources are from k8s/istio/*.yaml, k8s/app/auth-app.yaml and k8s/reports/auth-reports.yaml (no DENY policy is used).
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $clicks } = useSlideContext()
const s = computed(() => Math.min(Math.max($clicks.value, 0), 4))
const on = (n: number) => ({ on: s.value >= n, now: s.value === n })

const cards = [
  { n: 1, k: 'Gateway + VirtualService', chip: 'Routing', c: 'rt', d: 'Routes app, api and keycloak.localhost to the right service; adds or removes headers per route' },
  { n: 2, k: 'RequestAuthentication', chip: 'AuthN', c: 'an', d: 'Validates a JWT: issuer, signature, expiry, audience' },
  { n: 3, k: 'AuthorizationPolicy', chip: 'AuthZ', c: 'az', d: 'ALLOW / DENY / CUSTOM on hosts, paths and token claims' },
]
const pods = [
  { k: 'spring-api', app: 'Spring Boot', y: 0 },
  { k: 'reports-api', app: 'FastAPI', y: 104 },
]
</script>

<template>
  <div class="ie">
    <!-- the resources -->
    <div v-for="(c, i) in cards" :key="c.k" class="card" :class="[c.c, on(c.n)]" :style="{ top: i * 92 + 'px' }">
      <div class="ct"><b class="mono">{{ c.k }}</b><span class="chip">{{ c.chip }}</span></div>
      <p>{{ c.d }}</p>
    </div>

    <svg class="wires" viewBox="0 0 894 330">
      <!-- routes -->
      <g class="w rt" :class="on(1)">
        <path d="M620,58 C650,58 650,44 680,44" />
        <path d="M620,148 L680,148" />
        <path d="M620,215 L680,215" />
      </g>
      <!-- CUSTOM → OAuth2-Proxy -->
      <path class="w custom" :class="on(3)" d="M620,250 C650,250 650,271 680,271" />
      <!-- istiod -->
      <g class="w cfg" :class="on(4)">
        <path d="M250,41 C265,41 265,135 280,135" />
        <path d="M250,133 L280,135" />
        <path d="M250,225 C265,225 265,135 280,135" />
        <path d="M368,135 L418,135" class="out" />
      </g>
    </svg>

    <!-- istiod -->
    <div class="istiod" :class="on(4)">
      <b class="mono">istiod</b><small>YAML → Envoy config, sent to every proxy</small>
    </div>

    <!-- ingress gateway -->
    <div class="gw env" :class="{ cfgd: s >= 4 }">
      <div class="et"><b>Ingress gateway</b><small class="mono">Envoy · app · api · keycloak.localhost</small></div>
      <div class="badges">
        <span class="bd rt" :class="on(1)">route + headers</span>
        <span class="bd an" :class="on(2)">JWT ✓ issuer · signature</span>
        <span class="bd az" :class="on(3)">CUSTOM → OAuth2-Proxy</span>
        <span class="bd az" :class="on(3)">ALLOW per host</span>
      </div>
    </div>

    <!-- app pods with sidecars -->
    <div v-for="p in pods" :key="p.k" class="pod" :style="{ top: p.y + 'px' }">
      <small class="ns mono">pod · {{ p.k }}</small>
      <div class="sc env" :class="{ cfgd: s >= 4 }">
        <small class="mono">sidecar · Envoy</small>
        <span class="bd an" :class="on(2)">JWT ✓ aud</span>
        <span class="bd az" :class="on(3)">ALLOW roles</span>
      </div>
      <div class="app">
        <b>{{ p.app }}</b>
        <small :class="on(4)">no security code</small>
      </div>
    </div>
    <div class="side mono" style="top: 196px">Keycloak<small>login, keys</small></div>
    <div class="side op mono" :class="{ hot: s >= 3 }" style="top: 252px">OAuth2-Proxy<small>session cookie</small></div>

    <p class="sum" :class="on(4)">The rules run in Envoy, at the gateway and in every sidecar, <b>not in your code.</b> No EnvoyFilter needed.</p>
  </div>
</template>

<style scoped>
.ie { --navy: #14213d; --blue: #2459c9; --orange: #c2570c; --red: #c0392b; --violet: #7b3fbf; --green: #1f8a5b; --muted: #7a8496;
  position: relative; width: 894px; height: 380px; margin-top: 1rem; }
.mono { font-family: 'JetBrains Mono', monospace; }
.rt { --c: var(--blue); --cbg: #e4ecfb; }
.an { --c: var(--orange); --cbg: #fbe9dc; }
.az { --c: var(--red); --cbg: #fbe3e0; }

.card { position: absolute; left: 0; width: 250px; height: 82px; padding: 0.45rem 0.65rem; border-radius: 12px; background: #fff;
  border: 1px solid #e6eaf2; border-left: 4px solid var(--c); opacity: 0; transform: translateX(-12px); transition: all 0.45s; }
.card.on { opacity: 1; transform: none; }
.card.now { box-shadow: 0 0 0 3px color-mix(in srgb, var(--c) 20%, transparent); }
.ct { display: flex; align-items: center; justify-content: space-between; gap: 0.3rem; }
.ct b { font-size: 0.66rem; color: var(--navy); white-space: nowrap; }
.chip { padding: 0.05rem 0.45rem; border-radius: 99px; background: var(--cbg); color: var(--c); font: 700 0.5rem 'JetBrains Mono', monospace; }
.card p { margin: 0.3rem 0 0 !important; font-size: 0.6rem; line-height: 1.35; color: #1b2433; }

.wires { position: absolute; inset: 0; width: 894px; height: 330px; overflow: visible; pointer-events: none; }
.w { fill: none; stroke-width: 2; opacity: 0.18; transition: opacity 0.4s; }
.w path { fill: none; }
.w.rt { stroke: var(--blue); }
.w.custom { stroke: var(--red); stroke-dasharray: 5 4; opacity: 0; }
.w.cfg { stroke: var(--violet); stroke-dasharray: 4 4; opacity: 0; }
.w.cfg .out { stroke-width: 2.4; }
.w.on { opacity: 1; }
.w.rt.on path { stroke-dasharray: 80; stroke-dashoffset: 80; animation: draw 0.7s ease-out forwards; }
@keyframes draw { to { stroke-dashoffset: 0; } }

.istiod { position: absolute; left: 280px; top: 100px; width: 88px; height: 70px; padding: 0.35rem 0.4rem; border-radius: 12px;
  background: #f3effa; border: 1.5px solid var(--violet); display: flex; flex-direction: column; justify-content: center;
  opacity: 0; transform: scale(0.85); transition: all 0.45s; }
.istiod.on { opacity: 1; transform: none; }
.istiod b { font-size: 0.72rem; color: var(--violet); }
.istiod small { font-size: 0.46rem; line-height: 1.3; color: #1b2433; }

.env { transition: box-shadow 0.4s, border-color 0.4s; }
.env.cfgd { border-color: var(--violet) !important; box-shadow: 0 0 0 3px rgba(123, 63, 191, 0.16); }
.gw { position: absolute; left: 420px; top: 20px; width: 200px; height: 250px; padding: 0.5rem 0.6rem; border-radius: 14px;
  background: #fff; border: 1.5px solid #c9d2e3; }
.et b { display: block; font-size: 0.8rem; color: var(--navy); }
.et small { font-size: 0.46rem; color: var(--muted); }
.badges { display: flex; flex-direction: column; gap: 0.4rem; margin-top: 0.7rem; }
.bd { display: inline-block; align-self: flex-start; padding: 0.12rem 0.5rem; border-radius: 99px; background: var(--cbg); color: var(--c);
  font: 700 0.54rem 'JetBrains Mono', monospace; white-space: nowrap; opacity: 0; transform: scale(0.8); transition: all 0.35s 0.25s; }
.bd.on { opacity: 1; transform: none; }
.bd.now { box-shadow: 0 0 0 2px var(--c); }

.pod { position: absolute; left: 680px; width: 214px; height: 88px; padding: 1rem 0.4rem 0.4rem; border-radius: 12px;
  border: 1.5px dashed #c9d2e3; display: flex; gap: 0.35rem; }
.ns { position: absolute; left: 8px; top: 2px; font-size: 0.46rem; color: var(--muted); }
.sc { flex: none; width: 104px; padding: 0.2rem 0.35rem; border-radius: 8px; background: #fff; border: 1.5px solid #c9d2e3;
  display: flex; flex-direction: column; gap: 0.18rem; }
.sc small { font-size: 0.44rem; color: var(--muted); }
.sc .bd { font-size: 0.48rem; }
.app { flex: 1; border-radius: 8px; background: #e7f5ee; display: flex; flex-direction: column; align-items: center; justify-content: center; }
.app b { font-size: 0.7rem; color: var(--navy); }
.app small { font: 700 0.46rem 'JetBrains Mono', monospace; color: var(--green); opacity: 0; transition: opacity 0.4s 0.6s; }
.app small.on { opacity: 1; }

.side { position: absolute; left: 680px; width: 214px; height: 38px; padding: 0.2rem 0.6rem; border-radius: 10px; background: #fff;
  border: 1.5px solid #e2e6ee; font-size: 0.62rem; font-weight: 700; color: var(--navy); display: flex; align-items: center; justify-content: space-between; transition: all 0.4s; }
.side small { font: 400 0.48rem 'Inter', sans-serif; color: var(--muted); }
.side.hot { border-color: var(--red); background: #fdf1ef; }

.sum { position: absolute; left: 0; top: 300px; width: 894px; margin: 0 !important; padding: 0.5rem 0.8rem; border-radius: 10px;
  background: #f3effa; border-left: 4px solid var(--violet); font-size: 0.78rem; color: #1b2433; opacity: 0; transition: opacity 0.45s 0.4s; }
.sum.on { opacity: 1; }
</style>

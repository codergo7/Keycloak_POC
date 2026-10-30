<script setup lang="ts">
// What runs where in the POC, one layer per click (slide needs `clicks: 5`).
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $clicks } = useSlideContext()
const step = computed(() => Math.min($clicks.value, 5))

// wire: svg path, the step it appears on, and an optional colour class
const wires = [
  { d: 'M120 78 C150 78 160 135 185 135', at: 1 },
  { d: 'M120 228 C150 228 160 165 185 165', at: 1 },
  { d: 'M300 110 V45 H665 V60', at: 2 },
  { d: 'M730 90 H760', at: 2 },
  { d: 'M345 130 H385 V90 H415', at: 3 },
  { d: 'M555 90 H600', at: 3, cls: 'orange' },
  { d: 'M345 165 H470 V253 H590', at: 4 },
  { d: 'M265 240 V186', at: 5, cls: 'purple' },
  { d: 'M345 268 H590', at: 5, cls: 'purple' },
  { d: 'M345 250 H375 V150 H665 V120', at: 5, cls: 'purple' },
]

const labels = [
  { t: ':8080', x: 128, y: 140, at: 1 },
  { t: 'keycloak.localhost', x: 470, y: 32, at: 2 },
  { t: 'ext_authz', x: 349, y: 137, at: 3 },
  { t: 'back channel', x: 540, y: 124, at: 3, cls: 'orange' },
  { t: 'app · api routes', x: 478, y: 198, at: 4 },
  { t: 'config', x: 272, y: 204, at: 5, cls: 'purple' },
  { t: 'routes + policies', x: 440, y: 274, at: 5, cls: 'purple' },
  { t: 'JWKS keys', x: 672, y: 128, at: 5, cls: 'purple' },
]

const notes = [
  'One kind cluster on a laptop, with three namespaces. Click to fill it in.',
  'Browser and scripts both enter through one Istio ingress gateway on localhost:8080. It routes three hosts.',
  'iam: Keycloak with realm poc, storing its data in Postgres. Logins happen at keycloak.localhost.',
  'OAuth2-Proxy: the gateway asks it about every app.localhost request. It swaps the login code for tokens with Keycloak on the back channel.',
  'demo: the Spring Boot app with its Envoy sidecar. Both app.localhost and api.localhost end here.',
  'istiod pushes routes and policies to the gateway and every sidecar, and fetches Keycloak\'s public keys (JWKS) to check tokens.',
]
</script>

<template>
  <div class="arch">
    <div class="stage">
      <div class="cluster"><span>kind cluster · localhost:8080</span></div>
      <div class="ns istio"><span>istio-system</span></div>
      <div class="ns iam"><span>iam</span></div>
      <div class="ns demo"><span>demo</span></div>

      <svg class="wires" viewBox="0 0 900 330">
        <path v-for="(w, i) in wires" :key="i" :d="w.d" class="wire" :class="[w.cls, { shown: step >= w.at, live: step === w.at }]" />
      </svg>

      <div class="node browser" :class="{ shown: step >= 1, on: step === 1 }">Browser<small>a person</small></div>
      <div class="node script" :class="{ shown: step >= 1, on: step === 1 }">curl<small>a script</small></div>
      <div class="node gateway" :class="{ shown: step >= 1, on: step === 1 }">Ingress gateway<small>keycloak · app · api<br>.localhost</small></div>
      <div class="node keycloak" :class="{ shown: step >= 2, on: step === 2 }">Keycloak<small>realm poc</small></div>
      <div class="node postgres" :class="{ shown: step >= 2, on: step === 2 }">Postgres<small>no volume</small></div>
      <div class="node proxy" :class="{ shown: step >= 3, on: step === 3 }">OAuth2-Proxy<small>session cookie</small></div>
      <div class="node spring" :class="{ shown: step >= 4, on: step === 4 }">Spring Boot<small>+ Envoy sidecar</small></div>
      <div class="node istiod" :class="{ shown: step >= 5, on: step === 5 }">istiod<small>control plane</small></div>

      <div v-for="l in labels" :key="l.t" class="label" :class="[l.cls, { shown: step >= l.at }]" :style="{ left: l.x + 'px', top: l.y + 'px' }">{{ l.t }}</div>
    </div>

    <Transition name="n" mode="out-in">
      <p :key="step" class="note"><b v-if="step">{{ step }}.</b> {{ notes[step] }}</p>
    </Transition>
  </div>
</template>

<style scoped>
.stage { position: relative; width: 900px; height: 330px; margin: 0 auto; }
.wires { position: absolute; inset: 0; width: 100%; height: 100%; }

.cluster, .ns { position: absolute; border-radius: 14px; }
.cluster { left: 150px; top: 0; width: 750px; height: 330px; border: 2px dashed #c9cfdb; }
.ns { border: 1px solid #e0e4ec; background: rgba(255, 255, 255, 0.55); }
.cluster span, .ns span {
  position: absolute; left: 10px; top: 4px; font: 600 0.56rem 'JetBrains Mono', monospace; color: #7a8496;
  letter-spacing: 0.06em; text-transform: uppercase;
}
.cluster span { left: auto; right: 12px; top: -18px; }
.istio { left: 165px; top: 26px; width: 200px; height: 292px; }
.iam { left: 395px; top: 26px; width: 490px; height: 140px; }
.demo { left: 395px; top: 182px; width: 490px; height: 136px; }

.wire { fill: none; stroke: #2459c9; stroke-width: 2; opacity: 0; transition: opacity 0.5s; }
.wire.shown { opacity: 0.35; }
.wire.live { opacity: 1; stroke-dasharray: 5 6; animation: flow 0.8s linear infinite; }
.wire.orange { stroke: #c2570c; }
.wire.purple { stroke: #7b4bc4; }
@keyframes flow { to { stroke-dashoffset: -11; } }

.node {
  position: absolute; display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center;
  background: #fff; border: 1px solid #e6eaf2; border-radius: 12px; font-weight: 700; color: #14213d; font-size: 0.86rem;
  box-shadow: 0 8px 24px -18px rgba(20, 33, 61, 0.5);
  opacity: 0; transform: translateY(10px) scale(0.94); transition: all 0.5s cubic-bezier(0.3, 0.7, 0.3, 1.2);
}
.node.shown { opacity: 1; transform: none; }
.node small { font: 500 0.56rem/1.3 'JetBrains Mono', monospace; color: #7a8496; }
.node.on { background: #14213d; color: #fff; border-color: #14213d; }
.node.on small { color: #8db4ff; }
.browser { left: 0; top: 50px; width: 120px; height: 56px; }
.script { left: 0; top: 200px; width: 120px; height: 56px; }
.gateway { left: 185px; top: 110px; width: 160px; height: 76px; }
.istiod { left: 185px; top: 240px; width: 160px; height: 56px; }
.proxy { left: 415px; top: 60px; width: 140px; height: 60px; }
.keycloak { left: 600px; top: 60px; width: 130px; height: 60px; }
.postgres { left: 760px; top: 60px; width: 110px; height: 60px; }
.spring { left: 590px; top: 220px; width: 200px; height: 66px; }

.label {
  position: absolute; font: 600 0.56rem 'JetBrains Mono', monospace; color: #2459c9; white-space: nowrap;
  background: #f7f6f2; padding: 0 0.25rem; border-radius: 4px; opacity: 0; transition: opacity 0.4s 0.3s;
}
.label.shown { opacity: 1; }
.label.orange { color: #c2570c; }
.label.purple { color: #7b4bc4; }

.note { font-size: 0.86rem; color: #1b2433; min-height: 2.6rem; margin: 0.7rem 0 0; text-align: left; }
.n-enter-active, .n-leave-active { transition: all 0.25s; }
.n-enter-from { opacity: 0; transform: translateY(6px); }
.n-leave-to { opacity: 0; }
</style>

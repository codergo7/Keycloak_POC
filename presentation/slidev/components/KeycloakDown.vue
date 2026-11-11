<script setup lang="ts">
// "What if Keycloak goes down?": a 0–7 minute timeline after Keycloak stops. One lane per
// click, measured on the running POC (Keycloak scaled to 0): green while it works, red after.
// Times are measured points: 200 at 0 and 4.4 min, failures at 6.5 min. The slide needs `clicks: 5`.
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $clicks } = useSlideContext()
const s = computed(() => Math.max($clicks.value, 0))
const MAX = 7 // minutes on the axis
const x = (m: number) => `${(m / MAX) * 100}%`

const marks = [
  { m: 0, t: 'Keycloak stops', cls: 'red' },
  { m: 4, t: 'refresh due', cls: '' },
  { m: 5, t: 'token expires', cls: '' },
  { m: 6, t: '+60 s clock skew', cls: '' },
]
const lanes = [
  { who: 'Script, token from before', ok: 6, okT: '200: Envoy checks it offline, until exp + 60 s', bad: '401 expired' },
  { who: 'Browser, logged in before', ok: 5, okT: '200, even when the refresh fails', bad: '302 to login → 503' },
  { who: 'Browser, new login', ok: 0, okT: '', bad: '503 no healthy upstream' },
  { who: 'Script, new token', ok: 0, okT: '', bad: '503 at the token endpoint' },
]
</script>

<template>
  <div class="kd">
    <div class="axis">
      <div class="who" />
      <div class="track">
        <div v-for="m in [0, 1, 2, 3, 4, 5, 6, 7]" :key="m" class="tick" :style="{ left: x(m) }">{{ m }} min</div>
      </div>
    </div>
    <div class="body">
      <div class="marks">
        <div v-for="k in marks" :key="k.t" class="mark" :class="k.cls" :style="{ left: x(k.m) }"><span>{{ k.t }}</span></div>
      </div>
      <div v-for="(l, i) in lanes" :key="l.who" class="lane" :class="{ on: s > i }">
        <div class="who">{{ l.who }}</div>
        <div class="track">
          <div v-if="l.ok > 0" class="seg ok" :style="{ left: 0, width: x(l.ok) }"><span>{{ l.okT }}</span></div>
          <div class="seg bad" :style="{ left: x(l.ok), width: `calc(100% - ${x(l.ok)})` }"><span>{{ l.bad }}</span></div>
        </div>
      </div>
    </div>
    <div class="sum" :class="{ on: s >= 5 }">
      <div><b>Keeps working:</b> requests with a token that is still valid. Istio checks tokens with keys it already has, and never calls Keycloak per request.</div>
      <div><b>Stops:</b> new logins, new tokens and refreshes at once, and every existing session within about 5 minutes, when its token expires.</div>
    </div>
  </div>
</template>

<style scoped>
.kd { margin-top: 0.6rem; font-size: 0.75rem; }
.axis, .lane { display: flex; align-items: center; gap: 0.8rem; }
.who { width: 11rem; flex: none; font-weight: 600; color: #14213d; }
.track { position: relative; flex: 1; height: 100%; }
.axis .track { height: 1.2rem; border-bottom: 1px solid #c5c4c1; }
.tick { position: absolute; white-space: nowrap; transform: translateX(-50%); font: 600 0.55rem 'JetBrains Mono', monospace; color: #7a8496; }
.tick:last-child { transform: translateX(-100%); }
.body { position: relative; }
.marks { position: absolute; left: 11.8rem; right: 0; top: 0; bottom: 0; pointer-events: none; }
.mark { position: absolute; top: 0; bottom: 0; border-left: 1.5px dashed #b8c3d8; }
.mark.red { border-left: 2px solid #c0352b; }
.mark span { position: absolute; bottom: -1.1rem; left: 3px; white-space: nowrap; font: 600 0.5rem 'JetBrains Mono', monospace; color: #7a8496; }
.mark.red span { color: #c0352b; }
.lane { height: 3rem; opacity: 0.15; transition: opacity 0.4s; }
.lane.on { opacity: 1; }
.lane .track { height: 1.7rem; }
.seg { position: absolute; top: 0; bottom: 0; border-radius: 6px; display: flex; align-items: center; padding: 0 0.5rem; overflow: hidden; transform-origin: left; transform: scaleX(0); transition: transform 0.7s cubic-bezier(0.3, 0, 0.2, 1); }
.lane.on .seg { transform: scaleX(1); }
.lane.on .seg.bad { transition-delay: 0.6s; }
.seg span { font: 600 0.58rem 'JetBrains Mono', monospace; white-space: nowrap; }
.seg.ok { background: #def3e8; color: #1f8a5b; }
.seg.bad { background: #fbe3e1; color: #c0352b; }
.sum { margin-top: 1.6rem; display: grid; grid-template-columns: 1fr 1fr; gap: 0.8rem; opacity: 0; transform: translateY(10px); transition: all 0.5s; }
.sum.on { opacity: 1; transform: none; }
.sum div { background: #fff; border: 1px solid #e6eaf2; border-radius: 10px; padding: 0.55rem 0.7rem; line-height: 1.45; color: #4a5568; }
.sum b { color: #14213d; }
</style>

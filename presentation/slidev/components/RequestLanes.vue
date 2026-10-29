<script setup lang="ts">
// Several requests run through the same checkpoints; each lane appears on a
// click and its packet runs until the check that stops it (slide needs `clicks: 6`).
import { useSlideContext } from '@slidev/client'

const { $clicks } = useSlideContext()

const cols = ['Route', 'CUSTOM', 'JWT', 'ALLOW', 'mTLS', 'JWT', 'ALLOW', 'Spring']
const groups = [
  { label: 'ingress gateway', span: 4 },
  { label: 'spring sidecar', span: 4 },
]

const lanes = [
  { who: 'Browser, no session', req: 'GET app/api/whoami', stop: 1, code: '302 → Keycloak', cls: 'code-30x', why: 'oauth2-proxy: no session' },
  { who: 'Browser, with session', req: 'GET app/api/whoami + cookie', stop: 7, code: '200', cls: 'code-200', why: 'token from X-Auth-Request-Access-Token' },
  { who: 'curl, no token', req: 'GET api/api/user', stop: 3, code: '403', cls: 'code-403', why: 'no requestPrincipal at the edge' },
  { who: 'curl, tampered token', req: 'GET api/api/user + Bearer x.y.z', stop: 2, code: '401', cls: 'code-401', why: 'Jwt verification fails' },
  { who: 'alice token', req: 'GET api/api/admin', stop: 6, code: '403', cls: 'code-403', why: 'valid, but no admin role' },
  { who: 'admin token', req: 'GET api/api/admin', stop: 7, code: '200', cls: 'code-200', why: 'role admin' },
]

function pos(i: number) {
  return `${(i / (cols.length - 1)) * 100}%`
}
</script>

<template>
  <div class="lanes">
    <div class="head">
      <div class="who-col" />
      <div class="track-head">
        <div class="groups">
          <div v-for="g in groups" :key="g.label" class="group" :style="{ flex: g.span }">{{ g.label }}</div>
        </div>
        <div class="cols">
          <div v-for="(c, i) in cols" :key="i" class="col" :style="{ left: pos(i) }">{{ c }}</div>
        </div>
      </div>
      <div class="out-col" />
    </div>

    <div v-for="(l, i) in lanes" :key="l.who" class="lane" :class="{ shown: $clicks > i }">
      <div class="who-col">
        <div class="who">{{ l.who }}</div>
        <div class="req mono">{{ l.req }}</div>
      </div>
      <div class="track">
        <div class="rail" />
        <div v-for="(c, j) in cols" :key="j" class="tick" :class="{ passed: j < l.stop, stop: j === l.stop }"
          :style="{ left: pos(j), transitionDelay: $clicks > i ? j * 0.18 + 's' : '0s' }" />
        <div v-if="$clicks > i" class="packet" :class="l.cls"
          :style="{ '--to': pos(l.stop), animationDuration: 0.3 + l.stop * 0.18 + 's' }" />
      </div>
      <div class="out-col">
        <div v-if="$clicks > i" class="out" :style="{ animationDelay: 0.35 + l.stop * 0.18 + 's' }">
          <span :class="l.cls">{{ l.code }}</span>
          <div class="why">{{ l.why }}</div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.lanes { font-size: 0.78rem; }
.head, .lane { display: flex; align-items: center; gap: 1rem; }
.who-col { width: 11.5rem; flex: none; }
.out-col { width: 10rem; flex: none; }
.track-head, .track { position: relative; flex: 1; margin: 0 0.6rem; }
.groups { display: flex; gap: 0.6rem; margin: 0 -0.6rem 0.2rem; }
.group {
  text-align: center; font: 500 0.58rem 'JetBrains Mono', monospace; letter-spacing: 0.1em;
  text-transform: uppercase; color: #7a8496; border-bottom: 1px solid #c5c4c1; padding-bottom: 0.15rem;
}
.cols { position: relative; height: 1.2rem; }
.col { position: absolute; transform: translateX(-50%); font: 600 0.62rem 'JetBrains Mono', monospace; color: #14213d; white-space: nowrap; }

.lane { height: 2.75rem; opacity: 0.18; transition: opacity 0.4s; border-top: 1px solid #ecebe7; }
.lane.shown { opacity: 1; }
.who { font-weight: 600; color: #14213d; line-height: 1.2; }
.req { font-size: 0.6rem; color: #7a8496; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

.track { height: 100%; }
.rail { position: absolute; left: 0; right: 0; top: 50%; height: 2px; background: #e0e1e0; transform: translateY(-50%); }
.tick {
  position: absolute; top: 50%; width: 10px; height: 10px; border-radius: 999px; background: #fff;
  border: 2px solid #c5c4c1; transform: translate(-50%, -50%); transition: all 0.3s;
}
.lane.shown .tick.passed { border-color: #2459c9; background: #2459c9; }
.lane.shown .tick.stop { border-color: currentColor; }
.packet {
  position: absolute; top: 50%; width: 16px; height: 16px; border-radius: 999px; background: currentColor;
  transform: translate(-50%, -50%); box-shadow: 0 0 0 5px color-mix(in srgb, currentColor 20%, transparent);
  animation-name: run; animation-timing-function: cubic-bezier(0.5, 0, 0.3, 1); animation-fill-mode: forwards;
}
@keyframes run { from { left: 0; } to { left: var(--to); } }

.out { opacity: 0; animation: pop 0.35s cubic-bezier(0.2, 0.9, 0.3, 1.3) forwards; }
.out span { font: 700 0.95rem 'JetBrains Mono', monospace; }
.why { font-size: 0.62rem; color: #7a8496; line-height: 1.2; }
@keyframes pop { from { opacity: 0; transform: scale(0.7); } to { opacity: 1; transform: scale(1); } }
</style>

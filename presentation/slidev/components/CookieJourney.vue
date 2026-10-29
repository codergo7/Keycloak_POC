<script setup lang="ts">
// Where the session cookie and the identity headers travel (slide needs `clicks: 5`).
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $clicks } = useSlideContext()
const step = computed(() => Math.min($clicks.value, 5))

// chip positions per step, in px inside the 860×300 stage
const cookiePos = [
  { x: 30, y: 128 }, { x: 345, y: 128 }, { x: 200, y: 24 }, { x: 345, y: 128 }, { x: 345, y: 128 }, { x: 345, y: 128 },
]
const headersPos = [
  { x: 520, y: 24 }, { x: 520, y: 24 }, { x: 520, y: 24 }, { x: 470, y: 128 }, { x: 665, y: 128 }, { x: 665, y: 128 },
]
const cookie = computed(() => cookiePos[step.value])
const headers = computed(() => headersPos[step.value])

const notes = [
  'The browser holds the cookie. Click to follow one request.',
  'The browser sends Cookie: _oauth2_proxy=… to the ingress gateway.',
  'ext_authz forwards only cookie and authorization to oauth2-proxy (includeRequestHeadersInCheck).',
  'oauth2-proxy answers 200 with X-Auth-Request-* headers. Only headersToUpstreamOnAllow are copied into the request.',
  'The router applies the route rule headers.request.remove: [cookie]. Spring gets identity headers, never the session.',
  'On the way back no X-Auth-Request-* header is returned. Set-Cookie reaches the browser only when the session is refreshed.',
]
</script>

<template>
  <div class="journey">
    <div class="stage">
      <svg class="wires" viewBox="0 0 860 300">
        <path d="M150 170 H340" class="wire" :class="{ lit: step >= 1 }" />
        <path d="M430 140 V80" class="wire" :class="{ lit: step >= 2 && step <= 3 }" />
        <path d="M520 170 H700" class="wire" :class="{ lit: step >= 4 }" />
        <path d="M770 205 V262 H80 V205" class="wire back" :class="{ lit: step >= 5 }" />
      </svg>

      <div class="node browser" :class="{ on: step === 1 || step === 5 }">Browser</div>
      <div class="node gateway" :class="{ on: step >= 1 && step <= 4 }">Ingress gateway<small>ext_authz · router</small></div>
      <div class="node proxy" :class="{ on: step === 2 || step === 3 }">OAuth2-Proxy</div>
      <div class="node spring" :class="{ on: step >= 4 }">Spring Boot<small>+ sidecar</small></div>

      <div class="chip-move cookie" :class="{ stripped: step >= 4 }" :style="{ left: cookie.x + 'px', top: cookie.y + 'px' }">
        🍪 Cookie: _oauth2_proxy
      </div>
      <div class="chip-move headers" :class="{ shown: step >= 3 }" :style="{ left: headers.x + 'px', top: headers.y + 'px' }">
        X-Auth-Request-User<br>X-Auth-Request-Access-Token
      </div>

      <div class="resp" :class="{ shown: step >= 5 }">
        200 · <s>X-Auth-Request-*</s> · <span class="set">Set-Cookie only on refresh</span>
      </div>
      <div class="strip" :class="{ shown: step >= 4 }">✂ headers.request.remove: [cookie]</div>
    </div>

    <Transition name="n" mode="out-in">
      <p :key="step" class="note"><b v-if="step">{{ step }}.</b> {{ notes[step] }}</p>
    </Transition>
  </div>
</template>

<style scoped>
.stage { position: relative; width: 860px; height: 300px; margin: 0 auto; }
.wires { position: absolute; inset: 0; width: 100%; height: 100%; }
.wire { fill: none; stroke: #d6d8dc; stroke-width: 2; stroke-dasharray: 5 6; transition: stroke 0.4s; }
.wire.lit { stroke: #2459c9; animation: flow 0.8s linear infinite; }
.wire.back.lit { stroke: #1f8a5b; }
@keyframes flow { to { stroke-dashoffset: -11; } }

.node {
  position: absolute; display: flex; flex-direction: column; align-items: center; justify-content: center;
  background: #fff; border: 1px solid #e6eaf2; border-radius: 12px; font-weight: 700; color: #14213d;
  font-size: 0.9rem; transition: all 0.4s; box-shadow: 0 8px 24px -18px rgba(20, 33, 61, 0.5);
}
.node small { font: 500 0.58rem 'JetBrains Mono', monospace; color: #7a8496; }
.node.on { background: #14213d; color: #fff; border-color: #14213d; }
.node.on small { color: #8db4ff; }
.browser { left: 10px; top: 140px; width: 140px; height: 64px; }
.gateway { left: 340px; top: 140px; width: 180px; height: 64px; }
.proxy { left: 345px; top: 20px; width: 170px; height: 58px; }
.spring { left: 700px; top: 140px; width: 150px; height: 64px; }

.chip-move {
  position: absolute; font: 600 0.62rem/1.35 'JetBrains Mono', monospace; padding: 0.25rem 0.55rem;
  border-radius: 8px; white-space: nowrap; transition: all 0.8s cubic-bezier(0.5, 0, 0.25, 1);
  transform: translateY(-100%);
}
.cookie { background: #fde7cf; color: #8a3b06; }
.cookie.stripped { opacity: 0.35; text-decoration: line-through; transform: translateY(-100%) rotate(-4deg); }
.headers { background: #e3ecfb; color: #14213d; opacity: 0; }
.headers.shown { opacity: 1; }

.resp {
  position: absolute; left: 50%; top: 262px; transform: translate(-50%, -50%) scale(0.8); background: #def3e8;
  color: #135c3c; font: 600 0.66rem 'JetBrains Mono', monospace; padding: 0.25rem 0.7rem; border-radius: 999px;
  opacity: 0; transition: all 0.5s;
}
.resp.shown { opacity: 1; transform: translate(-50%, -50%) scale(1); }
.resp .set { color: #8a3b06; }
.strip {
  position: absolute; left: 430px; top: 222px; transform: translateX(-50%); font: 600 0.62rem 'JetBrains Mono', monospace;
  color: #c0352b; opacity: 0; transition: opacity 0.4s 0.4s; white-space: nowrap;
}
.strip.shown { opacity: 1; }

.note { font-size: 0.86rem; color: #1b2433; min-height: 2.6rem; margin: 0.6rem 0 0; text-align: left; }
.n-enter-active, .n-leave-active { transition: all 0.25s; }
.n-enter-from { opacity: 0; transform: translateY(6px); }
.n-leave-to { opacity: 0; }
</style>

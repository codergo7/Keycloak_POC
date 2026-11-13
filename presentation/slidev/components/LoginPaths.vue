<script setup lang="ts">
// Who talks to Keycloak during login (slide needs `clicks: 6`).
// Front channel: browser -> ingress gateway -> Keycloak. Back channel: OAuth2-Proxy -> Keycloak in-cluster.
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $clicks } = useSlideContext()
const step = computed(() => Math.min($clicks.value, 6))

const msgs = [
  '',
  'GET app.localhost/ → 302 Location: keycloak.localhost',
  'GET keycloak.localhost/realms/demo/…/auth',
  'POST password → 302 /oauth2/callback?code=…',
  'GET app.localhost/oauth2/callback?code=…',
  'POST /token + secret',
  '',
]
const msgPos = [
  { x: 10, y: 96 }, { x: 10, y: 96 }, { x: 10, y: 96 }, { x: 10, y: 96 }, { x: 10, y: 96 }, { x: 556, y: 118 }, { x: 556, y: 118 },
]
const msg = computed(() => msgPos[step.value])
const host = computed(() =>
  [ '', 'app.localhost', 'keycloak.localhost', 'keycloak.localhost', 'app.localhost', '', '' ][step.value])

const notes = [
  'Alice is not logged in yet. Click to see who talks to whom.',
  'OAuth2-Proxy finds no cookie and only answers with a 302 redirect to Keycloak’s public URL.',
  'The browser opens its own request to keycloak.localhost. It goes through the ingress gateway, which only routes it.',
  'Keycloak shows the login page, checks the password and redirects back with a one-time code. OAuth2-Proxy never sees the password.',
  'The browser brings the code to /oauth2/callback, routed by the gateway to OAuth2-Proxy.',
  'OAuth2-Proxy swaps the code for tokens pod to pod. This call skips the gateway and never touches the browser.',
  'Two names for one Keycloak: the public name is the token issuer, the internal name is used for tokens and keys.',
]
</script>

<template>
  <div class="paths">
    <div class="stage">
      <svg class="wires" viewBox="0 0 860 320">
        <path d="M150 168 H300" class="wire" :class="{ lit: step >= 1 && step <= 4 }" />
        <path d="M480 156 H530 V45 H650" class="wire" :class="{ lit: step === 1 || step === 4 }" />
        <path d="M480 180 H530 V275 H650" class="wire" :class="{ lit: step === 2 || step === 3 }" />
        <path d="M745 74 V246" class="wire back" :class="{ lit: step >= 5 }" />
        <text x="735" y="168" text-anchor="end" class="wire-label" :class="{ shown: step >= 5 }">back channel · svc.cluster.local</text>
      </svg>

      <div class="node browser" :class="{ on: step >= 1 && step <= 4 }">Browser<small>Alice</small></div>
      <div class="node gateway" :class="{ on: step >= 1 && step <= 4, off: step === 5 }">
        Ingress gateway<small>{{ step === 5 ? 'not on this path' : 'routes only' }}</small>
      </div>
      <div class="node proxy" :class="{ on: step === 1 || step === 4 || step === 5, off: step === 2 || step === 3 }">
        OAuth2-Proxy<small>{{ step === 2 || step === 3 ? 'not involved' : 'redirects · swaps code' }}</small>
      </div>
      <div class="node keycloak" :class="{ on: step === 2 || step === 3 || step === 5 }">Keycloak<small>login page · tokens</small></div>

      <div class="chip-move msg" :class="{ shown: msgs[step] }" :style="{ left: msg.x + 'px', top: msg.y + 'px' }">
        {{ msgs[step] }}
      </div>
      <div class="host" :class="{ shown: host }">Host: {{ host }}</div>

      <div class="names" :class="{ shown: step >= 6 }">
        <span><b>Public</b> keycloak.localhost:8080 · issuer, login page</span>
        <span><b>Internal</b> keycloak.identity.svc.cluster.local · token, JWKS</span>
      </div>
    </div>

    <Transition name="n" mode="out-in">
      <p :key="step" class="note"><b v-if="step">{{ step }}.</b> {{ notes[step] }}</p>
    </Transition>
  </div>
</template>

<style scoped>
.stage { position: relative; width: 860px; height: 320px; margin: 0 auto; }
.wires { position: absolute; inset: 0; width: 100%; height: 100%; }
.wire { fill: none; stroke: #d6d8dc; stroke-width: 2; stroke-dasharray: 5 6; transition: stroke 0.4s; }
.wire.lit { stroke: #2459c9; animation: flow 0.8s linear infinite; }
.wire.back.lit { stroke: #c2570c; stroke-width: 3; }
@keyframes flow { to { stroke-dashoffset: -11; } }
.wire-label { font: 600 10px 'JetBrains Mono', monospace; fill: #c2570c; opacity: 0; transition: opacity 0.4s 0.3s; }
.wire-label.shown { opacity: 1; }

.node {
  position: absolute; display: flex; flex-direction: column; align-items: center; justify-content: center;
  background: #fff; border: 1px solid #e6eaf2; border-radius: 12px; font-weight: 700; color: #14213d;
  font-size: 0.9rem; transition: all 0.4s; box-shadow: 0 8px 24px -18px rgba(20, 33, 61, 0.5);
}
.node small { font: 500 0.58rem 'JetBrains Mono', monospace; color: #7a8496; }
.node.on { background: #14213d; color: #fff; border-color: #14213d; }
.node.on small { color: #8db4ff; }
.node.off { opacity: 0.4; border-style: dashed; box-shadow: none; }
.browser { left: 10px; top: 136px; width: 140px; height: 64px; }
.gateway { left: 300px; top: 136px; width: 180px; height: 64px; }
.proxy { left: 650px; top: 16px; width: 190px; height: 58px; }
.keycloak { left: 650px; top: 246px; width: 190px; height: 58px; }

.chip-move {
  position: absolute; font: 600 0.62rem/1.35 'JetBrains Mono', monospace; padding: 0.25rem 0.55rem;
  border-radius: 8px; white-space: nowrap; transition: all 0.6s cubic-bezier(0.5, 0, 0.25, 1);
  background: #e3ecfb; color: #14213d; opacity: 0;
}
.chip-move.shown { opacity: 1; }
.host {
  position: absolute; left: 390px; top: 212px; transform: translateX(-50%); font: 600 0.62rem 'JetBrains Mono', monospace;
  color: #2459c9; white-space: nowrap; opacity: 0; transition: opacity 0.3s;
}
.host.shown { opacity: 1; }

.names {
  position: absolute; left: 10px; top: 248px; display: flex; flex-direction: column; gap: 0.3rem;
  font: 500 0.62rem 'JetBrains Mono', monospace; color: #14213d; opacity: 0; transform: translateY(6px); transition: all 0.4s;
}
.names.shown { opacity: 1; transform: none; }
.names span { background: #fcebdd; padding: 0.2rem 0.55rem; border-radius: 6px; }
.names b { color: #c2570c; margin-right: 0.3rem; }

.note { font-size: 0.86rem; color: #1b2433; min-height: 2.6rem; margin: 0.6rem 0 0; text-align: left; }
.n-enter-active, .n-leave-active { transition: all 0.25s; }
.n-enter-from { opacity: 0; transform: translateY(6px); }
.n-leave-to { opacity: 0; }
</style>

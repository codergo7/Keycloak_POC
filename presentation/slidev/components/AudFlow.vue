<script setup lang="ts">
// How Keycloak fills `aud` from client scopes, and how each sidecar checks it
// (slide needs `clicks: 7`). Steps 1-3: no reports scope. Steps 4-6: with it.
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $clicks } = useSlideContext()
const step = computed(() => Math.min($clicks.value, 7))

const withReports = computed(() => step.value >= 4)
const aud = computed(() => {
  if (step.value >= 5) return ['spring-api', 'reports-api']
  if (step.value >= 2 && step.value < 4) return ['spring-api']
  return []
})
// sidecar verdicts: null = not asked yet
const springOk = computed(() => (step.value === 3 || step.value >= 6 ? true : null))
const reportsOk = computed(() => (step.value === 3 ? false : step.value >= 6 ? true : null))

const notes = [
  'Where does aud come from? Click to request a token.',
  'cli-client asks for a token with the usual scopes, without reports.',
  'app-audience is a default scope of the client, so its mapper always runs: aud = spring-api.',
  'Spring\'s sidecar accepts it. The reports sidecar requires aud reports-api and answers 403.',
  'Same user, new request, now with scope=reports.',
  'reports is an optional scope: it runs only when asked for, and its mapper adds reports-api.',
  'Both sidecars accept the audience. From here, the roles decide.',
  'Removed on purpose: "audience resolve" would add reports-api to anyone with a reports role.',
]
</script>

<template>
  <div class="audflow">
    <div class="stage">
      <svg class="wires" viewBox="0 0 900 300">
        <path d="M150 150 H330" class="wire" :class="{ lit: step === 1 || step === 4 }" />
        <path d="M570 150 H595" class="wire" :class="{ lit: step === 2 || step === 5 }" />
        <path d="M745 135 C758 135 758 75 770 75" class="wire" :class="{ lit: step === 3 || step === 6 }" />
        <path d="M745 165 C758 165 758 225 770 225" class="wire" :class="{ lit: step === 3 || step === 6, bad: step === 3 }" />
      </svg>

      <div class="node client" :class="{ on: step === 1 || step === 4 }">cli-client<small>or oauth2-proxy</small></div>
      <div class="req" :class="{ shown: step >= 1 }">
        scope=openid … app-audience<span class="extra" :class="{ shown: withReports }"> reports</span>
      </div>

      <div class="kc">
        <div class="kc-head">Keycloak · realm demo<small>client scopes of cli-client</small></div>
        <div class="row" :class="{ active: step === 2 || step === 5 }">
          <span class="tag">default</span><b>app-audience</b>
          <span class="map">mapper: aud += spring-api</span>
        </div>
        <div class="row" :class="{ dim: !withReports, active: step === 5 }">
          <span class="tag opt">optional</span><b>reports</b>
          <span class="map">mapper: aud += reports-api</span>
        </div>
        <div class="row">
          <span class="tag">default</span><b>roles</b>
          <span class="map">realm + client roles</span>
          <span class="removed" :class="{ shown: step >= 7 }">✕ audience resolve (removed)</span>
        </div>
      </div>

      <div class="token" :class="{ on: aud.length && (step === 2 || step === 5) }">
        <div class="t-head">access token</div>
        <div class="t-line">aud:</div>
        <TransitionGroup name="chip" tag="div" class="chips">
          <span v-for="a in aud" :key="a" class="chip-aud" :class="{ orange: a === 'reports-api' }">{{ a }}</span>
        </TransitionGroup>
        <div v-if="!aud.length" class="t-empty">—</div>
      </div>

      <div class="node side spring">Spring sidecar<small>needs aud spring-api</small>
        <span class="verdict ok" :class="{ shown: springOk === true }">✓ aud ok</span>
      </div>
      <div class="node side reports">Reports sidecar<small>needs aud reports-api</small>
        <span class="verdict" :class="{ shown: reportsOk !== null, ok: reportsOk === true, bad: reportsOk === false }">
          {{ reportsOk === false ? '403 Audiences in Jwt are not allowed' : '✓ aud ok · roles decide' }}
        </span>
      </div>
    </div>

    <Transition name="n" mode="out-in">
      <p :key="step" class="note"><b v-if="step">{{ step }}.</b> {{ notes[step] }}</p>
    </Transition>
  </div>
</template>

<style scoped>
.stage { position: relative; width: 900px; height: 300px; margin: 0 auto; }
.wires { position: absolute; inset: 0; width: 100%; height: 100%; }
.wire { fill: none; stroke: #d6d8dc; stroke-width: 2; stroke-dasharray: 5 6; transition: stroke 0.4s; }
.wire.lit { stroke: #2459c9; animation: flow 0.8s linear infinite; }
.wire.lit.bad { stroke: #c0352b; }
@keyframes flow { to { stroke-dashoffset: -11; } }

.node {
  position: absolute; display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center;
  background: #fff; border: 1px solid #e6eaf2; border-radius: 12px; font-weight: 700; color: #14213d; font-size: 0.86rem;
  box-shadow: 0 8px 24px -18px rgba(20, 33, 61, 0.5); transition: all 0.4s;
}
.node small { font: 500 0.56rem/1.3 'JetBrains Mono', monospace; color: #7a8496; }
.node.on { background: #14213d; color: #fff; border-color: #14213d; }
.node.on small { color: #8db4ff; }
.client { left: 0; top: 115px; width: 150px; height: 70px; }

.req {
  position: absolute; left: 150px; top: 166px; width: 180px; font: 600 0.56rem/1.4 'JetBrains Mono', monospace;
  color: #2459c9; text-align: center; opacity: 0; transition: opacity 0.4s;
}
.req.shown { opacity: 1; }
.extra { color: #c2570c; opacity: 0; transition: opacity 0.4s; }
.extra.shown { opacity: 1; }

.kc { position: absolute; left: 330px; top: 10px; width: 240px; height: 280px; border: 1px solid #e0e4ec; border-radius: 14px; background: rgba(255,255,255,0.6); padding: 8px; }
.kc-head { font-weight: 700; color: #14213d; font-size: 0.8rem; margin-bottom: 6px; }
.kc-head small { display: block; font: 500 0.54rem 'JetBrains Mono', monospace; color: #7a8496; }
.row {
  position: relative; background: #fff; border: 1px solid #e6eaf2; border-radius: 10px; padding: 6px 8px; margin-bottom: 8px;
  font-size: 0.74rem; color: #14213d; transition: all 0.4s; min-height: 58px;
}
.row b { margin-left: 6px; }
.row .map { display: block; font: 500 0.56rem 'JetBrains Mono', monospace; color: #4a5568; margin-top: 4px; }
.row.dim { opacity: 0.4; }
.row.active { border-color: #2459c9; box-shadow: 0 0 0 3px rgba(36, 89, 201, 0.18); }
.tag { font: 600 0.5rem 'JetBrains Mono', monospace; text-transform: uppercase; background: #e3ecfb; color: #2459c9; padding: 1px 5px; border-radius: 5px; }
.tag.opt { background: #fde7cf; color: #8a3b06; }
.removed {
  display: block; font: 600 0.54rem 'JetBrains Mono', monospace; color: #c0352b; margin-top: 3px;
  opacity: 0; transform: translateX(-6px); transition: all 0.4s;
}
.removed.shown { opacity: 1; transform: none; }

.token {
  position: absolute; left: 595px; top: 85px; width: 150px; height: 130px; background: #fff; border: 1px solid #e6eaf2;
  border-radius: 12px; padding: 8px; transition: all 0.4s; box-shadow: 0 8px 24px -18px rgba(20, 33, 61, 0.5);
}
.token.on { border-color: #2459c9; box-shadow: 0 0 0 3px rgba(36, 89, 201, 0.18); }
.t-head { font-weight: 700; color: #14213d; font-size: 0.78rem; }
.t-line { font: 600 0.6rem 'JetBrains Mono', monospace; color: #7a8496; margin-top: 6px; }
.t-empty { font: 600 0.7rem 'JetBrains Mono', monospace; color: #c9cfdb; margin-top: 4px; }
.chips { display: flex; flex-direction: column; gap: 4px; margin-top: 4px; }
.chip-aud { font: 600 0.62rem 'JetBrains Mono', monospace; background: #e3ecfb; color: #14213d; padding: 2px 6px; border-radius: 6px; width: fit-content; }
.chip-aud.orange { background: #fde7cf; color: #8a3b06; }
.chip-enter-active, .chip-leave-active { transition: all 0.4s; }
.chip-enter-from { opacity: 0; transform: translateX(-14px); }
.chip-leave-to { opacity: 0; }

.side { width: 130px; height: 100px; justify-content: flex-start; padding-top: 10px; }
.spring { left: 770px; top: 25px; }
.reports { left: 770px; top: 175px; }
.verdict {
  font: 600 0.54rem/1.3 'JetBrains Mono', monospace; margin-top: 6px; padding: 2px 6px; border-radius: 6px;
  opacity: 0; transform: scale(0.85); transition: all 0.4s;
}
.verdict.shown { opacity: 1; transform: none; }
.verdict.ok { background: #def3e8; color: #135c3c; }
.verdict.bad { background: #fbe1df; color: #a12a21; }

.note { font-size: 0.86rem; color: #1b2433; min-height: 2.6rem; margin: 0.6rem 0 0; text-align: left; }
.n-enter-active, .n-leave-active { transition: all 0.25s; }
.n-enter-from { opacity: 0; transform: translateY(6px); }
.n-leave-to { opacity: 0; }
</style>

<script setup lang="ts">
// A sequence diagram driven by data from ../flows/qa-flows.ts: one message per click,
// a moving packet, and a panel with the request and the explanation.
// The slide needs `clicks:` equal to the number of steps in the flow.
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'
import { flows, type Kind, type Step } from '../flows/qa-flows'

const props = defineProps<{ flow: keyof typeof flows }>()
const { $clicks } = useSlideContext()

const data = computed(() => flows[props.flow])
const steps = computed(() => data.value.steps)
const n = computed(() => data.value.actors.length)
const X = computed(() => data.value.actors.map((_, i) => 70 + (i * 460) / (n.value - 1)))
const boxW = computed(() => Math.min(156, 460 / (n.value - 1) - 12))
const TOP = 74
const GAP = 46

const color: Record<Kind, string> = { front: '#2459c9', back: '#c2570c', self: '#1f8a5b', fail: '#c0352b', ok: '#1f8a5b' }
const current = computed(() => Math.min($clicks.value, steps.value.length))
const active = computed(() => (current.value > 0 ? steps.value[current.value - 1] : null))
const height = computed(() => TOP + (Math.max(...steps.value.map(s => s.row)) + 1) * GAP + 14)

function y(s: Step) {
  return TOP + 26 + s.row * GAP
}
function lineEnd(s: Step) {
  return X.value[s.to] + (s.to > s.from ? -4 : 4)
}
// a self loop points right, except on the last lifeline where it points left
function loopDir(s: Step) {
  return s.from === n.value - 1 ? -1 : 1
}
function isActor(a: number) {
  const s = active.value
  return !!s && (s.from === a || s.to === a)
}
</script>

<template>
  <div class="qa">
    <svg :viewBox="`0 0 600 ${height}`" class="diagram">
      <defs>
        <marker v-for="(c, k) in color" :id="`qa-arrow-${k}`" :key="k" viewBox="0 0 10 10" refX="9" refY="5"
          markerWidth="7" markerHeight="7" orient="auto-start-reverse">
          <path d="M0,0 L10,5 L0,10 z" :fill="c" />
        </marker>
      </defs>

      <g v-for="(a, i) in data.actors" :key="a">
        <line :x1="X[i]" :x2="X[i]" :y1="TOP - 22" :y2="height - 4" class="lifeline" />
        <rect :x="X[i] - boxW / 2" y="18" :width="boxW" height="30" rx="7" class="actor" :class="{ on: isActor(i) }" />
        <text :x="X[i]" y="37.5" class="actor-label" :class="{ on: isActor(i) }">{{ a }}</text>
      </g>

      <g v-for="(s, i) in steps" :key="i">
        <template v-if="i < current">
          <path v-if="s.from === s.to"
            :d="`M${X[s.from]} ${y(s) - 10} h${40 * loopDir(s)} v20 h${-36 * loopDir(s)}`" fill="none"
            :stroke="color[s.kind]" :marker-end="`url(#qa-arrow-${s.kind})`" class="msg draw"
            :class="{ past: i < current - 1 }" style="--len: 100px" />
          <line v-else :x1="X[s.from]" :x2="lineEnd(s)" :y1="y(s)" :y2="y(s)" :stroke="color[s.kind]"
            :marker-end="`url(#qa-arrow-${s.kind})`" class="msg" :class="{ past: i < current - 1, draw: i === current - 1 }"
            :style="{ '--len': Math.abs(X[s.to] - X[s.from]) + 'px' }" />
          <text :x="s.from === s.to ? X[s.from] + 48 * loopDir(s) : (X[s.from] + X[s.to]) / 2"
            :y="s.from === s.to ? y(s) + 3 : y(s) - 5" class="msg-label fadein"
            :class="{ past: i < current - 1, left: s.from === s.to && loopDir(s) > 0, right: s.from === s.to && loopDir(s) < 0 }"
            :fill="color[s.kind]">
            {{ s.label }}
          </text>
          <circle v-if="i === current - 1 && s.from !== s.to" :key="`p${current}`" cx="0" :cy="y(s)" r="5.5" class="packet"
            :fill="color[s.kind]" :style="{ '--from': X[s.from] + 'px', '--to': X[s.to] + 'px' }" />
        </template>
      </g>
    </svg>

    <div class="panel">
      <Transition name="panel" mode="out-in">
        <div v-if="active" :key="current">
          <div class="step-no">step {{ current }} / {{ steps.length }}</div>
          <h3>{{ active.title }}</h3>
          <p>{{ active.text }}</p>
          <pre v-if="active.code" class="http">{{ active.code }}</pre>
          <div><span v-for="c in active.chips" :key="c" class="chip"
            :class="{ red: active.kind === 'fail', green: active.kind === 'ok' || active.kind === 'self' }">{{ c }}</span></div>
        </div>
        <div v-else key="intro" class="intro">
          <h3>{{ data.intro.title }}</h3>
          <p>{{ data.intro.text }}</p>
        </div>
      </Transition>
    </div>
  </div>
</template>

<style scoped>
.qa { display: flex; gap: 1.2rem; align-items: flex-start; }
.diagram { width: 58%; flex: none; }
.panel { flex: 1; min-width: 0; }

.lifeline { stroke: #c5c4c1; stroke-dasharray: 3 4; }
.actor { fill: #e6eaf2; transition: fill 0.4s; }
.actor.on { fill: #14213d; }
.actor-label { font: 600 10.5px 'IBM Plex Sans', sans-serif; text-anchor: middle; fill: #4a5568; transition: fill 0.4s; }
.actor-label.on { fill: #fff; }

.msg { stroke-width: 1.8; transition: opacity 0.4s; }
.msg.past { opacity: 0.35; }
.msg.draw { stroke-dasharray: var(--len); stroke-dashoffset: var(--len); animation: draw 0.7s ease-out forwards; }
.msg-label { font: 500 9px 'JetBrains Mono', monospace; text-anchor: middle; }
.msg-label.left { text-anchor: start; }
.msg-label.right { text-anchor: end; }
.msg-label.fadein { opacity: 0; animation: fade 0.4s 0.25s ease-out forwards; }
.msg-label.past.fadein { animation-name: fade-past; }
.packet { filter: drop-shadow(0 0 6px currentColor); animation: travel 0.8s cubic-bezier(0.5, 0, 0.3, 1) forwards; }

@keyframes draw { to { stroke-dashoffset: 0; } }
@keyframes fade { to { opacity: 1; } }
@keyframes fade-past { to { opacity: 0.4; } }
@keyframes travel {
  from { transform: translateX(var(--from)); }
  to { transform: translateX(var(--to)); }
}

.step-no { font: 500 0.62rem 'JetBrains Mono', monospace; letter-spacing: 0.1em; text-transform: uppercase; color: #7a8496; }
.panel h3 { font-size: 1.05rem; font-weight: 700; color: #14213d; margin: 0.3rem 0 0.35rem; line-height: 1.25; }
.panel p { font-size: 0.78rem; line-height: 1.45; color: #4a5568; margin: 0 0 0.6rem; }
.http {
  background: #14213d; color: #e3ecfb; border-radius: 10px; padding: 0.65rem 0.8rem;
  font: 0.6rem/1.55 'JetBrains Mono', monospace; white-space: pre-wrap; overflow: hidden; margin: 0 0 0.55rem;
}
.intro { padding-top: 2.5rem; }

.panel-enter-active, .panel-leave-active { transition: all 0.3s ease; }
.panel-enter-from { opacity: 0; transform: translateX(16px); }
.panel-leave-to { opacity: 0; transform: translateX(-10px); }
</style>

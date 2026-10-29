<script setup lang="ts">
// Two days in Alice's life on a 0–12 h axis (slide needs `clicks: 2`).
//   click 1: she keeps working → silent refreshes until the 10 h hard stop
//   click 2: a 45 min lunch break → the 30 min idle timeout ends the session first
// Each scenario is keyed, so its CSS animations restart from zero.
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $clicks } = useSlideContext()
const scenario = computed(() => Math.min($clicks.value, 2))

const HOURS = 12
const SEC_PER_HOUR = 0.34 // animation speed
const x = (h: number) => (h / HOURS) * 100

interface Scenario {
  title: string
  requests: number[] // hours
  lastRefresh: number // where the sliding windows stop
  end: number // where the playhead stops
  endLabel: string
  endCause: 'max' | 'idle'
}

const every20min = (from: number, to: number) =>
  Array.from({ length: Math.floor((to - from) * 3) + 1 }, (_, i) => from + i / 3)

const scenarios: Record<number, Scenario> = {
  1: {
    title: 'Alice keeps working, a click every 20 minutes',
    requests: every20min(0, 10),
    lastRefresh: 10,
    end: 10,
    endLabel: '10:00 · login form',
    endCause: 'max',
  },
  2: {
    title: 'Alice takes a 45-minute lunch at 3 h',
    requests: every20min(0, 3),
    lastRefresh: 3,
    end: 3.75,
    endLabel: '3:45 · login form',
    endCause: 'idle',
  },
}
const s = computed(() => scenarios[scenario.value])
const dur = (h: number) => h * SEC_PER_HOUR + 's'
const ticks = [0, 2, 4, 6, 8, 10, 12]
</script>

<template>
  <div class="tl">
    <div class="head">
      <Transition name="t" mode="out-in">
        <div :key="scenario" class="title">
          <template v-if="s"><span class="no">{{ scenario }}</span> {{ s.title }}</template>
          <span v-else class="faint">Click to play a working day</span>
        </div>
      </Transition>
    </div>

    <div class="grid">
      <div class="labels">
        <div>Requests</div>
        <div>Keycloak idle <span class="mono">30m</span></div>
        <div><span class="mono name">_oauth2_proxy</span> <span class="mono">8h</span></div>
        <div>Keycloak max <span class="mono">10h</span></div>
      </div>

      <div class="plot">
        <div class="wall" :style="{ left: x(10) + '%' }" :class="{ hit: s?.endCause === 'max' }">
          <span>ssoSessionMaxLifespan</span>
        </div>

        <div :key="scenario" class="run">
          <template v-if="s">
            <!-- requests -->
            <div class="lane open">
              <i v-for="(h, i) in s.requests" :key="i" class="req" :style="{ left: x(h) + '%', animationDelay: dur(h) }" />
              <i class="req last" :style="{ left: x(s.end) + '%', animationDelay: dur(s.end) }" />
            </div>
            <!-- idle window: 30 min ahead of the last refresh -->
            <div class="lane">
              <div class="win idle" :class="{ dies: s.endCause === 'idle' }"
                :style="{ '--to': x(s.lastRefresh) + '%', width: x(0.5) + '%', animationDuration: dur(s.lastRefresh) + ', 0.4s',
                          animationDelay: '0s, ' + dur(s.lastRefresh + 0.5) }" />
              <span v-if="s.endCause === 'idle'" class="tag red" :style="{ left: x(s.lastRefresh + 0.5) + '%', animationDelay: dur(s.lastRefresh + 0.5) }">
                ✕ idle 30m, session dropped
              </span>
            </div>
            <!-- cookie window: re-issued for 8 h on each refresh -->
            <div class="lane">
              <div class="win cookie"
                :style="{ '--to': x(s.lastRefresh) + '%', width: x(8) + '%', animationDuration: dur(s.lastRefresh) }" />
              <span v-if="s.endCause === 'idle'" class="tag amber" :style="{ left: x(s.end) + '%', animationDelay: dur(s.end) }">
                still valid, but can’t refresh
              </span>
            </div>
            <!-- max lifespan: a clock that never resets -->
            <div class="lane">
              <div class="max" :style="{ '--to': x(s.end) + '%', animationDuration: dur(s.end) }" />
            </div>

            <div class="playhead" :style="{ '--to': x(s.end) + '%', animationDuration: dur(s.end) }" />
            <div class="end" :style="{ left: x(s.end) + '%', animationDelay: dur(s.end) }">{{ s.endLabel }}</div>
          </template>
        </div>

        <div class="axis">
          <span v-for="t in ticks" :key="t" :style="{ left: x(t) + '%' }">{{ t }}h</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.tl { font-size: 0.72rem; }
.head { height: 1.6rem; margin-bottom: 0.4rem; }
.title { font-weight: 700; font-size: 0.95rem; color: #14213d; }
.no {
  display: inline-flex; width: 1.4rem; height: 1.4rem; border-radius: 999px; background: #14213d; color: #fff;
  align-items: center; justify-content: center; font-size: 0.75rem; margin-right: 0.35rem;
}
.grid { display: flex; }
.labels { width: 9.5rem; flex: none; }
.labels div { height: 2.1rem; display: flex; align-items: center; font-weight: 600; color: #14213d; font-size: 0.7rem; gap: 0.3rem; }
.labels .mono { font-size: 0.6rem; color: #7a8496; font-weight: 500; }
.labels .mono.name { font-size: 0.68rem; color: #14213d; font-weight: 700; }
.plot { position: relative; flex: 1; }
.run { position: relative; }
.lane { position: relative; height: 2.1rem; border-bottom: 1px dashed #e0e1e0; overflow: hidden; }
.lane.open { overflow: visible; }
.run:empty { height: 8.4rem; }
.axis { position: relative; height: 1.2rem; }
.axis span { position: absolute; transform: translateX(-50%); font: 500 0.58rem 'JetBrains Mono', monospace; color: #7a8496; top: 0.2rem; }

.req {
  position: absolute; top: 50%; width: 6px; height: 6px; margin: -3px 0 0 -3px; border-radius: 99px; background: #2459c9;
  opacity: 0; animation: appear 0.2s forwards;
}
.req.last { background: #c0352b; width: 9px; height: 9px; margin: -4.5px 0 0 -4.5px; }

/* windows ride along with the playhead until the last refresh */
.win { position: absolute; top: 0.5rem; bottom: 0.5rem; left: 0; border-radius: 4px; animation-name: ride; animation-timing-function: linear; animation-fill-mode: forwards; }
.win.idle { background: #c2570c; }
.win.idle.dies { animation-name: ride, die; }
.win.cookie { background: linear-gradient(90deg, #f2a65a, #fde7cf); }
.max { position: absolute; top: 0.5rem; bottom: 0.5rem; left: 0; width: 0; background: repeating-linear-gradient(-45deg, #fbe9dc 0 6px, #fde7cf 6px 12px); border-radius: 4px; animation: grow linear forwards; }

.playhead { position: absolute; top: -0.2rem; height: 8.6rem; width: 2px; background: #14213d; left: 0; animation: ride linear forwards; }
.playhead::before { content: ''; position: absolute; top: -4px; left: -4px; width: 10px; height: 10px; border-radius: 99px; background: #14213d; }

.wall { position: absolute; top: -0.2rem; height: 8.6rem; border-left: 2px dashed #c0352b; z-index: 2; }
.wall span { position: absolute; bottom: 100%; transform: translateX(-50%); font: 700 0.55rem 'JetBrains Mono', monospace; color: #c0352b; white-space: nowrap; }
.wall.hit { animation: pulse 1.4s 3.4s ease-in-out infinite; }

.tag { position: absolute; top: 50%; transform: translate(0.4rem, -50%); white-space: nowrap; font: 700 0.58rem 'JetBrains Mono', monospace; padding: 0.05rem 0.35rem; border-radius: 4px; opacity: 0; animation: appear 0.3s forwards; }
.tag.red { background: #fbe3e1; color: #c0352b; }
.tag.amber { background: #fde7cf; color: #8a3b06; }
.end {
  position: absolute; top: 8.55rem; transform: translate(-50%, 0) scale(0.6); white-space: nowrap; z-index: 3;
  background: #c0352b; color: #fff; font: 700 0.66rem 'JetBrains Mono', monospace; padding: 0.15rem 0.55rem; border-radius: 999px;
  opacity: 0; animation: popin 0.45s cubic-bezier(0.3, 1.6, 0.5, 1) forwards;
}

@keyframes ride { from { left: 0; } to { left: var(--to); } }
@keyframes grow { from { width: 0; } to { width: var(--to); } }
@keyframes die { to { background: #c0352b; opacity: 0.25; } }
@keyframes appear { to { opacity: 1; } }
@keyframes popin { to { opacity: 1; transform: translate(-50%, 0) scale(1); } }
@keyframes pulse { 50% { border-color: rgba(192, 53, 43, 0.3); } }

.t-enter-active, .t-leave-active { transition: all 0.25s; }
.t-enter-from { opacity: 0; transform: translateY(6px); }
.t-leave-to { opacity: 0; }
</style>

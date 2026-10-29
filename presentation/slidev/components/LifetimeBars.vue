<script setup lang="ts">
// How long each token, session and cookie lives, on a log time axis (slide needs `clicks: 5`).
// Values are the live realm defaults and the oauth2-proxy flags.
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $clicks } = useSlideContext()
const step = computed(() => $clicks.value)

const AXIS_MAX = 24 * 60 // minutes; anything longer runs off the right edge
const pos = (min: number) => Math.min(100, (Math.log10(min) / Math.log10(AXIS_MAX)) * 100)

interface Row {
  group: number
  name: string
  life: string
  min: number
  src: string
  note: string
  kind: 'token' | 'session' | 'cookie'
  sliding?: boolean
  wall?: boolean
}

const rows: Row[] = [
  { group: 1, kind: 'token', name: 'Access token', life: '5 min', min: 5, src: 'accessTokenLifespan',
    note: 'Forwarded to Spring, which checks it again' },
  { group: 1, kind: 'token', name: 'ID token', life: '5 min', min: 5, src: 'accessTokenLifespan',
    note: 'Tells oauth2-proxy who logged in. Never leaves it' },
  { group: 1, kind: 'token', name: 'Refresh token', life: '30 min', min: 30, src: 'ssoSessionIdleTimeout', sliding: true,
    note: 'Only oauth2-proxy → Keycloak, on the back channel' },
  { group: 2, kind: 'session', name: 'SSO session · idle', life: '30 min', min: 30, src: 'ssoSessionIdleTimeout', sliding: true,
    note: 'Resets on every refresh' },
  { group: 2, kind: 'session', name: 'SSO session · max', life: '10 h', min: 600, src: 'ssoSessionMaxLifespan', wall: true,
    note: 'Counted from login. Never resets' },
  { group: 3, kind: 'cookie', name: '_oauth2_proxy', life: '8 h', min: 480, src: '--cookie-expire=8h', sliding: true,
    note: 'Holds all three tokens, encrypted. Re-issued on refresh' },
  { group: 3, kind: 'cookie', name: 'KEYCLOAK_IDENTITY', life: '10 h*', min: 600, src: 'ssoSessionMaxLifespan',
    note: '*Browser-session cookie unless “Remember me”' },
  { group: 3, kind: 'cookie', name: 'KEYCLOAK_REMEMBER_ME', life: '1 year →', min: AXIS_MAX, src: 'rememberMe',
    note: 'Only pre-fills the username' },
]

const ticks = [
  { label: '1m', min: 1 }, { label: '5m', min: 5 }, { label: '30m', min: 30 },
  { label: '1h', min: 60 }, { label: '8h', min: 480 }, { label: '24h', min: AXIS_MAX },
]
const groupLabel = ['', 'Tokens · in the cookie', 'Keycloak session · server side', 'Cookies · in the browser']
</script>

<template>
  <div class="lb" :class="{ focus4: step === 4, focus5: step >= 5 }">
    <div class="axis">
      <div class="lbl-col" />
      <div class="scale">
        <span v-for="t in ticks" :key="t.label" class="tick" :style="{ left: pos(t.min) + '%' }">{{ t.label }}</span>
      </div>
      <div class="note-col" />
    </div>

    <template v-for="(r, i) in rows" :key="r.name">
      <div v-if="i === 0 || rows[i - 1].group !== r.group" class="group" :class="{ shown: step >= r.group }">
        {{ groupLabel[r.group] }}
      </div>
      <div class="row" :class="[r.kind, { shown: step >= r.group, wallrow: r.wall }]">
        <div class="lbl-col">
          <div class="name mono">{{ r.name }}</div>
          <div class="src mono">{{ r.src }}</div>
        </div>
        <div class="track">
          <div class="bar" :style="{ width: (step >= r.group ? pos(r.min) : 0) + '%', transitionDelay: (i % 3) * 120 + 'ms' }">
            <span class="life" :class="{ inside: pos(r.min) > 40 }">{{ r.life }}<span v-if="r.sliding" class="spin">↻</span></span>
          </div>
        </div>
        <div class="note">{{ r.note }}</div>
      </div>
    </template>

    <!-- 4 min refresh trigger and the 10 h hard stop -->
    <div class="marker refresh" :style="{ left: `calc(var(--lbl) + (100% - var(--lbl) - var(--note)) * ${pos(4) / 100})` }">
      <span>refresh after 4m</span>
    </div>
    <div class="marker wall" :style="{ left: `calc(var(--lbl) + (100% - var(--lbl) - var(--note)) * ${pos(600) / 100})` }">
      <span>hard stop</span>
    </div>
  </div>
</template>

<style scoped>
.lb { --lbl: 11.5rem; --note: 13rem; position: relative; font-size: 0.72rem; padding-bottom: 1.2rem; }
.axis { display: flex; height: 1.1rem; }
.lbl-col { width: var(--lbl); flex: none; padding-right: 0.6rem; }
.scale { position: relative; flex: 1; border-bottom: 1px solid #d6d8dc; }
.note-col { width: var(--note); flex: none; }
.tick { position: absolute; transform: translateX(-50%); font: 500 0.58rem 'JetBrains Mono', monospace; color: #7a8496; }

.group {
  font: 600 0.58rem 'JetBrains Mono', monospace; letter-spacing: 0.1em; text-transform: uppercase; color: #2459c9;
  margin: 0.45rem 0 0.1rem; opacity: 0; transform: translateX(-8px); transition: all 0.4s;
}
.group.shown { opacity: 1; transform: none; }

.row { display: flex; align-items: center; height: 1.95rem; opacity: 0.12; transition: opacity 0.4s, filter 0.4s; }
.row.shown { opacity: 1; }
.name { font-weight: 700; font-size: 0.7rem; color: #14213d; white-space: nowrap; }
.src { font-size: 0.52rem; color: #7a8496; white-space: nowrap; }
.track { position: relative; flex: 1; height: 1.15rem; }
.bar {
  position: absolute; left: 0; top: 0; bottom: 0; border-radius: 0 6px 6px 0; width: 0;
  transition: width 0.9s cubic-bezier(0.2, 0.7, 0.2, 1);
  display: flex; align-items: center; justify-content: flex-end; overflow: visible;
}
.token .bar { background: linear-gradient(90deg, #e3ecfb, #2459c9); }
.session .bar { background: linear-gradient(90deg, #fbe9dc, #c2570c); }
.cookie .bar { background: linear-gradient(90deg, #fde7cf, #f2a65a); }
.life {
  position: absolute; left: calc(100% + 0.35rem); white-space: nowrap; font: 700 0.66rem 'JetBrains Mono', monospace; color: #14213d;
}
.spin { display: inline-block; margin-left: 0.2rem; color: #1f8a5b; animation: spin 2.4s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
.life.inside { left: auto; right: 0.45rem; color: #fff; }
.cookie .life.inside { color: #6b2e05; }
.inside .spin { color: inherit; }
.note { width: var(--note); flex: none; padding-left: 0.9rem; color: #4a5568; font-size: 0.62rem; line-height: 1.25; }
.row:not(.shown) .note, .row:not(.shown) .life { opacity: 0; }

.marker { position: absolute; top: 1.1rem; bottom: 0.2rem; width: 0; border-left: 2px dashed; opacity: 0; transition: opacity 0.5s; }
.marker span { position: absolute; top: 100%; transform: translate(-50%, 0.25rem); white-space: nowrap; font: 700 0.58rem 'JetBrains Mono', monospace; padding: 0 0.3rem; border-radius: 4px; }
.marker.refresh { border-color: #1f8a5b; }
.marker.refresh span { background: #def3e8; color: #135c3c; }
.marker.wall { border-color: #c0352b; }
.marker.wall span { background: #fbe3e1; color: #c0352b; }
.focus4 .marker.refresh, .focus5 .marker.refresh, .focus5 .marker.wall { opacity: 1; }
.focus5 .marker.wall { animation: pulse 1.6s ease-in-out infinite; }
@keyframes pulse { 50% { border-color: rgba(192, 53, 43, 0.35); } }
</style>

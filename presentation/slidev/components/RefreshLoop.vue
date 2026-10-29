<script setup lang="ts">
// The silent refresh: what oauth2-proxy does when the cookie is older than --cookie-refresh,
// and what happens when Keycloak's session is already gone (slide needs `clicks: 8`).
// Steps 1–5 are the happy path; 6–8 replay steps 4–5 with a dead session.
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $clicks } = useSlideContext()

type Kind = 'front' | 'back' | 'self' | 'fail'
interface Step {
  from: number
  to: number
  kind: Kind
  row: number
  label: string
  title: string
  text: string
  code: string
  chips: string[]
}

const actors = ['Browser', 'Gateway + OAuth2-Proxy', 'Keycloak']
const X = [70, 300, 530]
const TOP = 74
const GAP = 52

const steps: Step[] = [
  {
    from: 0, to: 1, kind: 'front', row: 0, label: 'GET /api/headers + cookie',
    title: 'Alice clicks, 4+ minutes after the last refresh',
    text: 'Nothing special from the browser: the same request with the same encrypted cookie.',
    code: 'GET /api/headers\nCookie: _oauth2_proxy=…   (saved 4m10s ago)',
    chips: ['no user action'],
  },
  {
    from: 1, to: 1, kind: 'self', row: 1, label: 'older than 4m → refresh',
    title: 'oauth2-proxy checks the cookie’s age',
    text: 'Under 4 minutes it answers 200 from the cookie alone, even if Keycloak already ended the session. Older, it refreshes first, so the token it forwards always has a minute left.',
    code: '--cookie-refresh=4m   < accessTokenLifespan 5m',
    chips: ['--cookie-refresh=4m', 'logout bites within 4m'],
  },
  {
    from: 1, to: 2, kind: 'back', row: 2, label: 'POST /token refresh_token',
    title: 'Back channel to Keycloak',
    text: 'oauth2-proxy sends the refresh token from inside the cookie, with its client secret. The browser never sees this call.',
    code: 'POST /realms/poc/protocol/openid-connect/token\ngrant_type=refresh_token\nrefresh_token=eyJ…\nclient_id=oauth2-proxy&client_secret=…',
    chips: ['back channel', 'confidential client'],
  },
  {
    from: 2, to: 1, kind: 'back', row: 3, label: '200 · new access + ID + refresh',
    title: 'Session alive: three fresh tokens',
    text: 'Keycloak checks the SSO session: idle under 30 min and younger than 10 h. It resets the idle timer and issues new tokens.',
    code: '← 200\naccess_token   expires_in 300\nid_token       (5 min)\nrefresh_token  refresh_expires_in 1800',
    chips: ['idle timer reset', '10 h clock keeps running'],
  },
  {
    from: 1, to: 0, kind: 'front', row: 4, label: '200 + Set-Cookie (8h again)',
    title: 'New cookie, request goes through',
    text: 'oauth2-proxy re-encrypts the tokens into a new cookie with a new 8 h Max-Age, and the request continues to Spring with the fresh access token.',
    code: '← 200   (request forwarded to Spring)\nSet-Cookie: _oauth2_proxy=…; Max-Age=28800; HttpOnly',
    chips: ['headersToDownstreamOnAllow: set-cookie'],
  },
  {
    from: 2, to: 1, kind: 'fail', row: 3, label: '400 invalid_grant',
    title: 'Now replay it after a 45-minute lunch',
    text: 'The idle timeout passed, so Keycloak has already dropped the session. The refresh token is refused.',
    code: '← 400\n{"error": "invalid_grant",\n "error_description": "Session not active"}',
    chips: ['ssoSessionIdleTimeout 30m'],
  },
  {
    from: 1, to: 0, kind: 'fail', row: 4, label: '302 → Keycloak login',
    title: 'The cookie is cleared, back to the login page',
    text: 'oauth2-proxy drops the session it can no longer refresh and starts a new login: same 302 as the very first visit.',
    code: '← 302 Location: keycloak.localhost/…/auth\nSet-Cookie: _oauth2_proxy=; Max-Age=0\nSet-Cookie: _oauth2_proxy_csrf=…; Max-Age=900',
    chips: ['session cleared'],
  },
  {
    from: 0, to: 2, kind: 'fail', row: 5, label: 'GET /auth → login form',
    title: 'Keycloak can’t help either',
    text: 'KEYCLOAK_IDENTITY points to the same dead session, so there is no silent SSO. Alice types her password again.',
    code: 'GET /realms/poc/protocol/openid-connect/auth\nCookie: KEYCLOAK_IDENTITY=…  (session gone)\n← 200 login form\nSet-Cookie: KEYCLOAK_IDENTITY=; Max-Age=0',
    chips: ['user interaction needed'],
  },
]

const color: Record<Kind, string> = { front: '#2459c9', back: '#c2570c', self: '#1f8a5b', fail: '#c0352b' }
const current = computed(() => Math.min($clicks.value, steps.length))
const active = computed(() => (current.value > 0 ? steps[current.value - 1] : null))
const failing = computed(() => current.value >= 6)
const height = TOP + 6 * GAP

function y(s: Step) {
  return TOP + 26 + s.row * GAP
}
// once the failure replay starts, the happy answers it replaces fade out
function visible(i: number) {
  if (i >= current.value) return false
  return !(failing.value && (i === 3 || i === 4))
}
function lineEnd(s: Step) {
  return X[s.to] + (s.to > s.from ? -4 : 4)
}
function isActor(a: number) {
  const s = active.value
  return !!s && (s.from === a || s.to === a)
}
</script>

<template>
  <div class="rl">
    <svg :viewBox="`0 0 600 ${height}`" class="diagram">
      <defs>
        <marker v-for="(c, k) in color" :id="`rl-arrow-${k}`" :key="k" viewBox="0 0 10 10" refX="9" refY="5"
          markerWidth="7" markerHeight="7" orient="auto-start-reverse">
          <path d="M0,0 L10,5 L0,10 z" :fill="c" />
        </marker>
      </defs>

      <g v-for="(a, i) in actors" :key="a">
        <line :x1="X[i]" :x2="X[i]" :y1="TOP - 22" :y2="height - 4" class="lifeline" />
        <rect :x="X[i] - 78" y="18" width="156" height="30" rx="7" class="actor" :class="{ on: isActor(i) }" />
        <text :x="X[i]" y="37.5" class="actor-label" :class="{ on: isActor(i) }">{{ a }}</text>
      </g>

      <g v-for="(s, i) in steps" :key="i">
        <template v-if="visible(i)">
          <!-- self check: a small loop on the lifeline -->
          <path v-if="s.kind === 'self'" :d="`M${X[s.from]} ${y(s) - 10} h40 v20 h-36`" fill="none" :stroke="color[s.kind]"
            :marker-end="`url(#rl-arrow-${s.kind})`" class="msg draw" :class="{ past: i < current - 1 }" style="--len: 100px" />
          <line v-else :x1="X[s.from]" :x2="lineEnd(s)" :y1="y(s)" :y2="y(s)" :stroke="color[s.kind]"
            :marker-end="`url(#rl-arrow-${s.kind})`" class="msg" :class="{ past: i < current - 1, draw: i === current - 1 }"
            :style="{ '--len': Math.abs(X[s.to] - X[s.from]) + 'px' }" />
          <text :x="s.kind === 'self' ? X[s.from] + 48 : (X[s.from] + X[s.to]) / 2" :y="s.kind === 'self' ? y(s) + 3 : y(s) - 5"
            class="msg-label fadein" :class="{ past: i < current - 1, left: s.kind === 'self' }" :fill="color[s.kind]">
            {{ s.label }}
          </text>
          <circle v-if="i === current - 1 && s.kind !== 'self'" :key="`p${current}`" cx="0" :cy="y(s)" r="5.5" class="packet"
            :fill="color[s.kind]" :style="{ '--from': X[s.from] + 'px', '--to': X[s.to] + 'px' }" />
        </template>
      </g>

      <!-- the Keycloak session, alive or dropped -->
      <g v-if="current >= 4" class="kc-session" :class="{ dead: failing }">
        <rect :x="X[2] - 66" :y="TOP + 26 + 3 * GAP - 46" width="132" height="22" rx="11" />
        <text :x="X[2]" :y="TOP + 26 + 3 * GAP - 31">{{ failing ? '✕ SSO session gone' : '✓ SSO session alive' }}</text>
      </g>
    </svg>

    <div class="panel">
      <Transition name="panel" mode="out-in">
        <div v-if="active" :key="current">
          <div class="step-no">step {{ current }} / {{ steps.length }} ·
            <span :style="{ color: color[active.kind] }">{{ failing ? 'session expired' : active.kind === 'back' ? 'back channel' : 'silent refresh' }}</span>
          </div>
          <h3>{{ active.title }}</h3>
          <p>{{ active.text }}</p>
          <pre class="http">{{ active.code }}</pre>
          <div><span v-for="c in active.chips" :key="c" class="chip" :class="{ red: failing, green: !failing && active.kind === 'self' }">{{ c }}</span></div>
        </div>
        <div v-else key="intro" class="intro">
          <h3>Tokens expire every 5 minutes</h3>
          <p>So why doesn’t Alice log in every 5 minutes? Click to follow a request made after the access token is old.</p>
        </div>
      </Transition>
    </div>
  </div>
</template>

<style scoped>
.rl { display: flex; gap: 1.2rem; align-items: flex-start; }
.diagram { width: 60%; flex: none; }
.panel { flex: 1; min-width: 0; }

.lifeline { stroke: #c5c4c1; stroke-dasharray: 3 4; }
.actor { fill: #e6eaf2; transition: fill 0.4s; }
.actor.on { fill: #14213d; }
.actor-label { font: 600 11px 'IBM Plex Sans', sans-serif; text-anchor: middle; fill: #4a5568; transition: fill 0.4s; }
.actor-label.on { fill: #fff; }

.msg { stroke-width: 1.8; transition: opacity 0.4s; }
.msg.past { opacity: 0.35; }
.msg.draw { stroke-dasharray: var(--len); stroke-dashoffset: var(--len); animation: draw 0.7s ease-out forwards; }
.msg-label { font: 500 9.5px 'JetBrains Mono', monospace; text-anchor: middle; }
.msg-label.left { text-anchor: start; }
.msg-label.fadein { opacity: 0; animation: fade 0.4s 0.25s ease-out forwards; }
.msg-label.past.fadein { animation-name: fade-past; }
.packet { filter: drop-shadow(0 0 6px currentColor); animation: travel 0.8s cubic-bezier(0.5, 0, 0.3, 1) forwards; }

.kc-session rect { fill: #def3e8; transition: fill 0.4s; }
.kc-session text { font: 700 9px 'JetBrains Mono', monospace; text-anchor: middle; fill: #135c3c; }
.kc-session.dead rect { fill: #fbe3e1; }
.kc-session.dead text { fill: #c0352b; }
.kc-session { animation: pop 0.45s cubic-bezier(0.3, 1.6, 0.5, 1); transform-box: fill-box; transform-origin: center; }

@keyframes draw { to { stroke-dashoffset: 0; } }
@keyframes fade { to { opacity: 1; } }
@keyframes fade-past { to { opacity: 0.4; } }
@keyframes pop { from { transform: scale(0.4); opacity: 0; } }
@keyframes travel {
  from { transform: translateX(var(--from)); }
  to { transform: translateX(var(--to)); }
}

.step-no { font: 500 0.62rem 'JetBrains Mono', monospace; letter-spacing: 0.1em; text-transform: uppercase; color: #7a8496; }
.panel h3 { font-size: 1.1rem; font-weight: 700; color: #14213d; margin: 0.3rem 0 0.35rem; line-height: 1.25; }
.panel p { font-size: 0.8rem; line-height: 1.45; color: #4a5568; margin: 0 0 0.6rem; }
.http {
  background: #14213d; color: #e3ecfb; border-radius: 10px; padding: 0.7rem 0.85rem;
  font: 0.64rem/1.55 'JetBrains Mono', monospace; white-space: pre; overflow: hidden; margin: 0 0 0.55rem;
}
.intro { padding-top: 2.5rem; }

.panel-enter-active, .panel-leave-active { transition: all 0.3s ease; }
.panel-enter-from { opacity: 0; transform: translateX(16px); }
.panel-leave-to { opacity: 0; transform: translateX(-10px); }
</style>

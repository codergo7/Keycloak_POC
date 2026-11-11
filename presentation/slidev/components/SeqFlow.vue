<script setup lang="ts">
// Authorization code flow as a sequence diagram.
// mode="overview": all 13 messages draw in one after another.
// mode="steps":    one message per click, with a packet travelling along it
//                  and a detail panel on the right (slide needs `clicks: 13`).
//                  Steps 4 and 5 show the real Keycloak login page (public/keycloak-login.png).
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const props = withDefaults(defineProps<{ mode?: 'overview' | 'steps' }>(), { mode: 'steps' })
const { $clicks } = useSlideContext()

const actors = ['Browser', 'Istio Ingress', 'OAuth2-Proxy', 'Keycloak', 'Spring Boot']
const X = [58, 178, 298, 418, 538]
const TOP = 74
const GAP = props.mode === 'overview' ? 27 : 26

type Kind = 'front' | 'back' | 'mesh'
interface Step {
  from: number
  to: number
  label: string
  kind: Kind
  title: string
  text: string
  code: string
  chips: string[]
  // show the login page screenshot: empty, or being filled in
  form?: 'show' | 'fill'
}

const steps: Step[] = [
  {
    from: 0, to: 1, kind: 'front', label: '1 · GET / (no cookie)',
    title: 'The first request has no session cookie',
    text: 'Alice opens the app. She has no cookie yet. The CUSTOM policy makes the ingress ask OAuth2-Proxy first.',
    code: 'GET / HTTP/1.1\nHost: app.localhost:8080\nUser-Agent: Mozilla/5.0\nCookie: (none)',
    chips: ['front channel', 'CUSTOM policy'],
  },
  {
    from: 1, to: 2, kind: 'mesh', label: '2 · logged in?',
    title: '“Is this request logged in?”',
    text: 'Envoy ext_authz sends a check request with only the cookie and authorization headers to oauth2-proxy:4180.',
    code: 'ext_authz check\n→ oauth2-proxy.identity:4180\n  cookie: (none)\n← no session',
    chips: ['ext_authz', 'no session yet'],
  },
  {
    from: 2, to: 0, kind: 'front', label: '3 · 302 → Keycloak login',
    title: 'No session: go and log in first',
    text: 'OAuth2-Proxy says no with a redirect. The URL says who asks, what it wants, and where to come back.',
    code: 'HTTP/1.1 302 Found\nLocation: keycloak.localhost/…/auth\n  ?client_id=oauth2-proxy\n  &response_type=code\n  &redirect_uri=…/oauth2/callback\n  &state=a1b2c3\nSet-Cookie: _oauth2_proxy_csrf=…',
    chips: ['302 redirect', 'state', 'CSRF cookie'],
  },
  {
    from: 0, to: 3, kind: 'front', label: '4 · GET /auth?response_type=code',
    title: 'The browser follows the redirect',
    text: 'Keycloak shows its own login page. The app never sees this page or the password.',
    code: 'GET /realms/demo/protocol/\n    openid-connect/auth?…\n← 200 login page',
    chips: ['authorization endpoint'],
    form: 'show',
  },
  {
    from: 0, to: 3, kind: 'front', label: '5 · POST username + password',
    title: 'Keycloak checks who you are',
    text: 'This is the one moment real authentication happens. Keycloak also sets its own SSO cookie.',
    code: 'POST …/login-actions/authenticate\nusername=alice&password=•••\n→ Keycloak SSO cookie set',
    chips: ['AuthN', 'password stays at Keycloak', 'SSO'],
    form: 'fill',
  },
  {
    from: 3, to: 0, kind: 'front', label: '6 · 302 /oauth2/callback?code=…',
    title: 'Keycloak hands back a one-time code',
    text: 'No tokens go to the browser. Only a short code, usable once and for about a minute, plus the same state.',
    code: 'HTTP/1.1 302 Found\nLocation: app.localhost:8080\n  /oauth2/callback\n  ?code=9f3e…c71\n  &state=a1b2c3',
    chips: ['authorization code', 'one-time', 'state echoed'],
  },
  {
    from: 0, to: 2, kind: 'front', label: '7 · GET /oauth2/callback?code=…',
    title: 'The code lands at OAuth2-Proxy',
    text: 'The VirtualService sends /oauth2/* straight to OAuth2-Proxy; the CUSTOM check skips it. state must match the CSRF cookie.',
    code: 'GET /oauth2/callback\n  ?code=9f3e…c71&state=a1b2c3\nCookie: _oauth2_proxy_csrf=a1b2c3\n→ state matches, continue',
    chips: ['VirtualService', 'notPaths /oauth2/*', 'CSRF check'],
  },
  {
    from: 2, to: 3, kind: 'back', label: '8 · POST /token + secret',
    title: 'Back channel: code in…',
    text: 'Server to server, never through the browser. OAuth2-Proxy proves who it is with its client secret.',
    code: 'POST /realms/demo/protocol/\n     openid-connect/token\ngrant_type=authorization_code\n&code=9f3e…c71\n&client_id=oauth2-proxy\n&client_secret=•••',
    chips: ['back channel', 'token endpoint', 'client secret'],
  },
  {
    from: 3, to: 2, kind: 'back', label: '9 · tokens (JWTs)',
    title: '…tokens out',
    text: 'Keycloak returns signed JWTs. Their audience includes spring-api thanks to the app-audience client scope.',
    code: '{\n  "access_token":  "eyJhbGciOi…",\n  "id_token":      "eyJhbGciOi…",\n  "refresh_token": "eyJhbGciOi…",\n  "expires_in": 300\n}',
    chips: ['JWT', 'aud: spring-api'],
  },
  {
    from: 2, to: 0, kind: 'front', label: '10 · 302 / + Set-Cookie',
    title: 'A session cookie is born',
    text: 'OAuth2-Proxy stores the session, tokens included, in an encrypted cookie and sends Alice back to the page she asked for.',
    code: 'HTTP/1.1 302 Found\nLocation: /\nSet-Cookie: _oauth2_proxy=<enc>;\n  HttpOnly; SameSite=Lax;\n  Max-Age=28800',
    chips: ['encrypted', 'HttpOnly', 'refresh 4m · expire 8h'],
  },
  {
    from: 0, to: 1, kind: 'front', label: '11 · GET / + cookie',
    title: 'Cookie in…',
    text: 'From now on every request carries the cookie. The browser stores it; the gateway stores nothing.',
    code: 'GET /api/whoami\nCookie: _oauth2_proxy=…',
    chips: ['session cookie'],
  },
  {
    from: 2, to: 1, kind: 'mesh', label: '12 · 200 + X-Auth-Request-*',
    title: '…identity headers out',
    text: 'OAuth2-Proxy decrypts the cookie and answers 200 with identity headers. No call to Keycloak needed.',
    code: '← 200\nX-Auth-Request-User: alice\nX-Auth-Request-Email: alice@…\nX-Auth-Request-Access-Token: eyJ…',
    chips: ['ext_authz allow', 'no Keycloak call'],
  },
  {
    from: 1, to: 4, kind: 'mesh', label: '13 · forward + headers, no cookie',
    title: 'Spring gets identity, not the session',
    text: 'The router strips the cookie and forwards the request. Spring’s sidecar validates the access token again.',
    code: '→ spring-app:8080\nX-Auth-Request-User: alice\nX-Auth-Request-Access-Token: eyJ…\nCookie: (removed by route rule)',
    chips: ['sidecar re-checks JWT', 'headers.request.remove'],
  },
]

const color: Record<Kind, string> = { front: '#2459c9', back: '#c2570c', mesh: '#4a5568' }

const current = computed(() =>
  props.mode === 'overview' ? steps.length : Math.min($clicks.value, steps.length),
)
const active = computed(() => (props.mode === 'steps' && current.value > 0 ? steps[current.value - 1] : null))
const height = TOP + steps.length * GAP + 10

function y(i: number) {
  return TOP + 14 + i * GAP
}
function isActor(a: number) {
  if (props.mode === 'overview') return true
  const s = active.value
  return !!s && (s.from === a || s.to === a)
}
function lineEnd(s: Step) {
  // stop a bit before the lifeline so the arrowhead sits on it
  return X[s.to] + (s.to > s.from ? -4 : 4)
}
</script>

<template>
  <div class="seq" :class="mode">
    <svg :viewBox="`0 0 600 ${height}`" class="diagram">
      <defs>
        <marker v-for="(c, k) in color" :id="`arrow-${k}`" :key="k" viewBox="0 0 10 10" refX="9" refY="5"
          markerWidth="7" markerHeight="7" orient="auto-start-reverse">
          <path d="M0,0 L10,5 L0,10 z" :fill="c" />
        </marker>
      </defs>

      <!-- actors and lifelines -->
      <g v-for="(a, i) in actors" :key="a">
        <line :x1="X[i]" :x2="X[i]" :y1="TOP - 22" :y2="height - 4" class="lifeline" />
        <rect :x="X[i] - 54" y="18" width="108" height="30" rx="7" class="actor"
          :class="{ on: isActor(i) }" />
        <text :x="X[i]" y="37.5" class="actor-label" :class="{ on: isActor(i) }">{{ a }}</text>
      </g>

      <!-- messages -->
      <g v-for="(s, i) in steps" :key="i">
        <template v-if="i < current">
          <line :x1="X[s.from]" :x2="lineEnd(s)" :y1="y(i)" :y2="y(i)" :stroke="color[s.kind]"
            :marker-end="`url(#arrow-${s.kind})`" class="msg"
            :class="{ past: mode === 'steps' && i < current - 1, draw: mode === 'overview' || i === current - 1 }"
            :style="{ '--len': Math.abs(X[s.to] - X[s.from]) + 'px', animationDelay: mode === 'overview' ? i * 0.22 + 's' : '0s' }" />
          <text :x="(X[s.from] + X[s.to]) / 2" :y="y(i) - 4.5" class="msg-label"
            :class="{ past: mode === 'steps' && i < current - 1, fadein: true }" :fill="color[s.kind]"
            :style="{ animationDelay: mode === 'overview' ? i * 0.22 + 0.15 + 's' : '0.25s' }">
            {{ s.label }}
          </text>
          <circle v-if="mode === 'steps' && i === current - 1" :key="`p${current}`" :cx="0" :cy="y(i)" r="5.5"
            class="packet" :fill="color[s.kind]"
            :style="{ '--from': X[s.from] + 'px', '--to': X[s.to] + 'px' }" />
        </template>
      </g>
    </svg>

    <div v-if="mode === 'steps'" class="panel">
      <Transition name="panel" mode="out-in">
        <div v-if="active" :key="current">
          <div class="step-no">step {{ current }} / {{ steps.length }} ·
            <span :style="{ color: color[active.kind] }">{{ active.kind === 'front' ? 'via the browser' :
              active.kind === 'back' ? 'back channel' : 'inside the mesh' }}</span>
          </div>
          <h3>{{ active.title }}</h3>
          <p>{{ active.text }}</p>
          <div v-if="active.form" class="browser">
            <div class="bar">
              <span class="dots"><i /><i /><i /></span>
              <span class="url"><b>keycloak.localhost</b>:8080/realms/demo/…/auth</span>
            </div>
            <div class="page">
              <img src="/keycloak-login.png" alt="Keycloak login page of the demo realm">
              <template v-if="active.form === 'fill'">
                <span class="typed user">alice</span>
                <span class="typed pass">••••••</span>
                <span class="press" />
              </template>
            </div>
          </div>
          <pre v-if="active.form === 'fill'" class="http one">POST …/login-actions/authenticate → SSO cookie set</pre>
          <pre v-else-if="!active.form" class="http">{{ active.code }}</pre>
          <div><span v-for="c in active.chips" :key="c" class="chip">{{ c }}</span></div>
        </div>
        <div v-else key="intro" class="intro">
          <h3>Click to walk the flow</h3>
          <p>13 messages, 5 actors, 1 login. Blue goes through the browser, orange is the back channel,
            grey stays inside the mesh.</p>
        </div>
      </Transition>
    </div>
  </div>
</template>

<style scoped>
.seq { display: flex; gap: 1.2rem; align-items: flex-start; }
.seq.overview .diagram { width: 100%; max-height: 410px; }
.seq.steps .diagram { width: 60%; flex: none; }
.panel { flex: 1; min-width: 0; }

.lifeline { stroke: #c5c4c1; stroke-dasharray: 3 4; }
.actor { fill: #e6eaf2; transition: fill 0.4s; }
.actor.on { fill: #14213d; }
.actor-label { font: 600 11px 'IBM Plex Sans', sans-serif; text-anchor: middle; fill: #4a5568; transition: fill 0.4s; }
.actor-label.on { fill: #fff; }

.msg { stroke-width: 1.8; transition: opacity 0.4s; }
.msg.past { opacity: 0.35; }
.msg.draw { stroke-dasharray: var(--len); stroke-dashoffset: var(--len); animation: draw 0.7s ease-out forwards; }
.msg-label { font: 500 9.5px 'JetBrains Mono', monospace; text-anchor: middle; transition: opacity 0.4s; }
.msg-label.past { opacity: 0.4; }
.msg-label.fadein { opacity: 0; animation: fade 0.4s ease-out forwards; }
.msg-label.past.fadein { animation: fade-past 0.4s ease-out forwards; }

.packet { filter: drop-shadow(0 0 6px currentColor); animation: travel 0.8s cubic-bezier(0.5, 0, 0.3, 1) forwards; }

@keyframes draw { to { stroke-dashoffset: 0; } }
@keyframes fade { to { opacity: 1; } }
@keyframes fade-past { to { opacity: 0.4; } }
@keyframes travel {
  from { transform: translateX(var(--from)); }
  to { transform: translateX(var(--to)); }
}

.step-no { font: 500 0.62rem 'JetBrains Mono', monospace; letter-spacing: 0.1em; text-transform: uppercase; color: #7a8496; }
.panel h3 { font-size: 1.15rem; font-weight: 700; color: #14213d; margin: 0.3rem 0 0.35rem; }
.panel p { font-size: 0.8rem; line-height: 1.45; color: #4a5568; margin: 0 0 0.6rem; }
.http {
  background: #14213d; color: #e3ecfb; border-radius: 10px; padding: 0.7rem 0.85rem;
  font: 0.66rem/1.55 'JetBrains Mono', monospace; white-space: pre; overflow: hidden; margin: 0 0 0.55rem;
}
.intro { padding-top: 2.5rem; }

/* the real Keycloak login page, steps 4 and 5 */
.browser {
  width: 200px; border-radius: 9px; overflow: hidden; margin: 0 0 0.5rem; background: #1b1d22;
  box-shadow: 0 10px 28px -14px rgba(20, 33, 61, 0.6); animation: rise 0.45s ease-out;
}
.bar { display: flex; align-items: center; gap: 6px; padding: 4px 6px; background: #e6eaf2; }
.dots { display: flex; gap: 3px; flex: none; }
.dots i { width: 5px; height: 5px; border-radius: 50%; background: #c5c4c1; }
.url { font: 500 0.44rem 'JetBrains Mono', monospace; color: #4a5568; background: #fff; border-radius: 4px; padding: 1px 5px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; min-width: 0; }
.url b { color: #c2570c; }
.page { position: relative; }
.page img { display: block; width: 100%; height: auto; }
/* positions are fractions of the 1148×1128 screenshot */
.typed {
  position: absolute; left: 13.5%; font: 600 7.5px/1 'JetBrains Mono', monospace; color: #fff;
  overflow: hidden; white-space: nowrap; width: 0; animation: type 0.7s steps(6, end) forwards;
}
.typed.user { top: 43.2%; animation-delay: 0.3s; }
.typed.pass { top: 58.8%; animation-delay: 1.1s; letter-spacing: 1px; }
.press {
  position: absolute; left: 12%; width: 78%; top: 73.5%; height: 6.3%; border-radius: 3px;
  background: rgba(255, 255, 255, 0); animation: press 0.5s 2s ease-out forwards;
}
.http.one { white-space: normal; font-size: 0.6rem; padding: 0.45rem 0.7rem; }

@keyframes rise { from { opacity: 0; transform: translateY(10px); } }
@keyframes type { to { width: 7ch; } }
@keyframes press {
  0% { background: rgba(255, 255, 255, 0); }
  40% { background: rgba(255, 255, 255, 0.45); }
  100% { background: rgba(255, 255, 255, 0.12); box-shadow: 0 0 0 2px #8db4ff; }
}

.panel-enter-active, .panel-leave-active { transition: all 0.3s ease; }
.panel-enter-from { opacity: 0; transform: translateX(16px); }
.panel-leave-to { opacity: 0; transform: translateX(-10px); }
</style>

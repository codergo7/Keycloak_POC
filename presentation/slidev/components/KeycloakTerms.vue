<script setup lang="ts">
// Keycloak terms as one picture of realm demo (slide 6). Needs `clicks: 6`.
// Values are from k8s/keycloak/realm-configmap.yaml.
// Click 1: the realm frame. 2: clients (the ones that ask for tokens, and the APIs).
// 3: users and groups. 4: realm roles and the client roles of reports-api.
// 5: client scopes: app-audience (default) and reports (optional) add an audience, groups adds the groups claim.
// 6: groups carry roles; alice's access token shows where each claim comes from.
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $clicks } = useSlideContext()
const s = computed(() => Math.min(Math.max($clicks.value, 0), 6))
const on = (n: number) => ({ on: s.value >= n, now: s.value === n })

const users = [
  { n: 'alice', y: 40 },
  { n: 'admin', y: 100 },
  { n: 'bob', y: 170 },
]
const groups = [
  { n: '/engineering', y: 40, x: 150, w: 120 },
  { n: '/admins', y: 100, x: 150, w: 120 },
  { n: '/finance', y: 170, x: 150, w: 120 },
  { n: '/managers', y: 220, x: 172, w: 98 },
]
// group → role, drawn on click 6
const carries = [
  'M270,57 C305,57 305,63 340,63',
  'M270,117 C305,117 305,99 340,99',
  'M270,187 C305,187 305,213 340,213',
  'M270,237 C305,237 305,253 340,253',
]
</script>

<template>
  <div class="kt">
    <!-- the realm -->
    <div class="realm" :class="on(1)">
      <span class="tab mono">realm <b>demo</b> · its own users, roles and clients</span>
    </div>

    <!-- column headers -->
    <div class="hd" :class="on(3)" style="left: 14px">Users</div>
    <div class="hd" :class="on(3)" style="left: 150px">Groups</div>
    <div class="hd" :class="on(4)" style="left: 340px">Roles</div>
    <div class="hd" :class="on(2)" style="left: 520px">Clients that ask</div>
    <div class="hd" :class="on(5)" style="left: 645px">Client scopes</div>
    <div class="hd" :class="on(2)" style="left: 765px">Clients = APIs</div>

    <svg class="wires" viewBox="0 0 894 380">
      <!-- membership -->
      <g class="w mem" :class="on(3)">
        <path d="M114,57 L150,57" /><path d="M114,117 L150,117" /><path d="M114,187 L150,187" />
        <path d="M160,204 L160,237 L172,237" class="tree" />
      </g>
      <!-- scopes -->
      <g class="w sc" :class="on(5)">
        <path d="M625,124 C635,124 635,68 645,68" />
        <path d="M625,124 C635,124 635,198 645,198" />
        <path d="M625,124 C635,124 635,266 645,266" />
        <path d="M745,68 L763,68" marker-end="url(#ah)" />
        <path d="M745,198 L763,198" marker-end="url(#ah)" />
      </g>
      <!-- groups carry roles -->
      <g class="w carry" :class="on(6)">
        <path v-for="(d, i) in carries" :key="i" :d="d" :style="{ '--i': i }" />
      </g>
      <defs>
        <marker id="ah" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="6" markerHeight="6" orient="auto">
          <path d="M0,0 L8,4 L0,8 z" fill="#2459c9" />
        </marker>
      </defs>
    </svg>

    <!-- users -->
    <div v-for="u in users" :key="u.n" class="box user" :class="on(3)" :style="{ left: '14px', top: u.y + 'px' }">
      <span class="i-carbon-user" />{{ u.n }}
    </div>
    <!-- groups -->
    <div v-for="g in groups" :key="g.n" class="box grp mono" :class="on(3)" :style="{ left: g.x + 'px', top: g.y + 'px', width: g.w + 'px' }">
      {{ g.n }}
    </div>
    <div class="later mono" :class="on(3)">bob joins in the API demo</div>

    <!-- roles -->
    <div class="rbox" :class="on(4)" style="top: 30px; height: 132px">
      <small>Realm roles · shared</small>
      <span class="role" style="top: 22px">developer</span>
      <span class="role" style="top: 58px">admin</span>
      <span class="role" style="top: 94px">user <i>given to every user directly</i></span>
    </div>
    <div class="rbox cr" :class="on(4)" style="top: 176px; height: 112px">
      <small>Client roles · <b>reports-api</b></small>
      <span class="role" style="top: 24px">viewer</span>
      <span class="role" style="top: 64px">editor <i>composite: contains viewer</i></span>
    </div>

    <!-- clients that ask for tokens -->
    <div class="box cl ask mono" :class="on(2)" style="left: 520px; top: 80px">oauth2-proxy<small>browser login</small></div>
    <div class="box cl ask mono" :class="on(2)" style="left: 520px; top: 140px">cli-client<small>scripts</small></div>

    <!-- client scopes -->
    <div class="scope mono" :class="on(5)" style="top: 54px"><b>app-audience</b><small>default · aud spring-api</small></div>
    <div class="scope mono" :class="on(5)" style="top: 184px"><b>reports</b><small>optional · aud reports-api</small></div>
    <div class="scope mono" :class="on(5)" style="top: 252px"><b>groups</b><small>default · groups claim</small></div>

    <!-- APIs -->
    <div class="box cl api mono" :class="on(2)" style="left: 765px; top: 42px">spring-api<small>Spring Boot</small></div>
    <div class="box cl api mono" :class="[on(2), { owner: s === 4 }]" style="left: 765px; top: 172px">reports-api<small>FastAPI · owns viewer, editor</small></div>

    <!-- the result: alice's token -->
    <div class="token mono" :class="on(6)">
      <span class="tt">alice’s access token</span>
      <span class="f">"aud": ["spring-api"]<small>app-audience</small></span>
      <span class="f">"groups": ["/engineering"]<small>groups scope</small></span>
      <span class="f">"realm_access.roles": ["developer", "user"]<small>/engineering + direct</small></span>
    </div>
  </div>
</template>

<style scoped>
.kt { --navy: #14213d; --blue: #2459c9; --orange: #c2570c; --green: #1f8a5b; --violet: #7b3fbf; --muted: #7a8496;
  position: relative; width: 894px; height: 380px; margin-top: 0.9rem; }
.mono { font-family: 'JetBrains Mono', monospace; }
.kt > div, .w { opacity: 0; transition: opacity 0.45s, transform 0.45s, box-shadow 0.3s, border-color 0.3s; }
.kt > .on, .w.on { opacity: 1; }

.realm { position: absolute; left: 0; top: 0; width: 894px; height: 304px; border: 2px dashed #b9c8e6; border-radius: 16px; background: #fbfcfe; transform: scale(0.97); }
.realm.on { transform: none; }
.realm.now { border-color: var(--blue); box-shadow: 0 0 0 4px rgba(36, 89, 201, 0.1); }
.tab { position: absolute; left: 14px; top: -11px; padding: 0 0.45rem; background: #f6f5f1; font-size: 0.6rem; color: var(--blue); }
.tab b { font-size: 0.7rem; }

.hd { position: absolute; top: 12px; font: 700 0.5rem 'JetBrains Mono', monospace; text-transform: uppercase; letter-spacing: 0.08em; color: var(--muted); }
.hd.now { color: var(--blue); }

.wires { position: absolute; inset: 0; width: 894px; height: 380px; overflow: visible; pointer-events: none; opacity: 1; }
.w path { fill: none; stroke-width: 1.6; }
.mem path { stroke: #9aa6bb; }
.mem .tree { stroke-dasharray: 3 3; }
.sc path { stroke: var(--blue); }
.carry path { stroke: var(--orange); stroke-width: 2.4; stroke-dasharray: 120; stroke-dashoffset: 120; }
.carry.on path { stroke-dashoffset: 0; transition: stroke-dashoffset 0.6s ease-out calc(var(--i) * 0.15s); }

.box { position: absolute; display: flex; align-items: center; gap: 0.35rem; height: 34px; padding: 0 0.6rem; border-radius: 9px;
  background: #fff; border: 1px solid #dfe5ef; font-size: 0.72rem; color: var(--navy); transform: translateY(6px); }
.box.on { transform: none; }
.user { width: 100px; height: 36px; font-weight: 700; background: #e4ecfb; border-color: #c8d6f2; }
.user span { color: var(--blue); }
.grp { font-size: 0.64rem; font-weight: 600; background: #eef2fa; }
.later { position: absolute; left: 150px; top: 262px; font-size: 0.5rem; color: var(--muted); }
.cl { flex-direction: column; align-items: flex-start; justify-content: center; gap: 0; height: 44px; width: 105px; font-size: 0.66rem; font-weight: 700; }
.cl small { font: 400 0.5rem 'Inter', sans-serif; color: var(--muted); }
.ask { border-left: 3px solid var(--blue); }
.api { width: 115px; height: 56px; border-left: 3px solid var(--green); background: #f1faf5; }
.api.owner { box-shadow: 0 0 0 3px rgba(194, 87, 12, 0.25); border-color: var(--orange); }
.box.now, .scope.now { box-shadow: 0 0 0 3px rgba(36, 89, 201, 0.15); }

.rbox { position: absolute; left: 340px; width: 150px; border-radius: 11px; background: #fff; border: 1px solid #f1d3bd; transform: translateY(6px); }
.rbox.on { transform: none; }
.rbox.now { box-shadow: 0 0 0 3px rgba(194, 87, 12, 0.18); }
.rbox small { position: absolute; left: 9px; top: 5px; font: 700 0.5rem 'JetBrains Mono', monospace; color: var(--orange); white-space: nowrap; }
.rbox small b { color: var(--navy); }
.role { position: absolute; left: 9px; display: flex; flex-direction: column; padding: 0.15rem 0.5rem; border-radius: 99px; background: #fbe9dc;
  font: 700 0.62rem 'JetBrains Mono', monospace; color: var(--navy); white-space: nowrap; }
.role i { font: italic 400 0.46rem 'Inter', sans-serif; color: var(--muted); }
.cr { border-style: dashed; }

.scope { position: absolute; left: 645px; width: 100px; padding: 0.2rem 0.45rem; border-radius: 8px; background: #e4ecfb; border: 1px solid #c8d6f2; transform: translateY(6px); }
.scope.on { transform: none; }
.scope b { display: block; font-size: 0.62rem; color: var(--blue); }
.scope small { display: block; font: 400 0.48rem 'Inter', sans-serif; color: #1b2433; white-space: nowrap; }

.token { position: absolute; left: 0; top: 318px; width: 894px; height: 58px; display: flex; align-items: center; gap: 0.9rem; padding: 0 0.9rem;
  border-radius: 12px; background: var(--navy); color: #e3ecfb; transform: translateY(10px); }
.token.on { transform: none; transition-delay: 0.7s; }
.tt { font: 700 0.56rem 'JetBrains Mono', monospace; text-transform: uppercase; letter-spacing: 0.06em; color: #f3a86b; white-space: nowrap; }
.f { display: flex; flex-direction: column; font-size: 0.66rem; white-space: nowrap; }
.f small { font: 400 0.5rem 'Inter', sans-serif; color: #aeb7cc; }
.f small::before { content: '← '; }
</style>

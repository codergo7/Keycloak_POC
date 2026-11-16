<script setup lang="ts">
// How the AuthorizationPolicy filters decide (backup slide, needs `clicks: 6`).
// Spring's sidecar, measured on the cluster: one envoy.filters.http.rbac (ALLOW) with one
// Envoy policy per rule of spring-workload-authorization; no CUSTOM or DENY policy there.
// alice GET /api/user  → "enforced allowed, matched policy ns[spring-api]-policy[spring-workload-authorization]-rule[1]"
// alice GET /api/admin → "enforced denied, matched policy none" → 403 RBAC: access denied
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $clicks } = useSlideContext()
const s = computed(() => Math.min(Math.max($clicks.value, 0), 6))

// request under test (clicks 4 and 5)
const req = computed(() => s.value === 4 ? { m: 'GET', p: '/api/user' } : s.value === 5 ? { m: 'GET', p: '/api/admin' } : null)
// where the request chip is: 0 start, 1 CUSTOM, 2 DENY, 3 ALLOW, 4 Spring
const chipAt = computed(() => s.value === 4 ? 4 : s.value === 5 ? 3 : 0)
const denied = computed(() => s.value === 5)

const gates = [
  { k: 'custom', a: 'CUSTOM', f: 'rbac (shadow) + ext_authz', here: 'none on this sidecar', ex: 'gateway: oauth2-external-auth' },
  { k: 'deny', a: 'DENY', f: 'rbac · action DENY', here: 'none in the POC', ex: 'match → 403 at once' },
  { k: 'allow', a: 'ALLOW', f: 'rbac · action ALLOW', here: 'spring-workload-authorization', ex: 'no match → 403' },
]

// the four rules; marks per request: [to, from, when]; '' = not evaluated
const rules = [
  { to: 'GET /api/public', from: 'anyone', when: '—' },
  { to: 'GET /api/user, /api/whoami', from: 'requestPrincipals *', when: 'roles ∋ user' },
  { to: 'GET /api/headers', from: 'requestPrincipals *', when: 'roles ∋ developer' },
  { to: 'GET /api/admin', from: 'requestPrincipals *', when: 'roles ∋ admin' },
]
const marks: Record<number, string[][]> = {
  4: [['✕', '', ''], ['✓', '✓', '✓'], ['✕', '', ''], ['✕', '', '']],
  5: [['✕', '', ''], ['✕', '', ''], ['✕', '', ''], ['✓', '✓', '✕']],
}
const matchRow = computed(() => s.value === 4 ? 1 : -1)
const showRules = computed(() => s.value === 2 || s.value === 4 || s.value === 5)

const notes = [
  'Every AuthorizationPolicy has one action. Envoy turns each action into its own filter, and they always run in the same order.',
  'CUSTOM first, then DENY, then ALLOW. A DENY match stops the request. If a workload has any ALLOW policy, the request must match one.',
  'Each rule becomes one Envoy policy. to becomes permissions, from and when become principals. A rule matches only if all its parts match.',
  'The filter reads facts that are already there: the request line, jwt_authn’s metadata, and the mTLS peer identity.',
  'alice GET /api/user: rule[1] matches on path, principal and role. Allowed, and Envoy logs which rule matched.',
  'alice GET /api/admin: only rule[3] has the path, and alice has no admin role. No rule matches, so 403 RBAC: access denied.',
  'The defaults decide the rest. The surprise is the third line: one ALLOW policy makes everything else denied.',
]
</script>

<template>
  <div class="az">
    <!-- row 1: request, the three gates, the app -->
    <div class="row">
      <div class="req" :class="{ on: req }">
        <div class="cap">request</div>
        <div class="mono rq">{{ req ? `${req.m} ${req.p}` : 'GET /api/…' }}</div>
        <div class="mono who">{{ req ? 'alice · roles developer, user' : 'Spring’s sidecar' }}</div>
      </div>
      <div v-for="(g, i) in gates" :key="g.k" class="gate" :class="[g.k, {
        lit: s >= 1, dim: req && i < 2, hot: (s === 2 || s >= 4) && i === 2 && s !== 6,
        pass: s === 4 && i === 2, stop: denied && i === 2 }]">
        <div class="gh"><b class="n">{{ i + 1 }}</b>{{ g.a }}</div>
        <div class="mono gf">{{ g.f }}</div>
        <div class="gx" :class="{ show: s >= 1 }">{{ req && i < 2 ? 'skipped: no policy' : g.here }}</div>
      </div>
      <div class="app" :class="{ ok: s === 4 }">Spring<small class="mono">{{ s === 4 ? '200 OK' : denied ? 'not reached' : ':8080' }}</small></div>
      <div class="chip mono" :class="['at' + chipAt, { show: req, bad: denied }]">{{ denied ? '403' : 'alice' }}</div>
    </div>

    <div class="panel">
      <Transition name="sw" mode="out-in">
        <!-- 0–1: the order and the combining rules -->
        <div v-if="s <= 1" key="order" class="order">
          <div v-for="(t, i) in [
            ['DENY wins', 'If a DENY policy matches, the request is rejected, even if an ALLOW policy would match too.'],
            ['ALLOW is a list', 'Once a workload has one ALLOW policy, only what matches one of its rules gets through.'],
            ['No policy, no check', 'A workload without ALLOW policies allows everything. That is the Istio default.'],
          ]" :key="t[0]" class="ocard" :class="{ show: s >= 1 }" :style="{ transitionDelay: 0.15 + i * 0.15 + 's' }">
            <b>{{ t[0] }}</b><span>{{ t[1] }}</span>
          </div>
        </div>

        <!-- 2, 4, 5: the rules of spring-workload-authorization -->
        <div v-else-if="showRules" key="rules" class="rules">
          <div class="pname mono">AuthorizationPolicy spring-workload-authorization · action ALLOW</div>
          <div class="rhead">
            <span />
            <span class="h to">to <i>→ permissions</i></span>
            <span class="h fr">from <i>→ principals</i></span>
            <span class="h wh">when <i>→ principals</i></span>
          </div>
          <div v-for="(r, i) in rules" :key="i" class="rrow" :class="{ match: matchRow === i, miss: s === 5 && i === 3 }">
            <span class="mono rn">rule[{{ i }}]</span>
            <span v-for="(c, j) in [r.to, r.from, r.when]" :key="j" class="cell mono">
              {{ c }}
              <em v-if="marks[s]?.[i]?.[j]" :class="marks[s][i][j] === '✓' ? 'ok' : 'no'" :style="{ animationDelay: 0.25 + i * 0.25 + j * 0.12 + 's' }">{{ marks[s][i][j] }}</em>
            </span>
          </div>
          <div class="logic mono" v-if="s === 2">rules: OR · inside a rule: AND · values in a list: OR</div>
          <div class="log mono" v-else :class="{ bad: denied }">
            <span>istio-proxy (rbac:debug)</span>
            {{ denied ? 'enforced denied, matched policy none' : 'enforced allowed, matched policy …spring-workload-authorization]-rule[1]' }}
          </div>
        </div>

        <!-- 3: where the values come from -->
        <div v-else-if="s === 3" key="src" class="src">
          <div class="lane"><span class="from mono">:method :path :authority</span><span class="arrow">←</span><b>the request line</b><span class="ex mono">to: methods, paths, hosts</span></div>
          <div class="lane"><span class="from mono">payload.iss · sub · realm_access.roles</span><span class="arrow">←</span><b>jwt_authn metadata</b><span class="ex mono">from: requestPrincipals · when: claims</span></div>
          <div class="lane"><span class="from mono">spiffe://cluster.local/ns/…/sa/…</span><span class="arrow">←</span><b>the mTLS peer certificate</b><span class="ex mono">from: principals, namespaces (Postgres)</span></div>
          <p class="srcp">No call goes out: the filter only compares. That is why <b>jwt_authn must run before rbac</b>, and why a missing token means no principal.</p>
        </div>

        <!-- 6: the defaults -->
        <div v-else key="def" class="defs">
          <div v-for="(d, i) in [
            ['no AuthorizationPolicy on the workload', 'everything allowed', 'ok'],
            ['a DENY policy matches', '403, whatever ALLOW says', 'no'],
            ['ALLOW policies exist, none matches', '403 RBAC: access denied', 'no'],
            ['ALLOW with spec: {} (allow-nothing)', 'nothing allowed', 'no'],
          ]" :key="i" class="drow" :style="{ animationDelay: i * 0.12 + 's' }">
            <span class="mono">{{ d[0] }}</span><b :class="d[2]">{{ d[1] }}</b>
          </div>
        </div>
      </Transition>
    </div>

    <Transition name="n" mode="out-in">
      <p :key="s" class="note"><b v-if="s">{{ s }}.</b> {{ notes[s] }}</p>
    </Transition>
  </div>
</template>

<style scoped>
.az { --navy: #14213d; --blue: #2459c9; --orange: #c2570c; --green: #1f8a5b; --red: #c0352b; --violet: #7b3fbf; --muted: #7a8496; width: 880px; margin: 0 auto; }
.mono { font-family: 'JetBrains Mono', monospace; }
.cap { font-size: 0.48rem; text-transform: uppercase; letter-spacing: 0.06em; color: var(--muted); }

.row { position: relative; display: grid; grid-template-columns: 150px 1fr 1fr 1fr 96px; gap: 10px; height: 70px; }
.req, .gate, .app { border-radius: 12px; border: 1px solid #e6eaf2; background: #fff; padding: 0.35rem 0.55rem; transition: all 0.4s; }
.req.on { border-color: var(--blue); box-shadow: 0 0 0 3px rgba(36, 89, 201, 0.12); }
.rq { font-size: 0.66rem; font-weight: 700; color: var(--navy); margin-top: 0.1rem; }
.who { font-size: 0.48rem; color: var(--muted); margin-top: 0.15rem; }

.gate { opacity: 0.45; border-style: dashed; }
.gate.lit { opacity: 1; border-style: solid; }
.gate.dim { opacity: 0.4; }
.gate.hot { border-color: var(--navy); box-shadow: 0 10px 26px -18px rgba(20, 33, 61, 0.7); }
.gate.pass { border-color: var(--green); box-shadow: 0 0 0 3px rgba(31, 138, 91, 0.15); }
.gate.stop { border-color: var(--red); box-shadow: 0 0 0 3px rgba(192, 53, 43, 0.15); animation: shake 0.45s 0.9s; }
@keyframes shake { 25% { transform: translateX(-4px); } 50% { transform: translateX(4px); } 75% { transform: translateX(-2px); } }
.gh { display: flex; align-items: center; gap: 0.35rem; font-weight: 800; font-size: 0.8rem; color: var(--navy); }
.gh .n { font-size: 0.5rem; width: 1rem; height: 1rem; border-radius: 50%; display: inline-flex; align-items: center; justify-content: center; color: #fff; background: var(--muted); }
.custom .n { background: var(--orange); } .deny .n { background: var(--red); } .allow .n { background: var(--green); }
.gf { font-size: 0.5rem; color: var(--muted); margin-top: 0.1rem; }
.gx { font-size: 0.52rem; color: var(--navy); margin-top: 0.2rem; font-weight: 600; opacity: 0; transition: opacity 0.4s 0.3s; }
.gx.show { opacity: 1; }

.app { display: flex; flex-direction: column; align-items: center; justify-content: center; font-weight: 700; color: var(--navy); font-size: 0.82rem; }
.app small { font-size: 0.5rem; color: var(--muted); }
.app.ok { background: var(--green); border-color: var(--green); color: #fff; transition-delay: 1.4s; }
.app.ok small { color: #d5f5e3; }

.chip {
  position: absolute; top: -12px; left: 40px; padding: 0.08rem 0.45rem; border-radius: 99px; background: var(--blue); color: #fff;
  font-size: 0.5rem; font-weight: 700; opacity: 0; transition: left 1.2s cubic-bezier(0.5, 0, 0.3, 1), opacity 0.3s, background 0.3s; z-index: 2;
}
.chip.show { opacity: 1; }
.chip.at3 { left: 640px; }
.chip.at4 { left: 806px; }
.chip.bad { background: var(--red); transition: left 1s cubic-bezier(0.5, 0, 0.3, 1), background 0.3s 1s; }

.panel { position: relative; margin-top: 12px; height: 190px; }
.order { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; height: 100%; align-content: start; }
.ocard { background: #fff; border: 1px solid #e6eaf2; border-radius: 12px; padding: 0.6rem 0.75rem; display: flex; flex-direction: column; gap: 0.3rem;
  opacity: 0; transform: translateY(10px); transition: all 0.5s; }
.ocard.show { opacity: 1; transform: none; }
.ocard b { color: var(--navy); font-size: 0.82rem; }
.ocard span { font-size: 0.66rem; color: #1b2433; line-height: 1.45; }

.rules { background: #fff; border: 1px solid #e6eaf2; border-radius: 12px; padding: 0.45rem 0.6rem; }
.rhead, .rrow { display: grid; grid-template-columns: 62px 1.35fr 1fr 1fr; gap: 8px; align-items: center; }
.rhead { font-size: 0.56rem; color: var(--muted); padding-bottom: 0.25rem; border-bottom: 1px solid #eef0f4; }
.pname { font-size: 0.52rem; color: var(--navy); font-weight: 700; margin-bottom: 0.2rem; }
.rhead .h { font-weight: 700; color: var(--navy); }
.rhead .h i { font-style: normal; font-weight: 600; font-size: 0.5rem; }
.rhead .to i { color: var(--blue); } .rhead .fr i, .rhead .wh i { color: var(--violet); }
.rrow { font-size: 0.56rem; color: var(--navy); padding: 0.22rem 0; border-radius: 6px; transition: background 0.4s 1s; }
.rrow.match { background: #e3f4ea; }
.rrow.miss { background: #fbe9e7; }
.rn { color: var(--muted); font-size: 0.5rem; padding-left: 0.25rem; }
.cell { display: flex; align-items: center; gap: 0.3rem; }
.cell em { font-style: normal; font-weight: 800; opacity: 0; animation: pop 0.3s forwards; }
.cell em.ok { color: var(--green); } .cell em.no { color: var(--red); }
@keyframes pop { from { opacity: 0; transform: scale(0.4); } to { opacity: 1; transform: none; } }
.logic { margin-top: 0.4rem; font-size: 0.54rem; color: var(--violet); font-weight: 700; }
.log { margin-top: 0.4rem; font-size: 0.52rem; color: var(--green); font-weight: 600; opacity: 0; animation: pop 0.4s 1.4s forwards; }
.log span { color: var(--muted); font-weight: 500; margin-right: 0.4rem; }
.log.bad { color: var(--red); }

.src { display: flex; flex-direction: column; gap: 8px; }
.lane { display: grid; grid-template-columns: 250px 18px 190px 1fr; align-items: center; gap: 6px; background: #fff; border: 1px solid #e6eaf2; border-radius: 10px;
  padding: 0.35rem 0.6rem; font-size: 0.62rem; color: var(--navy); opacity: 0; animation: pop 0.4s forwards; }
.lane:nth-child(2) { animation-delay: 0.15s; } .lane:nth-child(3) { animation-delay: 0.3s; }
.lane .from { font-size: 0.54rem; color: var(--blue); font-weight: 600; }
.lane .arrow { color: var(--muted); font-weight: 700; }
.lane .ex { font-size: 0.5rem; color: var(--muted); }
.srcp { font-size: 0.66rem; color: #1b2433; margin: 0.2rem 0 0; }

.defs { display: flex; flex-direction: column; gap: 7px; }
.drow { display: flex; justify-content: space-between; align-items: center; background: #fff; border: 1px solid #e6eaf2; border-radius: 10px;
  padding: 0.45rem 0.75rem; font-size: 0.66rem; color: var(--navy); opacity: 0; animation: pop 0.4s forwards; }
.drow b.ok { color: var(--green); } .drow b.no { color: var(--red); }
.drow:nth-child(3) { border-color: var(--navy); box-shadow: 0 0 0 3px rgba(20, 33, 61, 0.08); }

.note { font-size: 0.86rem; color: #1b2433; min-height: 2.5rem; margin: 0.6rem 0 0; text-align: left; }
.sw-enter-active, .sw-leave-active { transition: all 0.3s; }
.sw-enter-from { opacity: 0; transform: translateY(8px); }
.sw-leave-to { opacity: 0; }
.n-enter-active, .n-leave-active { transition: all 0.25s; }
.n-enter-from { opacity: 0; transform: translateY(6px); }
.n-leave-to { opacity: 0; }
</style>

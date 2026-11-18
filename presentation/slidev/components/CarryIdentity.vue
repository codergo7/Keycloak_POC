<script setup lang="ts">
// Two ways to carry identity: opens the POC part (slide 13). Needs `clicks: 6`.
// Each lane sends a request every 4 seconds, only on its own click (and the red one on click 3).
// Click 1: a browser request carries the encrypted session cookie; OAuth2-Proxy decrypts and checks it.
// Click 2: a script sends a bearer JWT; anyone can decode it; Istio's RequestAuthentication verifies it.
// Click 3: someone changes one claim in the JWT; the signature no longer matches → 401 at the gateway
//          (check 3 of make demo-api).
// Clicks 4–6: scope, claim and role, using alice's real token from the POC.
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $clicks } = useSlideContext()
const s = computed(() => Math.min(Math.max($clicks.value, 0), 6))
const tamper = computed(() => s.value === 3)

const lanes = [
  {
    k: 'ck', at: 1, actor: 'Browser', who: 'a person', icon: 'i-carbon-user', host: 'app.localhost',
    chip: 'Cookie', checker: 'OAuth2-Proxy', how: 'decrypts the cookie',
    facts: [['Sent as', 'Cookie: _oauth2_proxy=…'], ['Readable?', 'No: encrypted, HttpOnly'], ['Checked by', 'OAuth2-Proxy'], ['Host', 'app.localhost']],
  },
  {
    k: 'jw', at: 2, actor: 'Script', who: 'CLI or service', icon: 'i-carbon-terminal', host: 'api.localhost',
    chip: 'Bearer', checker: 'RequestAuthentication', how: 'verifies the signature',
    facts: [['Sent as', 'Authorization: Bearer eyJ…'], ['Readable?', 'Yes: anyone can decode it'], ['Checked by', 'Istio RequestAuthentication'], ['Host', 'api.localhost']],
  },
]
const st = (at: number) => (s.value < at ? 'wait' : s.value === at ? 'now' : 'done')
</script>

<template>
  <div class="ci">
    <div v-for="l in lanes" :key="l.k" class="lane" :class="[l.k, st(l.at), { bad: l.k === 'jw' && tamper }]">
      <div class="actor"><span :class="l.icon" class="ico" /><b>{{ l.actor }}</b><small>{{ l.who }}</small></div>

      <div class="track">
        <div class="rail"><span /></div>
        <!-- the credential, as the receiver sees it -->
        <div v-if="l.k === 'ck'" class="cred mono">
          <span class="lock i-carbon-locked" /><span class="enc">lSXX8KZHJZwH4q…</span><span class="pipe">|</span><span class="ts">1794585771</span><span class="pipe">|</span><span class="sg">sg3NN7AW…</span>
          <em>can’t read · can’t change</em>
        </div>
        <div v-else class="cred mono jwt">
          <span class="h">eyJhbGci…</span>.<span class="p">eyJzdWIi…</span>.<span class="g">kM2v…</span>
          <div class="dec">
            <span class="i-carbon-view" /> sub alice · roles [developer, <b :key="'r' + tamper" class="role" :class="{ hacked: tamper }">{{ tamper ? 'admin' : 'user' }}</b>]
          </div>
        </div>
        <!-- the request travelling -->
        <div v-if="s === l.at || (l.k === 'jw' && tamper)" :key="'pk' + s" class="packet mono">
          <span class="dot" />{{ l.chip }}
        </div>
      </div>

      <div class="chk">
        <small class="mono">{{ l.host }}</small>
        <b>{{ l.checker }}</b>
        <span class="how">{{ l.how }}</span>
        <span class="verdict mono">{{ l.k === 'jw' && tamper ? '✕ 401 signature' : '✓ valid' }}</span>
      </div>

      <div class="facts">
        <div v-for="(f, i) in l.facts" :key="f[0]" class="fact" :style="{ '--i': i }">
          <span>{{ f[0] }}</span><b :class="{ mono: f[1].includes(':') && i === 0 }">{{ f[1] }}</b>
        </div>
      </div>
    </div>

    <!-- scope · claim · role -->
    <div class="terms">
      <div class="term sc" :class="{ on: s >= 4, now: s === 4 }">
        <span class="chip">Scope</span><code>scope=openid reports</code><small>what the client asked for</small>
      </div>
      <div class="arr" :class="{ on: s >= 5 }">adds aud →</div>
      <div class="term cl" :class="{ on: s >= 5, now: s === 5 }">
        <span class="chip orange">Claim</span><code>"aud": ["spring-api", <b>"reports-api"</b>]</code><small>a fact written in the token</small>
      </div>
      <div class="arr" :class="{ on: s >= 6 }">one claim →</div>
      <div class="term rl" :class="{ on: s >= 6, now: s === 6 }">
        <span class="chip red">Role</span><code>realm_access.roles: ["developer", "user"]</code><small>what the user is allowed</small>
      </div>
    </div>
  </div>
</template>

<style scoped>
.ci { --navy: #14213d; --blue: #2459c9; --orange: #c2570c; --green: #1f8a5b; --red: #c0392b; --violet: #7b3fbf; --muted: #7a8496; margin-top: 0.6rem; }
.mono { font-family: 'JetBrains Mono', monospace; }

.lane {
  display: grid; grid-template-columns: 104px 1fr 184px 268px; gap: 0.6rem; align-items: center; height: 124px; padding: 0 0.8rem;
  margin-bottom: 0.7rem; border-radius: 14px; background: #fff; border: 1px solid #e6eaf2; box-shadow: 0 10px 26px -22px rgba(20, 33, 61, 0.6);
  transition: all 0.4s;
}
.lane.ck { --c: var(--orange); --cbg: #fbe9dc; }
.lane.jw { --c: var(--blue); --cbg: #e4ecfb; }
.lane.wait { opacity: 0.45; }
.lane.now { border-color: var(--c); box-shadow: 0 0 0 3px color-mix(in srgb, var(--c) 18%, transparent), 0 14px 30px -22px rgba(20, 33, 61, 0.6); }

.actor { display: flex; flex-direction: column; align-items: center; justify-content: center; height: 92px; border-radius: 12px; background: var(--cbg); }
.actor .ico { font-size: 1.4rem; color: var(--c); }
.actor b { font-size: 0.9rem; color: var(--navy); }
.actor small { font-size: 0.56rem; color: var(--muted); }

.track { position: relative; height: 100%; display: flex; flex-direction: column; justify-content: center; }
.rail { position: absolute; left: 0; right: 0; top: 30px; height: 2px; background: #e2e6ee; overflow: hidden; }
.rail span { position: absolute; inset: 0; background: var(--c); transform: translateX(-100%); transition: transform 1s ease-out; }
.lane.now .rail span, .lane.done .rail span { transform: none; }
.lane.done .rail span { transition: none; }
.lane.bad .rail span { background: var(--red); }

.packet {
  position: absolute; top: 18px; left: 0; display: flex; align-items: center; gap: 0.3rem; padding: 0.12rem 0.5rem; border-radius: 99px;
  background: var(--c); color: #fff; font-size: 0.62rem; font-weight: 700; box-shadow: 0 6px 16px -6px var(--c);
  animation: go 4s cubic-bezier(0.5, 0, 0.3, 1) infinite;
}
.packet .dot { width: 0.4rem; height: 0.4rem; border-radius: 50%; background: #fff; }
.lane.bad .packet { background: var(--red); }
/* one request every 4 s: travel ~1.1 s, then a pause */
@keyframes go { 0% { left: 0; opacity: 0; } 3% { opacity: 1; } 27% { left: calc(100% - 70px); opacity: 1; } 31%, 100% { left: calc(100% - 70px); opacity: 0; } }

.cred {
  margin-top: 44px; font-size: 0.62rem; color: var(--navy); opacity: 0; transform: translateY(6px); transition: all 0.4s;
  display: flex; flex-wrap: wrap; align-items: center; gap: 0.1rem 0.15rem;
}
.lane.now .cred { opacity: 1; transform: none; transition-delay: 0.3s; }
.lane.done .cred { opacity: 1; transform: none; }
.cred .lock { color: var(--orange); margin-right: 0.2rem; }
.cred .enc { background: #def3e8; padding: 0 0.2rem; border-radius: 3px; }
.cred .ts { background: #eef2fa; padding: 0 0.2rem; border-radius: 3px; }
.cred .sg { background: #fcebdd; padding: 0 0.2rem; border-radius: 3px; }
.cred .pipe { color: var(--muted); }
.cred em { flex-basis: 100%; font-style: normal; font-weight: 700; color: var(--orange); font-size: 0.56rem; margin-top: 0.2rem; }
.jwt .h { color: #c0392b; } .jwt .p { color: var(--violet); } .jwt .g { color: var(--blue); }
.jwt span.h, .jwt span.p, .jwt span.g { font-weight: 700; }
.dec { flex-basis: 100%; margin-top: 0.2rem; padding: 0.12rem 0.35rem; border-radius: 5px; background: #f3effa; color: #1b2433; font-size: 0.6rem; }
.dec span { color: var(--violet); vertical-align: -0.1rem; }
.role { padding: 0 0.15rem; border-radius: 3px; }
.role.hacked { background: var(--red); color: #fff; animation: flash 0.6s both; }
@keyframes flash { 0% { transform: scale(1.6); } 100% { transform: none; } }

.chk {
  display: flex; flex-direction: column; justify-content: center; height: 92px; padding: 0 0.7rem; border-radius: 12px;
  border: 1.5px dashed #c9d2e3; background: #fafbfd; transition: all 0.4s;
}
.chk small { font-size: 0.54rem; color: var(--muted); }
.chk b { font-size: 0.78rem; color: var(--navy); }
.chk .how { font-size: 0.58rem; color: #1b2433; }
.chk .verdict { font-size: 0.64rem; font-weight: 700; color: var(--green); opacity: 0; transition: opacity 0.3s; }
.lane.now .chk, .lane.done .chk { border-style: solid; border-color: var(--c); background: #fff; }
.lane.now .chk { transition-delay: 0.9s; }
.lane.now .verdict { opacity: 1; transition-delay: 1.05s; }
.lane.done .verdict { opacity: 1; }
.lane.bad .chk { border-color: var(--red); background: #fdeeec; animation: shake 0.4s 1s both; }
.lane.bad .verdict { color: var(--red); }
@keyframes shake { 25% { transform: translateX(-4px); } 50% { transform: translateX(4px); } 75% { transform: translateX(-2px); } }

.facts { display: flex; flex-direction: column; gap: 0.22rem; }
.fact { display: grid; grid-template-columns: 72px 1fr; font-size: 0.63rem; opacity: 0; transform: translateX(10px); transition: all 0.35s; }
.fact span { color: var(--muted); }
.fact b { font-weight: 600; color: var(--navy); }
.lane.now .fact { opacity: 1; transform: none; transition-delay: calc(1.2s + var(--i) * 0.12s); }
.lane.done .fact { opacity: 1; transform: none; }

.terms { display: flex; align-items: stretch; gap: 0.35rem; margin-top: 0.9rem; }
.term {
  flex: 1; display: flex; flex-direction: column; gap: 0.3rem; padding: 0.55rem 0.7rem; border-radius: 12px; background: #fff;
  border: 1px solid #e6eaf2; opacity: 0; transform: translateY(10px); transition: all 0.45s;
}
.term.on { opacity: 1; transform: none; }
.term.now { box-shadow: 0 0 0 3px rgba(36, 89, 201, 0.15); border-color: #b9c8e6; }
.term .chip { align-self: flex-start; }
.term code { font-size: 0.58rem; white-space: nowrap; }
.term code b { color: var(--orange); }
.term small { font-size: 0.7rem; color: #1b2433; }
.arr { align-self: center; font: 600 0.5rem 'JetBrains Mono', monospace; color: var(--muted); white-space: nowrap; opacity: 0; transition: opacity 0.4s; }
.arr.on { opacity: 1; }
</style>

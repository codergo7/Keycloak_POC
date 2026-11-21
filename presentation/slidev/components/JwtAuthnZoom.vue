<script setup lang="ts">
// Zoom into envoy.filters.http.jwt_authn on the spring-app sidecar (used by JwksFlow, steps 1–4):
// 1 find + decode the token, 2 verify it with keys it already has, 3 write the claims into the
// request's dynamic metadata (+ claim_to_headers), 4 later filters read the metadata, the app reads
// headers. Values are real: alice's token, the sidecar's jwt_authn/rbac config, and access-log
// lines from the gateway and the sidecar (format from istio-cm.yaml).
import { computed } from 'vue'

const props = defineProps<{ step: number }>()
const st = computed(() => props.step)

const claims = [
  { k: 'iss', v: '…/realms/demo', chk: 'issuer ✓' },
  { k: 'sub', v: '170b145d…', chk: '' },
  { k: 'aud', v: 'spring-api', chk: 'audience ✓' },
  { k: 'exp', v: '1794555059', chk: 'not expired ✓' },
  { k: 'realm_access.roles', v: '["developer","user"]', chk: '' },
]

interface Panel { t: string; p: string; code: string }
const panels: Record<number, Panel> = {
  1: { t: 'Inside jwt_authn 1/4 · find and decode the token',
    p: 'It takes the token from Authorization: Bearer, or a header listed in fromHeaders. It splits it at the two dots and decodes header and payload: plain base64url, readable by anyone.',
    code: `header    {"alg":"RS256","typ":"JWT","kid":"UHlGaDFC…"}     111 chars
payload   {"iss":…,"sub":…,"aud":…,"exp":…,"realm_access":…}  706 chars
signature  RS256 bytes, unreadable                            342 chars` },
  2: { t: 'Inside jwt_authn 2/4 · check it with what it already has',
    p: 'kid picks the key istiod pushed. The signature must match header + payload, then the claims are checked. Any failure stops the request here: 401, or 403 for the audience.',
    code: `kid  UHlGaDFC…           → local_jwks key   ✓
RS256(header.payload)    = signature         ✓
iss  …/realms/demo       = origins-0 issuer  ✓
exp  1794555059          > now − 60 s        ✓
aud  spring-api          ∈ audiences         ✓` },
  3: { t: 'Inside jwt_authn 3/4 · write the claims into metadata',
    p: 'The decoded payload is stored in the request’s dynamic metadata, under the filter’s own name. On the sidecar, claim_to_headers also writes the identity headers.',
    code: `payload_in_metadata: payload
  → metadata["envoy.filters.http.jwt_authn"]["payload"] = { iss, sub, aud, realm_access, … }
claim_to_headers: sub → x-auth-request-user, email → x-auth-request-email
forward: true     # the Authorization header stays on the request` },
  4: { t: 'Inside jwt_authn 4/4 · later filters read the metadata',
    p: 'rbac and the access log read the metadata. It lives only inside this Envoy, for this one request; the app never sees it. Spring gets headers. The gateway writes no header, so its log shows user=-.',
    code: `rbac        metadata jwt_authn payload.realm_access.roles one_of "user" → ALLOW
access log  jwt_subject=%DYNAMIC_METADATA(envoy.filters.http.jwt_authn:payload:sub)%
gateway     user=-             jwt_subject=170b145d…
sidecar     user=170b145d…     jwt_subject=170b145d…` },
}
const cur = computed(() => panels[st.value])
</script>

<template>
  <div class="zm">
    <div class="frame">
      <div class="flabel mono"><span class="i-carbon-zoom-in" /> inside <b>envoy.filters.http.jwt_authn</b> · spring-app sidecar</div>


      <!-- request headers -->
      <div class="req">
        <div class="cap mono">request headers</div>
        <div class="hrow mono"><b>authorization:</b> Bearer
          <span class="tk" :class="{ split: st >= 1 }"><i class="h">eyJhbGci</i>.<i class="p">eyJleHAi</i>.<i class="s">pfQeI…</i></span>
        </div>
        <div class="hrow mono add" :class="{ show: st >= 3 }"><b>x-auth-request-user:</b> 170b145d…</div>
        <div class="hrow mono add" :class="{ show: st >= 3 }"><b>x-auth-request-email:</b> alice@…</div>
        <div class="tag" :class="{ show: st >= 3 }">claim_to_headers</div>
      </div>

      <!-- decoded parts -->
      <div class="part hdr" :class="{ show: st >= 1, dim: st >= 3 }">
        <div class="pt"><i class="dot h" />header</div>
        <div class="kv mono">alg <b>RS256</b></div>
        <div class="kv mono">kid <b>UHlGaDFC…</b><em :class="{ show: st >= 2 }">→ key ✓</em></div>
      </div>
      <div class="part sig" :class="{ show: st >= 1, dim: st >= 3, ok: st === 2 }">
        <div class="pt"><i class="dot s" />signature</div>
        <div class="kv mono">{{ st >= 2 ? 'RS256 ✓' : '342 bytes' }}</div>
      </div>
      <div class="part pay" :class="{ show: st >= 1, flown: st >= 3 }">
        <div class="pt"><i class="dot p" />payload · claims</div>
        <div v-for="(c, i) in claims" :key="c.k" class="kv mono">
          {{ c.k }} <b>{{ c.v }}</b>
          <em v-if="c.chk" :class="{ show: st === 2 }" :style="{ transitionDelay: `${0.25 + i * 0.18}s` }">{{ c.chk }}</em>
        </div>
      </div>

      <!-- dynamic metadata -->
      <div class="meta" :class="{ show: st >= 3 }">
        <div class="cap mono">dynamic metadata · this request only</div>
        <div class="ns mono">envoy.filters.http.jwt_authn</div>
        <div class="mrow mono">payload.iss  <b>…/realms/demo</b></div>
        <div class="mrow mono" :class="{ hl: st >= 4 }">payload.sub  <b>170b145d…</b></div>
        <div class="mrow mono" :class="{ hl: st >= 4 }">payload.realm_access.roles  <b>[developer, user]</b></div>
      </div>

      <!-- consumers -->
      <div class="cons" :class="{ show: st >= 4 }">
        <div class="c mono"><span class="up">↑ reads</span><b>rbac</b> roles one_of "user" → <span class="g">ALLOW</span></div>
        <div class="c mono"><span class="up">↑ reads</span><b>access log</b> jwt_subject=170b145d…</div>
      </div>
      <div class="app mono" :class="{ show: st >= 4 }">→ Spring reads the <b>headers</b>, never the metadata</div>
    </div>

    <Transition name="sw" mode="out-in">
      <div v-if="cur" :key="st" class="panel">
        <div class="txt"><h4>{{ cur.t }}</h4><p>{{ cur.p }}</p></div>
        <pre class="code mono">{{ cur.code }}</pre>
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.zm { --navy: #14213d; --blue: #2459c9; --orange: #c2570c; --green: #1f8a5b; --red: #c0352b; --violet: #7b3fbf; --muted: #7a8496; }
.mono { font-family: 'JetBrains Mono', monospace; }
.frame { position: relative; width: 860px; height: 208px; margin: 0 auto; border: 1.5px solid var(--navy); border-radius: 14px; background: rgba(255, 255, 255, 0.6); box-shadow: 0 18px 40px -28px rgba(20, 33, 61, 0.6); }
.flabel { position: absolute; top: -0.62rem; left: 14px; background: var(--navy); color: #fff; font-size: 0.5rem; padding: 0.1rem 0.5rem; border-radius: 99px; display: flex; align-items: center; gap: 0.3rem; z-index: 3; }
.flabel b { color: #8db4ff; }
.wires { position: absolute; inset: 0; width: 100%; height: 100%; pointer-events: none; }
.w { fill: none; stroke: transparent; stroke-width: 2; stroke-dasharray: 5 6; transition: stroke 0.3s; }
.w.on { stroke: var(--blue); animation: flow 0.8s linear infinite; }
.w.ok.on { stroke: var(--green); }
@keyframes flow { to { stroke-dashoffset: -11; } }

.cap { font-size: 0.45rem; text-transform: uppercase; letter-spacing: 0.06em; color: var(--muted); margin-bottom: 0.2rem; }
.req { position: absolute; left: 12px; top: 22px; width: 220px; background: #fff; border: 1px solid #e6eaf2; border-radius: 10px; padding: 0.35rem 0.5rem; }
.hrow { font-size: 0.48rem; color: var(--navy); line-height: 1.7; white-space: nowrap; }
.hrow b { color: var(--muted); font-weight: 600; }
.hrow.add { max-height: 0; opacity: 0; overflow: hidden; transform: translateX(14px); transition: all 0.5s cubic-bezier(0.2, 0.7, 0.2, 1) 0.6s; }
.hrow.add.show { max-height: 1.2rem; opacity: 1; transform: none; }
.hrow.add b { color: var(--green); }
.tag { display: inline-block; margin-top: 0.15rem; font: 600 0.42rem 'JetBrains Mono', monospace; color: var(--green); background: #def3e8; border-radius: 99px; padding: 0.02rem 0.35rem; opacity: 0; transition: opacity 0.4s 0.9s; }
.tag.show { opacity: 1; }
.tk i { font-style: normal; font-weight: 700; transition: all 0.4s; }
.tk .h { color: var(--red); } .tk .p { color: var(--violet); } .tk .s { color: var(--blue); }
.tk.split i { padding: 0 0.12rem; border-radius: 3px; }
.tk.split .h { background: #fbe3e1; } .tk.split .p { background: #efe4fa; } .tk.split .s { background: #e3ecfb; }

.part { position: absolute; background: #fff; border: 1px solid #e6eaf2; border-radius: 10px; padding: 0.3rem 0.5rem; opacity: 0; transform: translateX(-150px) scale(0.6); transition: all 0.7s cubic-bezier(0.3, 0.8, 0.2, 1); }
.part.show { opacity: 1; transform: none; }
.part.dim { opacity: 0.35; }
.hdr { left: 268px; top: 22px; width: 172px; border-left: 3px solid var(--red); transition-delay: 0s; }
.sig { left: 452px; top: 22px; width: 93px; border-left: 3px solid var(--blue); transition-delay: 0.12s; }
.sig.ok { border-color: var(--green); box-shadow: 0 0 0 3px rgba(31, 138, 91, 0.15); }
.pay { left: 268px; top: 96px; width: 277px; border-left: 3px solid var(--violet); transition-delay: 0.24s; }
.pay.flown { opacity: 0; transform: translateX(300px) scale(0.5); transition-delay: 0s; }
.pt { font: 700 0.5rem 'JetBrains Mono', monospace; color: var(--navy); display: flex; align-items: center; gap: 0.3rem; margin-bottom: 0.15rem; }
.dot { width: 0.4rem; height: 0.4rem; border-radius: 50%; display: inline-block; }
.dot.h { background: var(--red); } .dot.p { background: var(--violet); } .dot.s { background: var(--blue); }
.kv { font-size: 0.46rem; color: var(--muted); line-height: 1.6; white-space: nowrap; display: flex; gap: 0.3rem; align-items: center; }
.kv b { color: var(--navy); font-weight: 600; }
.kv em { font-style: normal; font-weight: 700; color: var(--green); margin-left: auto; opacity: 0; transform: scale(0.6); transition: all 0.35s; }
.kv em.show { opacity: 1; transform: none; }

.meta { position: absolute; left: 578px; top: 22px; width: 268px; background: #f2f9f5; border: 1.5px solid var(--green); border-radius: 10px; padding: 0.35rem 0.5rem; opacity: 0; transform: scale(0.85); transition: all 0.55s cubic-bezier(0.3, 0.8, 0.2, 1) 0.45s; }
.meta.show { opacity: 1; transform: none; }
.ns { font-size: 0.48rem; font-weight: 700; color: var(--green); margin-bottom: 0.1rem; }
.mrow { font-size: 0.46rem; color: var(--muted); line-height: 1.65; white-space: nowrap; border-radius: 4px; padding: 0 0.2rem; transition: background 0.4s; }
.mrow b { color: var(--navy); font-weight: 600; }
.mrow.hl { background: #d5efe1; }

.cons { position: absolute; left: 578px; top: 112px; width: 268px; display: flex; flex-direction: column; gap: 0.25rem; opacity: 0; transform: translateY(10px); transition: all 0.5s 0.2s; }
.cons.show { opacity: 1; transform: none; }
.c { font-size: 0.46rem; color: var(--navy); background: #fff; border: 1px solid #e6eaf2; border-radius: 7px; padding: 0.2rem 0.45rem; }
.c b { color: var(--blue); margin-right: 0.3rem; }
.c .up { color: var(--green); font-weight: 700; margin-right: 0.35rem; }
.c .g { color: var(--green); font-weight: 700; }
.app { position: absolute; left: 12px; top: 128px; font-size: 0.48rem; color: var(--navy); opacity: 0; transition: opacity 0.5s 0.5s; }
.app.show { opacity: 1; }
.app b { color: var(--green); }

.panel { display: grid; grid-template-columns: 0.85fr 1.5fr; gap: 0.8rem; margin-top: 0.7rem; }
.txt { background: #fff; border: 1px solid #e6eaf2; border-radius: 12px; padding: 0.55rem 0.75rem; }
.txt h4 { margin: 0 0 0.25rem; font-size: 0.8rem; line-height: 1.3; font-weight: 700; color: var(--navy); }
.txt p { margin: 0; font-size: 0.64rem; line-height: 1.45; color: #4a5568; }
.code { margin: 0; background: #14213d; color: #dbe4f5; border-radius: 12px; padding: 0.55rem 0.75rem; font-size: 0.5rem; line-height: 1.6; white-space: pre; overflow: hidden; }
.sw-enter-active, .sw-leave-active { transition: all 0.25s ease; }
.sw-enter-from { opacity: 0; transform: translateY(8px); }
.sw-leave-to { opacity: 0; }
</style>

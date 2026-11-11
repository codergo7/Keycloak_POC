<script setup lang="ts">
// "How do I debug a 401 or 403?": one response per click. The pipeline lights up the
// filter that produced it, and the panel says which Istio resource to look at and why.
// Every message was produced on the running POC. The last click shows the tools.
// The slide needs `clicks: 9`.
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $clicks } = useSlideContext()
const s = computed(() => Math.min(Math.max($clicks.value, 0), 9))

// 0 ext_authz · 1 jwt_authn · 2 rbac · 3 router  |  4 jwt_authn · 5 rbac  |  6 app
const stages = [
  { f: 'ext_authz', r: 'CUSTOM', at: 'gw' }, { f: 'jwt_authn', r: 'RequestAuthn', at: 'gw' },
  { f: 'rbac', r: 'ALLOW', at: 'gw' }, { f: 'router', r: 'VirtualService', at: 'gw' },
  { f: 'jwt_authn', r: 'RequestAuthn', at: 'sc' }, { f: 'rbac', r: 'ALLOW', at: 'sc' },
  { f: 'app', r: 'or the network', at: 'app' },
]

interface Case { code: string; cls: string; msg: string; hint?: string; where: number[]; res: string; why: string; fix: string }
const cases: Case[] = [
  { code: '302', cls: 'code-30x', msg: 'Location: keycloak.localhost/…/auth', where: [0],
    res: 'AuthorizationPolicy oauth2-external-auth (CUSTOM)', why: 'OAuth2-Proxy found no valid session cookie.',
    fix: 'Normal for a new browser. In a loop? Check the cookie domain and the redirect URL.' },
  { code: '401', cls: 'code-401', msg: 'Jwt verification fails', where: [1, 4],
    res: 'RequestAuthentication: jwksUri', why: 'The signature does not match any key in Keycloak’s JWKS.',
    fix: 'Tampered token, or istiod cached old keys: restart istiod after Keycloak changes keys.' },
  { code: '401', cls: 'code-401', msg: 'Jwt is expired', where: [1, 4],
    res: 'RequestAuthentication (exp claim)', why: 'The access token is older than 5 minutes.',
    fix: 'Get a new token, or refresh it. Browsers: OAuth2-Proxy does this every 4 minutes.' },
  { code: '401', cls: 'code-401', msg: 'Jwt issuer is not configured', where: [1, 4],
    res: 'RequestAuthentication: issuer', why: 'The token’s iss is not listed, for example a token from another realm.',
    fix: 'Compare the token’s iss with the jwtRules issuer, character for character.' },
  { code: '403', cls: 'code-403', msg: 'Audiences in Jwt are not allowed', where: [4],
    res: 'RequestAuthentication: audiences (sidecar)', why: 'The token is valid, but not issued for this API.',
    fix: 'Ask for the right scope, for example scope=reports for reports-api.' },
  { code: '403', cls: 'code-403', msg: 'RBAC: access denied', hint: 'no x-envoy-upstream-service-time', where: [2],
    res: 'AuthorizationPolicy ingress-authorization', why: 'Denied at the gateway: no token, or the path is not listed.',
    fix: 'Send a token, or add the path to the gateway’s ALLOW rules.' },
  { code: '403', cls: 'code-403', msg: 'RBAC: access denied', hint: 'with x-envoy-upstream-service-time', where: [5],
    res: 'AuthorizationPolicy on the workload', why: 'The gateway let it through; the sidecar found no matching role claim.',
    fix: 'Decode the token and compare its roles with the policy’s when: values.' },
  { code: '503', cls: 'code-403', msg: 'upstream connect error · no healthy upstream', where: [6],
    res: 'Not a policy: the network or the pod', why: 'The pod is down, or mesh certificates expired (laptop sleep).',
    fix: 'kubectl get pods. After laptop sleep: make wake.' },
]
const cur = computed(() => (s.value >= 1 && s.value <= 8 ? cases[s.value - 1] : null))
function st(i: number) {
  if (!cur.value) return ''
  return cur.value.where.includes(i) ? 'hit' : ''
}
</script>

<template>
  <div class="dt">
    <div class="pipe">
      <div class="seg gw"><div class="lbl">Ingress gateway</div>
        <div class="row"><div v-for="i in [0, 1, 2, 3]" :key="i" class="st" :class="st(i)"><b>{{ stages[i].f }}</b><small>{{ stages[i].r }}</small></div></div>
      </div>
      <div class="seg sc"><div class="lbl">Sidecar</div>
        <div class="row"><div v-for="i in [4, 5]" :key="i" class="st" :class="st(i)"><b>{{ stages[i].f }}</b><small>{{ stages[i].r }}</small></div></div>
      </div>
      <div class="seg ap"><div class="lbl">App</div>
        <div class="row"><div class="st" :class="st(6)"><b>Spring</b><small>{{ stages[6].r }}</small></div></div>
      </div>
    </div>

    <Transition name="sw" mode="out-in">
      <div v-if="cur" :key="s" class="panel">
        <div class="resp">
          <div class="label">You got</div>
          <div class="code" :class="cur.cls">{{ cur.code }}</div>
          <div class="msg mono">{{ cur.msg }}</div>
          <div v-if="cur.hint" class="hint mono">{{ cur.hint }}</div>
        </div>
        <div class="diag">
          <div class="label">Look at</div>
          <div class="res mono">{{ cur.res }}</div>
          <p>{{ cur.why }}</p>
          <p class="fix">→ {{ cur.fix }}</p>
        </div>
      </div>
      <div v-else-if="s === 9" key="tools" class="tools">
        <div class="label">Tools that answer “which filter said no?”</div>
        <div class="cmd"><span>$</span> curl -i … <i># status, body text, x-envoy-upstream-service-time</i></div>
        <div class="cmd"><span>$</span> istioctl proxy-config log &lt;pod&gt; --level jwt:debug,rbac:debug</div>
        <div class="cmd"><span>$</span> kubectl logs &lt;pod&gt; -c istio-proxy <i># the reason, per request</i></div>
        <div class="cmd"><span>$</span> cut -d. -f2 &lt;&lt;&lt; "$TOKEN" | base64 -d <i># iss, aud, exp, roles</i></div>
      </div>
      <div v-else key="intro" class="intro">
        The status code and the body text tell you which filter answered. Click through the answers you will meet.
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.mono { font-family: 'JetBrains Mono', monospace; }
.pipe { display: flex; gap: 0.6rem; }
.seg { border: 1.5px dashed #b8c3d8; border-radius: 10px; padding: 0.3rem 0.4rem; background: rgba(255, 255, 255, 0.55); }
.seg.gw { flex: 4; } .seg.sc { flex: 2; } .seg.ap { flex: 1.1; }
.lbl { font: 700 0.55rem 'JetBrains Mono', monospace; text-transform: uppercase; letter-spacing: 0.06em; color: #14213d; margin-bottom: 0.25rem; }
.row { display: flex; gap: 0.3rem; }
.st { flex: 1; min-width: 0; background: #fff; border: 1px solid #e6eaf2; border-radius: 8px; padding: 0.3rem 0.35rem; transition: all 0.4s cubic-bezier(0.2, 0.7, 0.2, 1); }
.st b { display: block; font: 700 0.66rem 'JetBrains Mono', monospace; color: #14213d; }
.st small { display: block; font-size: 0.5rem; color: #7a8496; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.st.hit { background: #14213d; border-color: #14213d; transform: translateY(-4px); box-shadow: 0 10px 22px -10px rgba(20, 33, 61, 0.7); animation: ring 1.4s ease-out 0.3s infinite; }
.st.hit b { color: #fff; } .st.hit small { color: #aebbd6; }
@keyframes ring { 0% { box-shadow: 0 0 0 0 rgba(192, 53, 43, 0.5); } 100% { box-shadow: 0 0 0 10px rgba(192, 53, 43, 0); } }

.panel { display: grid; grid-template-columns: 0.9fr 1.4fr; gap: 0.8rem; margin-top: 0.9rem; }
.resp, .diag, .tools, .intro { background: #fff; border: 1px solid #e6eaf2; border-radius: 12px; padding: 0.7rem 0.9rem; }
.label { font: 700 0.55rem 'JetBrains Mono', monospace; text-transform: uppercase; letter-spacing: 0.08em; color: #7a8496; margin-bottom: 0.3rem; }
.code { font: 800 2.4rem/1 'JetBrains Mono', monospace; }
.msg { margin-top: 0.4rem; font-size: 0.75rem; font-weight: 700; color: #14213d; }
.hint { margin-top: 0.3rem; font-size: 0.58rem; color: #c2570c; }
.res { font-size: 0.72rem; font-weight: 700; color: #2459c9; }
.diag p { font-size: 0.72rem; line-height: 1.45; color: #4a5568; margin: 0.35rem 0 0; }
.diag p.fix { color: #1f8a5b; font-weight: 600; }
.tools { margin-top: 0.9rem; }
.cmd { font: 0.66rem/1.9 'JetBrains Mono', monospace; color: #14213d; }
.cmd span { color: #c2570c; margin-right: 0.4rem; }
.cmd i { color: #7a8496; font-style: normal; }
.intro { margin-top: 0.9rem; font-size: 0.8rem; color: #4a5568; }
.sw-enter-active, .sw-leave-active { transition: all 0.25s ease; }
.sw-enter-from { opacity: 0; transform: translateY(8px); }
.sw-leave-to { opacity: 0; }
</style>

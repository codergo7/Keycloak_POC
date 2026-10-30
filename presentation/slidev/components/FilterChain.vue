<script setup lang="ts">
// The real Envoy filter order at the ingress gateway and the Spring sidecar.
// One stage lights up per click (slide needs `clicks: 9`).
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $clicks } = useSlideContext()

interface Stage {
  name: string
  res: string
  ask: string
  fail?: string
  failClass?: string
  detail: string
}

const gateway: Stage[] = [
  { name: 'Gateway', res: 'Gateway', ask: 'Host accepted?', fail: '404', failClass: 'code-403',
    detail: 'Opens listener :8080 and accepts only keycloak / app / api .localhost. No routing logic of its own.' },
  { name: 'Route', res: 'VirtualService', ask: 'Which destination?',
    detail: 'First matching http[] route wins. Its header rules are remembered now and applied last, by the router.' },
  { name: 'CUSTOM', res: 'AuthzPolicy CUSTOM', ask: 'Ask oauth2-proxy?', fail: '302', failClass: 'code-30x',
    detail: 'Only for app.localhost browser requests without a Bearer token. oauth2-proxy answers 200 + identity headers, or 302 to Keycloak.' },
  { name: 'JWT', res: 'RequestAuthn', ask: 'Token valid?', fail: '401', failClass: 'code-401',
    detail: 'Runs after ext_authz. Validates a Bearer JWT if present. No token is fine here; a bad token is 401.' },
  { name: 'ALLOW', res: 'AuthzPolicy ALLOW', ask: 'Any rule matches?', fail: '403', failClass: 'code-403',
    detail: 'ingress-authorization: keycloak and app hosts are open; api.localhost needs requestPrincipals except /api/public.' },
  { name: 'Router', res: 'VirtualService', ask: 'Header rules, send',
    detail: 'Applies route header rules (e.g. remove cookie), then sends the request to the Spring pod.' },
]
const sidecar: Stage[] = [
  { name: 'JWT', res: 'RequestAuthn', ask: 'aud = spring-api?', fail: '401', failClass: 'code-401',
    detail: 'keycloak-jwt reads Authorization: Bearer and X-Auth-Request-Access-Token, and requires audience spring-api.' },
  { name: 'ALLOW', res: 'AuthzPolicy ALLOW', ask: 'Role claim ok?', fail: '403', failClass: 'code-403',
    detail: 'spring-workload-authorization: path + realm role claim (realm_access.roles). No matching rule, 403.' },
  { name: 'Spring', res: 'app :8080', ask: 'Business logic',
    detail: 'Reaches the app on localhost with identity headers. No login code, no token parsing in Spring.' },
]

const all = [...gateway, ...sidecar]
const step = computed(() => Math.min($clicks.value, all.length))
const active = computed(() => (step.value > 0 ? all[step.value - 1] : null))
function state(globalIndex: number) {
  if (globalIndex < step.value - 1) return 'done'
  if (globalIndex === step.value - 1) return 'on'
  return 'todo'
}
</script>

<template>
  <div class="fc">
    <div class="lane-title">Ingress gateway <span class="faint">· Envoy</span></div>
    <div class="row">
      <template v-for="(s, i) in gateway" :key="'g' + i">
        <div class="stage" :class="state(i)">
          <div class="res">{{ s.res }}</div>
          <div class="name">{{ s.name }}</div>
          <div class="ask">{{ s.ask }}</div>
          <div v-if="s.fail" class="fail" :class="s.failClass">✕ {{ s.fail }}</div>
        </div>
        <div v-if="i < gateway.length - 1" class="arrow" :class="state(i)">→</div>
      </template>
    </div>

    <div class="hop" :class="{ lit: step > gateway.length }">
      <span>to the pod</span>
    </div>

    <div class="lane-title">Spring sidecar <span class="faint">· Envoy</span></div>
    <div class="row">
      <template v-for="(s, i) in sidecar" :key="'s' + i">
        <div class="stage" :class="state(gateway.length + i)">
          <div class="res">{{ s.res }}</div>
          <div class="name">{{ s.name }}</div>
          <div class="ask">{{ s.ask }}</div>
          <div v-if="s.fail" class="fail" :class="s.failClass">✕ {{ s.fail }}</div>
        </div>
        <div v-if="i < sidecar.length - 1" class="arrow" :class="state(gateway.length + i)">→</div>
      </template>
    </div>

    <div class="detail">
      <Transition name="d" mode="out-in">
        <div v-if="active" :key="step">
          <b>{{ step }}. {{ active.name }}</b> <span class="faint mono">({{ active.res }})</span> — {{ active.detail }}
        </div>
        <div v-else key="none" class="faint">Click to send a request through both proxies.</div>
      </Transition>
    </div>
  </div>
</template>

<style scoped>
.lane-title { font: 600 0.72rem 'JetBrains Mono', monospace; letter-spacing: 0.08em; text-transform: uppercase; color: #14213d; margin: 0 0 0.35rem; }
.row { display: flex; align-items: stretch; gap: 0.3rem; }
.stage {
  position: relative; flex: 1; min-width: 0; border-radius: 10px; padding: 0.5rem 0.55rem 0.55rem;
  background: #fff; border: 1px solid #e6eaf2; transition: all 0.45s cubic-bezier(0.2, 0.7, 0.2, 1);
}
.stage.todo { opacity: 0.45; }
.stage.on {
  background: #14213d; border-color: #14213d; transform: translateY(-4px);
  box-shadow: 0 12px 26px -12px rgba(20, 33, 61, 0.6);
}
.stage.done { background: #e3ecfb; border-color: #e3ecfb; }
.res { font: 500 0.55rem 'JetBrains Mono', monospace; color: #7a8496; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.name { font-weight: 700; font-size: 0.95rem; color: #14213d; }
.ask { font-size: 0.68rem; color: #4a5568; line-height: 1.3; }
.on .res { color: #8db4ff; }
.on .name { color: #fff; }
.on .ask { color: #cfd7e8; }
.fail {
  position: absolute; right: 0.4rem; top: 0.4rem; font: 700 0.6rem 'JetBrains Mono', monospace;
  opacity: 0; transform: scale(0.6); transition: all 0.35s 0.25s;
}
.on .fail { opacity: 1; transform: scale(1); background: #fff; padding: 0 0.3rem; border-radius: 4px; }
.arrow { align-self: center; color: #c5c4c1; font-size: 1rem; transition: color 0.4s; }
.arrow.done { color: #2459c9; }
.hop { display: flex; justify-content: center; margin: 0.45rem 0 0.4rem; }
.hop span {
  font: 600 0.62rem 'JetBrains Mono', monospace; color: #7a8496; border: 1px dashed #c5c4c1;
  border-radius: 999px; padding: 0.1rem 0.8rem; transition: all 0.4s;
}
.hop.lit span { color: #fff; background: #2459c9; border-color: #2459c9; }
.detail { margin-top: 0.9rem; min-height: 3.2rem; font-size: 0.84rem; line-height: 1.5; color: #1b2433; }
.d-enter-active, .d-leave-active { transition: all 0.25s ease; }
.d-enter-from { opacity: 0; transform: translateY(6px); }
.d-leave-to { opacity: 0; }
</style>

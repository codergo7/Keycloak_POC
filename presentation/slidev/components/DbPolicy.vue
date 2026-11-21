<script setup lang="ts">
// "Who can reach the database?": four callers try to log in to Postgres, before and after
// the postgres-allow-keycloak policy. Every result was measured on the running POC with
// psql from temporary pods (and the smoke test, section 12). The config excerpt is from
// the Postgres sidecar's config_dump. The slide needs `clicks: 6`.
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const { $clicks } = useSlideContext()
const s = computed(() => Math.min(Math.max($clicks.value, 0), 6))

const callers = [
  { n: 'Keycloak', ns: 'identity', id: '…/ns/identity/sa/keycloak', was: 'sa/default', allowed: true },
  { n: 'OAuth2-Proxy', ns: 'identity · same namespace', id: '…/ns/identity/sa/oauth2-proxy', allowed: false },
  { n: 'spring-app', ns: 'spring-api · other namespace', id: '…/ns/spring-api/sa/default', allowed: false },
  { n: 'Pod outside the mesh', ns: 'default · no sidecar', id: '', allowed: false },
]
const gateOn = computed(() => s.value >= 3)
function lane(c: (typeof callers)[number]) {
  if (s.value === 1) return 'ok'
  if (s.value >= 4) return c.allowed ? 'ok' : 'deny'
  return ''
}
function result(c: (typeof callers)[number]) {
  if (s.value === 1) return 'psql login ✓ · 5 users read'
  if (s.value >= 4) return c.allowed ? 'login ✓' : 'connection closed'
  return ''
}
function idText(c: (typeof callers)[number]) {
  if (!c.id) return 'no certificate'
  if (s.value === 2 && c.was) return `${c.was} → sa/keycloak`
  return c.id
}

interface Panel { t: string; p: string; code: string; warn?: boolean }
const panels: Record<number, Panel> = {
  1: { t: 'Before: no policy, everyone gets in', warn: true,
    p: 'With no AuthorizationPolicy, the Postgres sidecar lets every connection through. We logged in with psql from each caller and read Keycloak’s user table. The password was the only lock.',
    code: `$ psql -h postgres.identity… -U keycloak \\
    -c "select count(*) from user_entity"
identity   / sa oauth2-proxy (mesh)     5
spring-api / sa default (mesh)          5
default ns / no sidecar (plaintext)     5` },
  2: { t: 'Every sidecar already has an identity',
    p: 'Each sidecar holds an mTLS certificate for its service account. Keycloak and Postgres shared the default account, so “allow Keycloak” would have meant “allow everyone using default”. Keycloak got its own. A pod without a sidecar has no certificate at all.',
    code: `apiVersion: v1
kind: ServiceAccount
metadata: { name: keycloak, namespace: identity }
---
# keycloak Deployment
    spec:
      serviceAccountName: keycloak
# its certificate: spiffe://cluster.local/ns/identity/sa/keycloak` },
  3: { t: 'One ALLOW rule: only Keycloak, only 5432',
    p: 'An ALLOW policy turns the default around: whatever is not listed is denied. The source is a principal, the identity in the caller’s certificate, not a token.',
    code: `# k8s/keycloak/postgres-authorization.yaml
kind: AuthorizationPolicy
metadata: { name: postgres-allow-keycloak, namespace: identity }
spec:
  selector: { matchLabels: { app: postgres } }
  action: ALLOW
  rules:
    - from: [{ source: { principals: ["cluster.local/ns/identity/sa/keycloak"] } }]
      to:   [{ operation: { ports: ["5432"] } }]` },
  4: { t: 'After: only Keycloak gets in',
    p: 'Keycloak still works, also after a restart with new connections. Everyone else is refused. TCP has no 403: Envoy accepts the connection and closes it straight away.',
    code: `sa keycloak (test pod)      5
sa oauth2-proxy             psql: server closed the connection unexpectedly
spring-api / sa default     psql: server closed the connection unexpectedly
no sidecar (plaintext)      psql: server closed the connection unexpectedly
$ make smoke   → 12. Postgres refuses spring-app ✓` },
  5: { t: 'Under the hood: envoy.filters.network.rbac',
    p: 'Postgres speaks TCP, not HTTP, so istiod builds the network rbac filter. It can only match who calls and on which port: no paths, no methods, no JWT claims.',
    code: `envoy.filters.network.rbac:          # Postgres sidecar, config_dump
  stat_prefix: tcp.
  policies:
    ns[identity]-policy[postgres-allow-keycloak]-rule[0]:
      principals:  authenticated.principal_name:
                     spiffe://cluster.local/ns/identity/sa/keycloak
      permissions: destination_port: 5432
$ pilot-agent request GET stats | grep tcp.rbac
tcp.rbac.allowed: 4     tcp.rbac.denied: 4` },
  6: { t: 'What it does not cover yet',
    p: 'Anyone who may create a pod with sa/keycloak in identity gets the same identity, so Kubernetes RBAC is part of the boundary. Keycloak and OAuth2-Proxy still accept any caller in the mesh. Next steps, not applied here:',
    code: `kind: AuthorizationPolicy        # deny everything in identity
metadata: { name: allow-nothing, namespace: identity }
spec: {}                         # then ALLOW each caller explicitly
---
kind: PeerAuthentication         # refuse plaintext completely
metadata: { name: default, namespace: identity }
spec: { mtls: { mode: STRICT } }` },
}
const cur = computed(() => panels[s.value])
</script>

<template>
  <div class="db">
    <div class="stage">
      <template v-for="(c, i) in callers" :key="c.n">
        <div class="caller" :style="{ gridRow: i + 1 }" :class="{ hl: s === 2 && c.was }">
          <b>{{ c.n }}</b>
          <small>{{ c.ns }}</small>
          <span class="cert mono" :class="{ none: !c.id, show: s >= 2 }">
            <i class="i-carbon-certificate" />{{ idText(c) }}
          </span>
        </div>
        <div class="lane" :style="{ gridRow: i + 1 }" :class="lane(c)">
          <div class="res mono">{{ result(c) }}</div>
          <div class="line"><i /></div>
        </div>
      </template>
      <div class="pg" :class="{ guarded: gateOn }">
        <div class="gate" :class="{ on: gateOn }">
          <small class="mono">sidecar</small>
          <b class="mono">network rbac</b>
          <span>{{ gateOn ? 'only sa/keycloak' : 'no policy: allow all' }}</span>
        </div>
        <div class="dbx">
          <span class="i-carbon-data-base" />
          <b>Postgres</b>
          <small class="mono">identity · 5432</small>
          <small>Keycloak’s users, sessions, keys</small>
        </div>
      </div>
    </div>

    <Transition name="sw" mode="out-in">
      <div v-if="cur" :key="s" class="panel">
        <div class="txt" :class="{ warn: cur.warn }"><h4>{{ cur.t }}</h4><p>{{ cur.p }}</p></div>
        <pre class="code mono">{{ cur.code }}</pre>
      </div>
      <div v-else key="intro" class="intro">
        Keycloak keeps everything in Postgres: users, password hashes, sessions, signing keys.
        Which pods in the cluster can log in to it? Click to find out.
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.db { --navy: #14213d; --blue: #2459c9; --orange: #c2570c; --green: #1f8a5b; --red: #c0352b; --muted: #7a8496; }
.mono { font-family: 'JetBrains Mono', monospace; }
.stage { display: grid; grid-template-columns: 15rem 1fr 11rem; grid-template-rows: repeat(4, 2.75rem); row-gap: 0.35rem; column-gap: 0; }
.caller { grid-column: 1; background: #fff; border: 1px solid #e6eaf2; border-radius: 9px; padding: 0.22rem 0.55rem; display: grid; grid-template-columns: auto 1fr; column-gap: 0.4rem; align-content: center; transition: all 0.4s; }
.caller b { font-size: 0.7rem; color: var(--navy); }
.caller small { font-size: 0.5rem; color: var(--muted); align-self: center; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.caller.hl { border-color: var(--orange); box-shadow: 0 0 0 3px rgba(194, 87, 12, 0.15); }
.cert { grid-column: 1 / -1; font-size: 0.48rem; color: var(--blue); display: flex; align-items: center; gap: 0.25rem; opacity: 0; transition: opacity 0.4s; white-space: nowrap; overflow: hidden; }
.cert.show { opacity: 1; }
.cert.none { color: var(--red); }
.caller.hl .cert { color: var(--orange); font-weight: 700; }

.lane { grid-column: 2; position: relative; display: flex; flex-direction: column; justify-content: center; padding: 0 0.3rem; }
.res { font-size: 0.5rem; font-weight: 700; text-align: center; min-height: 1.2em; margin-bottom: 0.15rem; }
.line { height: 2px; background: #d5d9e2; position: relative; }
.lane.ok .line { background: var(--green); }
.lane.ok .res { color: var(--green); }
.lane.ok .line i { position: absolute; top: -3px; width: 8px; height: 8px; border-radius: 50%; background: var(--green); animation: go 1.3s ease-in-out infinite; }
.lane.deny .line { background: linear-gradient(90deg, var(--red) 0 calc(100% - 1.4rem), transparent 0); }
.lane.deny .res { color: var(--red); }
.lane.deny .line i { position: absolute; top: -3px; width: 8px; height: 8px; border-radius: 50%; background: var(--red); animation: stop 1.3s ease-in infinite; }
.lane.deny .line::after { content: '✕'; position: absolute; right: 0.55rem; top: -0.5rem; font-size: 0.7rem; font-weight: 700; color: var(--red); }
@keyframes go { from { left: 0; } to { left: calc(100% - 8px); } }
@keyframes stop { 0% { left: 0; opacity: 1; } 75% { left: calc(100% - 1.6rem); opacity: 1; } 100% { left: calc(100% - 1.6rem); opacity: 0; } }

.pg { grid-column: 3; grid-row: 1 / 5; display: flex; gap: 0; border: 1.5px dashed #b8c3d8; border-radius: 12px; overflow: hidden; background: rgba(255, 255, 255, 0.55); transition: border-color 0.4s; }
.pg.guarded { border-color: var(--navy); border-style: solid; }
.gate { width: 3.6rem; flex: none; display: flex; flex-direction: column; justify-content: center; align-items: center; text-align: center; gap: 0.15rem; background: #eef0f4; padding: 0.3rem; transition: all 0.45s; }
.gate small { font-size: 0.42rem; color: var(--muted); }
.gate b { font-size: 0.5rem; color: var(--navy); line-height: 1.2; }
.gate span { font-size: 0.45rem; color: var(--muted); line-height: 1.25; }
.gate.on { background: var(--navy); }
.gate.on small, .gate.on span { color: #aebbd6; }
.gate.on b { color: #fff; }
.dbx { flex: 1; display: flex; flex-direction: column; justify-content: center; align-items: center; text-align: center; gap: 0.15rem; padding: 0.4rem; }
.dbx > span { font-size: 1.6rem; color: var(--navy); }
.dbx b { font-size: 0.78rem; color: var(--navy); }
.dbx small { font-size: 0.48rem; color: var(--muted); }

.panel { display: grid; grid-template-columns: 0.9fr 1.4fr; gap: 0.8rem; margin-top: 0.75rem; }
.txt, .intro { background: #fff; border: 1px solid #e6eaf2; border-radius: 12px; padding: 0.6rem 0.8rem; }
.txt.warn { border-color: #f1c6c2; background: #fdf3f2; }
.txt h4 { margin: 0 0 0.3rem; font-size: 0.85rem; line-height: 1.3; font-weight: 700; color: var(--navy); }
.txt.warn h4 { color: var(--red); }
.txt p { margin: 0; font-size: 0.68rem; line-height: 1.5; color: #4a5568; }
.code { margin: 0; background: #14213d; color: #dbe4f5; border-radius: 12px; padding: 0.6rem 0.8rem; font-size: 0.52rem; line-height: 1.6; white-space: pre; overflow: hidden; }
.intro { margin-top: 0.75rem; font-size: 0.8rem; line-height: 1.5; color: #4a5568; }
.sw-enter-active, .sw-leave-active { transition: all 0.25s ease; }
.sw-enter-from { opacity: 0; transform: translateY(8px); }
.sw-leave-to { opacity: 0; }
</style>

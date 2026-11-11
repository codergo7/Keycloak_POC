<script setup lang="ts">
// One browser request (alice → app.localhost/api/headers) through the ingress gateway
// and the Spring sidecar, filter by filter: ext_authz (AuthorizationPolicy CUSTOM),
// jwt_authn (RequestAuthentication), rbac (AuthorizationPolicy ALLOW), router (VirtualService).
// The sidecar's jwt_authn decodes the token and stores its claims; rbac then reads them.
// Click 11 repeats the request as bob, who has no developer role. Click 12 shows how the setup
// grows: more backends, each with its own sidecar and its own RequestAuthentication +
// AuthorizationPolicy pair, behind the same gateway. The slide needs `clicks: 12`.
// Token values (alg, kid, roles, aud) were taken from a real token of the running POC.
//
// mode="api": a script calls api.localhost/api/user with alice's token in Authorization: Bearer.
// ext_authz is not called, the gateway's jwt_authn validates the token and its rbac requires a
// principal, the router removes a fake X-Auth-Request-User header, and the sidecar checks the
// audience and the role. Clicks 8–10: no token (403 at the gateway), a tampered token (401 at
// the gateway), and /api/admin (403 at the sidecar). That slide needs `clicks: 10`.
// Every result was checked with curl against the running POC.
import { computed } from 'vue'
import { useSlideContext } from '@slidev/client'

const props = withDefaults(defineProps<{ mode?: 'browser' | 'api' }>(), { mode: 'browser' })
const api = computed(() => props.mode === 'api')

const { $clicks } = useSlideContext()
const s = computed(() => Math.min(Math.max($clicks.value, 0), api.value ? 10 : 12))
const bob = computed(() => !api.value && s.value === 11)
const more = computed(() => !api.value && s.value === 12)

// click 12: the other backends, each with its own pair of resources
const backends = [
  { ns: 'reports-api', app: 'FastAPI', ra: 'reports-jwt', aud: 'reports-api', ap: 'reports-authorization', claim: 'client roles' },
  { ns: 'x-api', app: 'x-api', sub: 'any language', ra: 'x-jwt', aud: 'x-api', ap: 'x-authorization', claim: 'client roles', isNew: true },
]

interface Filter { f: string; res: string; act?: string; ok: string }
const ingress: Filter[] = [
  { f: 'ext_authz', res: 'AuthorizationPolicy', act: 'CUSTOM', ok: '200 ✓' },
  { f: 'jwt_authn', res: 'RequestAuthentication', ok: 'no token' },
  { f: 'rbac', res: 'AuthorizationPolicy', act: 'ALLOW', ok: 'ALLOW ✓' },
  { f: 'router', res: 'VirtualService', ok: '− cookie' },
]
const sidecar: Filter[] = [
  { f: 'jwt_authn', res: 'RequestAuthentication', ok: 'valid ✓' },
  { f: 'rbac', res: 'AuthorizationPolicy', act: 'ALLOW', ok: 'ALLOW ✓' },
]
// which stage is active at each click (0–3 ingress, 4–5 sidecar, 6 the app)
const ACTIVE = [-1, 0, 1, 2, 3, 4, 4, 4, 4, 5, 6, 5, 6]

function state(i: number) {
  if (api.value) return apiState(i)
  if (bob.value) return i < 5 ? 'done' : i === 5 ? 'fail' : 'todo'
  const a = ACTIVE[s.value]
  if (a < 0 || i > a) return 'todo'
  return i === a ? 'on' : 'done'
}
function verdict(i: number, f: Filter) {
  if (api.value) return apiVerdict(i)
  if (state(i) === 'fail') return '✕ 403'
  if (i === 4 && s.value >= 5 && s.value <= 7) return 'decoding…'
  return f.ok
}

const user = computed(() => (bob.value ? 'bob' : 'alice'))
const sub = computed(() => (bob.value ? 'bfa3d087…' : '170b145d…'))
const roles = computed(() => (bob.value ? ['user'] : ['developer', 'user']))

const headers = computed(() => api.value ? apiHeaders.value : [
  { k: 'GET', v: '/api/headers', show: true },
  { k: 'Host', v: 'app.localhost', show: true },
  { k: 'Cookie', v: '_oauth2_proxy=…', show: true, gone: s.value >= 4 },
  { k: 'X-Auth-Request-User', v: user.value, show: s.value >= 1, fresh: s.value === 1 },
  { k: 'X-Auth-Request-Access-Token', v: 'eyJhbGciOiJSUzI1NiIs…', show: s.value >= 1, fresh: s.value === 1, hl: s.value === 5 },
])

// col 2: what happens inside the filter
const view = computed(() => {
  const v = s.value
  if (api.value) return v === 0 ? 'intro' : 'api'
  if (v === 0) return 'intro'
  if (v === 1) return 'ext'
  if (v === 2) return 'nojwt'
  if (v === 3) return 'rbacin'
  if (v === 4) return 'router'
  if (v <= 8) return 'decode'
  return 'claims'
})

// col 3: the Istio resource that configures the active filter
type Line = { t: string; hl?: boolean; mark?: '✓' | '✕' }
const yaml = computed<{ file: string; lines: Line[] } | null>(() => {
  const v = s.value
  if (api.value) return apiStep.value.yaml ?? null
  if (v === 1) return { file: 'ingress-authorization.yaml', lines: [
    { t: 'kind: AuthorizationPolicy' },
    { t: 'metadata: { name: oauth2-external-auth }' },
    { t: 'spec:' },
    { t: '  action: CUSTOM', hl: true },
    { t: '  provider: { name: oauth2-proxy }', hl: true },
    { t: '  rules:' },
    { t: '  - to:' },
    { t: '    - operation:' },
    { t: '        hosts: [app.localhost]', hl: true, mark: '✓' },
    { t: '        notPaths: [/oauth2/*, /api/public, …]' },
  ] }
  if (v === 2) return { file: 'ingress-authorization.yaml', lines: [
    { t: 'kind: RequestAuthentication' },
    { t: 'metadata: { name: demo-jwt-validation }' },
    { t: 'spec:' },
    { t: '  jwtRules:' },
    { t: '  - issuer: http://keycloak.localhost:8080/realms/demo' },
    { t: '    jwksUri: …/realms/demo/protocol/openid-connect/certs' },
    { t: '    # no fromHeaders: only Authorization: Bearer', hl: true },
  ] }
  if (v === 3) return { file: 'ingress-authorization.yaml', lines: [
    { t: 'kind: AuthorizationPolicy' },
    { t: 'metadata: { name: ingress-authorization }' },
    { t: 'spec:' },
    { t: '  action: ALLOW', hl: true },
    { t: '  rules:' },
    { t: '  - to: [{ operation: { hosts: [keycloak.localhost] } }]' },
    { t: '  - to: [{ operation: { hosts: [app.localhost] } }]', hl: true, mark: '✓' },
    { t: '  - from: [{ source: { requestPrincipals: ["*"] } }]' },
    { t: '    to: [{ operation: { hosts: [api.localhost], … } }]' },
  ] }
  if (v === 4) return { file: 'oauth2-proxy.yaml', lines: [
    { t: 'kind: VirtualService' },
    { t: 'spec:' },
    { t: '  hosts: [app.localhost]' },
    { t: '  http:' },
    { t: '  - route:' },
    { t: '    - destination: { host: spring-app.spring-api… }' },
    { t: '    headers:' },
    { t: '      request:' },
    { t: '        remove: [cookie]', hl: true, mark: '✓' },
  ] }
  if (v >= 5 && v <= 8) return { file: 'auth-app.yaml', lines: [
    { t: 'kind: RequestAuthentication' },
    { t: 'metadata: { name: keycloak-jwt }' },
    { t: 'spec:' },
    { t: '  selector: { matchLabels: { app: spring-app } }' },
    { t: '  jwtRules:' },
    { t: '  - issuer: http://keycloak.localhost:8080/realms/demo', hl: v === 7, mark: v >= 7 ? '✓' : undefined },
    { t: '    jwksUri: …/realms/demo/protocol/openid-connect/certs', hl: v === 6, mark: v >= 6 ? '✓' : undefined },
    { t: '    audiences: [spring-api]', hl: v === 7, mark: v >= 7 ? '✓' : undefined },
    { t: '    fromHeaders:', hl: v === 5 },
    { t: '    - name: Authorization   # prefix "Bearer "', hl: v === 5 },
    { t: '    - name: X-Auth-Request-Access-Token', hl: v === 5, mark: '✓' },
  ] }
  if (v === 9 || v === 11) return { file: 'auth-app.yaml', lines: [
    { t: 'kind: AuthorizationPolicy' },
    { t: 'metadata: { name: spring-workload-authorization }' },
    { t: 'spec:' },
    { t: '  action: ALLOW' },
    { t: '  rules:' },
    { t: '  - from:' },
    { t: '    - source:' },
    { t: '        requestPrincipals: ["*"]', hl: true, mark: '✓' },
    { t: '    to:' },
    { t: '    - operation: { methods: [GET], paths: [/api/headers] }', hl: true, mark: '✓' },
    { t: '    when:' },
    { t: '    - key: request.auth.claims[realm_access][roles]', hl: true },
    { t: '      values: ["developer"]', hl: true, mark: v === 11 ? '✕' : '✓' },
  ] }
  return null
})

const caption = computed(() => api.value ? apiStep.value.cap : [
  'alice’s browser sends GET app.localhost/api/headers with her session cookie. Two Envoy proxies check it before Spring sees it.',
  'ext_authz: the CUSTOM policy makes Envoy pause the request and ask OAuth2-Proxy. It answers 200 and adds the identity headers.',
  'jwt_authn at the gateway: no Authorization: Bearer header, so there is nothing to validate. A missing token is not an error.',
  'rbac at the gateway: the ALLOW policy has a rule for app.localhost, so the request may pass. OAuth2-Proxy already checked the user.',
  'router: the VirtualService removes the cookie and the request goes over mTLS to the Spring pod.',
  'jwt_authn at the sidecar: RequestAuthentication finds the token in X-Auth-Request-Access-Token.',
  'It decodes the header, finds the key with the same kid in Keycloak’s JWKS, and verifies the RS256 signature.',
  'It decodes the payload and checks the issuer, the expiry and the audience spring-api.',
  'It stores the result for the next filter: the principal (iss/sub) and the claims, as request.auth.claims.',
  'rbac at the sidecar: the ALLOW policy reads request.auth.claims. The rule for /api/headers needs the role developer, and alice has it.',
  'Spring receives the request with the identity headers and answers 200. It contains no token or login code.',
  'Same request as bob: the token is valid, but his roles are only ["user"]. No ALLOW rule matches, so the sidecar answers 403.',
  'Adding a backend: a namespace with a sidecar, one RequestAuthentication and one AuthorizationPolicy, and a route. The gateway and Keycloak stay the same.',
][s.value])

// ---------------------------------------------------------------- mode="api"
type Item =
  | { c: 'call'; cls: string; t: string }
  | { c: 'part'; cls: string; tag: string; rows: [string, string, string?, ('bad' | 'note')?][] }
interface ApiStep {
  a: number                       // active stage (0–5 filters, 6 the app), -1 none
  fail?: number; failText?: string // stage that rejects the request
  v?: Record<number, string>      // verdict overrides
  path: string; auth: 'ok' | 'none' | 'bad'; spoof: boolean
  col2: Item[]; p?: string; pBad?: boolean
  yaml?: { file: string; lines: Line[] }
  cap: string
}
const ISS = '…/realms/demo'
const SUB = '…/realms/demo/170b145d…'
const yGwRa = (bad = false): { file: string; lines: Line[] } => ({ file: 'ingress-authorization.yaml', lines: [
  { t: 'kind: RequestAuthentication' },
  { t: 'metadata: { name: demo-jwt-validation }' },
  { t: 'spec:' },
  { t: '  jwtRules:' },
  { t: '  - issuer: http://keycloak.localhost:8080/realms/demo', hl: !bad, mark: bad ? undefined : '✓' },
  { t: '    jwksUri: …/realms/demo/protocol/openid-connect/certs', hl: true, mark: bad ? '✕' : '✓' },
  { t: '    forwardOriginalToken: true' },
  { t: '    # no audiences: any token of the realm', hl: !bad },
  { t: '    # no fromHeaders: Authorization: Bearer only' },
] })
const yGwAp = (ok: boolean): { file: string; lines: Line[] } => ({ file: 'ingress-authorization.yaml', lines: [
  { t: 'kind: AuthorizationPolicy' },
  { t: 'metadata: { name: ingress-authorization }' },
  { t: 'spec:' },
  { t: '  action: ALLOW' },
  { t: '  rules:' },
  { t: '  # JWT-authenticated API requests' },
  { t: '  - from:' },
  { t: '    - source: { requestPrincipals: ["*"] }', hl: true, mark: ok ? '✓' : '✕' },
  { t: '    to:' },
  { t: '    - operation:' },
  { t: '        hosts: [api.localhost]', hl: ok, mark: ok ? '✓' : undefined },
  { t: '        paths: [/api/user, /api/whoami, …]', hl: ok, mark: ok ? '✓' : undefined },
] })
const yScAp = (admin: boolean): { file: string; lines: Line[] } => ({ file: 'auth-app.yaml', lines: [
  { t: 'kind: AuthorizationPolicy' },
  { t: 'metadata: { name: spring-workload-authorization }' },
  { t: 'spec:' },
  { t: '  action: ALLOW' },
  { t: '  rules:' },
  { t: admin ? '  # Admin role' : '  # User role' },
  { t: '  - from: [{ source: { requestPrincipals: ["*"] } }]', hl: true, mark: '✓' },
  { t: '    to:' },
  { t: admin ? '    - operation: { methods: [GET], paths: [/api/admin] }' : '    - operation: { methods: [GET], paths: [/api/user, …] }', hl: true, mark: '✓' },
  { t: '    when:' },
  { t: '    - key: request.auth.claims[realm_access][roles]', hl: true },
  { t: admin ? '      values: ["admin"]' : '      values: ["user"]', hl: true, mark: admin ? '✕' : '✓' },
] })

const API: ApiStep[] = [
  { a: -1, path: '/api/user', auth: 'ok', spoof: true, col2: [],
    cap: 'A script sends GET api.localhost/api/user with alice’s token in Authorization: Bearer. It also sends a fake X-Auth-Request-User: admin header.' },
  { a: 0, path: '/api/user', auth: 'ok', spoof: true,
    col2: [{ c: 'call', cls: 'muted', t: 'CUSTOM rule: hosts [app.localhost] ✕ api.localhost' }],
    p: 'The request does not match the rule, so Envoy skips ext_authz. OAuth2-Proxy is only for browsers; an API client brings its own token.',
    yaml: { file: 'ingress-authorization.yaml', lines: [
      { t: 'kind: AuthorizationPolicy' },
      { t: 'metadata: { name: oauth2-external-auth }' },
      { t: 'spec:' },
      { t: '  action: CUSTOM' },
      { t: '  provider: { name: oauth2-proxy }' },
      { t: '  rules:' },
      { t: '  - to:' },
      { t: '    - operation:' },
      { t: '        hosts: [app.localhost]', hl: true, mark: '✕' },
    ] },
    cap: 'ext_authz: the CUSTOM policy only matches app.localhost, so OAuth2-Proxy is not called.' },
  { a: 1, path: '/api/user', auth: 'ok', spoof: true,
    col2: [
      { c: 'part', cls: 'h', tag: 'header', rows: [['alg · kid', 'RS256 · UHlGaDFC…'], ['JWKS key', 'UHlGaDFC…', 'signature ✓']] },
      { c: 'part', cls: 'p', tag: 'payload', rows: [['iss', ISS, '✓'], ['exp', 'not expired', '✓'], ['aud', 'spring-api', 'not checked here', 'note']] },
      { c: 'part', cls: 'out', tag: 'stored for rbac', rows: [['principal', SUB]] },
    ],
    yaml: yGwRa(),
    cap: 'jwt_authn at the gateway: RequestAuthentication finds the Bearer token, verifies the signature with Keycloak’s JWKS, checks the issuer and the expiry, and sets the principal.' },
  { a: 2, path: '/api/user', auth: 'ok', spoof: true,
    col2: [{ c: 'call', cls: 'ok', t: 'principal set · rule "JWT-authenticated API requests" · ALLOW' }],
    p: 'For api.localhost the gateway requires a valid token. It does not look at roles yet: that happens next to each API.',
    yaml: yGwAp(true),
    cap: 'rbac at the gateway: the ALLOW rule for api.localhost needs a principal, and the token gave one.' },
  { a: 3, path: '/api/user', auth: 'ok', spoof: true,
    col2: [
      { c: 'call', cls: 'bad', t: 'X-Auth-Request-User: admin · removed' },
      { c: 'call', cls: 'ok', t: 'Authorization kept · → spring-app:8080' },
    ],
    p: 'api.localhost has no ext_authz, so any X-Auth-Request header must come from the client. The VirtualService removes them before Spring could trust them.',
    yaml: { file: 'app.yaml', lines: [
      { t: 'kind: VirtualService' },
      { t: 'metadata: { name: api }' },
      { t: 'spec:' },
      { t: '  hosts: [api.localhost]' },
      { t: '  http:' },
      { t: '  - route: [{ destination: { host: spring-app… } }]' },
      { t: '    headers:' },
      { t: '      request:' },
      { t: '        remove:' },
      { t: '        - x-auth-request-user', hl: true, mark: '✓' },
      { t: '        - x-auth-request-email', hl: true },
      { t: '        - x-auth-request-access-token, …', hl: true },
    ] },
    cap: 'router: the VirtualService removes the fake identity header and sends the request over mTLS to the Spring pod.' },
  { a: 4, path: '/api/user', auth: 'ok', spoof: false,
    col2: [
      { c: 'part', cls: 'p', tag: 'checked again', rows: [['signature', 'JWKS key UHlGaDFC…', '✓'], ['iss', ISS, '✓'], ['aud', 'spring-api', '✓']] },
      { c: 'part', cls: 'out', tag: 'stored for rbac', rows: [['principal', SUB], ['request.auth.claims', 'the payload']] },
    ],
    p: 'The audience is checked here, by the API the token was issued for.',
    yaml: { file: 'auth-app.yaml', lines: [
      { t: 'kind: RequestAuthentication' },
      { t: 'metadata: { name: keycloak-jwt }' },
      { t: 'spec:' },
      { t: '  selector: { matchLabels: { app: spring-app } }' },
      { t: '  jwtRules:' },
      { t: '  - issuer: http://keycloak.localhost:8080/realms/demo', hl: true, mark: '✓' },
      { t: '    jwksUri: …/realms/demo/protocol/openid-connect/certs', mark: '✓' },
      { t: '    audiences: [spring-api]', hl: true, mark: '✓' },
      { t: '    fromHeaders:' },
      { t: '    - name: Authorization   # prefix "Bearer "', hl: true, mark: '✓' },
      { t: '    - name: X-Auth-Request-Access-Token' },
    ] },
    cap: 'jwt_authn at the sidecar: keycloak-jwt reads the same token from Authorization, verifies it again, and checks the audience spring-api.' },
  { a: 5, path: '/api/user', auth: 'ok', spoof: false,
    col2: [{ c: 'part', cls: 'out', tag: 'from jwt_authn', rows: [['principal', SUB, '✓'], ['claims.realm_access.roles', '["developer", "user"]', 'user ✓']] }],
    yaml: yScAp(false),
    cap: 'rbac at the sidecar: the rule for /api/user needs the realm role user, and alice has it.' },
  { a: 6, path: '/api/user', auth: 'ok', spoof: false,
    col2: [{ c: 'call', cls: 'ok', t: '← 200 OK from Spring' }],
    p: 'Spring never saw the fake header, and it did not verify the token itself: two Envoy proxies did that.',
    cap: 'Spring receives the request and answers 200.' },
  { a: 2, fail: 2, failText: '✕ 403', v: { 1: 'no token' }, path: '/api/user', auth: 'none', spoof: false,
    col2: [
      { c: 'call', cls: 'muted', t: 'Authorization: (none) · no principal' },
      { c: 'call', cls: 'bad', t: '← 403 RBAC: access denied' },
    ],
    p: 'A missing token is not a bad token, so RequestAuthentication lets the request pass. But without a principal, no ALLOW rule for /api/user matches.',
    yaml: yGwAp(false),
    cap: 'No token: jwt_authn has nothing to check, so there is no principal. The gateway’s ALLOW policy answers 403.' },
  { a: 1, fail: 1, failText: '✕ 401', path: '/api/user', auth: 'bad', spoof: false,
    col2: [
      { c: 'call', cls: 'bad', t: 'signature does not match the JWKS key' },
      { c: 'call', cls: 'bad', t: '← 401 Jwt verification fails' },
    ],
    p: 'One changed character breaks the signature. The request stops at the first jwt_authn filter, and no AuthorizationPolicy is reached.',
    yaml: yGwRa(true),
    cap: 'Tampered token: the signature check fails, so the gateway answers 401.' },
  { a: 5, fail: 5, failText: '✕ 403', path: '/api/admin', auth: 'ok', spoof: false,
    col2: [{ c: 'part', cls: 'out', tag: 'from jwt_authn', rows: [['principal', SUB, '✓'], ['claims.realm_access.roles', '["developer", "user"]', 'no admin ✕', 'bad']] }],
    p: '403 from the sidecar: the gateway let the request in, because the role is checked next to the API.', pBad: true,
    yaml: yScAp(true),
    cap: 'alice calls /api/admin: the token is valid and passes the gateway, but she has no admin role. The sidecar answers 403.' },
]
const apiStep = computed(() => API[s.value])
const apiFail = computed(() => api.value && apiStep.value.fail !== undefined)
const API_OK = ['not called', 'valid ✓', 'ALLOW ✓', '− x-auth-*', 'aud ✓', 'ALLOW ✓']

function apiState(i: number) {
  const st = apiStep.value
  const passed = i === 0 ? 'skip' : 'done'
  if (st.fail !== undefined) return i < st.fail ? passed : i === st.fail ? 'fail' : 'todo'
  if (st.a < 0 || i > st.a) return 'todo'
  return i === st.a ? 'on' : passed
}
function apiVerdict(i: number) {
  const st = apiStep.value
  if (apiState(i) === 'fail') return st.failText
  return st.v?.[i] ?? API_OK[i]
}
const apiHeaders = computed(() => {
  const st = apiStep.value
  const h: { k: string; v: string; show: boolean; gone?: boolean; fresh?: boolean; hl?: boolean; fake?: boolean; tag?: string }[] = [
    { k: 'GET', v: st.path, show: true },
    { k: 'Host', v: 'api.localhost', show: true },
  ]
  if (st.auth === 'ok') h.push({ k: 'Authorization', v: 'Bearer eyJhbGciOiJSUzI1NiIs…', show: true, hl: s.value === 2 || s.value === 5 })
  if (st.auth === 'bad') h.push({ k: 'Authorization', v: 'Bearer eyJhbGci…FH-WYO48kC3A5ctsX', show: true, fake: true })
  if (st.spoof || (s.value >= 4 && s.value <= 7)) h.push({ k: 'X-Auth-Request-User', v: 'admin', show: true, fake: true, gone: s.value >= 4,
    tag: s.value >= 4 ? 'removed by the router' : 'fake · sent by the client, not by OAuth2-Proxy' })
  return h
})

// shared by both modes
const sidecarReached = computed(() => {
  if (!api.value) return s.value >= 5
  const st = apiStep.value
  return st.fail !== undefined ? st.fail >= 4 : st.a >= 4
})
const appOn = computed(() => (api.value ? s.value === 7 : s.value === 10))
const appOff = computed(() => (api.value ? apiFail.value : bob.value))
</script>

<template>
  <div class="ei">
    <!-- the pipeline -->
    <div class="pipe">
      <div class="end" :class="{ on: s === 0 }">
        <div class="end-name">{{ api ? 'Script' : 'Browser' }}</div><small>{{ api ? 'curl · alice' : user }}</small>
      </div>
      <div class="link" :class="{ lit: s >= 1 }"><span /></div>

      <div class="proxy gw">
        <div class="proxy-label">Ingress gateway <span>· Envoy · istio-system</span></div>
        <div class="filters">
          <div v-for="(f, i) in ingress" :key="'g' + i" class="pill" :class="state(i)">
            <i v-if="state(i) === 'on'" :key="'p' + s" class="packet" />
            <div class="f">{{ f.f }}<b v-if="f.act" class="act">{{ f.act }}</b></div>
            <div class="res">{{ f.res }}</div>
            <div class="verdict">{{ verdict(i, f) }}</div>
          </div>
        </div>
        <div class="ext" :class="api ? 'off' : { on: s === 1, done: s > 1 }">
          <span class="ext-arrow">⇅</span> OAuth2-Proxy <small>external authorizer</small>
        </div>
        <Transition name="grow">
          <div v-if="more" class="routes">
            <b>router · VirtualService</b> one route per backend
            <div class="steps">
              <div><i>1</i> Keycloak client + audience scope</div>
              <div><i>2</i> namespace with <span class="mono">istio-injection: enabled</span></div>
              <div><i>3</i> RequestAuthentication + AuthorizationPolicy</div>
              <div><i>4</i> a route in the VirtualService</div>
            </div>
          </div>
        </Transition>
      </div>

      <div class="right">
      <div class="row">
      <div class="link" :class="{ lit: sidecarReached }"><span /><em>mTLS</em></div>

      <div class="proxy sc">
        <div class="proxy-label">Sidecar <span>· Envoy · spring-api</span></div>
        <div class="filters">
          <div v-for="(f, i) in sidecar" :key="'s' + i" class="pill" :class="state(i + 4)">
            <i v-if="state(i + 4) === 'on'" :key="'p' + s" class="packet" />
            <div class="f">{{ f.f }}<b v-if="f.act" class="act">{{ f.act }}</b></div>
            <div class="res">{{ f.res }}</div>
            <div class="verdict">{{ verdict(i + 4, f) }}</div>
          </div>
        </div>
        <div class="ext" :class="api ? { on: s === 5, done: sidecarReached && s > 5 } : { on: s === 6, done: s > 6 }">
          <span class="ext-arrow">⤓</span> JWKS <small>public keys, via istiod</small>
        </div>
      </div>

      <div class="link" :class="{ lit: appOn }"><span /></div>
      <div class="end app" :class="{ on: appOn, off: appOff }">
        <div class="end-name">Spring</div><small>{{ appOn ? '200 OK' : appOff ? 'not reached' : ':8080' }}</small>
      </div>
      </div>

      <!-- click 12: more backends behind the same gateway -->
      <TransitionGroup name="grow">
        <div v-for="(b, k) in (more ? backends : [])" :key="b.ns" class="row extra" :class="{ isnew: b.isNew }"
          :style="{ transitionDelay: k * 0.35 + 's' }">
          <div class="link lit branch"><span /><em>mTLS</em></div>
          <div class="proxy sc">
            <div class="proxy-label">Sidecar <span>· Envoy · {{ b.ns }}</span><b v-if="b.isNew" class="newtag">new</b></div>
            <div class="filters">
              <div class="pill done">
                <div class="f">jwt_authn</div>
                <div class="res">RequestAuthentication</div>
                <div class="rname">{{ b.ra }}</div>
                <div class="verdict">aud {{ b.aud }}</div>
              </div>
              <div class="pill done">
                <div class="f">rbac<b class="act">ALLOW</b></div>
                <div class="res">AuthorizationPolicy</div>
                <div class="rname">{{ b.ap }}</div>
                <div class="verdict">{{ b.claim }}</div>
              </div>
            </div>
          </div>
          <div class="link lit"><span /></div>
          <div class="end app"><div class="end-name">{{ b.app }}</div><small>{{ b.sub || ':8080' }}</small></div>
        </div>
        <div v-if="more" key="dots" class="row dots" style="transition-delay: 0.7s">
          <span>⋮</span> the next backend: the same pair
        </div>
      </TransitionGroup>
      </div>
    </div>

    <!-- the detail -->
    <div v-if="!more" class="detail">
      <!-- col 1: the request -->
      <div class="col">
        <div class="col-title">The request</div>
        <div class="req">
          <TransitionGroup name="hdr">
            <div v-for="h in headers.filter(h => h.show)" :key="h.k" class="hdr"
              :class="{ gone: h.gone, fresh: h.fresh, hl: h.hl, fake: h.fake }">
              <span class="k">{{ h.k }}:</span> <span class="v">{{ h.v }}</span>
              <em v-if="h.tag" class="htag">{{ h.tag }}</em>
            </div>
          </TransitionGroup>
        </div>
      </div>

      <!-- col 2: inside the filter -->
      <div class="col">
        <div class="col-title">Inside the filter</div>
        <Transition name="view" mode="out-in">
          <div v-if="view === 'intro'" key="intro" class="hint">
            <template v-if="api">No browser, no cookie: the script brings its own token. Click to follow it through the same filters.</template>
            <template v-else>Each Istio resource becomes an Envoy filter. Click to follow the request through every filter.</template>
          </div>

          <div v-else-if="view === 'ext'" key="ext" class="box">
            <div class="call out">→ OAuth2-Proxy: GET /api/headers + Cookie</div>
            <div class="call back">← <b>200</b> + X-Auth-Request-User, -Email, -Access-Token</div>
            <p>OAuth2-Proxy decrypts the cookie; it does not call Keycloak. Envoy copies the allowed headers into the request (<span class="mono">headersToUpstreamOnAllow</span>).</p>
          </div>

          <div v-else-if="view === 'nojwt'" key="nojwt" class="box">
            <div class="call muted">Authorization: <i>(none)</i></div>
            <p>Nothing to validate, so no principal is set and the request continues. RequestAuthentication only <b>rejects bad tokens</b>; it never requires one.</p>
          </div>

          <div v-else-if="view === 'rbacin'" key="rbacin" class="box">
            <div class="call ok">rule 2 matches · ALLOW</div>
            <p>The gateway does not look at claims for app.localhost. The CUSTOM check has already authenticated the browser.</p>
          </div>

          <div v-else-if="view === 'router'" key="router" class="box">
            <div class="call ok">Cookie removed · → spring-app:8080</div>
            <p>The VirtualService header rules run last, in the router. Spring never sees the session cookie.</p>
          </div>

          <div v-else-if="view === 'decode'" key="decode" class="box decode">
            <div class="jwt" :class="{ split: s >= 6, scan: s === 5 }">
              <span class="seg h">eyJhbGciOiJSUzI1NiIs…</span><span class="dot">.</span><span class="seg p">eyJleHAiOjE3OTQz…</span><span class="dot">.</span><span class="seg sig">QtWjd_fIzyiPmkBe…</span>
            </div>
            <div v-if="s >= 6" class="part h">
              <span class="tag">header</span> alg: RS256 · kid: UHlGaDFC…
              <div class="match">kid = JWKS key UHlGaDFC… → <b>signature ✓</b></div>
            </div>
            <div v-if="s >= 7" class="part p">
              <span class="tag">payload</span>
              <div class="claim"><span>iss</span> …/realms/demo <b>✓</b></div>
              <div class="claim"><span>aud</span> spring-api <b>✓</b></div>
              <div class="claim"><span>exp</span> 12:15:25, not expired <b>✓</b></div>
              <div class="claim"><span>realm_access.roles</span> ["developer", "user"]</div>
            </div>
            <div v-if="s >= 8" class="part out">
              <span class="tag">stored for rbac</span>
              <div class="claim"><span>principal</span> …/realms/demo/170b145d…</div>
              <div class="claim"><span>request.auth.claims</span> the payload above</div>
            </div>
          </div>

          <div v-else-if="view === 'api'" :key="'api' + s" class="box decode">
            <template v-for="(it, k) in apiStep.col2" :key="k">
              <div v-if="it.c === 'call'" class="call" :class="it.cls">{{ it.t }}</div>
              <div v-else class="part" :class="it.cls">
                <span class="tag">{{ it.tag }}</span>
                <div v-for="r in it.rows" :key="r[0]" class="claim"><span>{{ r[0] }}</span> {{ r[1] }} <b v-if="r[2]" :class="r[3] || 'okc'">{{ r[2] }}</b></div>
              </div>
            </template>
            <p v-if="apiStep.p" :class="{ badp: apiStep.pBad }">{{ apiStep.p }}</p>
          </div>

          <div v-else key="claims" class="box decode">
            <div class="part out">
              <span class="tag">from jwt_authn</span>
              <div class="claim"><span>principal</span> …/realms/demo/{{ sub }} <b class="okc">✓</b></div>
              <div class="claim"><span>claims.preferred_username</span> {{ user }}</div>
              <div class="claim"><span>claims.aud</span> spring-api</div>
              <div class="claim roles"><span>claims.realm_access.roles</span>
                [<template v-for="(r, i) in roles" :key="r"><em :class="{ hit: r === 'developer' && s === 9 }">"{{ r }}"</em><template v-if="i < roles.length - 1">, </template></template>]
                <b v-if="s === 9" class="okc">developer ✓</b>
                <b v-if="bob" class="bad">no developer ✕</b>
              </div>
            </div>
            <p v-if="s === 10">Spring reads <span class="mono">X-Auth-Request-User</span>. It never parses the token.</p>
            <p v-if="bob" class="badp">403 RBAC: access denied, from the sidecar. The token was valid; the claim was missing.</p>
          </div>
        </Transition>
      </div>

      <!-- col 3: the Istio resource -->
      <div class="col">
        <div class="col-title">The Istio resource <span v-if="yaml" class="file">{{ yaml.file }}</span></div>
        <Transition name="view" mode="out-in">
          <div v-if="yaml" :key="yaml.lines[1].t" class="yaml">
            <div v-for="(l, i) in yaml.lines" :key="i" class="yl" :class="{ hl: l.hl }">
              <span>{{ l.t }}</span><b v-if="l.mark" :class="l.mark === '✕' ? 'bad' : 'okc'">{{ l.mark }}</b>
            </div>
          </div>
          <div v-else-if="appOn" key="app" class="hint">
            No Istio resource here: the request has passed every filter. <b>200 OK.</b>
          </div>
          <div v-else key="none" class="hint">The resource that configures the active filter appears here.</div>
        </Transition>
      </div>
    </div>

    <Transition name="cap" mode="out-in">
      <div :key="s" class="caption" :class="{ bad: bob || apiFail }"><b>{{ s }}</b> {{ caption }}</div>
    </Transition>
  </div>
</template>

<style scoped>
.ei { --navy: #14213d; --blue: #2459c9; --orange: #c2570c; --green: #1f8a5b; --red: #c0352b; --muted: #7a8496; }
.mono { font-family: 'JetBrains Mono', monospace; }

/* pipeline */
.pipe { display: flex; align-items: stretch; gap: 0; }
.end {
  flex: none; width: 70px; border-radius: 10px; background: #e6eaf2; display: flex; flex-direction: column;
  justify-content: center; align-items: center; transition: all 0.4s;
}
.end-name { font-weight: 700; font-size: 0.8rem; color: var(--navy); }
.end small { font: 500 0.55rem 'JetBrains Mono', monospace; color: var(--muted); }
.end.on { background: var(--navy); box-shadow: 0 0 0 4px rgba(36, 89, 201, 0.25); }
.end.on .end-name, .end.on small { color: #fff; }
.end.app.on { background: var(--green); box-shadow: 0 0 0 4px rgba(31, 138, 91, 0.25); }
.end.off { opacity: 0.35; }

.link { flex: none; width: 26px; position: relative; display: flex; align-items: center; }
.link span { display: block; width: 100%; height: 2px; background: #d5d9e2; position: relative; overflow: hidden; }
.link span::after {
  content: ''; position: absolute; inset: 0; background: var(--blue); transform: translateX(-100%);
  transition: transform 0.5s ease-out;
}
.link.lit span::after { transform: translateX(0); }
.link em { position: absolute; top: 34%; left: 50%; transform: translateX(-50%); font: 600 0.45rem 'JetBrains Mono', monospace; color: var(--muted); font-style: normal; }

.proxy { flex: 1; min-width: 0; border: 1.5px dashed #b8c3d8; border-radius: 12px; padding: 0.3rem 0.4rem 0.35rem; background: rgba(255, 255, 255, 0.55); }
.proxy.gw { flex: 2.2; }
.proxy.sc { flex: 1.25; }
.proxy-label { font: 700 0.58rem 'JetBrains Mono', monospace; text-transform: uppercase; letter-spacing: 0.06em; color: var(--navy); margin-bottom: 0.25rem; }
.proxy-label span { color: var(--muted); font-weight: 500; text-transform: none; letter-spacing: 0; }
.filters { display: flex; gap: 0.3rem; }

.pill {
  position: relative; flex: 1; min-width: 0; border-radius: 9px; padding: 0.3rem 0.35rem 0.25rem;
  background: #fff; border: 1px solid #e6eaf2; transition: all 0.45s cubic-bezier(0.2, 0.7, 0.2, 1);
}
.pill .f { font: 700 0.7rem 'JetBrains Mono', monospace; color: var(--navy); }
.pill .res { font-size: 0.5rem; color: var(--muted); line-height: 1.25; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.pill .f { display: flex; align-items: center; justify-content: space-between; gap: 0.2rem; }
.pill .act { font: 700 0.46rem 'JetBrains Mono', monospace; color: #fff; background: var(--orange); border-radius: 4px; padding: 0.05rem 0.25rem; }
.pill .verdict {
  margin-top: 0.15rem; font: 700 0.52rem 'JetBrains Mono', monospace; color: var(--green);
  opacity: 0; transform: scale(0.6); transform-origin: left; transition: all 0.3s 0.35s;
}
.pill.todo { opacity: 0.45; }
.pill.on {
  background: var(--navy); border-color: var(--navy); transform: translateY(-3px);
  box-shadow: 0 10px 22px -10px rgba(20, 33, 61, 0.7);
  animation: ring 1.6s ease-out 0.5s infinite;
}
.pill.on .f { color: #fff; }
.pill.on .res { color: #aebbd6; }
.pill.on .verdict { color: #8de0b5; }
.pill.done { background: #e3ecfb; border-color: #e3ecfb; }
.pill.on .verdict, .pill.done .verdict, .pill.fail .verdict { opacity: 1; transform: scale(1); }
.pill.fail { background: #fbe4e1; border-color: var(--red); animation: shake 0.5s 0.2s; }
.pill.fail .verdict { color: var(--red); }
.packet {
  position: absolute; top: -5px; left: 0; width: 10px; height: 10px; border-radius: 50%; background: #f2a65a;
  box-shadow: 0 0 10px 3px rgba(242, 166, 90, 0.8); animation: enter 0.6s cubic-bezier(0.3, 0, 0.2, 1) forwards;
}
@keyframes enter { from { left: -30px; opacity: 0; } to { left: calc(50% - 5px); opacity: 1; } }
@keyframes ring { 0% { box-shadow: 0 0 0 0 rgba(36, 89, 201, 0.45); } 100% { box-shadow: 0 0 0 10px rgba(36, 89, 201, 0); } }
@keyframes shake { 25% { transform: translateX(-4px); } 50% { transform: translateX(4px); } 75% { transform: translateX(-2px); } }

.ext {
  margin-top: 0.3rem; font: 600 0.55rem 'JetBrains Mono', monospace; color: var(--muted); border-radius: 6px;
  padding: 0.1rem 0.4rem; border: 1px dashed #c5c4c1; display: inline-block; transition: all 0.4s; opacity: 0.6;
}
.ext small { font-weight: 400; }
.ext.on { background: var(--orange); border-color: var(--orange); color: #fff; opacity: 1; }
.ext.on .ext-arrow { display: inline-block; animation: bob 0.8s ease-in-out infinite; }
.ext.done { opacity: 0.8; border-style: solid; color: var(--orange); }
@keyframes bob { 50% { transform: translateY(-2px); } }

/* detail */
.detail { display: grid; grid-template-columns: 0.95fr 1.2fr 1.25fr; gap: 0.6rem; margin-top: 0.6rem; height: 208px; }
.col { min-width: 0; background: #fff; border: 1px solid #e6eaf2; border-radius: 10px; padding: 0.4rem 0.5rem; overflow: hidden; }
.col-title { font: 700 0.55rem 'JetBrains Mono', monospace; text-transform: uppercase; letter-spacing: 0.08em; color: var(--muted); margin-bottom: 0.3rem; }
.col-title .file { text-transform: none; letter-spacing: 0; color: var(--blue); font-weight: 500; margin-left: 0.3rem; }

.req { font: 0.56rem/1.45 'JetBrains Mono', monospace; }
.hdr { position: relative; padding: 0.12rem 0.25rem; border-radius: 4px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; transition: all 0.4s; }
.hdr .k { color: var(--navy); font-weight: 700; }
.hdr .v { color: #4a5568; }
.hdr.fresh { animation: flash 1.2s ease-out; }
.hdr.hl { background: #fde7cf; }
.hdr.gone { opacity: 0.45; }
.hdr.gone::after { content: ''; position: absolute; left: 0.25rem; right: 0.25rem; top: 50%; height: 1.5px; background: var(--red); animation: strike 0.5s ease-out both; }
@keyframes strike { from { right: 100%; } }
@keyframes flash { 0% { background: #c9f0dc; } 100% { background: transparent; } }
.hdr-enter-active { transition: all 0.45s ease-out; }
.hdr-enter-from { opacity: 0; transform: translateX(-16px); }

.hint { font-size: 0.68rem; color: var(--muted); line-height: 1.45; padding-top: 0.4rem; }
.box p { font-size: 0.62rem; line-height: 1.45; color: #4a5568; margin: 0.35rem 0 0; }
.call { font: 0.56rem/1.4 'JetBrains Mono', monospace; padding: 0.2rem 0.35rem; border-radius: 5px; margin-bottom: 0.2rem; }
.call.out { background: #fbe9dc; color: var(--orange); animation: slidein 0.45s ease-out both; }
.call.back { background: #e1f4ea; color: var(--green); animation: slidein 0.45s 0.5s ease-out both; }
.call.muted { background: #eef0f4; color: var(--muted); }
.call.ok { background: #e1f4ea; color: var(--green); font-weight: 700; }
@keyframes slidein { from { opacity: 0; transform: translateX(-12px); } }

.jwt { font: 600 0.55rem 'JetBrains Mono', monospace; white-space: nowrap; overflow: hidden; display: flex; align-items: center; }
.jwt .seg { padding: 0.12rem 0.2rem; border-radius: 4px; transition: all 0.5s; overflow: hidden; text-overflow: ellipsis; }
.jwt .seg.h { color: var(--orange); }
.jwt .seg.p { color: var(--blue); }
.jwt .seg.sig { color: var(--green); }
.jwt .dot { color: var(--muted); transition: margin 0.5s; }
.jwt.split .dot { margin: 0 0.25rem; }
.jwt.split .seg.h { background: #fbe9dc; }
.jwt.split .seg.p { background: #e3ecfb; }
.jwt.split .seg.sig { background: #e1f4ea; }
.jwt.scan { background: linear-gradient(90deg, transparent 0%, rgba(242, 166, 90, 0.35) 50%, transparent 100%) no-repeat; background-size: 30% 100%; animation: scan 1.2s linear infinite; }
@keyframes scan { from { background-position: -30% 0; } to { background-position: 130% 0; } }

.part { margin-top: 0.3rem; border-radius: 6px; padding: 0.2rem 0.35rem; font: 0.54rem/1.45 'JetBrains Mono', monospace; color: var(--navy); animation: drop 0.5s ease-out both; }
.part.h { background: #fbe9dc; }
.part.p { background: #e3ecfb; }
.part.out { background: #e1f4ea; }
.part .tag { display: inline-block; font-weight: 700; text-transform: uppercase; font-size: 0.48rem; letter-spacing: 0.06em; color: var(--muted); margin-right: 0.3rem; }
.match { color: var(--green); }
.claim span { color: var(--muted); margin-right: 0.3rem; }
.claim b, .okc { color: var(--green); }
.claim em { font-style: normal; transition: all 0.4s; border-radius: 3px; }
.claim em.hit { background: var(--green); color: #fff; padding: 0 0.15rem; animation: pop 0.5s 0.3s both; }
.bad { color: var(--red); }
.badp { color: var(--red) !important; font-weight: 600; }
@keyframes drop { from { opacity: 0; transform: translateY(-8px); } }
@keyframes pop { 0% { transform: scale(1); } 50% { transform: scale(1.25); } 100% { transform: scale(1); } }

.yaml { background: var(--navy); border-radius: 8px; padding: 0.35rem 0.2rem; font: 0.52rem/1.5 'JetBrains Mono', monospace; color: #c7d3ea; }
.yl { display: flex; justify-content: space-between; gap: 0.3rem; padding: 0 0.3rem; border-radius: 3px; white-space: pre; transition: background 0.4s; }
.yl span { overflow: hidden; text-overflow: ellipsis; }
.yl.hl { background: rgba(242, 166, 90, 0.22); color: #fff; }
.yl b { flex: none; animation: pop 0.5s 0.4s both; }
.yl b.okc { color: #8de0b5; }
.yl b.bad { color: #ff9c92; }

.caption { margin-top: 0.5rem; font-size: 0.72rem; line-height: 1.4; color: #1b2433; min-height: 2rem; }
.caption b { display: inline-block; min-width: 1.3rem; height: 1.3rem; line-height: 1.3rem; text-align: center; border-radius: 50%; background: var(--navy); color: #fff; font-size: 0.6rem; margin-right: 0.35rem; }
.caption.bad b { background: var(--red); }

.view-enter-active, .view-leave-active { transition: all 0.25s ease; }
.view-enter-from { opacity: 0; transform: translateY(8px); }
.view-leave-to { opacity: 0; }
.cap-enter-active, .cap-leave-active { transition: opacity 0.2s; }
.cap-enter-from, .cap-leave-to { opacity: 0; }

/* mode="api" */
.pill.skip { opacity: 0.45; background: transparent; border: 1px dashed #b8c3d8; }
.pill.skip .verdict { opacity: 1; transform: scale(1); color: var(--muted); }
.ext.off { opacity: 0.35; text-decoration: line-through; }
.hdr.fake .v { color: var(--red); font-weight: 700; }
.htag { display: block; font: italic 500 0.48rem 'Inter', sans-serif; color: var(--red); white-space: normal; }
.hdr.gone .htag { color: var(--muted); }
.hdr:has(.htag)::after { top: 0.55rem; }
.claim b.bad { color: var(--red); }
.claim b.note { color: var(--muted); font-weight: 500; }
.call.bad { background: #fbe4e1; color: var(--red); font-weight: 700; }

/* click 12: more backends */
.right { flex: 1.65; min-width: 0; display: flex; flex-direction: column; gap: 0.4rem; }
.row { display: flex; align-items: stretch; }
.right > .row:first-child .proxy.sc { flex: 1; }
.row .proxy.sc { flex: 1; }
.row.extra .proxy { background: rgba(255, 255, 255, 0.85); }
.row.extra.isnew .proxy { border: 2px dashed var(--orange); background: #fffaf6; }
.row.extra.isnew .pill.done { background: #fbe9dc; border-color: #fbe9dc; }
.row.extra .end.app { background: #def3e8; }
.row.extra.isnew .end.app { background: #fbe9dc; }
.rname { font: 600 0.5rem 'JetBrains Mono', monospace; color: var(--navy); overflow-wrap: anywhere; }
.newtag { font: 700 0.46rem 'JetBrains Mono', monospace; color: #fff; background: var(--orange); border-radius: 4px; padding: 0.05rem 0.25rem; margin-left: 0.3rem; text-transform: none; }
.link.branch span::before { content: ''; position: absolute; left: 0; top: -60px; width: 2px; height: 60px; background: var(--blue); }
.link.branch span { overflow: visible; background: var(--blue); }
.row.dots { font: 600 0.55rem 'JetBrains Mono', monospace; color: var(--muted); padding-left: 30px; align-items: center; gap: 0.4rem; }
.row.dots span { font-size: 1rem; color: var(--orange); }
.routes { margin-top: 0.6rem; width: 62%; border-radius: 8px; background: #fff; border: 1px solid #e6eaf2; padding: 0.35rem 0.45rem; font-size: 0.6rem; color: var(--muted); }
.routes > b { font: 700 0.6rem 'JetBrains Mono', monospace; color: var(--navy); margin-right: 0.3rem; }
.steps { margin-top: 0.35rem; display: grid; grid-template-columns: 1fr; gap: 0.3rem; color: #1b2433; font-size: 0.6rem; }
.steps i { font-style: normal; display: inline-block; width: 0.95rem; height: 0.95rem; line-height: 0.95rem; text-align: center; border-radius: 50%; background: var(--orange); color: #fff; font-size: 0.5rem; font-weight: 700; margin-right: 0.25rem; }
.grow-enter-active { transition: all 0.5s cubic-bezier(0.2, 0.7, 0.2, 1); }
.grow-enter-from { opacity: 0; transform: translateY(-12px); }
</style>

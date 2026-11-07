// Data for the backup Q&A sequence diagrams (components/QaFlow.vue).
// Every result below was measured on the running cluster; the logout "fix"
// options in the last step are not set up in the POC.

export type Kind = 'front' | 'back' | 'self' | 'fail' | 'ok'

export interface Step {
  from: number
  to: number
  kind: Kind
  row: number
  label: string
  title: string
  text: string
  code?: string
  chips: string[]
}

export interface Flow {
  actors: string[]
  intro: { title: string; text: string }
  steps: Step[]
}

export const flows = {
  logout: {
    actors: ['Browser', 'OAuth2-Proxy', 'Keycloak', 'API sidecar'],
    intro: {
      title: 'Signing out is not the same as logging out',
      text: 'Three things hold bob’s login: the OAuth2-Proxy cookie, the Keycloak session, and access tokens already issued. Click to see what each logout step really ends.',
    },
    steps: [
      {
        from: 0, to: 1, kind: 'front', row: 0, label: 'GET /oauth2/sign_out',
        title: 'bob signs out of the app',
        text: 'OAuth2-Proxy deletes its own cookie and sends him to the start page. By default, that is all it does.',
        code: 'GET /oauth2/sign_out\n← 302 Location: /\n  Set-Cookie: _oauth2_proxy=; Max-Age=0',
        chips: ['app cookie deleted'],
      },
      {
        from: 1, to: 2, kind: 'front', row: 1, label: 'next click → 302 login',
        title: 'His next click goes to Keycloak',
        text: 'Without the cookie, OAuth2-Proxy sends him to the Keycloak login, exactly like the first visit.',
        code: 'GET /api/whoami\n← 302 keycloak.localhost/realms/demo/…/auth',
        chips: ['no app session'],
      },
      {
        from: 2, to: 0, kind: 'fail', row: 2, label: 'code issued, no password asked',
        title: 'Keycloak logs him straight back in',
        text: 'Keycloak’s own session is still alive, so it issues a new code without asking for a password. Signing out of the app did not sign him out of Keycloak.',
        code: 'Cookie: KEYCLOAK_IDENTITY=…   (still valid)\n← 302 /oauth2/callback?code=…\n→ GET /api/whoami ← 200',
        chips: ['single sign-on still on'],
      },
      {
        from: 0, to: 1, kind: 'fail', row: 3, label: 'copy of old cookie → 200',
        title: 'A copied cookie still works',
        text: 'The cookie is the session. OAuth2-Proxy decrypts it and keeps no list of signed-out sessions, so a copy taken before sign-out keeps working.',
        code: 'GET /api/whoami\nCookie: _oauth2_proxy=<copy from before sign-out>\n← 200',
        chips: ['stateless cookie'],
      },
      {
        from: 2, to: 2, kind: 'self', row: 4, label: 'admin: log out all sessions',
        title: 'An admin ends bob’s Keycloak session',
        text: 'Keycloak drops all of his sessions. From now on his refresh token is refused, so the browser session ends at the next refresh.',
        code: 'POST /admin/realms/demo/users/{id}/logout\n← 204',
        chips: ['refresh stops working'],
      },
      {
        from: 0, to: 3, kind: 'fail', row: 5, label: 'old access token → 200',
        title: 'Tokens already issued still work',
        text: 'Istio checks tokens offline with Keycloak’s public keys. It never asks Keycloak whether the session is still alive, so the token works until it expires: here at most 5 minutes.',
        code: 'GET /api/user\nAuthorization: Bearer <token from before the logout>\n← 200',
        chips: ['valid until exp'],
      },
      {
        from: 1, to: 1, kind: 'ok', row: 6, label: 'complete logout',
        title: 'How to make logout complete',
        text: 'End the Keycloak session too, by sending the user on to Keycloak’s logout endpoint after sign-out. Keep access tokens short. For revocable browser sessions, keep sessions on the server instead of in the cookie.',
        code: 'GET /oauth2/sign_out?rd=<Keycloak logout URL>\n--session-store-type=redis\naccessTokenLifespan = 5 minutes',
        chips: ['options, not set up in the POC'],
      },
    ],
  },

  spoof: {
    actors: ['Client', 'Gateway', 'OAuth2-Proxy', 'Spring'],
    intro: {
      title: 'Can a client fake the identity headers?',
      text: 'Spring receives the user’s name in X-Auth-Request-User. What stops a client from sending that header itself? Click to try it on both doors.',
    },
    steps: [
      {
        from: 0, to: 1, kind: 'fail', row: 0, label: 'fake User: admin',
        title: 'Door 1: bob fakes his identity header',
        text: 'bob sends his own session cookie, plus a header that claims he is admin.',
        code: 'GET app.localhost/api/whoami\nCookie: _oauth2_proxy=<bob>\nX-Auth-Request-User: admin',
        chips: ['fake header'],
      },
      {
        from: 2, to: 1, kind: 'back', row: 1, label: 'answer: user = bob',
        title: 'The real answer overwrites it',
        text: 'The gateway asks OAuth2-Proxy, and ext_authz copies its answer into the request. Headers with the same name are replaced.',
        code: '← 200\nX-Auth-Request-User: <bob’s id>',
        chips: ['overwritten'],
      },
      {
        from: 1, to: 3, kind: 'ok', row: 2, label: 'X-Auth-Request-User = bob',
        title: 'Spring sees bob',
        text: 'The fake value never arrives. Measured on the cluster: Spring shows bob’s id.',
        code: '"xAuthRequestUser": "b774…"   (bob)',
        chips: ['safe on Door 1'],
      },
      {
        from: 0, to: 1, kind: 'fail', row: 3, label: 'alice + fake User',
        title: 'Door 2: nothing overwrites it',
        text: 'On api.localhost there is no ext_authz. The gateway checks the token and, before our fix, passed the fake header on to Spring.',
        code: 'GET api.localhost/api/whoami\nAuthorization: Bearer <alice>\nX-Auth-Request-User: admin\n← "xAuthRequestUser": "admin"   (before the fix)',
        chips: ['found while testing'],
      },
      {
        from: 1, to: 3, kind: 'ok', row: 4, label: 'identity headers removed',
        title: 'The fix: remove them on the route',
        text: 'The api.localhost routes now remove every X-Auth-Request header that a client sends. Measured after the fix: Spring receives nothing.',
        code: 'headers:\n  request:\n    remove: [x-auth-request-user, x-auth-request-email,\n             x-auth-request-access-token, …]\n← "xAuthRequestUser": null',
        chips: ['k8s/app/app.yaml'],
      },
      {
        from: 3, to: 3, kind: 'self', row: 5, label: 'decide on verified claims',
        title: 'The rule behind it',
        text: 'Identity headers are hints from the gateway, never from the client. Access decisions use the verified token: the sidecar checks its signature and audience, and the policy checks its roles.',
        chips: ['trust the token, not the header'],
      },
    ],
  },
} satisfies Record<string, Flow>

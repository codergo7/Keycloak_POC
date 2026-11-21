// Data for the backup Q&A sequence diagrams (components/QaFlow.vue).
// logout: every result was measured on the running cluster; the "fix" options in
// its last step are not set up in the POC. s2s: describes options the POC does not
// set up (client credentials, token exchange); only option 1 matches the POC's checks.

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

  s2s: {
    actors: ['Service A', 'Keycloak', 'Service B · sidecar'],
    intro: {
      title: 'One service calls another',
      text: 'Service A needs data from service B. Which token should it send? Click for the three options. None of them is set up in the POC.',
    },
    steps: [
      {
        from: 0, to: 2, kind: 'fail', row: 0, label: 'forward alice’s token as is',
        title: 'Option 1: just forward the user’s token',
        text: 'The token was issued for A, so its audience is A. B’s RequestAuthentication only accepts tokens for B, so the call fails. That is the audience check doing its job.',
        code: 'GET b/data\nAuthorization: Bearer <alice, aud: a>\n← 403 Audiences in Jwt are not allowed',
        chips: ['wrong audience'],
      },
      {
        from: 0, to: 1, kind: 'back', row: 1, label: 'client_credentials',
        title: 'Option 2: A gets its own token',
        text: 'A logs in as itself, with its own client ID and secret. There is no user in this token: the subject is A’s service account.',
        code: 'POST /realms/demo/protocol/openid-connect/token\ngrant_type=client_credentials\nclient_id=a&client_secret=…',
        chips: ['client credentials'],
      },
      {
        from: 1, to: 0, kind: 'back', row: 2, label: 'token: sub = service-account-a',
        title: 'Keycloak issues a token for the service',
        text: 'The audience is B, and the roles are the roles of A’s service account. B decides what A may do, not what alice may do.',
        code: '{ "sub": "service-account-a", "azp": "a",\n  "aud": "b", "resource_access": { "b": { "roles": ["reader"] } } }',
        chips: ['no user'],
      },
      {
        from: 0, to: 2, kind: 'ok', row: 3, label: 'Bearer <A’s token> → 200',
        title: 'Good for jobs that act for themselves',
        text: 'B’s sidecar checks the audience and the service roles, exactly like for a user. Use it for batch jobs and internal calls that are not done on behalf of a user.',
        code: 'GET b/data\nAuthorization: Bearer <service-account-a, aud: b>\n← 200',
        chips: ['machine to machine'],
      },
      {
        from: 0, to: 1, kind: 'back', row: 4, label: 'token exchange: alice → aud b',
        title: 'Option 3: exchange alice’s token',
        text: 'If A acts on behalf of alice, it trades her token for a new one that is issued for B. This is OAuth token exchange, RFC 8693, which Keycloak supports.',
        code: 'grant_type=urn:ietf:params:oauth:grant-type:token-exchange\nsubject_token=<alice, aud: a>\naudience=b',
        chips: ['RFC 8693'],
      },
      {
        from: 1, to: 0, kind: 'back', row: 5, label: 'token: sub = alice, aud = b',
        title: 'Still alice, now for B',
        text: 'The new token keeps alice as the subject, with B as the audience. B’s rules see alice’s roles, and B knows the call came through A.',
        code: '{ "sub": "<alice>", "azp": "a", "aud": "b", … }',
        chips: ['on behalf of the user'],
      },
      {
        from: 0, to: 2, kind: 'ok', row: 6, label: 'Bearer <alice for B> → 200',
        title: 'Rule of thumb',
        text: 'Acting for itself: client credentials. Acting for a user: token exchange. Never widen a token’s audience just to make a call work.',
        code: 'GET b/data\nAuthorization: Bearer <alice, aud: b>\n← 200 (if alice has the role)',
        chips: ['least privilege'],
      },
    ],
  },
} satisfies Record<string, Flow>

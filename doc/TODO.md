# Keycloak POC: To do

Open items for the Keycloak + OAuth2-Proxy + Istio POC (kind cluster `iam-poc`), to implement later.
Each item says why it matters, the steps as tasks, and how to check it worked. Tick a step when it is
done; add new items as new numbered sections.

## 1. Lock down the identity namespace

Goal: in `identity`, every workload refuses all callers except the ones listed, and nobody can connect
in plaintext. Today only Postgres is locked (`postgres-allow-keycloak`, applied 2026-11-11); Keycloak and
OAuth2-Proxy still accept any caller in the mesh, and mTLS is PERMISSIVE, so pods outside the mesh can
reach them over plaintext.

The change has two parts:

- **allow-nothing:** an AuthorizationPolicy with an empty spec in `identity`. It is an ALLOW policy with
  no rules, so it denies everything; then one ALLOW policy per workload names its real callers.
- **PeerAuthentication STRICT:** sidecars in `identity` refuse every connection that is not mTLS.

```yaml
# sketch, not applied
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata: { name: allow-nothing, namespace: identity }
spec: {}
---
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata: { name: default, namespace: identity }
spec: { mtls: { mode: STRICT } }
```

### Callers to allow

| Workload | Port | Caller | Identity (principal) | Why it calls |
| --- | --- | --- | --- | --- |
| keycloak | 8080 | ingress gateway | `cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account` | browser login, admin console, `make token-*` (keycloak.localhost) |
| keycloak | 8080 | oauth2-proxy | `cluster.local/ns/identity/sa/oauth2-proxy` | `--redeem-url`, `--oidc-jwks-url`, `--profile-url` use keycloak.identity.svc |
| keycloak | 8080 | istiod | none: istiod has no sidecar, so it calls in plaintext | JWKS fetch for both RequestAuthentications |
| oauth2-proxy | 4180 | ingress gateway | `cluster.local/ns/istio-system/sa/istio-ingressgateway-service-account` | ext_authz check and the `/oauth2/*` routes |
| postgres | 5432 | keycloak | `cluster.local/ns/identity/sa/keycloak` | already done (`k8s/keycloak/postgres-authorization.yaml`) |

**Watch out, istiod:** with STRICT mTLS, Keycloak's sidecar refuses istiod's plaintext JWKS fetch. istiod
then pushes its placeholder key and every token gets 401 "Jwt verification fails" (see backup slide 36,
click 7). Options to test: a port-level PERMISSIVE exception on Keycloak's 8080 limited to the `/certs`
path by an ALLOW rule, or serving the JWKS another way. Decide before applying STRICT.

### Steps

- [ ] Write `k8s/keycloak/identity-authorization.yaml`: allow-nothing + one ALLOW policy per row of the table above
- [ ] Write `k8s/keycloak/identity-peerauthentication.yaml`: `mtls.mode: STRICT` for namespace `identity`
- [ ] Solve the istiod JWKS fetch (see the warning above) and note the choice in the YAML comments
- [ ] Add both files to `make deploy` in the Makefile, after `postgres-authorization.yaml`
- [ ] Apply, then restart istiod so it fetches the JWKS again (`make wake` covers this)
- [ ] Add smoke-test checks: a mesh pod (spring-app) cannot reach Keycloak's service directly, and a plaintext call is refused
- [ ] Update `doc/istio-request-flow.md` (section 4.7b) and backup slide 31, click 6: from "next steps" to "applied"

### How to verify

- [ ] `make smoke` and `AUTO=1 make demo-api` all pass
- [ ] Browser login as alice works, and the Keycloak admin console still works
- [ ] A token still validates after `kubectl -n istio-system rollout restart deploy/istiod` (proves the JWKS fetch works)
- [ ] From a pod in `default` (no sidecar): `curl http://keycloak.identity.svc.cluster.local:8080/realms/demo` fails
- [ ] From spring-app: the same curl gets 403 RBAC, while `api.localhost` calls still get 200
- [ ] Rollback if needed: `kubectl delete -f` both new files, then `make wake`

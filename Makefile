SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

CLUSTER ?= iam-poc
ISTIO_VERSION ?= 1.31.0
APP_IMAGE ?= iam-poc-app:dev
REPORTS_IMAGE ?= iam-poc-reports:dev

.PHONY: help prereqs cluster istio namespaces build load deploy wait up status \
        token-alice token-bob token-bob-reports token-admin decode smoke demo-api demo-door2 browser keycloak logs \
        logs-kc logs-proxy logs-app logs-reports shell-app restart wake clean reset

help:
	@echo "IAM POC targets"
	@echo "  make up            Create Kind + Istio + Keycloak + oauth2-proxy + app"
	@echo "  make smoke         Run API/JWT/RBAC smoke tests"
	@echo "  make demo-api      Guided live demo of the eight API access checks (AUTO=1: no pauses)"
	@echo "  make token-alice   Print Alice access token"
	@echo "  make token-bob-reports  Print Bob access token with scope=reports (aud reports-api)"
	@echo "  make show-claims-bob-reports  Decode it: aud has spring-api and reports-api"
	@echo "  make token-admin   Print admin access token"
	@echo "  make decode TOKEN=... Decode JWT locally"
	@echo "  make shell-app     Shell into Spring container (curl + jq installed)"
	@echo "  make logs-kc       Follow Keycloak logs"
	@echo "  make logs-proxy    Follow oauth2-proxy logs"
	@echo "  make logs-app      Follow Spring app logs"
	@echo "  make logs-reports  Follow reports API logs"
	@echo "  make status        Show pods/services/gateways"
	@echo "  make wake          After laptop sleep (503s): restart the mesh in order, keeps Keycloak data"
	@echo "  make reset         Delete and recreate everything"
	@echo "  make clean         Delete Kind cluster"
	@echo
	@echo "URLs:"
	@echo "  Keycloak: http://keycloak.localhost:8080  (admin/admin)"
	@echo "  Browser app: http://app.localhost:8080"
	@echo "  API:      http://api.localhost:8080/api/public"
	@echo "  Reports:  http://api.localhost:8080/reports (token with scope=reports)"

prereqs:
	@for c in docker kind kubectl curl jq make; do \
	  command -v $$c >/dev/null || { echo "Missing prerequisite: $$c"; exit 1; }; \
	done

cluster: prereqs
	@if kind get clusters | grep -qx "$(CLUSTER)"; then \
	  echo "Kind cluster $(CLUSTER) already exists"; \
	else \
	  kind create cluster --config kind/kind.yaml; \
	fi

istio: cluster
	ISTIO_VERSION="$(ISTIO_VERSION)" ./scripts/install-istio.sh
	kubectl apply -f k8s/istio/istio-cm.yaml
	kubectl apply -f k8s/istio/ingress-authorization.yaml
#	kubectl apply -f k8s/istio/ingress-remove-sensitive-headers.yaml
	

namespaces:
	kubectl apply -f k8s/base/namespaces.yaml

build:
	docker build -t "$(APP_IMAGE)" app
	docker build -t "$(REPORTS_IMAGE)" reports

load: build cluster
	kind load docker-image "$(APP_IMAGE)" --name "$(CLUSTER)"
	kind load docker-image "$(REPORTS_IMAGE)" --name "$(CLUSTER)"

deploy: namespaces load
	kubectl apply -f k8s/keycloak/postgres.yaml
	kubectl apply -f k8s/keycloak/realm-configmap.yaml
	kubectl apply -f k8s/keycloak/keycloak.yaml
	kubectl apply -f k8s/keycloak/postgres-authorization.yaml
	kubectl -n identity create serviceaccount oauth2-proxy --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -f k8s/oauth2-proxy/oauth2-proxy.yaml
	kubectl apply -f k8s/app/auth-app.yaml
	kubectl apply -f k8s/app/app.yaml
	kubectl apply -f k8s/reports/auth-reports.yaml
	kubectl apply -f k8s/reports/reports.yaml
	kubectl apply -f k8s/istio/gateway.yaml
	@echo "Waiting for Keycloak before enabling JWT validation..."
	kubectl -n identity rollout status deploy/postgres --timeout=180s
	kubectl -n identity rollout status deploy/keycloak --timeout=300s
	@echo "Restarting istiod so it re-fetches the Keycloak JWKS (first fetch fails while Keycloak is down)..."
	kubectl -n istio-system rollout restart deploy/istiod
	kubectl -n istio-system rollout status deploy/istiod --timeout=180s

wait:
	kubectl -n identity rollout status deploy/postgres --timeout=180s
	kubectl -n identity rollout status deploy/keycloak --timeout=300s
	kubectl -n identity rollout status deploy/oauth2-proxy --timeout=180s
	kubectl -n spring-api rollout status deploy/spring-app --timeout=180s
	kubectl -n reports-api rollout status deploy/reports-api --timeout=180s

up: istio deploy wait #observability
	@echo
	@echo "POC is ready."
	@echo "Keycloak:    http://keycloak.localhost:8080  admin/admin"
	@echo "Browser app: http://app.localhost:8080       alice/alice, bob/bob, admin/admin"
	@echo "API:         http://api.localhost:8080/api/public"
	@echo "Reports:     http://api.localhost:8080/reports"
	@echo "Run: make smoke"

status:
	kubectl get pods -A
	@echo
	kubectl -n istio-system get svc istio-ingressgateway
	@echo
	kubectl -n identity get gateway,virtualservice
	@echo
	kubectl -n istio-system get requestauthentication,authorizationpolicy

token-alice:
	@./scripts/get-token.sh alice alice

token-bob:
	@./scripts/get-token.sh bob bob

token-bob-reports:
	@./scripts/get-token.sh bob bob reports

token-admin:
	@./scripts/get-token.sh admin admin

decode:
	@test -n "$(TOKEN)" || { echo "Usage: make decode TOKEN=<jwt>"; exit 1; }
	@./scripts/decode-token.sh "$(TOKEN)"

smoke:
	@./scripts/smoke-test.sh

demo-api:
	@AUTO="$(AUTO)" ./scripts/demo-api.sh

demo-door2: demo-api   # old name, kept as an alias

browser:
	@echo "Open http://app.localhost:8080"

keycloak:
	@echo "Open http://keycloak.localhost:8080 (admin/admin)"

logs-kc:
	kubectl -n identity logs -f deploy/keycloak -c keycloak

logs-proxy:
	kubectl -n identity logs -f deploy/oauth2-proxy -c oauth2-proxy

logs-app:
	kubectl -n spring-api logs -f deploy/spring-app -c app

logs-reports:
	kubectl -n reports-api logs -f deploy/reports-api -c app

shell-app:
	kubectl -n spring-api exec -it deploy/spring-app -c app -- bash

restart:
	kubectl -n identity rollout restart deploy/keycloak deploy/oauth2-proxy
	kubectl -n spring-api rollout restart deploy/spring-app
	kubectl -n reports-api rollout restart deploy/reports-api

# After the laptop sleeps, workload certificates expire and every request gets a 503.
# Restart in order: gateways, Postgres's sidecar, Keycloak, istiod (fetches the JWKS
# again), then the apps. Postgres keeps its data in an emptyDir, so only its istio-proxy
# container is restarted (quitquitquit); restarting the pod would wipe Keycloak's users.
wake:
	kubectl -n istio-system rollout restart deploy/istio-ingressgateway deploy/istio-egressgateway
	kubectl -n istio-system rollout status deploy/istio-ingressgateway --timeout=180s
	kubectl -n identity exec deploy/postgres -c istio-proxy -- pilot-agent request POST quitquitquit >/dev/null || true
	kubectl -n identity wait pod -l app=postgres --for=condition=Ready --timeout=180s
	kubectl -n identity rollout restart deploy/keycloak
	kubectl -n identity rollout status deploy/keycloak --timeout=300s
	kubectl -n istio-system rollout restart deploy/istiod
	kubectl -n istio-system rollout status deploy/istiod --timeout=180s
	kubectl -n identity rollout restart deploy/oauth2-proxy
	kubectl -n spring-api rollout restart deploy/spring-app
	kubectl -n reports-api rollout restart deploy/reports-api
	kubectl -n identity rollout status deploy/oauth2-proxy --timeout=180s
	kubectl -n spring-api rollout status deploy/spring-app --timeout=180s
	kubectl -n reports-api rollout status deploy/reports-api --timeout=180s
	@echo "Mesh restarted. Run: make smoke"

clean:
	kind delete cluster --name "$(CLUSTER)"

reset: clean up

observability:
	./scripts/install-observability.sh

show-claims-alice:
	@./scripts/show-claims.sh alice alice

show-claims-bob:
	@./scripts/show-claims.sh bob bob

show-claims-bob-reports:
	@./scripts/show-claims.sh bob bob reports

show-claims-admin:
	@./scripts/show-claims.sh admin admin

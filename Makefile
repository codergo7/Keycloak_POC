SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

CLUSTER ?= iam-poc
ISTIO_VERSION ?= 1.31.0
APP_IMAGE ?= iam-poc-app:dev

.PHONY: help prereqs cluster istio namespaces build load deploy wait up status \
        token-alice token-bob token-admin decode smoke browser keycloak logs \
        logs-kc logs-proxy logs-app shell-app restart clean reset

help:
	@echo "IAM POC targets"
	@echo "  make up            Create Kind + Istio + Keycloak + oauth2-proxy + app"
	@echo "  make smoke         Run API/JWT/RBAC smoke tests"
	@echo "  make token-alice   Print Alice access token"
	@echo "  make token-admin   Print admin access token"
	@echo "  make decode TOKEN=... Decode JWT locally"
	@echo "  make shell-app     Shell into Spring container (curl + jq installed)"
	@echo "  make logs-kc       Follow Keycloak logs"
	@echo "  make logs-proxy    Follow oauth2-proxy logs"
	@echo "  make logs-app      Follow Spring app logs"
	@echo "  make status        Show pods/services/gateways"
	@echo "  make reset         Delete and recreate everything"
	@echo "  make clean         Delete Kind cluster"
	@echo
	@echo "URLs:"
	@echo "  Keycloak: http://keycloak.localhost:8080  (admin/admin)"
	@echo "  Browser app: http://app.localhost:8080"
	@echo "  API:      http://api.localhost:8080/api/public"

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

namespaces:
	kubectl apply -f k8s/base/namespaces.yaml

build:
	docker build -t "$(APP_IMAGE)" app

load: build cluster
	kind load docker-image "$(APP_IMAGE)" --name "$(CLUSTER)"

deploy: namespaces load
	kubectl apply -f k8s/keycloak/postgres.yaml
	kubectl apply -f k8s/keycloak/realm-configmap.yaml
	kubectl apply -f k8s/keycloak/keycloak.yaml
	kubectl apply -f k8s/oauth2-proxy/oauth2-proxy.yaml
	kubectl apply -f k8s/app/app.yaml
	kubectl apply -f k8s/istio/gateway.yaml
	@echo "Waiting for Keycloak before enabling JWT validation..."
	kubectl -n iam rollout status deploy/postgres --timeout=180s
	kubectl -n iam rollout status deploy/keycloak --timeout=300s
	kubectl apply -f k8s/istio/jwt-auth.yaml
	kubectl apply -f k8s/service-a/service-a.yaml

wait:
	kubectl -n iam rollout status deploy/postgres --timeout=180s
	kubectl -n iam rollout status deploy/keycloak --timeout=300s
	kubectl -n iam rollout status deploy/oauth2-proxy --timeout=180s
	kubectl -n demo rollout status deploy/spring-app --timeout=180s

up: istio deploy wait observability
	@echo
	@echo "POC is ready."
	@echo "Keycloak:    http://keycloak.localhost:8080  admin/admin"
	@echo "Browser app: http://app.localhost:8080       alice/alice, bob/bob, admin/admin"
	@echo "API:         http://api.localhost:8080/api/public"
	@echo "Run: make smoke"

status:
	kubectl get pods -A
	@echo
	kubectl -n istio-system get svc istio-ingressgateway
	@echo
	kubectl -n iam get gateway,virtualservice
	@echo
	kubectl -n istio-system get requestauthentication,authorizationpolicy

token-alice:
	@./scripts/get-token.sh alice alice

token-bob:
	@./scripts/get-token.sh bob bob

token-admin:
	@./scripts/get-token.sh admin admin

decode:
	@test -n "$(TOKEN)" || { echo "Usage: make decode TOKEN=<jwt>"; exit 1; }
	@./scripts/decode-token.sh "$(TOKEN)"

smoke:
	@./scripts/smoke-test.sh

browser:
	@echo "Open http://app.localhost:8080"

keycloak:
	@echo "Open http://keycloak.localhost:8080 (admin/admin)"

logs-kc:
	kubectl -n iam logs -f deploy/keycloak -c keycloak

logs-proxy:
	kubectl -n iam logs -f deploy/oauth2-proxy -c oauth2-proxy

logs-app:
	kubectl -n demo logs -f deploy/spring-app -c app

shell-app:
	kubectl -n demo exec -it deploy/spring-app -c app -- bash

restart:
	kubectl -n iam rollout restart deploy/keycloak deploy/oauth2-proxy
	kubectl -n demo rollout restart deploy/spring-app

clean:
	kind delete cluster --name "$(CLUSTER)"

reset: clean up

observability:
	./scripts/install-observability.sh

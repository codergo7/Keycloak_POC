#!/usr/bin/env bash
set -euo pipefail

ISTIO_RELEASE="${ISTIO_RELEASE:-1.31}"

BASE_URL="https://raw.githubusercontent.com/istio/istio/release-${ISTIO_RELEASE}/samples/addons"

echo "Installing Prometheus..."
kubectl apply -f "${BASE_URL}/prometheus.yaml"

echo "Installing Kiali..."
kubectl apply -f "${BASE_URL}/kiali.yaml"

echo "Installing Grafana..."
kubectl apply -f "${BASE_URL}/grafana.yaml"

echo "Installing Jaeger..."
kubectl apply -f "${BASE_URL}/jaeger.yaml"

echo "Waiting for observability components..."

kubectl rollout status deployment/prometheus \
  -n istio-system --timeout=180s

kubectl rollout status deployment/kiali \
  -n istio-system --timeout=180s

kubectl rollout status deployment/grafana \
  -n istio-system --timeout=180s

kubectl apply -f k8s/observability/telemetry.yaml

echo "Observability stack installed."


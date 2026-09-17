#!/usr/bin/env bash
set -euo pipefail
ISTIO_VERSION="${ISTIO_VERSION:-1.30.4}"

if ! command -v istioctl >/dev/null 2>&1; then
  echo "istioctl not found; downloading Istio ${ISTIO_VERSION} to .tools/"
  mkdir -p .tools
  if [ ! -d ".tools/istio-${ISTIO_VERSION}" ]; then
    curl -L "https://istio.io/downloadIstio" | ISTIO_VERSION="${ISTIO_VERSION}" TARGET_ARCH="$(uname -m | sed 's/x86_64/x86_64/;s/aarch64/arm64/')" sh -
    mv "istio-${ISTIO_VERSION}" .tools/
  fi
  ISTIOCTL=".tools/istio-${ISTIO_VERSION}/bin/istioctl"
else
  ISTIOCTL="$(command -v istioctl)"
fi

"${ISTIOCTL}" install -y --set profile=demo

# Make the ingress gateway reachable through Kind's hostPort mappings.
kubectl -n istio-system patch svc istio-ingressgateway --type='json' \
  -p='[
    {"op":"replace","path":"/spec/type","value":"NodePort"}
  ]'

HTTP_INDEX="$(kubectl -n istio-system get svc istio-ingressgateway -o json | jq -r '.spec.ports | to_entries[] | select(.value.port==80) | .key')"
HTTPS_INDEX="$(kubectl -n istio-system get svc istio-ingressgateway -o json | jq -r '.spec.ports | to_entries[] | select(.value.port==443) | .key')"

kubectl -n istio-system patch svc istio-ingressgateway --type='json' \
  -p="[{\"op\":\"replace\",\"path\":\"/spec/ports/${HTTP_INDEX}/nodePort\",\"value\":30080}]"

kubectl -n istio-system patch svc istio-ingressgateway --type='json' \
  -p="[{\"op\":\"replace\",\"path\":\"/spec/ports/${HTTPS_INDEX}/nodePort\",\"value\":30443}]"

kubectl -n istio-system rollout status deploy/istiod --timeout=180s
kubectl -n istio-system rollout status deploy/istio-ingressgateway --timeout=180s

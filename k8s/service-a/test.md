```bash
kubectl exec -n service-a deploy/service-a -c service-a -- \
  curl -i \
  http://spring-app.demo.svc.cluster.local:8080/api/internal
```



1. User authentication
   User → Keycloak
   "Who is the user?"

2. JWT authorization
   JWT → Istio
   "Does this user/client have the required role/group/claim?"

3. Service-to-service authentication
   Service A → mTLS → Spring
   "Which Kubernetes workload is calling?"

4. Service-to-service authorization
   ServiceAccount identity → AuthorizationPolicy
   "Is this workload allowed to call /api/internal?"

5. Application authorization
   Spring Boot
   "Is this operation allowed according to business state/rules?"



Service A
SA: service-a
      │
      │ Istio mTLS
      ▼
Spring Envoy
      │
      │ PeerAuthentication: STRICT
      │
      │ AuthorizationPolicy
      │ allowed SA: service-a/service-a
      ▼
GET /api/internal
      │
      ▼
    200 OK


```bash
kubectl run bad-client \
  -n service-a \
  --image=curlimages/curl:8.12.1 \
  --restart=Never \
  --command -- sleep 3600


---

kubectl exec -n service-a bad-client -c bad-client -- \
  curl -i \
  http://spring-app.demo.svc.cluster.local:8080/api/internal


```

bad-client
SA: default
      │
      │ Istio mTLS
      ▼
Spring Envoy
      │
      │ authenticated ✓
      │ authorized ✗
      ▼
    403


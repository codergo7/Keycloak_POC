```bash
SPRING_POD=$(kubectl get pod -n spring-api \
  -l app=spring-app \
  -o jsonpath='{.items[0].metadata.name}')

istioctl x describe pod "$SPRING_POD" -n spring-api
```


```bash
istioctl dashboard kiali
```
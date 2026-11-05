```bash
SPRING_POD=$(kubectl get pod -n demo \
  -l app=spring-app \
  -o jsonpath='{.items[0].metadata.name}')

istioctl x describe pod "$SPRING_POD" -n demo
```


```bash
istioctl dashboard kiali
```
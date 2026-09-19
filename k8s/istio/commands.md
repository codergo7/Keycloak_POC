```bash
istioctl x describe pod \
  $(kubectl get pod -n service-a -l app=service-a -o jsonpath='{.items[0].metadata.name}') \
  -n service-a


---

SPRING_POD=$(kubectl get pod -n demo \
  -l app=spring-app \
  -o jsonpath='{.items[0].metadata.name}')

istioctl x describe pod "$SPRING_POD" -n demo
```
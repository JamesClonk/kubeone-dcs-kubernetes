#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "deployments" ]]; then
  cd ..
fi

# additional configuration, add a ClusterRoleBinding
cluster_hostname=$(yq -e eval '.kubernetes.hostname' config.yaml)
cat > "deployments/hubble.ingress.yaml" <<EOF
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/auth-signin: https://oauth2-proxy.${cluster_hostname}/oauth2/start
    nginx.ingress.kubernetes.io/auth-url: https://oauth2-proxy.${cluster_hostname}/oauth2/auth
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "lets-encrypt"
  labels:
    app: hubble-ui
    app.kubernetes.io/instance: hubble-ui
  name: hubble-ui-ingress
  namespace: kube-system
spec:
  ingressClassName: nginx
  rules:
  - host: hubble.${cluster_hostname}
    http:
      paths:
      - backend:
          service:
            name: hubble-ui
            port:
              number: 80
        path: /
        pathType: ImplementationSpecific
  tls:
  - hosts:
    - hubble.${cluster_hostname}
    secretName: hubble-ui-tls
EOF
kubectl -n "kube-system" apply -f "deployments/hubble.ingress.yaml"

echo " "
echo "================================================================================================================="
echo "Hubble UI has been made accessible, visit: https://hubble.${cluster_hostname}"
echo "================================================================================================================="

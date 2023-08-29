#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "deployments" ]]; then
	cd ..
fi

# chart source: https://github.com/kubernetes/dashboard
repository="https://kubernetes.github.io/dashboard/"
chart="kubernetes-dashboard"
version="6.0.8"
namespace="${chart}"

cluster_hostname=$(yq -e eval '.kubernetes.hostname' config.yaml)
cat > "deployments/${chart}.values.yaml" <<EOF
metricsScraper:
  enabled: true
protocolHttp: true
service:
  externalPort: 80
extraArgs:
- --enable-insecure-login
ingress:
  enabled: true
  className: nginx
  hosts:
  - dashboard.${cluster_hostname}
  tls:
  - secretName: kubernetes-dashboard-tls
    hosts:
    - dashboard.${cluster_hostname}
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/auth-signin: "https://oauth2-proxy.${cluster_hostname}/oauth2/start"
    nginx.ingress.kubernetes.io/auth-url: "https://oauth2-proxy.${cluster_hostname}/oauth2/auth"
    # nginx.ingress.kubernetes.io/auth-response-headers: >-
    #   X-Auth-Request-Email,X-Auth-Request-Preferred-,X-Auth-Request-Access-Token,
    #   X-Auth-Request-Roles,X-Auth-Request-User,X-Auth-Request-Groups,X-Forwarded-Groups,
    #   Authorization
    cert-manager.io/cluster-issuer: "lets-encrypt"
    # ingress.kubernetes.io/configuration-snippet: |
    #   auth_request_set \$token \$upstream_http_authorization;
    #   proxy_set_header Authorization \$token;
    #   proxy_pass_header Authorization;
EOF
deployments/install-chart.sh "${repository}" "${chart}" "${namespace}" "${version}" "deployments/${chart}.values.yaml"
echo " "

# additional configuration, add a ClusterRoleBinding
cat > "deployments/${chart}.crb.yaml" <<EOF
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
EOF
kubectl -n ${namespace} apply -f "deployments/${chart}.crb.yaml"

echo " "
echo "================================================================================================================="
echo "Kubernetes dashboard has been installed, visit: https://dashboard.${cluster_hostname}"
echo "To login, create a temporary token by running: kubectl -n kubernetes-dashboard create token kubernetes-dashboard"
echo "================================================================================================================="

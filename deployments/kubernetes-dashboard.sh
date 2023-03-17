#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "deployments" ]]; then
	cd ..
fi

repository="https://kubernetes.github.io/dashboard/"
release="kubernetes-dashboard"
chart="kubernetes-dashboard"
version="6.0.5"
namespace="${release}"

kubeapi_hostname=$(cat terraform/output.json | jq -r .kubeone_api.value.endpoint)
cat > "deployments/${release}.values.yaml" <<EOF
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
  - dashboard.${kubeapi_hostname}
  tls:
  - secretName: kubernetes-dashboard-tls
    hosts:
    - dashboard.${kubeapi_hostname}
  annotations:
    cert-manager.io/cluster-issuer: "lets-encrypt"
EOF
deployments/install-chart.sh "${repository}" "${release}" "${chart}" "${version}" "deployments/${release}.values.yaml"
echo " "

# additional configuration, add a ClusterRoleBinding
cat > "deployments/${release}.crb.yaml" <<EOF
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
kubectl apply -f "deployments/${release}.crb.yaml"

echo " "
echo "================================================================================================================="
echo "Kubernetes dashboard has been installed, visit: https://dashboard.${kubeapi_hostname}"
echo "To login, create a temporary token by running: kubectl -n kubernetes-dashboard create token kubernetes-dashboard"
echo "================================================================================================================="

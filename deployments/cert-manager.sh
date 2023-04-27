#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "deployments" ]]; then
	cd ..
fi

repository="https://charts.jetstack.io"
chart="cert-manager"
version="v1.11.0"
namespace="${chart}"

cat > "deployments/${chart}.values.yaml" <<EOF
installCRDs: true
EOF
deployments/install-chart.sh "${repository}" "${chart}" "${namespace}" "${version}" "deployments/${chart}.values.yaml"
echo " "

# additional configuration, add a ClusterIssuer
cat > "deployments/${chart}.cluster-issuer.yaml" <<EOF
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: lets-encrypt
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: lets-encrypt
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
kubectl -n ${namespace} apply -f "deployments/${chart}.cluster-issuer.yaml"

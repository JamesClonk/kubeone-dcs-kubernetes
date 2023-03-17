#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "deployments" ]]; then
	cd ..
fi

repository="https://charts.jetstack.io"
release="cert-manager"
chart="cert-manager"
version="v1.11.0"
namespace="${release}"

cat > "deployments/${release}.values.yaml" <<EOF
installCRDs: true
EOF
deployments/install-chart.sh "${repository}" "${release}" "${chart}" "${version}" "deployments/${release}.values.yaml"
echo " "

# additional configuration, add a ClusterIssuer
cat > "deployments/${release}.cluster-issuer.yaml" <<EOF
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
kubectl apply -f "deployments/${release}.cluster-issuer.yaml"

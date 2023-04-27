#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "deployments" ]]; then
	cd ..
fi

repository="https://kubernetes.github.io/ingress-nginx"
chart="ingress-nginx"
version="4.5.2"
namespace="${chart}"

external_ip=$(cat terraform/output.json | jq -r .external_ip.value)
cat > "deployments/${chart}.values.yaml" <<EOF
controller:
  metrics:
    enabled: true
  service:
    annotations:
      prometheus.io/scrape: "true"
      prometheus.io/port: "10254"
    externalIPs:
    - ${external_ip}
    type: NodePort
    nodePorts:
      http: "30080"
      https: "30443"
  ingressClassResource:
    default: true
EOF
deployments/install-chart.sh "${repository}" "${chart}" "${namespace}" "${version}" "deployments/${chart}.values.yaml"

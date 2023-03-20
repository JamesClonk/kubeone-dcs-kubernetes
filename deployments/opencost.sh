#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "deployments" ]]; then
	cd ..
fi

repository="https://opencost.github.io/opencost-helm-chart"
chart="opencost"
version="1.7.0"
namespace="${chart}"

kubeapi_hostname=$(cat terraform/output.json | jq -r .kubeone_api.value.endpoint)
cat > "deployments/${chart}.values.yaml" <<EOF
service:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9003"
opencost:
  prometheus:
    external:
      enabled: false
    internal:
      enabled: true
      namespaceName: prometheus
      serviceName: prometheus-server
      port: 80
EOF
deployments/install-chart.sh "${repository}" "${chart}" "${version}" "deployments/${chart}.values.yaml"

echo " "
echo "================================================================================================================="
echo "OpenCost has been installed ..."
echo "To access, open a port-forwarding by running: kubectl -n opencost port-forward svc/opencost 9090:9090"
echo "================================================================================================================="

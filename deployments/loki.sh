#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "deployments" ]]; then
	cd ..
fi

# chart source: https://github.com/grafana/loki/tree/main/production/helm/loki
repository="https://grafana.github.io/helm-charts"
chart="loki"
version="5.5.5"
namespace="${chart}"

cat > "deployments/${chart}.values.yaml" <<EOF
loki:
  auth_enabled: false
  commonConfig:
    replication_factor: 1
  storage:
    type: filesystem
test:
  enabled: false
monitoring:
  dashboards:
    enabled: false
  rules:
    enabled: false
    alerting: false
  serviceMonitor:
    enabled: false
  selfMonitoring:
    enabled: false
    grafanaAgent:
      installOperator: false
  lokiCanary:
    enabled: false
singleBinary:
  replicas: 1
  persistence:
    size: 20Gi
EOF
deployments/install-chart.sh "${repository}" "${chart}" "${namespace}" "${version}" "deployments/${chart}.values.yaml"

#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "deployments" ]]; then
	cd ..
fi

# chart source: https://github.com/grafana/helm-charts
repository="https://grafana.github.io/helm-charts"
chart="promtail"
version="6.11.5"
namespace="${chart}"

cat > "deployments/${chart}.values.yaml" <<EOF
config:
  clients:
  - url: http://loki.loki.svc.cluster.local:3100/loki/api/v1/push
tolerations:
- effect: NoSchedule
  operator: Exists
- key: node-role.kubernetes.io/master
  operator: Exists
  effect: NoSchedule
- key: node-role.kubernetes.io/control-plane
  operator: Exists
  effect: NoSchedule
EOF
deployments/install-chart.sh "${repository}" "${chart}" "${namespace}" "${version}" "deployments/${chart}.values.yaml"

#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "deployments" ]]; then
	cd ..
fi

repository="https://grafana.github.io/helm-charts"
chart="promtail"
version="6.9.3"
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
deployments/install-chart.sh "${repository}" "${chart}" "${version}" "deployments/${chart}.values.yaml"

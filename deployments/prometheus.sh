#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "deployments" ]]; then
	cd ..
fi

repository="https://prometheus-community.github.io/helm-charts"
release="prometheus"
chart="prometheus"
version="19.7.2"
namespace="${release}"

kubeapi_hostname=$(cat terraform/output.json | jq -r .kubeone_api.value.endpoint)
cat > "deployments/${release}.values.yaml" <<EOF
alertmanager:
  enabled: true
  strategy:
    type: Recreate
  persistence:
    size: 1Gi
server:
  persistentVolume:
    size: 10Gi
kube-state-metrics:
  enabled: true
prometheus-node-exporter:
  enabled: true
  tolerations:
  - effect: NoSchedule
    operator: Exists
  - key: node-role.kubernetes.io/master
    operator: Exists
    effect: NoSchedule
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
prometheus-pushgateway:
  enabled: true
EOF
deployments/install-chart.sh "${repository}" "${release}" "${chart}" "${version}" "deployments/${release}.values.yaml"

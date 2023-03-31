#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "deployments" ]]; then
	cd ..
fi
source "deployments/semver.sh"

repository="https://prometheus-community.github.io/helm-charts"
chart="prometheus"
version="19.7.2"
namespace="${chart}"

function upgradeActions() {
  set +u
  if [[ -z "${KUBECONFIG}" ]]; then
    KUBECONFIG="kubeone-kubeconfig"
  fi
  set -u

  current_version=$(helm list --kubeconfig "${KUBECONFIG}" --namespace "${namespace}" --filter "${chart}" -o json | jq -r '.[0].app_version | "0.0.0"')
  if [[ "${current_version}" == "0.0.0" ]]; then
    return # new installation, don't need to perform any upgrade actions
  fi

  if semverLT ${current_version} "15.0.0"; then
    echo "performing upgrade actions to [15.0] ..."
    kubectl delete --kubeconfig "${KUBECONFIG}" deployments.apps -l "app.kubernetes.io/instance=prometheus,app.kubernetes.io/name=kube-state-metrics" --cascade="orphan" --namespace="${namespace}" || true
  fi

  if semverLT ${current_version} "18.0.0"; then
    echo "performing upgrade actions to [18.0] ..."
    kubectl scale --kubeconfig "${KUBECONFIG}" deploy prometheus-server --replicas=0 --namespace="${namespace}" || true
  fi

  echo " "
}
upgradeActions

cat > "deployments/${chart}.values.yaml" <<EOF
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
deployments/install-chart.sh "${repository}" "${chart}" "${version}" "deployments/${chart}.values.yaml"

echo " "
echo "================================================================================================================="
echo "Prometheus has been installed ..."
echo "To access, open a port-forwarding by running: kubectl -n prometheus port-forward svc/prometheus-server 9090:80"
echo "================================================================================================================="

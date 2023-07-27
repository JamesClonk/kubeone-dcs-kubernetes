#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "deployments" ]]; then
	cd ..
fi
source "tools/semver.sh"

# chart source: https://github.com/prometheus-community/helm-charts
repository="https://prometheus-community.github.io/helm-charts"
chart="prometheus"
version="22.6.7"
namespace="${chart}"

function upgradeActions() {
  set +u
  if [[ -z "${KUBECONFIG}" ]]; then
    KUBECONFIG="kubeone-kubeconfig"
  fi
  set -u

  current_version=$(helm list --kubeconfig "${KUBECONFIG}" --namespace "${namespace}" --filter "${chart}" -o json | jq -r '.[0].chart // "prometheus-0.0.0" | sub("prometheus-";"")')
  if [[ "${current_version}" == "0.0.0" ]]; then
    return # new installation, don't need to perform any upgrade actions
  fi

  if semverLT ${current_version} "15.0.0"; then
    echo "performing upgrade actions to [15.0] ..."
    kubectl delete --kubeconfig "${KUBECONFIG}" deployments.apps -l "app.kubernetes.io/instance=prometheus,app.kubernetes.io/name=kube-state-metrics" --cascade="orphan" --namespace="${namespace}" || true
    sleep 5
  fi

  if semverLT ${current_version} "18.0.0"; then
    echo "performing upgrade actions to [18.0] ..."
    kubectl scale --kubeconfig "${KUBECONFIG}" deploy prometheus-server --replicas=0 --namespace="${namespace}" || true
    sleep 5
  fi

  if semverLT ${current_version} "22.0.0"; then
    echo "performing upgrade actions to [22.0] ..."
    kubectl delete --kubeconfig "${KUBECONFIG}" deploy -l "app=prometheus" --namespace="${namespace}" || true
    kubectl delete --kubeconfig "${KUBECONFIG}" deploy,sts -l "app.kubernetes.io/name=prometheus" --namespace="${namespace}" || true
    sleep 5
  fi

  echo " "
}
upgradeActions

cluster_hostname=$(yq -e eval '.kubernetes.hostname' config.yaml)
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
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
      nginx.ingress.kubernetes.io/auth-signin: "https://oauth2-proxy.${cluster_hostname}/oauth2/start"
      nginx.ingress.kubernetes.io/auth-url: "https://oauth2-proxy.${cluster_hostname}/oauth2/auth"
      cert-manager.io/cluster-issuer: "lets-encrypt"
    hosts:
    - prometheus.${cluster_hostname}
    tls:
    - secretName: prometheus-tls
      hosts:
      - prometheus.${cluster_hostname}

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
deployments/install-chart.sh "${repository}" "${chart}" "${namespace}" "${version}" "deployments/${chart}.values.yaml"

echo " "
echo "================================================================================================================="
echo "Prometheus has been installed, visit: https://prometheus.${cluster_hostname}"
echo "================================================================================================================="

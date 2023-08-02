#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "deployments" ]]; then
	cd ..
fi

# chart source: https://github.com/longhorn/charts
repository="https://charts.longhorn.io"
chart="longhorn"
version="1.5.1"
namespace="longhorn-system"

# deploy longhorn installer helpers first, to ensure all necessary packages are available
kubectl create namespace ${namespace} || true
kubectl -n ${namespace} apply -f https://raw.githubusercontent.com/longhorn/longhorn/v${version}/deploy/prerequisite/longhorn-iscsi-installation.yaml
kubectl -n ${namespace} apply -f https://raw.githubusercontent.com/longhorn/longhorn/v${version}/deploy/prerequisite/longhorn-nfs-installation.yaml
# longhorn v2 data engine is currently a preview feature and should not yet be utilized in a production environment
# kubectl -n ${namespace} apply -f https://raw.githubusercontent.com/longhorn/longhorn/v${version}/deploy/prerequisite/longhorn-spdk-setup.yaml
# kubectl -n ${namespace} apply -f https://raw.githubusercontent.com/longhorn/longhorn/v${version}/deploy/prerequisite/longhorn-nvme-cli-installation.yaml

min() {
    printf "%s\n" "${@:2}" | sort "$1" | head -n1
}
max() {
    min ${1}r ${@:2}
}
# calculate number of volume replicas
# value must be nof min. worker nodes, minus 1 (because the worker node might want to be updated be machinecontroller)
# value must be within 1<=x<=3
initial_machinedeployment_replicas=$(($(cat terraform/output.json | jq -r .longhorn_replica_values.value.initial_machinedeployment_replicas)-1))
cluster_autoscaler_min_replicas=$(($(cat terraform/output.json | jq -r .longhorn_replica_values.value.cluster_autoscaler_min_replicas)-1))
longhorn_volume_replicas=$(max -g 1 $(min -g ${initial_machinedeployment_replicas} ${cluster_autoscaler_min_replicas} 3))
# is VCD or Longhorn going to be the default storage class?
longhorn_default_class=$(kubectl get storageclass -A -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}' | grep 'vcd' >/dev/null && echo "false" || echo "true")

cluster_hostname=$(yq -e eval '.kubernetes.hostname' config.yaml)
cat > "deployments/${chart}.values.yaml" <<EOF
persistence:
  defaultClass: ${longhorn_default_class}
  defaultFsType: ext4
  defaultClassReplicaCount: ${longhorn_volume_replicas}
  defaultReplicaAutoBalance: least-effort

defaultSettings:
  kubernetesClusterAutoscalerEnabled: true
  defaultReplicaCount: ${longhorn_volume_replicas}
  replicaAutoBalance: least-effort
  # replicaReplenishmentWaitInterval: 300
  disableSchedulingOnCordonedNode: true
  nodeDrainPolicy: block-if-contains-last-replica
  fastReplicaRebuildEnabled: true
  snapshotDataIntegrity: fast-check
  snapshotDataIntegrityCronjob: 0 3 * * *
  snapshotDataIntegrityImmediateCheckAfterSnapshotCreation: false
  upgradeChecker: false

ingress:
  enabled: true
  ingressClassName: nginx
  host: longhorn.${cluster_hostname}
  tls: true
  secureBackends: false
  tlsSecret: longhorn-tls
  path: /
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/auth-signin: "https://oauth2-proxy.${cluster_hostname}/oauth2/start"
    nginx.ingress.kubernetes.io/auth-url: "https://oauth2-proxy.${cluster_hostname}/oauth2/auth"
    cert-manager.io/cluster-issuer: "lets-encrypt"
EOF
deployments/install-chart.sh "${repository}" "${chart}" "${namespace}" "${version}" "deployments/${chart}.values.yaml"

echo " "
echo "================================================================================================================="
echo "Longhorn has been installed, visit: https://longhorn.${cluster_hostname}"
echo "================================================================================================================="

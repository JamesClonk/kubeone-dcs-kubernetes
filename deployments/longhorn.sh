#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "deployments" ]]; then
	cd ..
fi

repository="https://charts.longhorn.io"
chart="longhorn"
version="1.4.1"
namespace="longhorn-system"

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
cat > "deployments/${chart}.values.yaml" <<EOF
persistence:
  defaultClass: true
  defaultFsType: ext4
  defaultClassReplicaCount: ${longhorn_volume_replicas}
EOF
deployments/install-chart.sh "${repository}" "${chart}" "${namespace}" "${version}" "deployments/${chart}.values.yaml"

echo " "
echo "================================================================================================================="
echo "Longhorn has been installed ..."
echo "To access, open a port-forwarding by running: kubectl -n longhorn-system port-forward svc/longhorn-frontend 9999:80"
echo "================================================================================================================="

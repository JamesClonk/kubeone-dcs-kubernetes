#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "tools" ]]; then
	cd ..
fi

# ======================================================================================================================
echo " "
echo "generating [credentials.yaml] ..."
cp templates/credentials.template.yaml credentials.yaml.tmp

export VCD_URL=$(yq -e eval '.vcd.url' config.yaml)
export VCD_ORG=$(yq -e eval '.vcd.org' config.yaml)
export VCD_VDC=$(yq -e eval '.vcd.vdc' config.yaml)
export VCD_USER=$(yq -e eval '.vcd.user' config.yaml)
export VCD_PASSWORD=$(yq -e eval '.vcd.password' config.yaml)

yq ".VCD_URL = \"${VCD_URL}\"" -i credentials.yaml.tmp
yq ".VCD_ORG = \"${VCD_ORG}\"" -i credentials.yaml.tmp
yq ".VCD_VDC = \"${VCD_VDC}\"" -i credentials.yaml.tmp
yq ".VCD_USER = \"${VCD_USER}\"" -i credentials.yaml.tmp
yq ".VCD_PASSWORD = \"${VCD_PASSWORD}\"" -i credentials.yaml.tmp

cat credentials.yaml.tmp > credentials.yaml
rm -f credentials.yaml.tmp || true
# ======================================================================================================================

# ======================================================================================================================
echo "generating [kubeone.yaml] ..."
cp templates/kubeone.template.yaml kubeone.yaml.tmp

export KUBERNETES_HOSTNAME=$(yq -e eval '.kubernetes.hostname' config.yaml)
export KUBERNETES_VERSION=$(yq -e eval '.kubernetes.version' config.yaml)
export CSI_STORAGE_PROFILE=$(yq -e eval '.kubernetes.csi.storage_profile' config.yaml)

yq ".versions.kubernetes = \"${KUBERNETES_VERSION}\"" -i kubeone.yaml.tmp
yq ".features.openidConnect.config.issuerUrl = \"https://dex.${KUBERNETES_HOSTNAME}/dex\"" -i kubeone.yaml.tmp
yq ".addons.addons |= map(select(.params.storageProfile != null).params.storageProfile =\"${CSI_STORAGE_PROFILE}\")" -i kubeone.yaml.tmp
# yq ".addons.addons.[2].params.storageProfile = \"${CSI_STORAGE_PROFILE}\"" -i kubeone.yaml.tmp
# yq ".addons.addons.[3].params.storageProfile = \"${CSI_STORAGE_PROFILE}\"" -i kubeone.yaml.tmp

cat kubeone.yaml.tmp > kubeone.yaml
rm -f kubeone.yaml.tmp || true
# ======================================================================================================================

# ======================================================================================================================
echo "generating [terraform/terraform.tfvars] ..."
cp templates/terraform.template.tfvars terraform/terraform.tfvars.tmp

export VCD_EDGEGATEWAY=$(yq -e eval '.vcd.edge_gateway_name' config.yaml)
export VCD_CATALOG=$(yq -e eval '.vcd.catalog_name // "KubeOne"' config.yaml)
export VCD_CLUSTER=$(yq -e eval '.vcd.cluster_name // "kubeone"' config.yaml)
export CP_MEMORY=$(yq -e eval '.control_plane.memory // 4096' config.yaml)
export CP_CPU=$(yq -e eval '.control_plane.cpus // 2' config.yaml)
export CP_DISK=$(yq -e eval '.control_plane.disk_size_mb // 51200' config.yaml)
export CP_STORAGE_PROFILE=$(yq -e eval '.control_plane.storage_profile // "*"' config.yaml)
export CP_VM_COUNT=$(yq -e eval '.control_plane.vm_count // 3' config.yaml)
export WORKER_MEMORY=$(yq -e eval '.workers.memory // 8192' config.yaml)
export WORKER_CPU=$(yq -e eval '.workers.cpus // 4' config.yaml)
export WORKER_DISK=$(yq -e eval '.workers.disk_size_gb // 250' config.yaml)
export WORKER_STORAGE_PROFILE=$(yq -e eval '.workers.storage_profile // "*"' config.yaml)
export WORKER_INIT_REPLICA=$(yq -e eval '.workers.initial_machinedeployment_replicas // 3' config.yaml)
export WORKER_MIN_REPLICA=$(yq -e eval '.workers.cluster_autoscaler_min_replicas // 3' config.yaml)
export WORKER_MAX_REPLICA=$(yq -e eval '.workers.cluster_autoscaler_max_replicas // 5' config.yaml)

sed "s|\(vcd_url[ \t]*=[ \t]*\)\".*\"|\1\"${VCD_URL}\"|g" -i terraform/terraform.tfvars.tmp
sed "s|\(vcd_user[ \t]*=[ \t]*\)\".*\"|\1\"${VCD_USER}\"|g" -i terraform/terraform.tfvars.tmp
sed "s|\(vcd_password[ \t]*=[ \t]*\)\".*\"|\1\"${VCD_PASSWORD}\"|g" -i terraform/terraform.tfvars.tmp
sed "s|\(vcd_org[ \t]*=[ \t]*\)\".*\"|\1\"${VCD_ORG}\"|g" -i terraform/terraform.tfvars.tmp
sed "s|\(vcd_vdc[ \t]*=[ \t]*\)\".*\"|\1\"${VCD_VDC}\"|g" -i terraform/terraform.tfvars.tmp
sed "s|\(vcd_edge_gateway_name[ \t]*=[ \t]*\)\".*\"|\1\"${VCD_EDGEGATEWAY}\"|g" -i terraform/terraform.tfvars.tmp

sed "s|\(cluster_hostname[ \t]*=[ \t]*\)\".*\"|\1\"${KUBERNETES_HOSTNAME}\"|g" -i terraform/terraform.tfvars.tmp
sed "s|\(cluster_name[ \t]*=[ \t]*\)\".*\"|\1\"${VCD_CLUSTER}\"|g" -i terraform/terraform.tfvars.tmp
sed "s|\(catalog_name[ \t]*=[ \t]*\)\".*\"|\1\"${VCD_CATALOG}\"|g" -i terraform/terraform.tfvars.tmp

sed "s|\(control_plane_disk_storage_profile[ \t]*=[ \t]*\)\".*\"|\1\"${CP_STORAGE_PROFILE}\"|g" -i terraform/terraform.tfvars.tmp
sed "s|\(worker_disk_storage_profile[ \t]*=[ \t]*\)\".*\"|\1\"${WORKER_STORAGE_PROFILE}\"|g" -i terraform/terraform.tfvars.tmp

sed "s|\(control_plane_memory[ \t]*=[ \t]*\)[0-9]*|\1${CP_MEMORY}|g" -i terraform/terraform.tfvars.tmp
sed "s|\(control_plane_cpus[ \t]*=[ \t]*\)[0-9]*|\1${CP_CPU}|g" -i terraform/terraform.tfvars.tmp
sed "s|\(control_plane_disk_size_mb[ \t]*=[ \t]*\)[0-9]*|\1${CP_DISK}|g" -i terraform/terraform.tfvars.tmp
sed "s|\(worker_memory[ \t]*=[ \t]*\)[0-9]*|\1${WORKER_MEMORY}|g" -i terraform/terraform.tfvars.tmp
sed "s|\(worker_cpus[ \t]*=[ \t]*\)[0-9]*|\1${WORKER_CPU}|g" -i terraform/terraform.tfvars.tmp
sed "s|\(worker_disk_size_gb[ \t]*=[ \t]*\)[0-9]*|\1${WORKER_DISK}|g" -i terraform/terraform.tfvars.tmp

sed "s|\(control_plane_vm_count[ \t]*=[ \t]*\)[0-9]*|\1${CP_VM_COUNT}|g" -i terraform/terraform.tfvars.tmp
sed "s|\(initial_machinedeployment_replicas[ \t]*=[ \t]*\)[0-9]*|\1${WORKER_INIT_REPLICA}|g" -i terraform/terraform.tfvars.tmp
sed "s|\(cluster_autoscaler_min_replicas[ \t]*=[ \t]*\)[0-9]*|\1${WORKER_MIN_REPLICA}|g" -i terraform/terraform.tfvars.tmp
sed "s|\(cluster_autoscaler_max_replicas[ \t]*=[ \t]*\)[0-9]*|\1${WORKER_MAX_REPLICA}|g" -i terraform/terraform.tfvars.tmp

cat terraform/terraform.tfvars.tmp > terraform/terraform.tfvars
rm -f terraform/terraform.tfvars.tmp || true
# ======================================================================================================================

#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "tools" ]]; then
	cd ..
fi

# ======================================================================================================================
echo " "

BASTION_HOST=$(cat terraform/output.json | jq -r .kubeone_api.value.endpoint)
# BASTION_HOST=$(cat terraform/output.json | jq -r .kubeone_hosts.value.control_plane.bastion)
BASTION_PORT=$(cat terraform/output.json | jq -r .kubeone_hosts.value.control_plane.bastion_port)
BASTION_USER=$(cat terraform/output.json | jq -r .kubeone_hosts.value.control_plane.bastion_user)

echo "SSH into bastion host [${BASTION_USER}@${BASTION_HOST}:${BASTION_PORT}]:"

ssh "${BASTION_USER}@${BASTION_HOST}" -p ${BASTION_PORT} -A
# ======================================================================================================================

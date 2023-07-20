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

CONTROL_PLANES=$(cat terraform/output.json | jq -r .kubeone_hosts.value.control_plane.private_address)
CONTROL_PLANE_PORT=$(cat terraform/output.json | jq -r .kubeone_hosts.value.control_plane.ssh_port)
CONTROL_PLANE_USER=$(cat terraform/output.json | jq -r .kubeone_hosts.value.control_plane.ssh_user)
# ======================================================================================================================

CONTROL_PLANE_INDEX=1
echo "${CONTROL_PLANES}" | jq -cr '.[]' | while read CONTROL_PLANE_IP; do
	echo "Connecting to control-plane ${CONTROL_PLANE_INDEX} [${CONTROL_PLANE_IP}] ..."

	if (( $CONTROL_PLANE_INDEX == 1 )); then
		tmux new-window -n 'kubeone-control-plane' "bash -c 'ssh \"${BASTION_USER}@${BASTION_HOST}\" -p ${BASTION_PORT} -A -t ssh \"${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}\" -p ${CONTROL_PLANE_PORT} -o \"StrictHostKeyChecking=no\" -o \"UserKnownHostsFile=/dev/null\"'"
		tmux select-window -t ':kubeone-control-plane'
	else
		tmux split-window -t ':kubeone-control-plane' -l 1 "bash -c 'ssh \"${BASTION_USER}@${BASTION_HOST}\" -p ${BASTION_PORT} -A -t ssh \"${CONTROL_PLANE_USER}@${CONTROL_PLANE_IP}\" -p ${CONTROL_PLANE_PORT} -o \"StrictHostKeyChecking=no\" -o \"UserKnownHostsFile=/dev/null\"'"
		tmux select-layout -t ':kubeone-control-plane' tiled
	fi
	CONTROL_PLANE_INDEX=$(( CONTROL_PLANE_INDEX + 1 ))
done

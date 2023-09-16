#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "deployments" ]]; then
	cd ..
fi

# chart source: ./wireguard
repository="-"
chart="wireguard"
version="0.0.1"
namespace="${chart}"

wireguard_server_address=$(yq -e eval '.kubernetes.wireguard.serverAddress // "10.242.42.1/24"' config.yaml)
wireguard_server_key=$(yq -e eval '.kubernetes.wireguard.privateKey' config.yaml)
cat > "deployments/${chart}.values.yaml" <<EOF
wireguard:
  serverAddress: ${wireguard_server_address}
  privateKey: ${wireguard_server_key}
  clients: []
EOF
yq -e eval '.wireguard.clients = (load("config.yaml") | .kubernetes.wireguard.clients // [])' -i "deployments/${chart}.values.yaml"
deployments/install-chart.sh "${repository}" "${chart}" "${namespace}" "${version}" "deployments/${chart}.values.yaml"

echo " "
echo "================================================================================================================="
echo "WireGuard VPN has been installed, consult the README.md on how to configure your local wg0 interface"
echo "================================================================================================================="

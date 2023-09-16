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

cat > "deployments/${chart}.values.yaml" <<EOF
wireguard:
  serverAddress: 10.242.42.1/24
  privateKey: aFNRgUHsMqyrj7cwWwsSKQvkEgXqTbJxiuTOjU3KB1c=

  clients:
  - name: workstation
    publicKey: pTAAvK3WkMy1MHgTlWJCdvoNpMSEy/WnfNblV96XUQw=
    allowedIPs: 10.242.42.5/32
EOF
deployments/install-chart.sh "${repository}" "${chart}" "${namespace}" "${version}" "deployments/${chart}.values.yaml"

echo " "
echo "================================================================================================================="
echo "WireGuard VPN has been installed, consult the README.md on how to configure your local wg0 interface"
echo "================================================================================================================="

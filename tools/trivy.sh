#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "tools" ]]; then
	cd ..
fi

# ======================================================================================================================
echo " "
echo "running Trivy scan for Kubernetes ..."

#trivy k8s --report=all --slow --format=json --output=trivy.json cluster
trivy k8s --report=all --slow --format=table --output=trivy.out cluster

echo " "
echo "================================================================================================================="
echo "Scan complete, the result is available in [trivy.out]"
echo "================================================================================================================="
# ======================================================================================================================

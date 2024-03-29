#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "deployments" ]]; then
	cd ..
fi

set +u
if [[ -z "${KUBECONFIG}" ]]; then
  KUBECONFIG="kubeone-kubeconfig"
fi
set -u

if [[ "$#" -ne 5 ]]; then
    echo "usage: ./install-chart.sh <repo> <chart> <namespace> <version> <values>"
    exit 1
fi

repository=$1
chart=$2
namespace=$3
version=$4
values=$5

echo " "
if helm history --kubeconfig "${KUBECONFIG}" --max 1 --namespace "${namespace}" "${chart}" 2>/dev/null | grep "FAILED" | cut -f1 | grep -q 1; then
	helm uninstall --kubeconfig "${KUBECONFIG}" --wait --namespace "${namespace}" "${chart}"
fi

REPO_URL=""
if [[ "${repository}" != "-" ]]; then
	REPO_URL="--repo ${repository}"
fi
CHART_NAME="${chart}"
if [[ "${repository}" == "-" ]]; then
	CHART_NAME="./deployments/${chart}"
fi

echo "installing chart [${chart}] ..."
helm upgrade --kubeconfig "${KUBECONFIG}" \
	--install --create-namespace --dependency-update \
	--cleanup-on-fail --atomic --wait --timeout "15m" \
	--values "${values}" \
	--namespace "${namespace}" \
	${REPO_URL} \
	--version "${version}" \
	"${chart}" "${CHART_NAME}"

echo " "
helm list --all --namespace "${namespace}"

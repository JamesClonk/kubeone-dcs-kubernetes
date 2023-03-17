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
    echo "usage: ./install-chart.sh <repo> <release> <chart> <version> <values>"
    exit 1
fi

repository=$1
release=$2
chart=$3
version=$4
values=$5
namespace="${release}"

helm repo add "${release}" "${repository}"
helm search repo "${release}"
helm list --all --namespace "${namespace}"

echo " "
if helm history --kubeconfig "${KUBECONFIG}" --max 1 --namespace "${namespace}" "${release}" 2>/dev/null | grep "FAILED" | cut -f1 | grep -q 1; then
	helm uninstall --kubeconfig "${KUBECONFIG}" --wait --namespace "${namespace}" "${release}"
fi

helm upgrade --kubeconfig "${KUBECONFIG}" \
	--install --create-namespace --dependency-update \
	--cleanup-on-fail --atomic --wait --timeout "10m" \
	--values "${values}" \
	--namespace "${namespace}" \
	--repo "${repository}" \
	--version "${version}" \
	"${release}" "${chart}"

echo " "
helm list --all --namespace "${namespace}"

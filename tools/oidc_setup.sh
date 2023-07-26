#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "tools" ]]; then
	cd ..
fi

# ======================================================================================================================
echo " "
echo "setting up OIDC for Kubernetes ..."

cluster_hostname=$(yq -e eval '.kubernetes.hostname' config.yaml)
oidc_secret=$(yq -e eval '.kubernetes.oidc.secret' config.yaml)
kubectl oidc-login setup \
	--oidc-issuer-url=https://dex.${cluster_hostname}/dex \
	--oidc-client-id=kubernetes \
	--oidc-client-secret=${oidc_secret} \
	--oidc-extra-scope=email,groups,profile 2>/dev/null

decode_base64_url() {
	local len=$((${#1} % 4))
	local result="$1"
	if [ $len -eq 2 ]; then result="$1"'=='
	elif [ $len -eq 3 ]; then result="$1"'='
	fi
	echo "$result" | tr '_-' '/+' | openssl enc -d -base64
}
decode_jwt(){
	decode_base64_url $(echo -n $1 | cut -d "." -f 2) | jq .
}
OIDC_TOKEN=$(kubectl oidc-login get-token \
        --oidc-issuer-url=https://dex.${cluster_hostname}/dex \
        --oidc-client-id=kubernetes \
        --oidc-client-secret=${oidc_secret} \
        --oidc-extra-scope=email \
        --oidc-extra-scope=groups \
        --oidc-extra-scope=profile)
JWT=$(echo "${OIDC_TOKEN}" | jq -r '.status.token')
OIDC_SUB=$(decode_jwt ${JWT} | jq -r .sub)

echo "preparing ClusterRoleBinding for oidc-cluster-admin ..."
kubectl create clusterrolebinding oidc-cluster-admin --clusterrole=cluster-admin --user="oidc:${OIDC_SUB}" -o yaml --dry-run=client | kubectl apply -f -
#kubectl create clusterrolebinding oidc-cluster-admin --clusterrole=cluster-admin --user="https://dex.${cluster_hostname}/dex#${OIDC_SUB}" -o yaml --dry-run=client | kubectl apply -f -

echo "configuring \"oidc\" user in [${KUBECONFIG}] ..."
kubectl config set-credentials oidc \
	--exec-api-version=client.authentication.k8s.io/v1beta1 \
	--exec-command=kubectl \
	--exec-arg=oidc-login \
	--exec-arg=get-token \
	--exec-arg=--oidc-issuer-url=https://dex.${cluster_hostname}/dex \
	--exec-arg=--oidc-client-id=kubernetes \
	--exec-arg=--oidc-client-secret=${oidc_secret} \
	--exec-arg=--oidc-extra-scope=email \
	--exec-arg=--oidc-extra-scope=groups \
	--exec-arg=--oidc-extra-scope=profile

echo " "
echo "================================================================================================================="
echo "Try to use it with: kubectl --user=oidc get namespaces"
echo "================================================================================================================="

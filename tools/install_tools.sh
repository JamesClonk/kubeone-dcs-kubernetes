#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "tools" ]]; then
	cd ..
fi

# ======================================================================================================================
# alternative to sha256sum
if [ -z $(command -v sha256sum) ]; then
	function sha256sum() { openssl sha256 "$@" | awk '{print $2}'; }
fi

function install_tool {
	local -r tool_name="$1"; shift
	local -r tool_url="$1"; shift
	local -r tool_checksum="$1"; shift
	echo " -> checking [${tool_name}] ..."
	CHECKSUM_EXIT=0
	sha256sum "$HOME/bin/${tool_name}" 2>/dev/null | grep "${tool_checksum}" >/dev/null || CHECKSUM_EXIT=$?
	if [ ${CHECKSUM_EXIT} -ne 0 ]; then
		rm -f "$HOME/bin/${tool_name}" >/dev/null || true
		echo " -> downloading [${tool_name}] ..."
		wget -q "${tool_url}" -O "$HOME/bin/${tool_name}" 2>/dev/null
		chmod +x "$HOME/bin/${tool_name}"
	fi
	sha256sum "$HOME/bin/${tool_name}" | grep "${tool_checksum}" >/dev/null || (echo "checksum failed for [${tool_name}]"; exit 1)
}

function install_tool_from_zipfile {
	local -r tool_path="$1"; shift
	local -r tool_name="$1"; shift
	local -r tool_url="$1"; shift
	local -r tool_checksum="$1"; shift
	echo " -> checking [${tool_name}] ..."
	CHECKSUM_EXIT=0
	sha256sum "$HOME/bin/${tool_name}" 2>/dev/null | grep "${tool_checksum}" >/dev/null || CHECKSUM_EXIT=$?
	if [ ${CHECKSUM_EXIT} -ne 0 ]; then
		rm -f "$HOME/bin/${tool_name}" >/dev/null || true
		echo " -> downloading [${tool_name}] ..."
		wget -q "${tool_url}" -O "$HOME/bin/${tool_name}.zip" 2>/dev/null
		echo " -> unpacking [${tool_name}.zip] ..."
		unzip -p "$HOME/bin/${tool_name}.zip" "${tool_path}" > "$HOME/bin/${tool_name}"
		chmod +x "$HOME/bin/${tool_name}"
		rm -f "$HOME/bin/${tool_name}.zip"
	fi
	sha256sum "$HOME/bin/${tool_name}" | grep "${tool_checksum}" >/dev/null || (echo "checksum failed for [${tool_name}]"; exit 1)
}

function install_tool_from_tarball {
	local -r tool_path="$1"; shift
	local -r tool_name="$1"; shift
	local -r tool_url="$1"; shift
	local -r tool_checksum="$1"; shift
	echo " -> checking [${tool_name}] ..."
	CHECKSUM_EXIT=0
	sha256sum "$HOME/bin/${tool_name}" 2>/dev/null | grep "${tool_checksum}" >/dev/null || CHECKSUM_EXIT=$?
	if [ ${CHECKSUM_EXIT} -ne 0 ]; then
		rm -f "$HOME/bin/${tool_name}" >/dev/null || true
		echo " -> downloading [${tool_name}] ..."
		wget -q "${tool_url}" -O "$HOME/bin/${tool_name}.tgz" 2>/dev/null
		echo " -> unpacking [${tool_name}.tgz] ..."
		STRIP_COMPONENTS=$(echo "${tool_path}" | awk -F"/" '{print NF-1}')
		tar -xvzf "$HOME/bin/${tool_name}.tgz" --strip-components=${STRIP_COMPONENTS} -C "$HOME/bin/" "${tool_path}" >/dev/null
		chmod +x "$HOME/bin/${tool_name}"
		rm -f "$HOME/bin/${tool_name}.tgz"
	fi
	sha256sum "$HOME/bin/${tool_name}" | grep "${tool_checksum}" >/dev/null || (echo "checksum failed for [${tool_name}]"; exit 1)
}
# ======================================================================================================================

# ======================================================================================================================
echo " "
echo "Installing CLI tools into [~/bin]:"

if [ ! -d "$HOME/bin" ]; then
	mkdir "$HOME/bin"
fi
export PATH="$HOME/bin:$PATH"

OS=$(uname)
if [ ${OS} == "Darwin" ]; then
	ARCH=$(uname -p)
	if [ ${ARCH} == "arm" ]; then
		echo "-> downloading binaries for Apple Silicon MacOSX ..."
		install_tool "kubectl" "https://storage.googleapis.com/kubernetes-release/release/v1.25.8/bin/darwin/arm64/kubectl" "6519e273017590bd8b193d650af7a6765708f1fed35dcbcaffafe5f33872dfb4"
		install_tool "jq" "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-osx-amd64" "5c0a0a3ea600f302ee458b30317425dd9632d1ad8882259fcaf4e9b868b2b1ef"
		install_tool_from_zipfile "kubeone" "kubeone" "https://github.com/kubermatic/kubeone/releases/download/v1.6.2/kubeone_1.6.2_darwin_arm64.zip" "6119c779cfef51ceb50d8ca6ccad55a8409fbcc75046a76c9db40197ec85b773"
		install_tool_from_zipfile "terraform" "terraform" "https://releases.hashicorp.com/terraform/1.2.9/terraform_1.2.9_darwin_arm64.zip" "98f73281fd89a4bac7426149b9f2de8df492eb660b9441f445894dd112fd2c5c"
		install_tool_from_tarball "darwin-arm64/helm" "helm" "https://get.helm.sh/helm-v3.10.3-darwin-arm64.tar.gz" "b5176d9b89ff43ac476983f58020ee2407ed0cbb5b785f928a57ff01d2c63754"
	else
		echo "-> downloading binaries for Intel MacOSX ..."
		install_tool "kubectl" "https://storage.googleapis.com/kubernetes-release/release/v1.25.8/bin/darwin/amd64/kubectl" "4fc94a62065d25f8048272da096e1c5e3bd22676752fb3a24537e4ad62a33382"
		install_tool "jq" "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-osx-amd64" "5c0a0a3ea600f302ee458b30317425dd9632d1ad8882259fcaf4e9b868b2b1ef"
		install_tool_from_zipfile "kubeone" "kubeone" "https://github.com/kubermatic/kubeone/releases/download/v1.6.2/kubeone_1.6.2_darwin_amd64.zip" "ac4b003da67aa9ee900421be353259b82364ff9dc5180502939ab9afbf0bb5cf"
		install_tool_from_zipfile "terraform" "terraform" "https://releases.hashicorp.com/terraform/1.2.9/terraform_1.2.9_darwin_amd64.zip" "4b7b4179653c5d501818d8523575e86e60f901506b986d035f2aa6870a810f24"
		install_tool_from_tarball "darwin-amd64/helm" "helm" "https://get.helm.sh/helm-v3.10.3-darwin-amd64.tar.gz" "8f422d213a9f3530fe516c8b69be74059d89b9954b1afadb9ae6dc81edb52615"
	fi
else
	echo "-> downloading binaries for Linux ..."
	install_tool "kubectl" "https://storage.googleapis.com/kubernetes-release/release/v1.26.6/bin/linux/amd64/kubectl" "ee23a539b5600bba9d6a404c6d4ea02af3abee92ad572f1b003d6f5a30c6f8ab"
	install_tool "jq" "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64" "af986793a515d500ab2d35f8d2aecd656e764504b789b66d7e1a0b727a124c44"
	install_tool_from_zipfile "kubeone" "kubeone" "https://github.com/kubermatic/kubeone/releases/download/v1.6.2/kubeone_1.6.2_linux_amd64.zip" "3586b92e0c8e7a18384ffccfa160faf25290ecf86828419df71720947f82fdb6"
	install_tool_from_zipfile "terraform" "terraform" "https://releases.hashicorp.com/terraform/1.2.9/terraform_1.2.9_linux_amd64.zip" "70fa1a9c71347e7b220165b9c06df0a55f5af57dad8135f14808b343d1b5924a"
	install_tool_from_tarball "linux-amd64/helm" "helm" "https://get.helm.sh/helm-v3.10.3-linux-amd64.tar.gz" "cc5223b23fd2ccdf4c80eda0acac7a6a5c8cdb81c5b538240e85fe97aa5bc3fb"
fi
# ======================================================================================================================
echo " "

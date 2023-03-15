.DEFAULT_GOAL := help
SHELL := /bin/bash

ROOT_DIR=$(realpath .)
SSH_KEY="${ROOT_DIR}/ssh_key_id_rsa"
SSH_PUB_KEY="${SSH_KEY}.pub"
OS_IMAGE="ubuntu-20.04-server-cloudimg-amd64.ova"

# ======================================================================================================================
.PHONY: help
## help: prints this help message
help:
	@echo "Usage:"
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' |  sed -e 's/^/ /'
# ======================================================================================================================

# ======================================================================================================================
.PHONY: check-env
## check-env: verifies current working environment meets all requirements
check-env:
	which terraform
	which kubeone
	test -f "${OS_IMAGE}" || curl -s https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.ova > "${OS_IMAGE}"
	test -f "${SSH_KEY}" || ssh-keygen -t rsa -b 4096 -f "${SSH_KEY}" -N ''
	chmod 640 "${SSH_PUB_KEY}" && chmod 600 "${SSH_KEY}"
	ssh-add "${SSH_KEY}" || true
	kubeone version > ${ROOT_DIR}/kubeone.version.json
# ======================================================================================================================

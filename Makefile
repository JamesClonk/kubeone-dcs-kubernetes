.DEFAULT_GOAL := help
SHELL := /bin/bash

ROOT_DIR=$(realpath .)
TERRAFORM_DIR="${ROOT_DIR}/terraform"
SSH_KEY="${ROOT_DIR}/ssh_key_id_rsa"
SSH_PUB_KEY="${SSH_KEY}.pub"
OS_IMAGE="${TERRAFORM_DIR}/ubuntu-20.04-server-cloudimg-amd64.ova"
CONFIG_FILE="kubeone.yaml"
CREDENTIALS_FILE="credentials.yaml"

CLUSTER_NAME="KubeOne"

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
	test -f "${TERRAFORM_DIR}/main.tf" || kubeone init --provider vmware-cloud-director --terraform --path ${TERRAFORM_DIR} --cluster-name ${CLUSTER_NAME} -c ${CREDENTIALS_FILE}
# ======================================================================================================================

# ======================================================================================================================
.PHONY: terraform
## terraform: provision all infrastructure
terraform: check-env terraform-init terraform-apply terraform-output

.PHONY: terraform-init
## terraform-init: initialize terraform
terraform-init:
	cd ${TERRAFORM_DIR} && terraform init

.PHONY: terraform-check
## terraform-check: validate terraform configuration and show plan
terraform-check:
	cd ${TERRAFORM_DIR} && \
		terraform validate && \
		terraform plan

.PHONY: terraform-apply
## terraform-apply: apply terraform configuration and provision infrastructure
terraform-apply:
	cd ${TERRAFORM_DIR} && \
		terraform apply -auto-approve

.PHONY: terraform-refresh
## terraform-refresh: refresh and view terraform state
terraform-refresh:
	cd ${TERRAFORM_DIR} && \
		terraform refresh

.PHONY: terraform-output
## terraform-output: output terraform information into file for kubeone
terraform-output:
	cd ${TERRAFORM_DIR} && \
		terraform output -json > output.json

.PHONY: terraform-destroy
## kterraform-destroy: delete and cleanup infrastructure
terraform-destroy:
	cd ${TERRAFORM_DIR} && \
		terraform destroy

#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "deployments" ]]; then
	cd ..
fi

# chart source: https://github.com/falcosecurity/charts
repository="https://falcosecurity.github.io/charts"
chart="falco"
version="3.4.1"
namespace="${chart}"

cluster_hostname=$(yq -e eval '.kubernetes.hostname' config.yaml)
cat > "deployments/${chart}.values.yaml" <<EOF
scc:
  create: false

driver:
  enabled: true
  kind: ebpf
  ebpf:
    hostNetwork: false
    leastPrivileged: true

collectors:
  enabled: true
  docker:
    enabled: false
  containerd:
    enabled: true
    socket: /run/containerd/containerd.sock
  crio:
    enabled: false
  kubernetes:
    enabled: true

falcosidekick:
  enabled: true
  replicaCount: 1
  loki:
    hostport: "http://loki.loki.svc.cluster.local:3100"
    endpoint: "/loki/api/v1/push"
    # -- minimum priority of event to use this output, order is 'emergency\|alert\|critical\|error\|warning\|notice\|informational\|debug or ""'
    minimumpriority: ""
    checkcert: false
  webui:
    enabled: true
    replicaCount: 1
    ingress:
      enabled: true
      annotations:
        nginx.ingress.kubernetes.io/ssl-redirect: "true"
        nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
        nginx.ingress.kubernetes.io/auth-signin: "https://oauth2-proxy.${cluster_hostname}/oauth2/start"
        nginx.ingress.kubernetes.io/auth-url: "https://oauth2-proxy.${cluster_hostname}/oauth2/auth"
        cert-manager.io/cluster-issuer: "lets-encrypt"
      hosts:
      - host: falco.${cluster_hostname}
        paths:
        - path: /
      tls:
      - secretName: falco-ui-tls
        hosts:
        - falco.${cluster_hostname}
EOF
deployments/install-chart.sh "${repository}" "${chart}" "${namespace}" "${version}" "deployments/${chart}.values.yaml"

echo " "
echo "================================================================================================================="
echo "Falco Security has been installed, visit: https://falco.${cluster_hostname}"
echo "The default login will be 'admin:admin'"
echo "================================================================================================================="

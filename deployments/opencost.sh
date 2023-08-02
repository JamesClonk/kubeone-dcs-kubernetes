#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "deployments" ]]; then
	cd ..
fi

# chart source: https://github.com/opencost/opencost-helm-chart
repository="https://opencost.github.io/opencost-helm-chart"
chart="opencost"
version="1.14.5"
namespace="${chart}"

cluster_hostname=$(yq -e eval '.kubernetes.hostname' config.yaml)
cat > "deployments/${chart}.values.yaml" <<EOF
service:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9003"

opencost:
  exporter:
    extraEnv:
      CONFIG_PATH: /tmp/opencost-config
    extraVolumeMounts:
    - mountPath: /tmp/opencost-config
      name: opencost-config
  prometheus:
    external:
      enabled: false
    internal:
      enabled: true
      namespaceName: prometheus
      serviceName: prometheus-server
      port: 80
  ui:
    ingress:
      enabled: true
      ingressClassName: nginx
      annotations:
        nginx.ingress.kubernetes.io/ssl-redirect: "true"
        nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
        nginx.ingress.kubernetes.io/auth-signin: "https://oauth2-proxy.${cluster_hostname}/oauth2/start"
        nginx.ingress.kubernetes.io/auth-url: "https://oauth2-proxy.${cluster_hostname}/oauth2/auth"
        cert-manager.io/cluster-issuer: "lets-encrypt"
      hosts:
      - host: opencost.${cluster_hostname}
        paths:
        - /
      tls:
      - secretName: opencost-tls
        hosts:
        - opencost.${cluster_hostname}

extraVolumes:
- name: opencost-config
  configMap:
    name: opencost-config

EOF
deployments/install-chart.sh "${repository}" "${chart}" "${namespace}" "${version}" "deployments/${chart}.values.yaml"
echo " "

# additional configuration, add a ConfigMap
cat > "deployments/${chart}.cm.yaml" <<EOF
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: opencost-config
  namespace: ${namespace}
data:
  default.json: |
    {
        "provider": "custom",
        "description": "Default prices based on DCS Price List",
        "CPU": "0.02777",
        "RAM": "0.01254 ",
        "storage": "0.00048",
        "zoneNetworkEgress": "0.0",
        "regionNetworkEgress": "0.0",
        "internetNetworkEgress": "0.0"
    }
EOF
kubectl -n ${namespace} apply -f "deployments/${chart}.cm.yaml"

echo " "
echo "================================================================================================================="
echo "OpenCost has been installed, visit: https://opencost.${cluster_hostname}"
echo "================================================================================================================="

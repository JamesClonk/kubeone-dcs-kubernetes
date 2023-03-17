#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "deployments" ]]; then
	cd ..
fi

repository="https://grafana.github.io/helm-charts"
chart="grafana"
version="6.52.4"
namespace="${chart}"

kubeapi_hostname=$(cat terraform/output.json | jq -r .kubeone_api.value.endpoint)
cat > "deployments/${chart}.values.yaml" <<EOF
deploymentStrategy:
  type: Recreate
persistence:
  enabled: true
  size: 5Gi
ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
  - grafana.${kubeapi_hostname}
  tls:
  - secretName: grafana-tls
    hosts:
    - grafana.${kubeapi_hostname}
  annotations:
    cert-manager.io/cluster-issuer: "lets-encrypt"
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus-server.prometheus.svc.cluster.local
      access: proxy
      isDefault: true
    - name: Loki
      type: loki
      url: http://loki.loki.svc.cluster.local:3100
dashboardProviders:
  dashboardproviders.yaml:
    apiVersion: 1
    providers:
    - name: 'default'
      orgId: 1
      folder: ''
      type: file
      disableDeletion: false
      editable: true
      options:
        path: /var/lib/grafana/dashboards/default
dashboards:
  default:
    node-exporter:
      gnetId: 1860
      revision: 27
    ingress-controller:
      url: https://raw.githubusercontent.com/swisscom/terraform-dcs-kubernetes/master/deployments/dashboards/ingress-controller.json
      token: ''
    cilium-agent:
      url: https://raw.githubusercontent.com/swisscom/terraform-dcs-kubernetes/master/deployments/dashboards/cilium-agent.json
      token: ''
    cilium-operator:
      url: https://raw.githubusercontent.com/swisscom/terraform-dcs-kubernetes/master/deployments/dashboards/cilium-operator.json
      token: ''
    hubble:
      url: https://raw.githubusercontent.com/swisscom/terraform-dcs-kubernetes/master/deployments/dashboards/hubble.json
      token: ''
EOF
deployments/install-chart.sh "${repository}" "${chart}" "${version}" "deployments/${chart}.values.yaml"

echo " "
echo "================================================================================================================="
echo "Grafana has been installed, visit: https://grafana.${kubeapi_hostname}"
echo "Get the admin password: kubectl -n grafana get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo"
echo "================================================================================================================="
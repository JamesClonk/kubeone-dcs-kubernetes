#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "deployments" ]]; then
	cd ..
fi

# chart source: https://github.com/grafana/helm-charts
repository="https://grafana.github.io/helm-charts"
chart="grafana"
version="6.57.4"
namespace="${chart}"

cluster_hostname=$(yq -e eval '.kubernetes.hostname' config.yaml)
oidc_secret=$(yq -e eval '.kubernetes.oidc.secret' config.yaml)
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
  - grafana.${cluster_hostname}
  tls:
  - secretName: grafana-tls
    hosts:
    - grafana.${cluster_hostname}
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "lets-encrypt"

grafana.ini:
  analytics:
    check_for_updates: false
  auth:
    disable_login_form: true
    disable_signout_menu: true
    skip_org_role_sync: true
    oauth_allow_insecure_email_lookup: true
  auth.anonymous:
    enabled: false
  auth.basic:
    enabled: false
  auth.proxy:
    enabled: false
  auth.generic_oauth:
    enabled: true
    name: Dex
    auto_login: true
    allow_sign_up: true
    client_id: grafana
    client_secret: "${oidc_secret}"
    auth_url: https://dex.${cluster_hostname}/dex/auth
    token_url: https://dex.${cluster_hostname}/dex/token
    api_url: https://dex.${cluster_hostname}/dex/userinfo
    skip_org_role_sync: true
    scopes: openid groups email profile
  users:
    allow_sign_up: false
    auto_assign_org: true
    auto_assign_org_role: Admin
    verify_email_enabled: false
  security:
    cookie_secure: true
    cookie_samesite: lax
  log:
    mode: console
  grafana_net:
    url: https://grafana.net
  paths:
    data: /var/lib/grafana/
    logs: /var/log/grafana
    plugins: /var/lib/grafana/plugins
    provisioning: /etc/grafana/provisioning
  server:
    domain: grafana.${cluster_hostname}
    root_url: https://grafana.${cluster_hostname}

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
EOF
deployments/install-chart.sh "${repository}" "${chart}" "${namespace}" "${version}" "deployments/${chart}.values.yaml"

echo " "
echo "================================================================================================================="
echo "Grafana has been installed, visit: https://grafana.${cluster_hostname}"
echo "To get the local admin password if necessary (username 'admin'), run the following command:"
echo "kubectl -n grafana get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo"
echo "================================================================================================================="

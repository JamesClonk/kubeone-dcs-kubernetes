#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "deployments" ]]; then
  cd ..
fi

# chart source: https://github.com/dexidp/helm-charts
repository="https://charts.dexidp.io"
chart="dex"
version="0.15.2"
namespace="${chart}"

cluster_hostname=$(yq -e eval '.kubernetes.hostname' config.yaml)
oidc_secret=$(yq -e eval '.kubernetes.oidc.secret' config.yaml)
admin_password=$(yq -e eval '.kubernetes.admin_password' config.yaml)
cat > "deployments/${chart}.values.yaml" <<EOF
ingress:
  enabled: true
  ingressClassName: nginx
  hosts:
  - host: dex.${cluster_hostname}
    paths:
    - path: /
      pathType: ImplementationSpecific
  tls:
  - secretName: dex-tls
    hosts:
    - dex.${cluster_hostname}
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "lets-encrypt"

config:
  issuer: https://dex.${cluster_hostname}/dex
  storage:
    type: kubernetes
    config:
      inCluster: true

  oauth2:
    skipApprovalScreen: true
  web:
    http: 0.0.0.0:5556
  telemetry:
    http: 0.0.0.0:5558

  enablePasswordDB: true
  staticPasswords:
  - email: "admin@${cluster_hostname}"
    hash: "${admin_password}"
    username: "admin@${cluster_hostname}"
    userID: "08efa7f1-7459-434f-9815-fd5b8b92a5d0"

  staticClients:
  - id: kubernetes
    name: Kubernetes
    redirectURIs:
    - 'http://localhost:8000'
    secret: "${oidc_secret}"
  - id: oauth2-proxy
    name: oauth2-proxy
    redirectURIs:
    - 'https://oauth2-proxy.${cluster_hostname}/oauth2/callback'
    secret: "${oidc_secret}"
  - id: grafana
    name: grafana
    redirectURIs:
    - 'https://grafana.${cluster_hostname}/login/generic_oauth'
    secret: "${oidc_secret}"

  # connectors:
  #   - type: github
  #     id: github
  #     name: GitHub
  #     config:
  #       clientID: <your github app client ID here>
  #       clientSecret: <your github app client secret here>
  #       redirectURI: https://dex.${cluster_hostname}/dex/callback
  #       # you can configure the connector further, for example by restricting it to only a certain org or team.
  #       # These restrictions depend on the provider, check the Dex documentation for more info.
  #       #orgs:
  #       #- name: exampleorg
EOF
deployments/install-chart.sh "${repository}" "${chart}" "${namespace}" "${version}" "deployments/${chart}.values.yaml"

echo " "
echo "================================================================================================================="
echo "Dex has been installed."
echo "To setup OIDC for your cluster run the command: 'make oidc-setup'"
echo "================================================================================================================="

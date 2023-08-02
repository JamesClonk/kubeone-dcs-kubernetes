#!/bin/bash
set -e
set -u
set -o pipefail
if [[ "$(basename ${PWD})" == "deployments" ]]; then
  cd ..
fi

# chart source: https://github.com/oauth2-proxy/manifests
repository="https://oauth2-proxy.github.io/manifests"
chart="oauth2-proxy"
version="6.16.1"
namespace="${chart}"

cluster_hostname=$(yq -e eval '.kubernetes.hostname' config.yaml)
oidc_secret=$(yq -e eval '.kubernetes.oidc.secret' config.yaml)
oidc_cookie=$(yq -e eval '.kubernetes.oidc.cookie' config.yaml)
cat > "deployments/${chart}.values.yaml" <<EOF
config:
  clientID: "oauth2-proxy"
  clientSecret: "${oidc_secret}"
  cookieSecret: "${oidc_cookie}"

  configFile: |-
    email_domains = [ "*" ]
    # email_domains = [ "${cluster_hostname}" ]
    upstreams = [ "file:///dev/null" ]

    redirect_url = "https://oauth2-proxy.${cluster_hostname}/oauth2/callback"
    whitelist_domains = ".${cluster_hostname}"
    cookie_domains = ".${cluster_hostname}"

    provider = "oidc"
    oidc_issuer_url = "https://dex.${cluster_hostname}/dex"

    cookie_expire = "168h"
    cookie_secure = "true"
    cookie_httponly = "true"
    cookie_samesite = "lax"

authenticatedEmailsFile:
  enabled: false

ingress:
  enabled: true
  className: nginx
  hosts:
  - oauth2-proxy.${cluster_hostname}
  tls:
  - secretName: oauth2-proxy-tls
    hosts:
    - oauth2-proxy.${cluster_hostname}
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/server-snippet: |
      large_client_header_buffers 4 32k;
    cert-manager.io/cluster-issuer: "lets-encrypt"

proxyVarsAsSecrets: true

podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "44180"

httpScheme: http

htpasswdFile:
  enabled: false

sessionStorage:
  type: cookie

redis:
  enabled: false

metrics:
  enabled: true
  port: 44180
  servicemonitor:
    enabled: false
EOF
deployments/install-chart.sh "${repository}" "${chart}" "${namespace}" "${version}" "deployments/${chart}.values.yaml"

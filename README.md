# kubeone-dcs-kubernetes

[![Build](https://img.shields.io/github/actions/workflow/status/swisscom/kubeone-dcs-kubernetes/master.yml?branch=master&label=Build)](https://github.com/swisscom/kubeone-dcs-kubernetes/actions/workflows/master.yml)
[![License](https://img.shields.io/badge/License-Apache--2.0-lightgrey)](https://github.com/swisscom/kubeone-dcs-kubernetes/blob/master/LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Kubernetes-blue)](https://kubernetes.io/)
[![IaC](https://img.shields.io/badge/IaC-Terraform-purple)](https://www.terraform.io/)

Deploy Kubernetes with [KubeOne](https://www.kubermatic.com/products/kubermatic-kubeone/) on vCloud / [Swisscom DCS+](https://dcsguide.scapp.swisscom.com/)

-----

Table of Contents
=================
* [Kubernetes cluster with KubeOne](#kubernetes-cluster-with-kubeone)
  + [Architecture](#architecture)
  + [Components on cluster](#components-on-cluster)
* [How to deploy](#how-to-deploy)
  + [Requirements](#requirements)
    - [DCS+ resources](#dcs-resources)
      * [Virtual Data Center](#virtual-data-center)
      * [Edge Gateway](#edge-gateway)
      * [API User](#api-user)
    - [Local CLI tools](#local-cli-tools)
  + [Configuration](#configuration)
    - [Hostname](#hostname)
  + [Installation](#installation)
* [Troubleshooting](#troubleshooting)
* [Q&A](#q-a)
  + [Why have shell scripts for deployments?](#why-have-shell-scripts-for-deployments)

## Kubernetes cluster with KubeOne

### Architecture
![DCS+ KubeOne Architecture](https://raw.githubusercontent.com/JamesClonk/kubeone-dcs-kubernetes/data/dcs_kubeone.png)

### Components on cluster

| Component | Type | Description |
| --- | --- | --- |
| [Cilium](https://cilium.io/) | Networking | An open-source, cloud native and eBPF-based Kubernetes CNI that is providing, securing and observing network connectivity between container workloads |
| [vCloud CSI driver](https://github.com/vmware/cloud-director-named-disk-csi-driver) | Storage | Container Storage Interface (CSI) driver for VMware Cloud Director |
| [Ingress NGINX](https://kubernetes.github.io/ingress-nginx/) | Routing | Provides HTTP traffic routing, load balancing, SSL termination and name-based virtual hosting |
| [Cert Manager](https://cert-manager.io/) | Certificates | Cloud-native, automated TLS certificate management and [Let's Encrypt](https://letsencrypt.org/) integration for Kubernetes |
| [Kubernetes Dashboard](https://github.com/kubernetes/dashboard) | Dashboard | A general purpose, web-based UI for Kubernetes clusters that allows users to manage and troubleshoot applications on the cluster, as well as manage the cluster itself |
| [Prometheus](https://prometheus.io/) | Metrics | An open-source systems monitoring and alerting platform, collects and stores metrics in a time series database |
| [Loki](https://grafana.com/oss/loki/) | Logs | A horizontally scalable, highly available log aggregation and storage system |
| [Promtail](https://grafana.com/docs/loki/latest/clients/promtail/) | Logs | An agent which collects and ships the contents of logs on Kubernetes into the Loki log storage |
| [Grafana](https://grafana.com/oss/grafana/) | Dashboard | Allows you to query, visualize, alert on and understand all of your Kubernetes metrics and logs |
| [Kured](https://kured.dev/) | System | A daemonset that performs safe automatic node reboots when needed by the package management system of the underlying OS |

## How to deploy

### Requirements

#### Local CLI tools

For deploying a Kubernetes cluster with this module you will need to have all the following CLI tools installed on your machine:
- [kubeone](https://docs.kubermatic.com/kubeone/v1.6/getting-kubeone/)
- [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- [helm](https://helm.sh/docs/intro/install/)
- [curl](https://curl.se/)
- [jq](https://stedolan.github.io/jq/)
- [git](https://git-scm.com/)
- [make](https://www.gnu.org/software/make/)

This module has so far only been tested running under Linux and MacOSX. Your experience with Windows tooling may vary.

## Q&A

### Why have shell scripts for deployments?

Why not using just `helm install ...` or KubeOne's `addon` or `helmReleases` functionality, and have custom shell scripts for each and every additional Helm chart that gets installed into the cluster?

Consider this: https://github.com/prometheus-community/helm-charts/tree/prometheus-19.7.2/charts/prometheus#to-190

Some Helm charts require manual actions to be taken by users when upgrading between major/minor versions of theirs. Your Helm upgrade might fail if you miss these steps (actually it will almost definitely fail in the mentioned example). While the easy way out would be to just casually mention such issues in the release notes (if you don't forget), that's not exactly very user friendly however.
From experience Helm has also otherwise quite often proven itself to be flaky during upgrade operations, frequently getting stuck in pending or failed states.

Shell scripts on the other hand can contain very specific *if/else/case* code paths for any such upgrade scenarios to be taken into consideration and implemented accordingly.

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
* [Up and running](#up-and-running)
  + [kubectl](#kubectl)
  + [DCS+](#dcs)
  + [Kubernetes-Dashboard](#kubernetes-dashboard)
  + [Grafana](#grafana)
  + [OpenCost](#opencost)
  + [Cilium Hubble UI](#cilium-hubble-ui)
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

## Up and running

TODO: ...

### kubectl

There should be a `kubeone-kubeconfig` file written to the root directory. This file contains the configuration and credentials to access and manage your Kubernetes cluster. You can set the environment variable `KUBECONFIG` to this file to have your `kubectl` CLI use it for the remainder of your terminal session.
```bash
$ export KUBECONFIG=kubeone-kubeconfig
```
Now you can run any `kubectl` commands you want to manage your cluster, for example:
```bash
$ kubectl cluster-info
Kubernetes control plane is running at https://my-kubernetes.my-domain.com:6443
CoreDNS is running at https://my-kubernetes.my-domain.com:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
KubeDNSUpstream is running at https://my-kubernetes.my-domain.com:6443/api/v1/namespaces/kube-system/services/kube-dns-upstream:dns/proxy

$ kubectl get nodes -o wide
NAME                                   STATUS   ROLES           AGE     VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
kubeone-cp-1                           Ready    control-plane   4d22h   v1.25.6   192.168.1.10   <none>        Ubuntu 20.04.5 LTS   5.4.0-144-generic   containerd://1.6.18
kubeone-cp-2                           Ready    control-plane   4d22h   v1.25.6   192.168.1.11   <none>        Ubuntu 20.04.5 LTS   5.4.0-144-generic   containerd://1.6.18
kubeone-cp-3                           Ready    control-plane   4d22h   v1.25.6   192.168.1.12   <none>        Ubuntu 20.04.5 LTS   5.4.0-144-generic   containerd://1.6.18
kubeone-worker-pool-64578b898d-kbbgs   Ready    <none>          4d16h   v1.25.6   192.168.1.54   <none>        Ubuntu 20.04.5 LTS   5.4.0-144-generic   containerd://1.6.18
kubeone-worker-pool-64578b898d-sqlhk   Ready    <none>          4d16h   v1.25.6   192.168.1.55   <none>        Ubuntu 20.04.5 LTS   5.4.0-144-generic   containerd://1.6.18

$ kubectl get namespaces
NAME                   STATUS   AGE
cert-manager           Active   4d21h
cloud-init-settings    Active   4d22h
default                Active   4d22h
grafana                Active   4d20h
ingress-nginx          Active   4d21h
kube-node-lease        Active   4d22h
kube-public            Active   4d22h
kube-system            Active   4d22h
kubernetes-dashboard   Active   4d21h
loki                   Active   4d20h
opencost               Active   4d20h
prometheus             Active   4d21h
promtail               Active   4d21h
reboot-coordinator     Active   4d22h
```

### DCS+
![DCS+ Dashboard](https://raw.githubusercontent.com/JamesClonk/kubeone-dcs-kubernetes/data/dcs_dashboard.png)

By default (unless configured otherwise in your `terraform.tfvars`) once the deployment is done you should see something similar to above in your DCS+ Portal. There will be 1 bastion host (a jumphost VM for SSH access to the other VMs), 3 control plane VMs for the Kubernetes server nodes, and several worker VMs that are responsible for running your Kubernetes workload.

### Kubernetes-Dashboard
![DCS+ Dashboard](https://raw.githubusercontent.com/JamesClonk/kubeone-dcs-kubernetes/data/dcs_k8s_dashboard.png)

The Kubernetes dashboard will automatically be available to you after installation under [https://dashboard.my-kubernetes.my-domain.com](https://grafana.my-kubernetes.my-domain.com) (with *my-kubernetes.my-domain.com* being the value you configured in `terraform.tfvars -> kubeapi_hostname`)

In order to login you will first need to request a temporary access token from your Kubernetes cluster:
```bash
$ kubectl -n kubernetes-dashboard create token kubernetes-dashboard --duration "60m"
```
With this token you will be able to sign in into the dashboard.
> **Note**: This token is only valid temporarily, you will need request a new one each time it has expired.

### Grafana
![DCS+ Grafana](https://raw.githubusercontent.com/JamesClonk/kubeone-dcs-kubernetes/data/dcs_grafana.png)

The Grafana dashboard will automatically be available to you after installation under [https://grafana.my-kubernetes.my-domain.com](https://grafana.my-kubernetes.my-domain.com) (with *my-kubernetes.my-domain.com* being the value you configured in `terraform.tfvars -> kubeapi_hostname`)

The username for accessing Grafana will be `admin` and the password can be retrieved from Kubernetes by running:
```bash
$ kubectl -n grafana get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

### OpenCost
![DCS+ Grafana](https://raw.githubusercontent.com/JamesClonk/kubeone-dcs-kubernetes/data/dcs_opencost.png)

To access the OpenCost dashboard you have to initialize a localhost port-forwarding towards the service on the cluster, since it is not exposed externally:
```bash
$ kubectl -n opencost port-forward service/opencost 9090:9090
```
This will setup a port-forwarding for `localhost:9090` on your machine. Now you can open the OpenCost dashboard in your browser by going to [http://localhost:9090/](http://localhost:9090/).

### Cilium Hubble UI
![DCS+ Hubble](https://raw.githubusercontent.com/JamesClonk/kubeone-dcs-kubernetes/data/dcs_cilium_hubble.png)

The easiest way to access the Cilium Hubble UI is to download and install the [Cilium CLI](https://github.com/cilium/cilium-cli), and then simply run the following command:
```bash
$ cilium hubble ui
```
This will setup a port-forwarding in the background and open up a browser, pointing to the Hubble UI at [http://localhost:12000](http://localhost:12000).

## Troubleshooting

## Q&A

### Why have shell scripts for deployments?

Why not using just `helm install ...` or KubeOne's `addon` or `helmReleases` functionality, and have custom shell scripts for each and every additional Helm chart that gets installed into the cluster?

Consider this: https://github.com/prometheus-community/helm-charts/tree/prometheus-19.7.2/charts/prometheus#to-190

Some Helm charts require manual actions to be taken by users when upgrading between major/minor versions of theirs. Your Helm upgrade might fail if you miss these steps (actually it will almost definitely fail in the mentioned example). While the easy way out would be to just casually mention such issues in the release notes (if you don't forget), that's not exactly very user friendly however.
From experience Helm has also otherwise quite often proven itself to be flaky during upgrade operations, frequently getting stuck in pending or failed states.

Shell scripts on the other hand can contain very specific *if/else/case* code paths for any such upgrade scenarios to be taken into consideration and implemented accordingly.

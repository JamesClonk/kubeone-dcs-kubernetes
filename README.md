# kubeone-dcs-kubernetes

[![Build](https://img.shields.io/github/actions/workflow/status/swisscom/kubeone-dcs-kubernetes/master.yml?branch=master&label=Build)](https://github.com/swisscom/kubeone-dcs-kubernetes/actions/workflows/master.yml)
[![License](https://img.shields.io/badge/License-Apache--2.0-lightgrey)](https://github.com/swisscom/kubeone-dcs-kubernetes/blob/master/LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Kubernetes-blue)](https://kubernetes.io/)
[![IaC](https://img.shields.io/badge/IaC-Terraform-purple)](https://www.terraform.io/)

Deploy Kubernetes with [KubeOne](https://www.kubermatic.com/products/kubermatic-kubeone/) on vCloud / [Swisscom DCS+](https://dcsguide.scapp.swisscom.com/)

-----

Table of Contents
=================
* [Kubernetes clusters with KubeOne](#kubernetes-clusters-with-kubeone)
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
  + [Helm chart failures](#helm-chart-failures)
* [Q&A](#qa)
  + [Why have shell scripts for deployments?](#why-have-shell-scripts-for-deployments)

## Kubernetes clusters with KubeOne

This repository supports you in creating an autoscaling Kubernetes cluster with [KubeOne](https://github.com/kubermatic/kubeone) on [Swisscom DCS+](https://www.swisscom.ch/en/business/enterprise/offer/cloud/cloudservices/dynamic-computing-services.html) infrastructure. It also installs and manages additional deployments on the cluster, such as ingress-nginx, cert-manager and a whole set of logging/metrics/monitoring related components.
It consists of three main components:
- Infrastructure provisioning via [`/terraform/`](/terraform/)
- Kubernetes cluster and autoscaling workers via [`/kubeone.yaml`](/kubeone.yaml)
- Helm chart [`/deployments/`](/deployments/) for all additional components
Each of these is responsible for a specific subset of features provided by the overall solution.

The **terraform** module will provision resources on DCS+ and setup a private internal network (192.168.1.0/24 CIDR by default), attach an Edge Gateway with an external public IP and configure loadbalancing services, deploy a bastion host (jumphost) for external SSH access into the private network, and finally a set of Kubernetes control plane VMs.

The **kubeone** automation will then connect via SSH over the bastion host to all those control plane nodes and install a vanilla Kubernetes cluster on them. It will also install the [machine-controller](https://github.com/kubermatic/machine-controller) and [cluster-autoscaler](https://github.com/kubernetes/autoscaler), which will then dynamically provision additional VMs to be used as worker nodes for hosting your workload.

Finally the **deployments** component is responsible for installing other system components and software on to the Kubernetes cluster. It does most of its work through official Helm charts, plus some additional customization directly via kubectl / manifests and some shell scripting.

The final result is a fully functioning, highly available, autoscaling Kubernetes cluster, complete with all the batteries included you need to get you started. *Ingress* Controller for HTTP virtual hosting / routing, TLS certificate management with automatic Let's Encrypt certificates for all your HTTPS traffic, dynamic cluster-autoscaling of worker nodes, *PersistentVolume* support, and an entire monitoring stack for metrics and logs.

### Architecture
![DCS+ KubeOne Architecture](https://raw.githubusercontent.com/JamesClonk/kubeone-dcs-kubernetes/data/dcs_k8s.png)
#### KubeOne overview
![DCS+ KubeOne Infrastructure](https://d33wubrfki0l68.cloudfront.net/e03c9a4bf4744091c11730f7563cccfe859687e7/09afc/static/infrastructure-provider_kubeone_overview.png)

### Components on cluster

| Component | Type | Description |
| --- | --- | --- |
| [Cilium](https://cilium.io/) | Networking | An open-source, cloud native and eBPF-based Kubernetes CNI that is providing, securing and observing network connectivity between container workloads |
| [vCloud CSI driver](https://github.com/vmware/cloud-director-named-disk-csi-driver) | Storage | Container Storage Interface (CSI) driver for VMware Cloud Director |
| [Machine-Controller](https://github.com/kubermatic/machine-controller) | Compute | Dynamic creation of Kubernetes worker nodes on VMware Cloud Director |
| [Ingress NGINX](https://kubernetes.github.io/ingress-nginx/) | Routing | Provides HTTP traffic routing, load balancing, SSL termination and name-based virtual hosting |
| [Cert Manager](https://cert-manager.io/) | Certificates | Cloud-native, automated TLS certificate management and [Let's Encrypt](https://letsencrypt.org/) integration for Kubernetes |
| [Kubernetes Dashboard](https://github.com/kubernetes/dashboard) | Dashboard | A general purpose, web-based UI for Kubernetes clusters that allows users to manage and troubleshoot applications on the cluster, as well as manage the cluster itself |
| [Prometheus](https://prometheus.io/) | Metrics | An open-source systems monitoring and alerting platform, collects and stores metrics in a time series database |
| [Loki](https://grafana.com/oss/loki/) | Logs | A horizontally scalable, highly available log aggregation and storage system |
| [Promtail](https://grafana.com/docs/loki/latest/clients/promtail/) | Logs | An agent which collects and ships the contents of logs on Kubernetes into the Loki log storage |
| [Grafana](https://grafana.com/oss/grafana/) | Dashboard | Allows you to query, visualize, alert on and understand all of your Kubernetes metrics and logs |
| [OpenCost](https://www.opencost.io/) | Dashboard | Measure and visualize your infrastructure and container costs in real time |
| [Kured](https://kured.dev/) | System | A daemonset that performs safe automatic node reboots when needed by the package management system of the underlying OS |

## How to deploy

### Requirements

#### Local CLI tools

For deploying a Kubernetes cluster with this repository you will need to have all the following CLI tools installed on your machine:
- [kubeone](https://docs.kubermatic.com/kubeone/v1.6/getting-kubeone/)
- [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- [helm](https://helm.sh/docs/intro/install/)
- [curl](https://curl.se/)
- [jq](https://stedolan.github.io/jq/)
- [git](https://git-scm.com/)
- [make](https://www.gnu.org/software/make/)

This repository has so far only been tested running under Linux and MacOSX. Your experience with Windows tooling may vary.

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

By default (unless configured otherwise in your `terraform.tfvars`) once the deployment is done you should see something similar to the picture above in your DCS+ Portal. There will be 1 bastion host (a jumphost VM for SSH access to the other VMs), 3 control plane VMs for the Kubernetes server nodes, and several dynamically created worker VMs that are responsible for running your Kubernetes workload.

### Kubernetes-Dashboard
![DCS+ Dashboard](https://raw.githubusercontent.com/JamesClonk/kubeone-dcs-kubernetes/data/dcs_k8s_dashboard.png)

The Kubernetes dashboard will automatically be available to you after installation under [https://dashboard.my-kubernetes.my-domain.com](https://grafana.my-kubernetes.my-domain.com) (with *my-kubernetes.my-domain.com* being the value you configured in `terraform.tfvars -> cluster_hostname`)

In order to login you will first need to request a temporary access token from your Kubernetes cluster:
```bash
$ kubectl -n kubernetes-dashboard create token kubernetes-dashboard --duration "60m"
```
With this token you will be able to sign in into the dashboard.
> **Note**: This token is only valid temporarily, you will need request a new one each time it has expired.

### Grafana
![DCS+ Grafana](https://raw.githubusercontent.com/JamesClonk/kubeone-dcs-kubernetes/data/dcs_grafana.png)

The Grafana dashboard will automatically be available to you after installation under [https://grafana.my-kubernetes.my-domain.com](https://grafana.my-kubernetes.my-domain.com) (with *my-kubernetes.my-domain.com* being the value you configured in `terraform.tfvars -> cluster_hostname`)

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

### Helm chart failures

There could be an issue where a Helm chart deployment fails with an error message such as this:
```
Error: UPGRADE FAILED: another operation (install/upgrade/rollback) is in progress
```

In order to fix this issue the release has to either be deleted entirely or rolled back to a previous revision. The commands for rolling back would be the following:
```
# check for failed deployments
helm list --failed -a -A
# show history of a specific chart
helm history [chart] -n [namespace]
# rollback chart to a previous revision
helm rollback [chart] [revision]
```

`helm history` should return information regarding the chart revisions, their status and description as to whether it completed successfully or not.
Run the Helm deployment again once the chart rollback is successful and it is not listed as *pending* anymore.

## Q&A

### Why have shell scripts for deployments?

Why not using just `helm install ...` directly or KubeOne's `addon` or `helmReleases` functionality, and instead have custom shell scripts for each and every additional Helm chart that gets installed into the cluster?

Consider these examples: https://github.com/prometheus-community/helm-charts/tree/prometheus-19.7.2/charts/prometheus#to-190 or https://grafana.com/docs/loki/latest/installation/helm/upgrade-from-2.x/

Some Helm charts require manual actions to be taken by users when upgrading between major/minor versions of theirs. Your Helm upgrade might fail if you miss these steps (actually it will almost definitely fail in the mentioned examples). While the easy way out would be to just casually mention such issues in the release notes (if you don't forget), it's not exactly very user friendly however.

From experience Helm has also otherwise proven itself to be flaky quite often during upgrade operations, frequently getting stuck in pending or failed states, and in general not being a very effective tool for deployments and resource management. Much better tools, like for example [kapp](https://carvel.dev/kapp/), would be available for this, but "unfortunately" the ubiquity of pre-packaged Helm charts makes it necessary to turn a blind eye towards Helm's shortcomings in that regard.

Customized shell scripts on the other hand can contain very specific *if/else/case* code paths for any such upgrade scenarios to be taken into consideration and implemented accordingly.

See [`/deployments/prometheus.sh`](https://github.com/JamesClonk/kubeone-dcs-kubernetes/blob/e11db365f1d85a76da61ecac162240065a4d1b4d/deployments/prometheus.sh#L27-L35) as an example, it deals specifically with the upgrade path from *pre-v15.0* to *v18.0+*.

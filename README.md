# kubeone-dcs-kubernetes

[![Build](https://img.shields.io/github/actions/workflow/status/swisscom/kubeone-dcs-kubernetes/master.yml?branch=master&label=Build)](https://github.com/swisscom/kubeone-dcs-kubernetes/actions/workflows/master.yml)
[![License](https://img.shields.io/badge/License-Apache--2.0-lightgrey)](https://github.com/swisscom/kubeone-dcs-kubernetes/blob/master/LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Kubernetes-blue)](https://kubernetes.io/)
[![IaC](https://img.shields.io/badge/IaC-Terraform-purple)](https://www.terraform.io/)

Deploy Kubernetes with [Kubermatic KubeOne](https://www.kubermatic.com/products/kubermatic-kubeone/) on vCloud / [Swisscom DCS+](https://dcsguide.scapp.swisscom.com/)

-----

Table of Contents
=================
* [Kubernetes clusters with KubeOne](#kubernetes-clusters-with-kubeone)
  + [Architecture](#architecture)
  + [Components on cluster](#components-on-cluster)
* [How to deploy](#how-to-deploy)
  + [Requirements](#requirements)
    - [DCS+ resources](#dcs-resources)
      * [Dynamic Data Center](#dynamic-data-center)
      * [Edge Gateway](#edge-gateway)
      * [API User](#api-user)
    - [Local CLI tools](#local-cli-tools)
  + [Configuration](#configuration)
    - [Terraform](#terraform)
      * [Hostname](#hostname)
      * [Cluster sizing recommendations](#cluster-sizing-recommendations)
        + [Small / Starter](#small--starter)
        + [Medium / Default values](#medium--default-values)
        + [Large](#large)
    - [KubeOne](#kubeone)
  + [Installation](#installation)
    - [Infrastructure](#infrastructure)
    - [Kubernetes](#kubernetes)
    - [Deployments](#deployments)
* [Up and running](#up-and-running)
  + [kubectl](#kubectl)
  + [DCS+](#dcs)
  + [Kubernetes-Dashboard](#kubernetes-dashboard)
  + [Prometheus](#prometheus)
  + [Grafana](#grafana)
  + [Longhorn](#longhorn)
  + [OpenCost](#opencost)
  + [Cilium Hubble UI](#cilium-hubble-ui)
* [Troubleshooting](#troubleshooting)
  + [Helm chart failures](#helm-chart-failures)
  + [Node eviction blocked](#node-eviction-blocked)
* [Q&A](#qa)
  + [Why have shell scripts for deployments?](#why-have-shell-scripts-for-deployments)

## Kubernetes clusters with KubeOne

This repository supports you in creating an autoscaling Kubernetes cluster with [Kubermatic](https://www.kubermatic.com/) [KubeOne](https://github.com/kubermatic/kubeone) on [Swisscom DCS+](https://www.swisscom.ch/en/business/enterprise/offer/cloud/cloudservices/dynamic-computing-services.html) infrastructure. It also installs and manages additional deployments on the cluster, such as ingress-nginx, cert-manager, longhorn and a whole set of logging/metrics/monitoring related components.
It consists of three main components:
- Infrastructure provisioning via [`/terraform/`](/terraform/)
- Kubernetes cluster and autoscaling workers via [`/kubeone.yaml`](/kubeone.yaml)
- Helm chart [`/deployments/`](/deployments/) for all additional components
Each of these is responsible for a specific subset of features provided by the overall solution.

The **Terraform** module will provision resources on DCS+ and setup a private internal network (192.168.1.0/24 CIDR by default), attach an Edge Gateway with an external public IP and configure loadbalancing services, deploy a bastion host (jumphost) for external SSH access into the private network, and finally a set of Kubernetes control plane VMs.

The **KubeOne** automation will then connect via SSH over the bastion host to all those control plane nodes and install a vanilla Kubernetes cluster on them. It will also install the [machine-controller](https://github.com/kubermatic/machine-controller) and [cluster-autoscaler](https://github.com/kubernetes/autoscaler), which will then dynamically provision additional VMs to be used as worker nodes for hosting your workload.

Finally the **Deployments** component is responsible for installing other system components and software on to the Kubernetes cluster. It does most of its work through official Helm charts, plus some additional customization directly via kubectl / manifests and some shell scripting.

The final result is a fully functioning, highly available, autoscaling Kubernetes cluster, complete with all the batteries included you need to get you started. *Ingress* Controller for HTTP virtual hosting / routing, TLS certificate management with automatic Let's Encrypt certificates for all your HTTPS traffic, dynamic cluster-autoscaling of worker nodes, *PersistentVolume* support, and an entire monitoring stack for metrics and logs.

### Architecture
![DCS+ KubeOne Architecture](https://raw.githubusercontent.com/JamesClonk/kubeone-dcs-kubernetes/data/dcs_k8s.png)
#### KubeOne overview
![DCS+ KubeOne Infrastructure](https://d33wubrfki0l68.cloudfront.net/e03c9a4bf4744091c11730f7563cccfe859687e7/09afc/static/infrastructure-provider_kubeone_overview.png)

### Components on cluster

| Component | Type | Description |
| --- | --- | --- |
| [Cilium](https://cilium.io/) | Networking | An open-source, cloud native and eBPF-based Kubernetes CNI that is providing, securing and observing network connectivity between container workloads |
| [vCloud CSI](https://github.com/vmware/cloud-director-named-disk-csi-driver) | Storage (Default) | Container Storage Interface (CSI) driver for VMware vCloud Director |
| [Longhorn](https://longhorn.io/) | Storage (Alternative) | Highly available persistent storage for Kubernetes, provides cloud-native block storage with backup functionality |
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

To use this repository you will need to have a valid account / contract number on [Swisscom DCS+](https://dcsguide.scapp.swisscom.com/).

Configure your contract number (PRO-number) in `terraform.tfvars -> vcd_org` and `credentials.yaml -> VCD_ORG`.

#### DCS+ resources

For deploying a Kubernetes cluster with KubeOne on DCS+ you will need to manually create the following resources first before you can proceed:
- a VDC / Dynamic Data Center (DDC)
- an Edge Gateway with Internet in your VDC/DDC
- an API User (with OVA/OVF Import ExtraConfig permissions)

##### Dynamic Data Center

Login to the DCS+ management portal and go to [Catalog](https://portal.swisscomcloud.com/catalog/). From there you can order a new **Dynamic Data Center**. The *"Service Level"* does not matter for Kubernetes, pick anything you want.

See the official DCS+ documentation on [Dynamic Data Center](https://dcsguide.scapp.swisscom.com/ug3/dcs_portal.html#dynamic-data-center) for more information.

Configure the name of your newly created DDC in `terraform.tfvars -> vcd_vdc` and `credentials.yaml -> VCD_VDC`.

##### Edge Gateway

Login to the DCS+ management portal and go to [My Items](https://portal.swisscomcloud.com/my-items/) view. From here click on the right hand side on *"Actions"* and then select **Create Internet Access** for your *Dynamic Data Center*. Make sure to check the box *"Edge Gateway"* and then fill out all the other values. For *"IP Range Size"* you can select the smallest value available, this installation will only need one public IP for an external LoadBalancer. On *"Edge Gateway Configuration"* it is important that you select the **Large** configuration option to create an Edge Gateway with an advanced feature set, otherwise it will be missing loadbalancing features and not function correctly!

See the official DCS+ documentation on [Create Internet Access](https://dcsguide.scapp.swisscom.com/ug3/dcs_portal.html#internet-access) for more information.

Configure the name of this Edge Gateway in `terraform.tfvars -> vcd_edge_gateway_name`.

> **Note**: Also have a look in the vCloud Director web UI and check what the external/public IP assigned to this newly created Edge Gateway is by going to its **Configuration -> Gateway Interfaces** page and looking for the **Primary IP**. You will need this IP to set up DNS *A* and *CNAME* records with your Kubernetes cluster hostname.

##### API User

Login to the DCS+ management portal and go to [Catalog](https://portal.swisscomcloud.com/catalog/). From there you can order a new **vCloudDirector API User**. Make sure to leave *"Read only user?"* unchecked, otherwise your new API user will not be able to do anything!

See the official DCS+ documentation on [Cloud Director API Users](https://dcsguide.scapp.swisscom.com/ug3/dcs_portal.html#cloud-director-api-user) for more information.

> **Note**: Once you have created the API user, you will need contact Swisscom Support and request the additional permission **"vApp > Preserve ExtraConfig Elements during OVA Import and Export"** to be configured for that user, it is required if you want to use the vCloud-CSI in your Kubernetes cluster!

Configure the new API username and password in `terraform.tfvars -> vcd_user | vcd_password` and `credentials.yaml -> VCD_USER | VCD_PASSWORD`.
Make sure to also set the API URL at `vcd_url` and `VCD_URL` respectively. Check out the official DCS+ documentation on how to determine the API URL value, see [Cloud Director API - API access methods](https://dcsguide.scapp.swisscom.com/ug3/vcloud_director.html#api-access-methods).

#### Local CLI tools

For deploying a Kubernetes cluster with this repository you will need to have all the following CLI tools installed on your machine:
- [kubeone](https://docs.kubermatic.com/kubeone/v1.6/getting-kubeone/)
- [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- [helm](https://helm.sh/docs/intro/install/)
- [curl](https://curl.se/)
- [jq](https://stedolan.github.io/jq/)
- [git](https://git-scm.com/)
- [make](https://www.gnu.org/software/make/)

A quick way to get those CLI tools installed on your machine is to run the helper command `make install-tools`. This will download and install most of the required binaries in your home directory, under `~/bin/`. Make sure to add that directory to your $PATH environment variable afterwards.

```bash
# run the command
make install-tools

Installing CLI tools into [~/bin]:
-> downloading binaries for Linux ...
 -> checking [kubectl] ...
 -> downloading [kubectl] ...
 -> checking [jq] ...
 -> downloading [jq] ...
 -> checking [kubeone] ...
 -> downloading [kubeone] ...
 -> unpacking [kubeone.zip] ...
 -> checking [terraform] ...
 -> downloading [terraform] ...
 -> unpacking [terraform.zip] ...
 -> checking [helm] ...
 -> downloading [helm] ...
 -> unpacking [helm.tgz] ...

# add installation directory to your PATH
export PATH=$PATH:~/bin
```

This repository has so far only been tested running under Linux and MacOSX. Your experience with Windows tooling may vary.

### Configuration

#### Terraform

All data for the infrastructure provisioning part via Terraform lives in the [/terraform](/terraform) subdirectory of this repository, and all possible configuration variables are defined in the [variables.tf](/terraform/variables.tf) file. Most of them already have a sensible default value and only a small handful are required to be configured manually. For any such variable that does not have a default (or you want to set to a different value) you will have to create and add a configuration entry in your `terraform.tfvars` file.

To get you started quickly there is also an example configuration file included, [terraform.example.tfvars](/terraform/terraform.example.tfvars), which contains the minimal set of variables required to provision the infrastructure.

```terraform
vcd_url      = "https://vcd-pod-bravo.swisscomcloud.com/api"
vcd_user     = "api_vcd_my_username"
vcd_password = "my_password"

vcd_org         = "PRO-0123456789"
vcd_vdc         = "my-data-center"
vcd_edgegateway = "PRO-0123456789-my-edge-gateway"

cluster_hostname = "my-kubernetes.my-domain.com"
```

You can just copy this file over to `terraform.tfvars` and start editing it to fill in your values:
```bash
$ cp terraform/terraform.example.tfvars terraform/terraform.tfvars
$ vim terraform/terraform.tfvars
```

##### Hostname

The variable `cluster_hostname` plays an important role in setting up your Kubernetes cluster. Many of the components that are installed will have [Ingresses](https://kubernetes.io/docs/concepts/services-networking/ingress/) created and configured with that domain name as part of their hostname. For example Grafana will be made available on `https://grafana.<cluster_hostname>`.

In order for this to work correctly you should setup a new DNS **A** record for the domain name you want to be using, pointing it to the external/public IP of the Edge Gateway. Look for the IP in the vCloud Director web UI. After that you will also have to add a wildcard **CNAME** record, pointing to the newly created *A* record.

For example, if you want to use `my-kubernetes.my-domain.com`, the DNS entries would look something like this:
```bash
;ANSWER
*.my-kubernetes.my-domain.com. 600 IN CNAME my-kubernetes.my-domain.com.
my-kubernetes.my-domain.com. 600 IN A 147.5.206.13
```

##### Cluster sizing recommendations

There are also separate configuration variables for each aspect of the virtual machines that will be provisioned by Terraform initially and later on dynamically by the machine-controller and cluster-autoscaler components. These are all the variables starting with `control_plane_*` or `worker_*`, or ending with `*_replicas` in `variables.tf`.

Here are some examples for possible cluster size customizations:

###### Small / Starter
| Node type | Setting | Variable name | Value |
| --- | --- | --- | --- |
| Control plane | Number of VMs | `control_plane_vm_count` | `1` |
| Control plane | vCPUs | `control_plane_cpus` | `1` |
| Control plane | Memory (in MB) | `control_plane_memory` | `2048` |
| Worker | Initial number of VMs | `initial_machinedeployment_replicas` | `1` |
| Worker | Minimum number of VMs | `cluster_autoscaler_min_replicas` | `1` |
| Worker | Maximum number of VMs | `cluster_autoscaler_max_replicas` | `3` |
| Worker | vCPUs | `worker_cpus` | `2` |
| Worker | Memory (in MB) | `worker_memory` | `4096` |
| Worker | Disk size (in GB) | `worker_disk_size_gb` | `80` |

###### Medium / Default values
| Node type | Setting | Variable name | Value |
| --- | --- | --- | --- |
| Control plane | Number of VMs | `control_plane_vm_count` | `3` |
| Control plane | vCPUs | `control_plane_cpus` | `2` |
| Control plane | Memory (in MB) | `control_plane_memory` | `4096` |
| Worker | Initial number of VMs | `initial_machinedeployment_replicas` | `2` |
| Worker | Minimum number of VMs | `cluster_autoscaler_min_replicas` | `2` |
| Worker | Maximum number of VMs | `cluster_autoscaler_max_replicas` | `5` |
| Worker | vCPUs | `worker_cpus` | `4` |
| Worker | Memory (in MB) | `worker_memory` | `8192` |
| Worker | Disk size (in GB) | `worker_disk_size_gb` | `250` |

###### Large
| Node type | Setting | Variable name | Value |
| --- | --- | --- | --- |
| Control plane | Number of VMs | `control_plane_vm_count` | `3` |
| Control plane | vCPUs | `control_plane_cpus` | `4` |
| Control plane | Memory (in MB) | `control_plane_memory` | `4096` |
| Worker | Initial number of VMs | `initial_machinedeployment_replicas` | `5` |
| Worker | Minimum number of VMs | `cluster_autoscaler_min_replicas` | `3` |
| Worker | Maximum number of VMs | `cluster_autoscaler_max_replicas` | `15` |
| Worker | vCPUs | `worker_cpus` | `4` |
| Worker | Memory (in MB) | `worker_memory` | `16384` |
| Worker | Disk size (in GB) | `worker_disk_size_gb` | `150` |

> **Note**: The more worker nodes you have, the smaller the disk size gets that they need in order to distribute and cover all your `PersistentVolume` needs if you are using the Longhorn storage class. This is why the worker nodes in the *Large* cluster example actually have a smaller disk than in the *Medium* example. If you don't intend to use Longhorn volumes and mostly rely on the vCloud-CSI, you can reduce your worker disks to less than 100 GB each for example.

Set the amount of control plane nodes to either be 1, 3 or 5. They have to be an odd number for the quorum to work correctly, and anything above 5 is not really that beneficial anymore. For a highly-available setup usually the perfect number of control plane nodes is `3`.

The initial, minimum and maximum amount of worker nodes can be set to anything between 1 and 100. Do not set it to a number higher than that unless you know what you are doing, other variables would need to be changed too since by default the network configuration currently supports only a maximum of 100 worker nodes!

> **Note**: Please be aware that if you use only 1 worker or control plane VM your workload will not be highly-available anymore, for if any of these VMs crashes or becomes unavailable it might affect your running containers.

#### KubeOne

KubeOne's purpose is to install Kubernetes itself onto the virtual machines provisioned by Terraform. As part of that process it will also install machine-controller onto the cluster, a component which will allow Kubernetes via cluster-autoscaler to dynamically provision further virtual machines on Swisscom DCS+, serving as additional worker nodes for the cluster.

For KubeOne and the machine-controller to work correctly they will need to know about the infrastructure in advance and more specifically also the credentials necessary to interact with Swisscom DCS+.

To get you started quickly there is an example configuration file included, [credentials.example.yaml](/credentials.example.yaml), which contains all the values that must be configured first before using KubeOne.

```yaml
VCD_URL: https://vcd-pod-bravo.swisscomcloud.com/api
VCD_ORG: PRO-0123456789
VCD_VDC: my-data-center
VCD_USER: api_vcd_my_username
VCD_PASSWORD: my_password
```

You can just copy this file over to `credentials.yaml` and start editing it to fill in your values:
```bash
$ cp credentials.example.yaml credentials.yaml
$ vim credentials.yaml
```

The other file of interest is the main configuration file of KubeOne itself, [kubeone.yaml](/kubeone.yaml). In this file you can configure various aspects of the Kubernetes cluster setup it will perform, what version to install, what CNI to use, what CSI to use, etc..

Please refer to the [Kubermatic KubeOne - v1beta2 API Reference](https://docs.kubermatic.com/kubeone/v1.6/references/kubeone-cluster-v1beta2/) for a full list of all configuration settings available.

The `kubeone.yaml` provided in this repository should mostly already have sensible defaults and only really needs to be adjusted if you either don't want to make use of the vCloud-CSI for volumes on Kubernetes and set it as your default storage-class, or to adjust the `storageProfile` to match your Swisscom DCS+ storage.

Before you can use the vCloud-CSI you will need to open up a Service Request with Swisscom first in order to request your API user being able to upload OVF templates while preserving the `ExtraConfig: disk.EnableUUID=true` parameter. By default API users on DCS+ unfortunately do not have the necessary permissions unless explicitely requested. Without that permission the uploaded OS template and any VMs created based on it will not allow the vCloud-CSI to detect attached disks by UUID, and thus not function properly.
If you are sure your API user has the necessary permission, then all that is left to do is to modify the `default-storage-class` addon in `kubeone.yaml`, you will need to adjust the `storageProfile` of the `default-storage-class`:
```yaml
addons:
  addons:
  - name: default-storage-class
    params:
      storageProfile: Ultra Fast Storage A # adjust to a storage profile of your choice, see "VCD UI -> Data Centers -> Storage -> Storage Policies"
```
Please adjust the `storageProfile` to one of the storage policies available to you in your Swisscom DCS+ data center. You can view the storage policies from the DCS+ UI by clicking on **Data Centers** -> **Storage** -> **Storage Policies**.

> **Note**: When using the vCloud-CSI you must adjust the `storageProfile` and have the additional permissions for OVF upload on your user/API accounts, or *PersistentVolumes* will not work! Make sure that your API user has the necessary **"vApp > Preserve ExtraConfig Elements during OVA Import and Export"** permission!

If you do not want to go through the trouble of having to request these extra permission for your API users, then you simply don't need to deploy the vCloud-CSI. To disable it go into `kubeone.yaml` and comment out the `csi-vmware-cloud-director` and `default-storage-class` addons. This repository will then automatically configure Longhorn to be the default storage class on your cluster and use it provide volumes.

### Installation

:warning: If you are impatient and don't want to read any further then you can simply run this command after previously having [configured](#configuration) `terraform.tfstate`, `kubeone.yaml` and `credentials.yaml`:
```bash
make all
```
Continue reading for a detailed explanation on what this all entails.

---

This repository includes a `Makefile` in the root directory. All steps necessary to provision a Kubernetes cluster are defined within there.

To get a list of all possible `make` commands available, you can consult the help message:
```bash
$ make help

Usage:
  help                          print this help message
  all                           runs all steps to provision and setup Kubernetes
  check-env                     verify current working environment meets all requirements
  terraform                     provision all infrastructure
  terraform-init                initialize Terraform
  terraform-check               validate Terraform configuration and show plan
  terraform-apply               apply Terraform configuration and provision infrastructure
  terraform-refresh             refresh and view Terraform state
  terraform-output              output Terraform information into file for KubeOne
  terraform-destroy             delete and cleanup infrastructure
  kubeone                       run all KubeOne / Kubernetes provisioning steps
  kubeone-apply                 run KubeOne to deploy Kubernetes
  kubeone-kubeconfig            write kubeconfig file
  kubeone-generate-workers      generate a machinedeployments manifest for the cluster
  kubeone-apply-workers         apply machinedeployments to the cluster
  kubeone-addons                list KubeOne addons
  deployments                   install all deployments on Kubernetes
  deploy-longhorn               deploy/update Longhorn storage
  deploy-ingress-nginx          deploy/update Nginx Ingress-controller
  deploy-cert-manager           deploy/update Cert-Manager
  deploy-kubernetes-dashboard   deploy/update Kubernetes dashboard
  dashboard-token               create a temporary login token for Kubernetes dashboard
  deploy-prometheus             deploy/update Prometheus
  deploy-loki                   deploy/update Loki
  deploy-promtail               deploy/update Promtail
  deploy-grafana                deploy/update Grafana
  grafana-password              get the admin password for Grafana
  deploy-opencost               deploy/update OpenCost
```

#### Infrastructure

The first step towards our goal is to provision the infrastructure.

Install [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) on your machine if you do not have it already. See the section about [local CLI tools](#local-cli-tools) above for all required tools needed.

After you have configured `terraform.tfvars` you can start the entire Terraform infrastructure provisioning by simply typing:
```bash
$ make terraform
```
That command will run all necessary steps. If it is the first run then it is likely going to take quite a bit of time to finish, up to 15-20 minutes, as it needs to create a lot of new resources on DCS+. Just let it run until it finishes.

If you want to have more fine-grained control over the various steps being executed, you could also run them manually in this order:
```bash
$ make check-env # verifies current working environment meets all requirements
$ make terraform-init # initializes Terraform
$ make terraform-apply # applies Terraform configuration and provisions infrastructure
$ make terraform-output # outputs Terraform information into file for KubeOne
```

Each time before you provision or modify the infrastructure you can do a "dry-run" first and check what changes Terraform would do:
```bash
$ make terraform-check # validates Terraform configuration and shows plan
```
Everything shown here is what Terraform will create or modify for you in Swisscom DCS+.

#### Kubernetes

The second step is to setup (or upgrade) a Kubernetes cluster on our newly provisioned infrastructure with KubeOne.

Install [KubeOne](https://docs.kubermatic.com/kubeone/v1.6/getting-kubeone/) on your machine if you do not have it already. See the section about [local CLI tools](#local-cli-tools) above for all required tools needed.

After you have configured `kubeone.yaml` and `credentials.yaml` you can proceed with the installation of Kubernetes by typing:
```bash
$ make kubeone
```
That command will then connect via SSH over the bastion host to the previously provisioned control plane VMs and install Kubernetes on them.

> **Note**: The KubeOne commands will only work if you previously ran the Terraform steps, as they depend on output files being generated there.

If you want to have more fine-grained control over the various steps being executed, you could also run them manually in this order:
```bash
$ make check-env # verifies current working environment meets all requirements
$ make kubeone-apply # runs KubeOne to deploy Kubernetes
$ make kubeone-kubeconfig # writes the kubeconfig file
$ make kubeone-generate-workers # generates a machinedeployments manifest for the cluster
$ make kubeone-apply-workers # applies machinedeployments manifest to the cluster
```

#### Deployments

The final step is to deploy all other additional components on to the newly installed Kubernetes cluster.

Install [Helm](https://helm.sh/docs/intro/install/) on your machine if you do not have it already. See the section about [local CLI tools](#local-cli-tools) above for all required tools needed.

After you have installed Kubernetes via KubeOne you can install all additional components by typing:
```bash
$ make deployments
```
That command will then install a collection of useful addons and components via Helm charts onto your Kubernetes cluster.

All of them are optional and not strictly required, but provide quality-of-life improvements for your Kubernetes experience. If you want to have more fine-grained control over all the various components being installed, you could also deploy them manually and pick and choose which ones you want to install:
```bash
$ make deploy-ingress-nginx # deploys or updates Nginx Ingress-controller
$ make deploy-cert-manager # deploys or updates Cert-Manager
$ make deploy-kubernetes-dashboard # deploys or updates Kubernetes-Dashboard
$ make deploy-prometheus # deploys or updates Promethes
$ make deploy-loki # deploys or updates Loki
$ make deploy-promtail # deploys or updates Promtail
$ make deploy-grafana # deploys or updates Grafana
$ make deploy-opencost # deploys or updates OpenCost
```

## Up and running

Once the installation of all the components has finished you should have a fully functioning Kubernetes cluster up and running in your Swisscom DCS+ data center. Here are a few examples on how to access these components and the cluster itself:

### kubectl

There should be a `kubeone-kubeconfig` file written to the root directory. This file contains the configuration and credentials to access and manage your Kubernetes cluster. You can set the environment variable `KUBECONFIG` to this file to have your `kubectl` CLI use it automatically for the remainder of your terminal session.
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
longhorn-system        Active   4d22h
opencost               Active   4d20h
prometheus             Active   4d21h
promtail               Active   4d21h
reboot-coordinator     Active   4d22h
```

### DCS+
![DCS+ Dashboard](https://raw.githubusercontent.com/JamesClonk/kubeone-dcs-kubernetes/data/dcs_dashboard.png)

By default (unless configured otherwise in your `terraform.tfvars` or `kubeone.yaml`) once the deployment is done you should see something similar to the picture above in your DCS+ UI. There will be 1 bastion host (a jumphost VM for SSH access to the other VMs), 3 control plane VMs for the Kubernetes server nodes, and several dynamically created worker VMs that are responsible for running your Kubernetes workload.

### Kubernetes-Dashboard
![DCS+ Dashboard](https://raw.githubusercontent.com/JamesClonk/kubeone-dcs-kubernetes/data/dcs_k8s_dashboard.png)

The Kubernetes dashboard will automatically be available to you after the installation under [https://dashboard.my-kubernetes.my-domain.com](https://grafana.my-kubernetes.my-domain.com) (with *my-kubernetes.my-domain.com* being the value you configured in `terraform.tfvars -> cluster_hostname`)

In order to login you will first need to request a temporary access token from your Kubernetes cluster:
```bash
$ kubectl -n kubernetes-dashboard create token kubernetes-dashboard --duration "60m"
```
With this token you will be able to sign in into the dashboard.
> **Note**: This token is only valid temporarily, you will need request a new one each time it has expired.

### Prometheus
![DCS+ Prometheus](https://raw.githubusercontent.com/JamesClonk/kubeone-dcs-kubernetes/data/dcs_prometheus.png)

To access the Prometheus UI you have to initialize a localhost port-forwarding towards the service on the cluster, since it is not exposed externally:
```bash
$ kubectl -n prometheus port-forward service/prometheus-server 9090:80
```
This will setup a port-forwarding for `localhost:9090` on your machine. Now you can open the Prometheus UI in your browser by going to [http://localhost:9090/](http://localhost:9090/).

### Grafana
![DCS+ Grafana](https://raw.githubusercontent.com/JamesClonk/kubeone-dcs-kubernetes/data/dcs_grafana.png)

The Grafana dashboard will automatically be available to you after installation under [https://grafana.my-kubernetes.my-domain.com](https://grafana.my-kubernetes.my-domain.com) (with *my-kubernetes.my-domain.com* being the value you configured in `terraform.tfvars -> cluster_hostname`)

The username for accessing Grafana will be `admin` and the password can be retrieved from Kubernetes by running:
```bash
$ kubectl -n grafana get secret grafana -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

### Longhorn
![DCS+ Longhorn](https://raw.githubusercontent.com/JamesClonk/kubeone-dcs-kubernetes/data/dcs_longhorn.png)

To access the Longhorn dashboard you have to initialize a localhost port-forwarding towards the service on the cluster, since it is not exposed externally:
```bash
$ kubectl -n longhorn-system port-forward service/longhorn-frontend 9999:80
```
This will setup a port-forwarding for `localhost:9999` on your machine. Now you can open the Longhorn dashboard in your browser by going to [http://localhost:9999/#/dashboard](http://localhost:9999/).

### OpenCost
![DCS+ OpenCost](https://raw.githubusercontent.com/JamesClonk/kubeone-dcs-kubernetes/data/dcs_opencost.png)

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

### Node eviction blocked

Due to the nature of Longhorn and how it distributes volume replicas, it might happen that the draining and eviction of a Kubernetes node can get blocked. Longhorn tries to keep all its volumes (and their replicas) in a *`Healthy`* state and thus can block node eviction.

If you use Longhorn as your default storage class instead of the vCloud-CSI and you noticed that the cluster-autoscaler or machine-controller cannot remove an old node, scale down to fewer nodes, or a node remaining seemingly forever being stuck in an unschedulable state, then it might be because there are Longhorn volume replicas on those nodes.

To fix the issue, login to the Longhorn UI (check further [above](#longhorn) on how to do that), go to the *"Node"* tab, click on the hamburger menu of the affected node and then select *"Edit Node and Disks"*. In the popup menu you can then forcefully disable *"Node Scheduling"* and enable *"Eviction Requested"*. This will instruct Longhorn to migrate the remaining volume replicas to other available nodes, thus freeing up Kubernetes to fully drain and remove the old node.

## Q&A

### Why have shell scripts for deployments?

Why not using just `helm install ...` directly or KubeOne's `addon` or `helmReleases` functionality, and instead have custom shell scripts for each and every additional Helm chart that gets installed into the cluster?

Consider these examples: https://github.com/prometheus-community/helm-charts/tree/prometheus-19.7.2/charts/prometheus#to-190 or https://grafana.com/docs/loki/latest/installation/helm/upgrade-from-2.x/

Some Helm charts require manual actions to be taken by users when upgrading between major/minor versions of theirs. Your Helm upgrade might fail if you miss these steps (actually it will almost definitely fail in the mentioned examples). While the easy way out would be to just casually mention such issues in the release notes (if you don't forget), it's not exactly very user friendly however.

From experience Helm has also otherwise proven itself to be flaky quite often during upgrade operations, frequently getting stuck in pending or failed states, and in general not being a very effective tool for deployments and resource management. Much better tools, like for example [kapp](https://carvel.dev/kapp/), would be available for this, but "unfortunately" the ubiquity of pre-packaged Helm charts makes it necessary to turn a blind eye towards Helm's shortcomings in that regard.

Customized shell scripts on the other hand can contain very specific *if/else/case* code paths for any such upgrade scenarios to be taken into consideration and implemented accordingly.

See [`/deployments/prometheus.sh`](https://github.com/JamesClonk/kubeone-dcs-kubernetes/blob/e11db365f1d85a76da61ecac162240065a4d1b4d/deployments/prometheus.sh#L27-L35) as an example, it deals specifically with the upgrade path from *pre-v15.0* to *v18.0+*.

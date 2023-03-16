/*
Copyright 2022 The KubeOne Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

# Configure the VMware Cloud Director Provider
provider "vcd" {
  /*
  See https://registry.terraform.io/providers/vmware/vcd/latest/docs#argument-reference
  for config options reference
  */
  url                  = var.vcd_url
  auth_type            = "integrated"
  user                 = var.vcd_user
  password             = var.vcd_password
  org                  = var.vcd_org_name
  vdc                  = var.vcd_vdc_name
  allow_unverified_ssl = var.vcd_allow_insecure
  max_retry_timeout    = 120
  logging              = var.vcd_logging
}

locals {
  external_network_name = var.external_network_name == "" ? element([for net in data.vcd_edgegateway.edge_gateway.external_network : net.name if tolist(net.subnet)[0].use_for_default_route], 0) : var.external_network_name
  external_network_ip   = var.external_network_ip == "" ? data.vcd_edgegateway.edge_gateway.default_external_network_ip : var.external_network_ip

  cluster_autoscaler_min_replicas = var.cluster_autoscaler_min_replicas > 0 ? var.cluster_autoscaler_min_replicas : var.initial_machinedeployment_replicas
  cluster_autoscaler_max_replicas = var.cluster_autoscaler_max_replicas > 0 ? var.cluster_autoscaler_max_replicas : var.initial_machinedeployment_replicas
}

# Existing edge gateway in VDC
data "vcd_edgegateway" "edge_gateway" {
  name = var.vcd_edge_gateway_name
}

# Edge gateway settings
resource "vcd_edgegateway_settings" "edge_gateway" {
  edge_gateway_id         = data.vcd_edgegateway.edge_gateway.id
  lb_enabled              = true
  lb_acceleration_enabled = true
  lb_logging_enabled      = false

  fw_enabled                      = true
  fw_default_rule_logging_enabled = false
}

# Routed network that will be connected to the edge gateway
resource "vcd_network_routed" "network" {
  name        = "${var.cluster_name}-routed-network"
  description = "Routed network for ${var.cluster_name} vApp"

  edge_gateway = data.vcd_edgegateway.edge_gateway.name

  interface_type = var.network_interface_type

  gateway = var.gateway_ip

  dhcp_pool {
    start_address = var.dhcp_start_address
    end_address   = var.dhcp_end_address
  }

  dns1 = var.network_dns_server_1
  dns2 = var.network_dns_server_2

  depends_on = [vcd_edgegateway_settings.edge_gateway]
}

# Dedicated vApp for cluster resources; vms, disks, network, etc.
resource "vcd_vapp" "cluster" {
  name        = var.cluster_name
  description = "vApp for ${var.vcd_vdc_name} cluster"

  metadata_entry {
    key         = "provisioner"
    value       = "KubeOne"
    type        = "MetadataStringValue"
    user_access = "READWRITE"
    is_system   = false
  }
  metadata_entry {
    key         = "cluster_name"
    value       = var.cluster_name
    type        = "MetadataStringValue"
    user_access = "READWRITE"
    is_system   = false
  }
  metadata_entry {
    key         = "type"
    value       = "Kubernetes Cluster"
    type        = "MetadataStringValue"
    user_access = "READWRITE"
    is_system   = false
  }

  depends_on = [vcd_network_routed.network]
}

# Connect the dedicated routed network to vApp
resource "vcd_vapp_org_network" "network" {
  vapp_name = var.cluster_name

  org_network_name = vcd_network_routed.network.name

  depends_on = [vcd_vapp.cluster, vcd_network_routed.network]
}

# OS image catalog
resource "vcd_catalog" "catalog" {
  name = var.catalog_name

  delete_recursive = "true"
  delete_force     = "true"

  depends_on = [vcd_vapp.cluster]
}

# upload OS image
resource "vcd_catalog_vapp_template" "vapp_template" {
  catalog_id = vcd_catalog.catalog.id
  name       = var.template_name

  ova_path          = var.os_image_file
  upload_piece_size = 10
}

# Create VMs for bastion host
resource "vcd_vapp_vm" "bastion" {
  vapp_name     = vcd_vapp.cluster.name
  name          = "${var.cluster_name}-bastion"
  computer_name = "${var.cluster_name}-bastion"

  metadata_entry {
    key         = "provisioner"
    value       = "KubeOne"
    type        = "MetadataStringValue"
    user_access = "READWRITE"
    is_system   = false
  }
  metadata_entry {
    key         = "cluster_name"
    value       = var.cluster_name
    type        = "MetadataStringValue"
    user_access = "READWRITE"
    is_system   = false
  }
  metadata_entry {
    key         = "role"
    value       = "bastion"
    type        = "MetadataStringValue"
    user_access = "READWRITE"
    is_system   = false
  }

  guest_properties = {
    "instance-id" = "${var.cluster_name}-bastion"
    "hostname"    = "${var.cluster_name}-bastion"
    "public-keys" = file(var.ssh_public_key_file)
  }

  vapp_template_id = data.vcd_catalog_vapp_template.vapp_template.id

  # resource allocation for the VM
  memory                 = 1024
  cpus                   = 1
  cpu_cores              = 1
  cpu_hot_add_enabled    = true
  memory_hot_add_enabled = true
  accept_all_eulas       = true
  power_on               = true

  # Wait upto 5 minutes for IP addresses to be assigned
  network_dhcp_wait_seconds = 300

  network {
    type               = "org"
    name               = vcd_vapp_org_network.network.org_network_name
    ip_allocation_mode = "MANUAL"
    ip                 = cidrhost("${var.gateway_ip}/24", 5)
    is_primary         = true
  }

  depends_on = [vcd_vapp_org_network.network]
}

# Create VMs for control plane
resource "vcd_vapp_vm" "control_plane" {
  count         = var.control_plane_vm_count
  vapp_name     = vcd_vapp.cluster.name
  name          = "${var.cluster_name}-cp-${count.index + 1}"
  computer_name = "${var.cluster_name}-cp-${count.index + 1}"

  metadata_entry {
    key         = "provisioner"
    value       = "KubeOne"
    type        = "MetadataStringValue"
    user_access = "READWRITE"
    is_system   = false
  }
  metadata_entry {
    key         = "cluster_name"
    value       = var.cluster_name
    type        = "MetadataStringValue"
    user_access = "READWRITE"
    is_system   = false
  }
  metadata_entry {
    key         = "role"
    value       = "control-plane"
    type        = "MetadataStringValue"
    user_access = "READWRITE"
    is_system   = false
  }

  guest_properties = {
    "instance-id" = "${var.cluster_name}-cp-${count.index + 1}"
    "hostname"    = "${var.cluster_name}-cp-${count.index + 1}"
    "public-keys" = file(var.ssh_public_key_file)
  }

  vapp_template_id = data.vcd_catalog_vapp_template.vapp_template.id

  # resource allocation for the VM
  memory                 = var.control_plane_memory
  cpus                   = var.control_plane_cpus
  cpu_cores              = var.control_plane_cpu_cores
  cpu_hot_add_enabled    = true
  memory_hot_add_enabled = true
  accept_all_eulas       = true
  power_on               = true

  # Wait upto 5 minutes for IP addresses to be assigned
  network_dhcp_wait_seconds = 300

  network {
    type               = "org"
    name               = vcd_vapp_org_network.network.org_network_name
    ip_allocation_mode = "MANUAL"
    ip                 = cidrhost("${var.gateway_ip}/24", 10 + count.index)
    is_primary         = true
  }

  override_template_disk {
    bus_type        = "paravirtual"
    size_in_mb      = var.control_plane_disk_size
    bus_number      = 0
    unit_number     = 0
    storage_profile = var.control_plane_disk_storage_profile
  }

  depends_on = [vcd_vapp_org_network.network]
}

#################################### NAT and Firewall rules ####################################

# Create SNAT rule to access the Internet
resource "vcd_nsxv_snat" "rule_internet" {
  edge_gateway = data.vcd_edgegateway.edge_gateway.name
  network_type = "ext"
  network_name = local.external_network_name

  original_address   = "${var.gateway_ip}/24"
  translated_address = local.external_network_ip

  depends_on = [vcd_edgegateway_settings.edge_gateway]
}

# Create Hairpin SNAT rule
resource "vcd_nsxv_snat" "rule_internal" {
  edge_gateway = data.vcd_edgegateway.edge_gateway.name
  network_type = "org"
  network_name = vcd_network_routed.network.name

  original_address   = "${var.gateway_ip}/24"
  translated_address = var.gateway_ip

  depends_on = [vcd_edgegateway_settings.edge_gateway]
}

# Create DNAT rule to allow SSH from the Internet to bastion host
resource "vcd_nsxv_dnat" "rule_ssh_bastion" {
  edge_gateway = data.vcd_edgegateway.edge_gateway.name
  network_type = "ext"
  network_name = local.external_network_name

  original_address = local.external_network_ip
  original_port    = 22

  translated_address = vcd_vapp_vm.bastion.network[0].ip
  translated_port    = 22
  protocol           = "tcp"

  depends_on = [vcd_edgegateway_settings.edge_gateway]
}

# Create the firewall rule to access the Internet
resource "vcd_nsxv_firewall_rule" "rule_internet" {
  edge_gateway = data.vcd_edgegateway.edge_gateway.name
  name         = "${var.cluster_name}-firewall-rule-internet"

  action = "accept"

  source {
    org_networks = [vcd_network_routed.network.name]
  }

  destination {
    ip_addresses = []
  }

  service {
    protocol = "any"
  }

  depends_on = [vcd_edgegateway_settings.edge_gateway]
}

# Create the firewall rule to allow SSH from the Internet
resource "vcd_nsxv_firewall_rule" "rule_ssh_bastion" {
  edge_gateway = data.vcd_edgegateway.edge_gateway.name
  name         = "${var.cluster_name}-firewall-rule-ssh"

  action = "accept"

  source {
    ip_addresses = ["any"]
  }

  destination {
    ip_addresses = [local.external_network_ip]
  }

  service {
    protocol = "tcp"
    port     = 22
  }

  depends_on = [vcd_edgegateway_settings.edge_gateway]
}

# Create the firewall rule to allow access to API server
resource "vcd_nsxv_firewall_rule" "rule_kube_apiserver" {
  edge_gateway = data.vcd_edgegateway.edge_gateway.name
  name         = "${var.cluster_name}-firewall-rule-kube-apiserver"

  action = "accept"

  source {
    ip_addresses = ["any"]
  }

  destination {
    ip_addresses = [local.external_network_ip]
  }

  service {
    protocol = "tcp"
    port     = 6443
  }

  depends_on = [vcd_edgegateway_settings.edge_gateway]
}

# Create the firewall rule to allow access to nginx ingress
resource "vcd_nsxv_firewall_rule" "rule_nginx_ingress" {
  edge_gateway = data.vcd_edgegateway.edge_gateway.name
  name         = "${var.cluster_name}-firewall-rule-nginx-ingress"

  action = "accept"

  source {
    ip_addresses = ["any"]
  }

  destination {
    ip_addresses = [local.external_network_ip]
  }

  service {
    protocol = "tcp"
    port     = 80
  }
  service {
    protocol = "tcp"
    port     = 443
  }

  depends_on = [vcd_edgegateway_settings.edge_gateway]
}

# Create the firewall rule to allow access to nodeports
resource "vcd_nsxv_firewall_rule" "rule_nodeports" {
  edge_gateway = data.vcd_edgegateway.edge_gateway.name
  name         = "${var.cluster_name}-firewall-rule-nodeports"

  action = "accept"

  source {
    ip_addresses = ["any"]
  }

  destination {
    ip_addresses = [local.external_network_ip]
  }

  service {
    protocol = "tcp"
    port     = "30000-32767"
  }
  service {
    protocol = "udp"
    port     = "30000-32767"
  }

  depends_on = [vcd_edgegateway_settings.edge_gateway]
}


#################################### Loadbalancer settings ####################################
resource "vcd_lb_app_profile" "app_profile" {
  edge_gateway = data.vcd_edgegateway.edge_gateway.name

  name = "${var.cluster_name}-control-plane"
  type = "tcp"

  depends_on = [vcd_edgegateway_settings.edge_gateway]
}

resource "vcd_lb_service_monitor" "cp_monitor" {
  edge_gateway = data.vcd_edgegateway.edge_gateway.name

  name        = "${var.cluster_name}-control-plane-monitor"
  interval    = 15
  timeout     = 20
  max_retries = 5
  type        = "https"
  method      = "GET"
  url         = "/healthz"

  depends_on = [vcd_edgegateway_settings.edge_gateway]
}

resource "vcd_lb_server_pool" "control_plane" {
  edge_gateway = data.vcd_edgegateway.edge_gateway.name

  name                = "${var.cluster_name}-control-plane"
  algorithm           = "round-robin"
  enable_transparency = "true"

  monitor_id = vcd_lb_service_monitor.cp_monitor.id

  dynamic "member" {
    for_each = vcd_vapp_vm.control_plane
    content {
      condition    = "enabled"
      name         = member.value.name
      ip_address   = member.value.network[0].ip
      port         = 6443
      monitor_port = 6443
      weight       = 1
    }
  }
}

resource "vcd_lb_virtual_server" "control_plane" {
  edge_gateway = data.vcd_edgegateway.edge_gateway.name

  name                = "${var.cluster_name}-control-plane"
  ip_address          = local.external_network_ip
  protocol            = "tcp"
  port                = 6443
  enable_acceleration = true
  app_profile_id      = vcd_lb_app_profile.app_profile.id
  server_pool_id      = vcd_lb_server_pool.control_plane.id
}

resource "vcd_lb_service_monitor" "ingress" {
  edge_gateway = data.vcd_edgegateway.edge_gateway.name

  name        = "${var.cluster_name}-ingress-monitor"
  interval    = 15
  timeout     = 20
  max_retries = 5
  type        = "tcp"
  # method      = "GET"
  # url         = "/healthz"

  depends_on = [vcd_edgegateway_settings.edge_gateway]
}

resource "vcd_lb_server_pool" "ingress-http" {
  edge_gateway = data.vcd_edgegateway.edge_gateway.name

  name                = "${var.cluster_name}-ingress-http"
  algorithm           = "round-robin"
  enable_transparency = "true"

  monitor_id = vcd_lb_service_monitor.ingress.id

  dynamic "member" {
    for_each = range(0, var.control_plane_vm_count)
    content {
      condition    = "enabled"
      name         = "${var.cluster_name}-control-plane-${member.value + 1}"
      ip_address   = cidrhost("${var.gateway_ip}/24", 10 + member.value)
      port         = 30080
      monitor_port = 30080
      weight       = 1
    }
  }
}

resource "vcd_lb_virtual_server" "ingress-http" {
  edge_gateway = data.vcd_edgegateway.edge_gateway.name

  name                = "${var.cluster_name}-ingress-http"
  ip_address          = local.external_network_ip
  protocol            = "tcp"
  port                = 80
  enable_acceleration = true
  app_profile_id      = vcd_lb_app_profile.app_profile.id
  server_pool_id      = vcd_lb_server_pool.ingress-http.id
}

resource "vcd_lb_server_pool" "ingress-https" {
  edge_gateway = data.vcd_edgegateway.edge_gateway.name

  name                = "${var.cluster_name}-ingress-https"
  algorithm           = "round-robin"
  enable_transparency = "true"

  monitor_id = vcd_lb_service_monitor.ingress.id

  dynamic "member" {
    for_each = range(0, var.control_plane_vm_count)
    content {
      condition    = "enabled"
      name         = "${var.cluster_name}-worker-${member.value + 1}"
      ip_address   = cidrhost("${var.gateway_ip}/24", 10 + member.value)
      port         = 30443
      monitor_port = 30443
      weight       = 1
    }
  }
}

resource "vcd_lb_virtual_server" "ingress-https" {
  edge_gateway = data.vcd_edgegateway.edge_gateway.name

  name                = "${var.cluster_name}-ingress-https"
  ip_address          = local.external_network_ip
  protocol            = "tcp"
  port                = 443
  enable_acceleration = true
  app_profile_id      = vcd_lb_app_profile.app_profile.id
  server_pool_id      = vcd_lb_server_pool.ingress-https.id
}

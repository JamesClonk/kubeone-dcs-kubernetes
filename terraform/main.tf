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
  lb_acceleration_enabled = false
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
}

# Create SNAT rule to access the Internet
resource "vcd_nsxv_snat" "rule_internet" {
  edge_gateway = data.vcd_edgegateway.edge_gateway.name
  network_type = "ext"
  network_name = local.external_network_name

  original_address   = "${var.gateway_ip}/24"
  translated_address = local.external_network_ip
}

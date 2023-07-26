vcd_url      = "https://vcd-pod-bravo.swisscomcloud.com/api"
vcd_user     = "api_vcd_my_username"
vcd_password = "my_password"

vcd_org               = "PRO-0123456789"
vcd_vdc               = "my-data-center"
vcd_edge_gateway_name = "PRO-0123456789-my-edge-gateway"

cluster_hostname = "my-kubernetes.my-domain.com" # adjust to your hostname, make sure you have a valid DNS records pointing to the edge gateway beforehand

cluster_name = "kubeone"
catalog_name = "KubeOne"

control_plane_disk_storage_profile = "Ultra Fast Storage A with Backup" # adjust to a storage profile of your choice, see "VCD UI -> Data Centers -> Storage -> Storage Policies"
worker_disk_storage_profile        = "Ultra Fast Storage A"             # adjust to a storage profile of your choice, see "VCD UI -> Data Centers -> Storage -> Storage Policies"

control_plane_memory       = 4096
control_plane_cpus         = 2
control_plane_disk_size_mb = 51200
worker_memory              = 8192
worker_cpus                = 4
worker_disk_size_gb        = 250

initial_machinedeployment_replicas = 3
cluster_autoscaler_min_replicas    = 3
cluster_autoscaler_max_replicas    = 5

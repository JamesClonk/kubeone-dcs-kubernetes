vcd_url      = "https://vcd-pod-bravo.swisscomcloud.com/api"
vcd_user     = "api_vcd_my_username"
vcd_password = "my_password"

vcd_org         = "PRO-0123456789"
vcd_vdc         = "my-data-center"
vcd_edgegateway = "PRO-0123456789-my-edge-gateway"

kubeapi_hostname = "my-kubernetes.my-domain.com" # adjust to your hostname, make sure you have a valid DNS *A* record pointing to the edge gateway beforehand

control_plane_disk_storage_profile = "Ultra Fast Storage A with Backup" # adjust to a storage profile of your choice, see "VCD UI -> Data Centers -> Storage -> Storage Policies"
worker_disk_storage_profile        = "Ultra Fast Storage A"             # adjust to a storage profile of your choice, see "VCD UI -> Data Centers -> Storage -> Storage Policies"

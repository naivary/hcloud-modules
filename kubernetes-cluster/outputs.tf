output "kubeconfig" {
  value     = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}

output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "talos_secrets" {
  value     = talos_machine_secrets.this
  sensitive = true
}

output "control_plane_ips" {
  value = [
    for index, ip in local.control_plane_ips : tostring(ip)
  ]
}

output "worker_node_ips" {
  value = [
    for index, ip in local.worker_node_ips : tostring(ip)
  ]
}

output "worker_machine_config" {
  value     = data.talos_machine_configuration.worker_node.machine_configuration
  sensitive = true
}

output "control_plane_machine_config" {
  value     = data.talos_machine_configuration.control_plane.machine_configuration
  sensitive = true
}

output "talos_ccm_version" {
  value = local.talos_ccm_version
}

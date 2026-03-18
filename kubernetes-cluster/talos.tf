locals {
  talos_support_matrix = {
    "1.12.0" : "1.35.0"
  }
  talos_ccm_version = yamldecode(data.github_repository_file.talos_ccm_app.content).spec.sources[0].targetRevision
  // control_plane_ip is the primary ip used by talos to bootstrap the Control Plane
  control_plane_ip = one(hcloud_server.control_planes[0].network).ip

  control_plane_ips = {
    for index, node in hcloud_server.control_planes : index => one(node.network).ip
  }
  worker_node_ips = {
    for index, node in hcloud_server.worker_nodes : index => one(node.network).ip
  }
  patch_template_data = {
    load_balancer_ip   = data.hcloud_load_balancer.control_planes.network_ip
    subnet_ip_range    = var.subnet_ip_range
    cluster_dns_domain = var.cluster_dns_domain
    cluster_name       = var.cluster_name
    subnet_gw          = cidrhost(var.subnet_ip_range, 1)
    inline_manifests = [
      {
        name     = "talos-ccm.yaml"
        contents = data.helm_template.talos_ccm.manifest
      }
    ]
  }
}

data "github_repository_file" "talos_ccm_app" {
  repository = "dwg-berlin/fpq-kube-apps-tmpl"
  branch     = "main"
  file       = "apps/talos-ccm.yaml"
}

data "github_repository_file" "talos_ccm_values" {
  repository = "dwg-berlin/fpq-kube-apps-tmpl"
  branch     = "main"
  file       = "talos-ccm/values.yaml"
}

data "helm_template" "talos_ccm" {
  chart     = "oci://ghcr.io/siderolabs/charts/talos-cloud-controller-manager"
  name      = "talos-ccm"
  namespace = "kube-system"
  version   = local.talos_ccm_version
  values = [
    data.github_repository_file.talos_ccm_values.content
  ]
}

// NOTE: this is needed because network_ip is not
// automatically updated by the provider after attachment
// to a private network (subnet)
data "hcloud_load_balancer" "control_planes" {
  id = hcloud_load_balancer.control_planes.id

  depends_on = [
    hcloud_load_balancer_network.control_planes
  ]
}

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

data "talos_client_configuration" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  cluster_name         = var.cluster_name
  endpoints = [
    data.hcloud_load_balancer.control_planes.network_ip
  ]

  depends_on = [
    hcloud_load_balancer_network.control_planes
  ]
}

data "talos_machine_configuration" "control_plane" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${data.hcloud_load_balancer.control_planes.network_ip}:6443"
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = local.talos_support_matrix[var.talos_version]
  config_patches = [
    for file in fileset(path.module, "patches/control-plane/*.yaml") :
    templatefile("${path.module}/${file}", local.patch_template_data)
  ]

  depends_on = [
    hcloud_load_balancer_network.control_planes,
    data.helm_template.talos_ccm
  ]
}

data "talos_machine_configuration" "worker_node" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${data.hcloud_load_balancer.control_planes.network_ip}:6443"
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = local.talos_support_matrix[var.talos_version]
  config_patches = [
    for file in fileset(path.module, "patches/worker-node/*.yaml") :
    templatefile("${path.module}/${file}", local.patch_template_data)
  ]

  depends_on = [
    hcloud_load_balancer_network.control_planes,
    data.helm_template.talos_ccm
  ]
}

resource "talos_machine_configuration_apply" "control_plane" {
  for_each                    = local.control_plane_ips
  client_configuration        = data.talos_client_configuration.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane.machine_configuration
  node                        = each.value

  depends_on = [
    hcloud_server.control_planes
  ]
}

resource "talos_machine_configuration_apply" "worker_node" {
  for_each                    = local.worker_node_ips
  client_configuration        = data.talos_client_configuration.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker_node.machine_configuration
  node                        = each.value

  depends_on = [
    hcloud_server.worker_nodes
  ]
}

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.control_plane_ip

  depends_on = [
    talos_machine_configuration_apply.control_plane
  ]
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.control_plane_ip

  depends_on = [
    talos_machine_bootstrap.this
  ]
}

resource "local_sensitive_file" "talosconfig" {
  content  = data.talos_client_configuration.this.talos_config
  filename = pathexpand("~/.talos/config")
}

resource "local_sensitive_file" "kubeconfig" {
  content  = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename = pathexpand("~/.kube/config")
}

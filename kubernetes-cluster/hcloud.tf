data "hcloud_image" "talos" {
  with_selector = "os=talos,version=v${var.talos_version}"
}

data "hcloud_network" "this" {
  id = var.network_id
}

# Add the terraform runner server to the private network to be able to 
# provision the cluster over the private network.
resource "hcloud_server_network" "infra" {
  server_id = var.terraform_runner_id
  subnet_id = var.subnet_id
}

resource "hcloud_placement_group" "control_planes" {
  name = "control-planes-${var.cluster_id}"
  type = "spread"
  labels = {
    node-role  = "control-plane"
    cluster-id = var.cluster_id
  }
}

resource "hcloud_placement_group" "worker_nodes" {
  name = "worker-nodes-${var.cluster_id}"
  type = "spread"
  labels = {
    node-role  = "worker-nodes"
    cluster-id = var.cluster_id
  }
}

resource "hcloud_server" "control_planes" {
  for_each           = var.control_planes
  name               = "control-plane-${each.key}-${var.cluster_id}"
  image              = data.hcloud_image.talos.id
  server_type        = each.value.server_type
  location           = each.value.location
  placement_group_id = hcloud_placement_group.control_planes.id

  network {
    network_id = data.hcloud_network.this.id
  }

  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }

  labels = {
    node-role  = "control-plane"
    cluster-id = var.cluster_id
  }
}

resource "hcloud_server" "worker_nodes" {
  for_each           = var.worker_nodes
  name               = "worker-node-${each.key}-${var.cluster_id}"
  image              = data.hcloud_image.talos.id
  server_type        = each.value.server_type
  location           = each.value.location
  placement_group_id = hcloud_placement_group.worker_nodes.id

  network {
    network_id = data.hcloud_network.this.id
  }

  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }

  labels = {
    node-role  = "worker-node"
    cluster-id = var.cluster_id
  }
}

resource "hcloud_load_balancer" "control_planes" {
  name               = "control-planes-${var.cluster_id}"
  load_balancer_type = var.lb_control_planes.type
  location           = var.lb_control_planes.location

  labels = {
    cluster-id = var.cluster_id
  }
}

resource "hcloud_load_balancer_network" "control_planes" {
  load_balancer_id = hcloud_load_balancer.control_planes.id
  subnet_id        = var.subnet_id
  // Load Balancer is only for private usage. 
  // The Kubernetes API is not facing the internet.
  enable_public_interface = false
}

resource "hcloud_load_balancer_target" "control_planes" {
  type             = "label_selector"
  load_balancer_id = hcloud_load_balancer.control_planes.id
  label_selector   = "node-role=control-plane,cluster-id=${var.cluster_id}"
  use_private_ip   = true

  depends_on = [
    hcloud_load_balancer_network.control_planes
  ]
}

resource "hcloud_load_balancer_service" "kube_apiserver" {
  load_balancer_id = hcloud_load_balancer.control_planes.id
  protocol         = "tcp"
  listen_port      = 6443
  destination_port = 6443
}

resource "hcloud_load_balancer_service" "talos_api" {
  load_balancer_id = hcloud_load_balancer.control_planes.id
  protocol         = "tcp"
  listen_port      = 50000
  destination_port = 50000
}

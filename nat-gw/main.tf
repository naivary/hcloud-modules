locals {
  os_image_ubuntu = "ubuntu-24.04"
  nat_server_config = templatefile("${path.module}/templates/nat_server_cloud_init.yaml", {
    ip_range = data.hcloud_network.this.ip_range
  })
  master    = hcloud_server.nat_servers[0]
  master_ip = one(local.master.network).ip
}

data "hcloud_network" "this" {
  id = var.network_id
}

resource "hcloud_ssh_key" "this" {
  name       = "nat-gw-${var.nat_id}"
  public_key = file(var.ssh_pub_key_path)
}

resource "hcloud_network_route" "gw" {
  network_id  = data.hcloud_network.this.id
  destination = "0.0.0.0/0"
  gateway     = local.master_ip
}

resource "hcloud_server" "nat_servers" {
  for_each    = var.gateway_servers
  name        = "nat-gw-${each.key}-${var.nat_id}"
  server_type = each.value.server_type
  location    = each.value.location
  image       = local.os_image_ubuntu
  user_data   = local.nat_server_config
  ssh_keys = [
    hcloud_ssh_key.this.name
  ]

  network {
    network_id = data.hcloud_network.this.id
  }
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  labels = {
    id = var.nat_id
  }
}

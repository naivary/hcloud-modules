variable "cluster_id" {
  description = "unique id for this deployment"
  type        = string
}

variable "subnet_id" {
  description = "subnet id to use for the servers"
  type        = string
}

variable "talos_version" {
  description = "talos linux version"
  type        = string
  default     = "1.12.0"
}

variable "subnet_ip_range" {
  description = "ip range of subnet"
  type        = string
}

variable "network_id" {
  description = "private network id"
  type        = number
}

variable "control_planes" {
  description = "configuration opf control plane"
  type = map(object({
    server_type = string
    location    = string
  }))
  validation {
    condition     = length(var.control_planes) % 2 != 0
    error_message = "The number of control plane nodes must be odd to satisfy RAFT quorum and >0"
  }
  default = {
    0 = {
      server_type = "cx23"
      location    = "fsn1"
    }
  }
}

variable "worker_nodes" {
  description = "A list of worker node definitions. Each object specifies the server type and the deployment location for an individual worker node. Use this to configure and scale the worker fleet by providing multiple node configurations."
  type = map(object({
    server_type = string
    location    = string
  }))
  default = {}
}

variable "lb_control_planes" {
  description = "configuration of the internal load balancer for the Kubernetes API Servers"
  type = object({
    location = string
    type     = string
  })
  default = {
    location = "fsn1"
    type     = "lb11"
  }
}

variable "cluster_name" {
  description = "cluster name"
  type        = string
}

variable "cluster_dns_domain" {
  description = "Kubernetes DNS name"
  type        = string
  default     = "cluster.local"
}

variable "terraform_runner_id" {
  description = "infra system server id which is running the terraform module"
  type        = number
}

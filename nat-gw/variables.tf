variable "nat_id" {
  description = "id of this nat server"
  type        = string
}

variable "network_id" {
  description = "private network id for which a network gateway should be created"
  type        = number
}

variable "gateway_servers" {
  description = "configuration of the gateway servers"
  type = map(object({
    server_type = string
    location    = string
  }))
  validation {
    error_message = "For now only one server can be created. HA will be available in the future."
    condition     = length(var.gateway_servers) == 1
  }

  default = {
    0 = {
      server_type = "cx23"
      location    = "fsn1"
    }
  }
}

variable "ssh_pub_key_path" {
  type = string
}

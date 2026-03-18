terraform {
  required_version = "1.11.2"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "1.57.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.10.0-beta.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.6.1"
    }
    github = {
      source  = "integrations/github"
      version = "6.8.3"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
    }
  }
}

variable "deployment" {
  description = "Optional deployment selector. If unset, it is inferred from the HCP Terraform workspace name."
  type        = string
  default     = null

  validation {
    condition     = var.deployment == null || contains(["ingress", "egress"], var.deployment)
    error_message = "deployment must be either ingress or egress."
  }
}

variable "project_id" {
  description = "GCP project ID that hosts both Boundary worker VPCs for this lab."
  type        = string
  default     = "hc-7b8a3d9e0a6949c7b4095d4d8b2"
}

variable "region" {
  description = "GCP region."
  type        = string
  default     = "asia-northeast1"
}

variable "zone" {
  description = "GCP zone."
  type        = string
  default     = "asia-northeast1-a"
}

variable "prefix" {
  description = "Short resource name prefix."
  type        = string
  default     = "boundary-homework"
}

variable "boundary_addr" {
  description = "HCP Boundary cluster URL."
  type        = string
  default     = "https://12a3f882-0e51-4df8-9120-314f6af5e269.boundary.hashicorp.cloud"
}

variable "boundary_auth_method_id" {
  description = "Boundary password auth method ID for the admin user."
  type        = string
  default     = null
}

variable "boundary_login_name" {
  description = "Boundary admin login name."
  type        = string
  default     = null
}

variable "boundary_password" {
  description = "Boundary admin password."
  type        = string
  default     = null
  sensitive   = true
}

variable "boundary_cluster_id" {
  description = "HCP Boundary cluster ID."
  type        = string
  default     = "12a3f882-0e51-4df8-9120-314f6af5e269"
}

variable "boundary_version" {
  description = "Boundary Enterprise worker binary version."
  type        = string
  default     = "0.21.3+ent"
}

variable "ingress_vpc_cidr" {
  description = "Ingress VPC CIDR."
  type        = string
  default     = "10.20.0.0/20"
}

variable "ingress_subnet_cidr" {
  description = "Ingress worker subnet CIDR."
  type        = string
  default     = "10.20.1.0/24"
}

variable "psc_nat_subnet_cidr" {
  description = "PSC service attachment NAT subnet CIDR."
  type        = string
  default     = "10.20.2.0/24"
}

variable "egress_vpc_cidr" {
  description = "Egress VPC CIDR."
  type        = string
  default     = "10.30.0.0/20"
}

variable "egress_subnet_cidr" {
  description = "Egress worker and target subnet CIDR."
  type        = string
  default     = "10.30.1.0/24"
}

variable "tfc_organization" {
  description = "HCP Terraform organization that owns the ingress workspace."
  type        = string
  default     = "xinyao-dev-org-terraform"
}

variable "ingress_workspace_name" {
  description = "Workspace that exposes the ingress PSC service attachment output."
  type        = string
  default     = "boundary-homework-ingress"
}

variable "psc_service_attachment_self_link" {
  description = "Optional PSC service attachment self link. If unset, the value is read from the ingress workspace outputs."
  type        = string
  default     = null
}

variable "target_ssh_user" {
  description = "Linux user created on the target VM for Boundary SSH access."
  type        = string
  default     = "boundary"
}

variable "trusted_user_ca_public_key" {
  description = "Optional Vault SSH CA public key to trust on the target VM. Populated during the final Vault integration step."
  type        = string
  default     = ""
}

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

variable "boundary_version" {
  description = "Boundary Enterprise worker binary version."
  type        = string
  default     = "0.21.3+ent"
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

variable "boundary_org_name" {
  description = "Boundary org scope name for the homework resources."
  type        = string
  default     = "Hashicorp-org"
}

variable "boundary_project_name" {
  description = "Boundary project scope name for the homework resources."
  type        = string
  default     = "Hashicorp-project"
}

variable "boundary_host_catalog_name" {
  description = "Boundary static host catalog name."
  type        = string
  default     = "hashicorp-catalog-boundary"
}

variable "boundary_host_name" {
  description = "Boundary static host name for the GCE target VM."
  type        = string
  default     = "ssh-target-hashicorp"
}

variable "boundary_host_set_name" {
  description = "Boundary host set name for SSH targets."
  type        = string
  default     = "hashicorp-ssh-hosts"
}

variable "boundary_target_name" {
  description = "Boundary SSH target name."
  type        = string
  default     = "ssh-hashicorp-target"
}

variable "boundary_compute_group_name" {
  description = "Boundary group name for users allowed to connect to the SSH target."
  type        = string
  default     = "compute_ssh_groups"
}

variable "boundary_compute_group_member_ids" {
  description = "Boundary user IDs to add to the compute SSH group. Add the admin user ID here when available."
  type        = set(string)
  default     = []
}

variable "boundary_compute_role_name" {
  description = "Boundary role name that grants SSH target access."
  type        = string
  default     = "compute_ssh_role"
}

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

variable "worker_reauth_revision" {
  description = "Bump this value to force replacement of the controller-led worker and VM so a fresh activation token is used."
  type        = string
  default     = "20260602-worker-reauth-1"
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

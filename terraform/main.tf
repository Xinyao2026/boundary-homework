provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "boundary" {
  addr                   = var.boundary_addr
  auth_method_id         = var.boundary_auth_method_id
  auth_method_login_name = var.boundary_login_name
  auth_method_password   = var.boundary_password
}

locals {
  inferred_deployment = strcontains(terraform.workspace, "egress") ? "egress" : "ingress"
  deployment          = coalesce(var.deployment, local.inferred_deployment)
}

module "ingress" {
  count  = local.deployment == "ingress" ? 1 : 0
  source = "./workspaces/ingress"

  project_id              = var.project_id
  region                  = var.region
  zone                    = var.zone
  prefix                  = var.prefix
  boundary_cluster_id     = var.boundary_cluster_id
  boundary_version        = var.boundary_version
  ingress_vpc_cidr        = var.ingress_vpc_cidr
  ingress_subnet_cidr     = var.ingress_subnet_cidr
  psc_nat_subnet_cidr     = var.psc_nat_subnet_cidr
}

module "egress" {
  count  = local.deployment == "egress" ? 1 : 0
  source = "./workspaces/egress"

  project_id                        = var.project_id
  region                            = var.region
  zone                              = var.zone
  prefix                            = var.prefix
  boundary_version                  = var.boundary_version
  egress_vpc_cidr                   = var.egress_vpc_cidr
  egress_subnet_cidr                = var.egress_subnet_cidr
  tfc_organization                  = var.tfc_organization
  ingress_workspace_name            = var.ingress_workspace_name
  psc_service_attachment_self_link  = var.psc_service_attachment_self_link
  target_ssh_user                   = var.target_ssh_user
  trusted_user_ca_public_key        = var.trusted_user_ca_public_key
}

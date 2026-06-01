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

provider "tfe" {}

data "tfe_outputs" "ingress" {
  count        = var.psc_service_attachment_self_link == null ? 1 : 0
  organization = var.tfc_organization
  workspace    = var.ingress_workspace_name
}

locals {
  labels = {
    app      = "boundary"
    homework = "boundary-homework"
    layer    = "egress"
  }

  psc_service_attachment_self_link = var.psc_service_attachment_self_link == null ? data.tfe_outputs.ingress[0].nonsensitive_values.psc_service_attachment_self_link : var.psc_service_attachment_self_link
}

resource "google_project_service" "required" {
  for_each = toset([
    "compute.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "servicedirectory.googleapis.com",
    "serviceusage.googleapis.com",
    "sts.googleapis.com",
  ])

  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

resource "google_compute_network" "egress" {
  name                    = "${var.prefix}-egress-vpc"
  auto_create_subnetworks = false

  depends_on = [google_project_service.required]
}

resource "google_compute_subnetwork" "egress" {
  name          = "${var.prefix}-egress-subnet"
  ip_cidr_range = var.egress_subnet_cidr
  network       = google_compute_network.egress.id
  region        = var.region
}

resource "google_compute_router" "egress" {
  name    = "${var.prefix}-egress-router"
  network = google_compute_network.egress.id
  region  = var.region
}

resource "google_compute_router_nat" "egress" {
  name                               = "${var.prefix}-egress-nat"
  router                             = google_compute_router.egress.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_address" "psc_endpoint" {
  name         = "${var.prefix}-psc-endpoint-ip"
  region       = var.region
  subnetwork   = google_compute_subnetwork.egress.id
  address_type = "INTERNAL"
}

resource "google_compute_forwarding_rule" "psc_endpoint" {
  name                    = "${var.prefix}-psc-endpoint"
  region                  = var.region
  network                 = google_compute_network.egress.id
  subnetwork              = google_compute_subnetwork.egress.id
  ip_address              = google_compute_address.psc_endpoint.id
  target                  = local.psc_service_attachment_self_link
  load_balancing_scheme   = ""
  allow_psc_global_access = false
}

resource "google_service_account" "egress_worker" {
  account_id   = "${var.prefix}-egress"
  display_name = "Boundary egress worker"
}

resource "google_service_account" "target_vm" {
  account_id   = "${var.prefix}-target"
  display_name = "Boundary target VM"
}

data "google_compute_image" "ubuntu" {
  family  = "ubuntu-2404-lts-amd64"
  project = "ubuntu-os-cloud"
}

resource "boundary_worker" "egress" {
  scope_id    = "global"
  name        = "${var.prefix}-egress-worker"
  description = "Egress worker for Boundary homework"
}

resource "boundary_scope" "org" {
  scope_id                 = "global"
  name                     = var.boundary_org_name
  description              = "Boundary homework organization"
  auto_create_admin_role   = true
  auto_create_default_role = true
}

resource "boundary_scope" "project" {
  scope_id                 = boundary_scope.org.id
  name                     = var.boundary_project_name
  description              = "Boundary homework project"
  auto_create_admin_role   = true
  auto_create_default_role = true
}

resource "boundary_host_catalog_static" "gce" {
  scope_id    = boundary_scope.project.id
  name        = var.boundary_host_catalog_name
  description = "Static catalog for Boundary homework GCE targets"
}

resource "boundary_host_static" "target_vm" {
  host_catalog_id = boundary_host_catalog_static.gce.id
  name            = var.boundary_host_name
  description     = "GCE VM target for Boundary SSH access"
  address         = google_compute_instance.target_vm.network_interface[0].network_ip
}

resource "boundary_host_set_static" "target_vms" {
  host_catalog_id = boundary_host_catalog_static.gce.id
  name            = var.boundary_host_set_name
  description     = "GCE VM hosts reachable from the egress worker"
  host_ids        = [boundary_host_static.target_vm.id]
}

resource "boundary_target" "ssh" {
  scope_id                 = boundary_scope.project.id
  type                     = "ssh"
  name                     = var.boundary_target_name
  description              = "SSH target for the Boundary homework GCE VM"
  default_port             = 22
  session_connection_limit = -1

  host_source_ids = [
    boundary_host_set_static.target_vms.id,
  ]

  ingress_worker_filter = "\"ingress\" in \"/tags/type\" and \"boundary-homework\" in \"/tags/env\""
  egress_worker_filter  = "\"egress\" in \"/tags/type\" and \"boundary-homework\" in \"/tags/env\""
}

resource "boundary_group" "compute_ssh" {
  scope_id    = boundary_scope.project.id
  name        = var.boundary_compute_group_name
  description = "Users allowed to connect to Boundary homework SSH targets"
  member_ids  = var.boundary_compute_group_member_ids
}

resource "boundary_role" "compute_ssh" {
  scope_id      = boundary_scope.project.id
  name          = var.boundary_compute_role_name
  description   = "Allow users to list and connect to the Boundary homework SSH target"
  principal_ids = [boundary_group.compute_ssh.id]

  grant_strings = [
    "ids=*;type=target;actions=list,read,authorize-session",
    "ids=*;type=session;actions=list,read,cancel:self",
  ]
}

resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.prefix}-egress-allow-iap-ssh"
  network = google_compute_network.egress.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["boundary-egress-worker", "boundary-target-vm"]
}

resource "google_compute_firewall" "allow_worker_to_target_ssh" {
  name    = "${var.prefix}-egress-allow-worker-target-ssh"
  network = google_compute_network.egress.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_tags = ["boundary-egress-worker"]
  target_tags = ["boundary-target-vm"]
}

resource "google_compute_instance" "egress_worker" {
  name         = "${var.prefix}-egress-worker"
  machine_type = "e2-small"
  zone         = var.zone
  tags         = ["boundary-egress-worker"]
  labels       = local.labels

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.egress.id
  }

  service_account {
    email  = google_service_account.egress_worker.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = templatefile("${path.module}/templates/egress-worker-startup.sh.tftpl", {
    boundary_version = var.boundary_version
    activation_token = boundary_worker.egress.controller_generated_activation_token
    upstream_addr    = "${google_compute_address.psc_endpoint.address}:9202"
    worker_name      = "${var.prefix}-egress-worker"
  })

  depends_on = [
    google_compute_router_nat.egress,
    google_compute_forwarding_rule.psc_endpoint,
  ]
}

resource "google_compute_instance" "target_vm" {
  name         = "${var.prefix}-target-vm"
  machine_type = "e2-small"
  zone         = var.zone
  tags         = ["boundary-target-vm"]
  labels       = merge(local.labels, { layer = "target" })

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.egress.id
  }

  service_account {
    email  = google_service_account.target_vm.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = templatefile("${path.module}/templates/target-vm-startup.sh.tftpl", {
    target_ssh_user            = var.target_ssh_user
    trusted_user_ca_public_key = var.trusted_user_ca_public_key
  })

  depends_on = [google_compute_router_nat.egress]
}

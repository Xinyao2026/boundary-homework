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
  labels = {
    app      = "boundary"
    homework = "boundary-homework"
    layer    = "ingress"
  }
}

resource "google_project_service" "required" {
  for_each = toset([
    "compute.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "serviceusage.googleapis.com",
    "sts.googleapis.com",
  ])

  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

resource "google_compute_network" "ingress" {
  name                    = "${var.prefix}-ingress-vpc"
  auto_create_subnetworks = false

  depends_on = [google_project_service.required]
}

resource "google_compute_subnetwork" "ingress" {
  name          = "${var.prefix}-ingress-subnet"
  ip_cidr_range = var.ingress_subnet_cidr
  network       = google_compute_network.ingress.id
  region        = var.region
}

resource "google_compute_subnetwork" "psc_nat" {
  name          = "${var.prefix}-psc-nat-subnet"
  ip_cidr_range = var.psc_nat_subnet_cidr
  network       = google_compute_network.ingress.id
  region        = var.region
  purpose       = "PRIVATE_SERVICE_CONNECT"
}

resource "google_service_account" "ingress_worker" {
  account_id   = "${var.prefix}-ingress"
  display_name = "Boundary ingress worker"
}

resource "google_compute_address" "ingress_worker_public" {
  name   = "${var.prefix}-ingress-worker-ip"
  region = var.region
}

data "google_compute_image" "ubuntu" {
  family  = "ubuntu-2404-lts-amd64"
  project = "ubuntu-os-cloud"
}

resource "terraform_data" "worker_reauth" {
  triggers_replace = [var.worker_reauth_revision]
}

resource "boundary_worker" "ingress" {
  scope_id    = "global"
  name        = "${var.prefix}-ingress-worker"
  description = "Ingress worker for Boundary homework"

  lifecycle {
    replace_triggered_by = [terraform_data.worker_reauth]
  }
}

resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.prefix}-ingress-allow-iap-ssh"
  network = google_compute_network.ingress.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["boundary-ingress-worker"]
}

resource "google_compute_firewall" "allow_boundary_proxy_public" {
  name    = "${var.prefix}-ingress-allow-proxy-public"
  network = google_compute_network.ingress.name

  allow {
    protocol = "tcp"
    ports    = ["9202"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["boundary-ingress-worker"]
}

resource "google_compute_firewall" "allow_boundary_proxy_psc" {
  name    = "${var.prefix}-ingress-allow-proxy-psc"
  network = google_compute_network.ingress.name

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [
    var.psc_nat_subnet_cidr,
    "35.191.0.0/16",
    "130.211.0.0/22",
  ]
  target_tags = ["boundary-ingress-worker"]
}

resource "google_compute_instance" "ingress_worker" {
  name         = "${var.prefix}-ingress-worker"
  machine_type = "e2-small"
  zone         = var.zone
  tags         = ["boundary-ingress-worker"]
  labels       = local.labels

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.ingress.id

    access_config {
      nat_ip = google_compute_address.ingress_worker_public.address
    }
  }

  service_account {
    email  = google_service_account.ingress_worker.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = templatefile("${path.module}/templates/ingress-worker-startup.sh.tftpl", {
    boundary_cluster_id = var.boundary_cluster_id
    boundary_version    = var.boundary_version
    activation_token    = boundary_worker.ingress.controller_generated_activation_token
    public_addr         = "${google_compute_address.ingress_worker_public.address}:9202"
    worker_name         = "${var.prefix}-ingress-worker"
  })

  lifecycle {
    ignore_changes = [metadata_startup_script]
    replace_triggered_by = [
      boundary_worker.ingress,
      terraform_data.worker_reauth,
    ]
  }
}

resource "google_compute_instance_group" "ingress_workers" {
  name = "${var.prefix}-ingress-workers"
  zone = var.zone

  instances = [
    google_compute_instance.ingress_worker.self_link,
  ]

  named_port {
    name = "boundary-proxy"
    port = 9202
  }
}

resource "google_compute_health_check" "boundary_proxy" {
  name = "${var.prefix}-boundary-proxy-hc"

  tcp_health_check {
    port = 9202
  }
}

resource "google_compute_region_backend_service" "ingress_proxy" {
  name                  = "${var.prefix}-ingress-proxy"
  region                = var.region
  protocol              = "TCP"
  load_balancing_scheme = "INTERNAL"
  health_checks         = [google_compute_health_check.boundary_proxy.id]

  backend {
    group          = google_compute_instance_group.ingress_workers.id
    balancing_mode = "CONNECTION"
  }
}

resource "google_compute_forwarding_rule" "ingress_proxy" {
  name                  = "${var.prefix}-ingress-proxy-ilb"
  region                = var.region
  network               = google_compute_network.ingress.id
  subnetwork            = google_compute_subnetwork.ingress.id
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.ingress_proxy.id
  ip_protocol           = "TCP"
  all_ports             = true
  allow_global_access   = true
}

resource "google_compute_service_attachment" "ingress_proxy" {
  name                  = "${var.prefix}-ingress-psc-sa"
  region                = var.region
  description           = "PSC service attachment for Boundary ingress worker proxy"
  connection_preference = "ACCEPT_AUTOMATIC"
  enable_proxy_protocol = false
  nat_subnets           = [google_compute_subnetwork.psc_nat.id]
  target_service        = google_compute_forwarding_rule.ingress_proxy.id
}

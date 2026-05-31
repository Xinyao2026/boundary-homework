output "ingress_network_id" {
  value = google_compute_network.ingress.id
}

output "ingress_subnet_id" {
  value = google_compute_subnetwork.ingress.id
}

output "ingress_worker_internal_ip" {
  value = google_compute_instance.ingress_worker.network_interface[0].network_ip
}

output "ingress_worker_public_ip" {
  value = google_compute_address.ingress_worker_public.address
}

output "ingress_worker_id" {
  value = boundary_worker.ingress.id
}

output "psc_service_attachment_id" {
  value = google_compute_service_attachment.ingress_proxy.id
}

output "psc_service_attachment_self_link" {
  value = google_compute_service_attachment.ingress_proxy.self_link
}

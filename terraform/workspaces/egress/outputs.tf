output "egress_network_id" {
  value = google_compute_network.egress.id
}

output "egress_subnet_id" {
  value = google_compute_subnetwork.egress.id
}

output "psc_endpoint_ip" {
  value = google_compute_address.psc_endpoint.address
}

output "egress_worker_internal_ip" {
  value = google_compute_instance.egress_worker.network_interface[0].network_ip
}

output "egress_worker_id" {
  value = boundary_worker.egress.id
}

output "target_vm_internal_ip" {
  value = google_compute_instance.target_vm.network_interface[0].network_ip
}

output "target_ssh_user" {
  value = var.target_ssh_user
}

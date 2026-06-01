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

output "boundary_org_id" {
  value = boundary_scope.org.id
}

output "boundary_project_id" {
  value = boundary_scope.project.id
}

output "boundary_host_catalog_id" {
  value = boundary_host_catalog_static.gce.id
}

output "boundary_target_id" {
  value = boundary_target.ssh.id
}

output "boundary_compute_group_id" {
  value = boundary_group.compute_ssh.id
}

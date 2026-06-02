output "egress_network_id" {
  value = google_compute_network.egress.id
}

output "egress_subnet_id" {
  value = google_compute_subnetwork.egress.id
}

output "psc_endpoint_ip" {
  value = google_compute_address.psc_endpoint.address
}

output "psc_endpoint_forwarding_rule_name" {
  value = google_compute_forwarding_rule.psc_endpoint.name
}

output "egress_worker_internal_ip" {
  value = google_compute_instance.egress_worker.network_interface[0].network_ip
}

output "egress_worker_upstream_addr" {
  value = local.egress_worker_upstream_addr
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

output "vault_boundary_namespace" {
  value = var.enable_vault_integration ? local.vault_full_boundary_namespace : null
}

output "vault_ssh_mount_path" {
  value = var.enable_vault_integration ? vault_mount.ssh_client_signer[0].path : null
}

output "vault_ssh_ca_public_key" {
  value = var.enable_vault_integration ? vault_ssh_secret_backend_ca.boundary[0].public_key : null
}

output "boundary_vault_credential_store_id" {
  value = var.enable_vault_integration ? boundary_credential_store_vault.boundary[0].id : null
}

output "boundary_vault_credential_library_id" {
  value = var.enable_vault_integration ? boundary_credential_library_vault_ssh_certificate.boundary[0].id : null
}

output "deployment" {
  value = local.deployment
}

output "ingress_network_id" {
  value = try(module.ingress[0].ingress_network_id, null)
}

output "ingress_subnet_id" {
  value = try(module.ingress[0].ingress_subnet_id, null)
}

output "ingress_worker_internal_ip" {
  value = try(module.ingress[0].ingress_worker_internal_ip, null)
}

output "ingress_worker_public_ip" {
  value = try(module.ingress[0].ingress_worker_public_ip, null)
}

output "ingress_worker_id" {
  value = try(module.ingress[0].ingress_worker_id, null)
}

output "psc_service_attachment_id" {
  value = try(module.ingress[0].psc_service_attachment_id, null)
}

output "psc_service_attachment_self_link" {
  value = try(module.ingress[0].psc_service_attachment_self_link, null)
}

output "egress_network_id" {
  value = try(module.egress[0].egress_network_id, null)
}

output "egress_subnet_id" {
  value = try(module.egress[0].egress_subnet_id, null)
}

output "psc_endpoint_ip" {
  value = try(module.egress[0].psc_endpoint_ip, null)
}

output "egress_worker_internal_ip" {
  value = try(module.egress[0].egress_worker_internal_ip, null)
}

output "egress_worker_id" {
  value = try(module.egress[0].egress_worker_id, null)
}

output "target_vm_internal_ip" {
  value = try(module.egress[0].target_vm_internal_ip, null)
}

output "target_ssh_user" {
  value = try(module.egress[0].target_ssh_user, null)
}

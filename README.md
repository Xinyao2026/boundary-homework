# boundary-homework

Terraform code and learning notes for the Boundary homework.

## Beginner Guide

Start here if you are new to Boundary, Vault, Private Service Connect, or HCP Terraform:

- [Boundary Homework Beginner Guide](docs/boundary-homework-beginner-guide-zh.md)

The guide explains the full workflow, key Terraform files, architecture, validation steps, and common troubleshooting notes.

## Terraform Workspaces

Terraform code is organized by HCP Terraform workspace:

- `terraform/workspaces/ingress`: ingress worker, ingress VPC, internal load balancer, and PSC service attachment.
- `terraform/workspaces/egress`: egress worker, target VM, PSC endpoint, Boundary resources, and Vault SSH certificate integration.

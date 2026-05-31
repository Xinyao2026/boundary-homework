terraform {
  required_version = ">= 1.7.0"

  required_providers {
    boundary = {
      source  = "hashicorp/boundary"
      version = "~> 1.5"
    }

    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

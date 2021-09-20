terraform {
  required_version = ">= 0.14.11"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.61"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 3.61"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.1"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.7"
    }
  }
}

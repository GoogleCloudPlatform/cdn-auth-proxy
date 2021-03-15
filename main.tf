# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

provider "google" {
  project = var.project_id
  region  = var.region
}

# For beta-only resources
provider "google-beta" {
  project = var.project_id
  region  = var.region
}

data "google_project" "project" {
  project_id = var.project_id
}

# Cloud Resource Manager needs to be enabled first, before other services.
resource "google_project_service" "resourcemanager" {
  project            = var.project_id
  service            = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "services" {
  project = var.project_id
  for_each = toset([
    "cloudbuild.googleapis.com",
    "compute.googleapis.com",
    "containerregistry.googleapis.com",
    "iam.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "storage-api.googleapis.com",
    "storage.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false

  depends_on = [
    google_project_service.resourcemanager,
  ]
}

# Build the container images
resource "null_resource" "build" {
  provisioner "local-exec" {
    environment = {
      PROJECT_ID = var.project_id
      TAG        = "initial"
    }
    command = "${path.module}/s3-authn-proxy/build"
  }
  depends_on = [
    google_project_service.services["cloudbuild.googleapis.com"],
  ]
}

resource "google_storage_bucket" "gcs_origin" {
  count = var.gcs_s3_compatibility ? 1 : 0

  name          = "${var.project_id}-cdn"
  location      = var.region
  force_destroy = true

  uniform_bucket_level_access = true

  depends_on = [
    google_project_service.services["storage-api.googleapis.com"]
  ]
}

resource "google_storage_bucket_object" "test_object" {
  count = var.gcs_s3_compatibility ? 1 : 0

  name          = "test.txt"
  bucket        = google_storage_bucket.gcs_origin[0].name
  cache_control = "public, max-age=86400"
  content_type  = "text/css"

  content = <<-EOT
  Line 1
  Line 2
  Line 3
  EOT
}

resource "google_service_account" "gcs_origin" {
  count = var.gcs_s3_compatibility ? 1 : 0

  project      = var.project_id
  account_id   = "gcs-origin"
  display_name = "Used to access GCS bucket in S3 compatibility mode"

  depends_on = [
    google_project_service.services["iam.googleapis.com"]
  ]
}

resource "google_storage_hmac_key" "key" {
  count = var.gcs_s3_compatibility ? 1 : 0

  service_account_email = google_service_account.gcs_origin[0].email

  depends_on = [
    google_project_service.services["storage-api.googleapis.com"],
  ]
}

resource "time_sleep" "sleep_for_hmac" {
  create_duration = "15s"

  depends_on = [
    google_storage_hmac_key.key,
  ]
}

resource "google_storage_bucket_iam_member" "member" {
  count = var.gcs_s3_compatibility ? 1 : 0

  bucket = google_storage_bucket.gcs_origin[0].name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.gcs_origin[0].email}"
}

locals {
  origin_bucket_secrets = {
    AWS_ACCESS_KEY_ID     = var.gcs_s3_compatibility ? google_storage_hmac_key.key[0].access_id : var.s3_origin_bucket_secrets.AWS_ACCESS_KEY_ID
    AWS_SECRET_ACCESS_KEY = var.gcs_s3_compatibility ? google_storage_hmac_key.key[0].secret : var.s3_origin_bucket_secrets.AWS_SECRET_ACCESS_KEY
  }
}

resource "google_secret_manager_secret" "authn_proxy_secret" {
  for_each  = local.origin_bucket_secrets
  secret_id = each.key
  replication {
    automatic = true
  }

  depends_on = [
    google_project_service.services["secretmanager.googleapis.com"],
    time_sleep.sleep_for_hmac,
  ]
}

resource "google_secret_manager_secret_version" "authn_proxy_secret_version" {
  for_each = local.origin_bucket_secrets

  secret      = google_secret_manager_secret.authn_proxy_secret[each.key].id
  secret_data = each.value

  depends_on = [
    time_sleep.sleep_for_hmac,
  ]
}

resource "google_service_account" "authn_proxy" {
  project      = var.project_id
  account_id   = "authn-proxy-sa"
  display_name = "CDN authn proxy"

  depends_on = [
    google_project_service.services["iam.googleapis.com"]
  ]
}

# Grant authn_proxy service account access to the secrets
resource "google_secret_manager_secret_iam_member" "authn_proxy" {
  for_each  = var.s3_origin_bucket_secrets
  secret_id = google_secret_manager_secret.authn_proxy_secret[each.key].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.authn_proxy.email}"
}

locals {
  authn_proxy_env_vars = {
    ORIGIN_BUCKET_REGION    = var.gcs_s3_compatibility ? var.region : var.s3_origin_bucket_region
    ORIGIN_BUCKET_NAME      = var.gcs_s3_compatibility ? google_storage_bucket.gcs_origin[0].name : var.s3_origin_bucket_name
    ORIGIN_STORAGE_ENDPOINT = var.gcs_s3_compatibility ? "storage.googleapis.com" : var.s3_origin_storage_endpoint
    AWS_ACCESS_KEY_ID       = "sm://${var.project_id}/AWS_ACCESS_KEY_ID"
    AWS_SECRET_ACCESS_KEY   = "sm://${var.project_id}/AWS_SECRET_ACCESS_KEY"
  }
}

resource "google_cloud_run_service" "authn_proxy" {
  name     = "authn-proxy"
  project  = var.project_id
  location = var.region

  autogenerate_revision_name = true

  metadata {
    annotations = {
      # Only allow access to the authn_proxy from cloud load balancer
      # and other compute
      "run.googleapis.com/ingress" : "internal-and-cloud-load-balancing"
      "run.googleapis.com/ingress-status" : "internal-and-cloud-load-balancing"
      "run.googleapis.com/launch-stage" : "BETA"
    }
  }

  template {
    spec {
      service_account_name = google_service_account.authn_proxy.email

      containers {
        image = "gcr.io/${var.project_id}/authn-proxy:initial"

        dynamic "env" {
          for_each = local.authn_proxy_env_vars
          content {
            name  = env.key
            value = env.value
          }
        }
      }
    }
  }
  depends_on = [
    google_project_service.services["run.googleapis.com"],
    google_secret_manager_secret_iam_member.authn_proxy,
    google_secret_manager_secret_version.authn_proxy_secret_version["AWS_ACCESS_KEY_ID"],
    google_secret_manager_secret_version.authn_proxy_secret_version["AWS_SECRET_ACCESS_KEY"],
    null_resource.build
  ]

  lifecycle {
    ignore_changes = [
      template[0].spec[0].containers[0].image,
      metadata[0].annotations,
    ]
  }
}

# Allow unauthenticated access to the Cloud Run endpoint.
resource "google_cloud_run_service_iam_member" "member" {
  location = google_cloud_run_service.authn_proxy.location
  project  = google_cloud_run_service.authn_proxy.project
  service  = google_cloud_run_service.authn_proxy.name
  role     = "roles/run.invoker"
  member   = "allUsers"

  depends_on = [
    google_cloud_run_service.authn_proxy
  ]
}

resource "google_compute_region_network_endpoint_group" "authn_proxy_neg" {
  name                  = "authn-proxy-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  cloud_run {
    service = google_cloud_run_service.authn_proxy.name
  }
}

resource "google_compute_backend_service" "authn_proxy_be" {
  provider = google-beta
  name     = "authn-proxy-be"

  enable_cdn = true
  cdn_policy {
    cache_key_policy {
      include_host         = false
      include_protocol     = false
      include_query_string = false
    }
    cache_mode        = "CACHE_ALL_STATIC"
    default_ttl       = 86400
    client_ttl        = 86400
    max_ttl           = 86400
    serve_while_stale = 86400
  }

  backend {
    group = google_compute_region_network_endpoint_group.authn_proxy_neg.id
  }
}

# Optional http forwarding_rule -> target_http_proxy -> url_map
#   -> authn_proxy_be
resource "google_compute_global_address" "cdn_public_ip" {
  count = var.deploy_global_http_lb ? 1 : 0
  name  = "cdn-public-ip"

  ip_version = "IPV4"
  depends_on = [
    google_project_service.services["compute.googleapis.com"],
  ]
}

resource "google_compute_global_forwarding_rule" "authn_proxy" {
  count = var.deploy_global_http_lb ? 1 : 0
  name  = "authn-proxy-lb"

  target     = google_compute_target_http_proxy.authn_proxy[0].id
  port_range = "80"
  ip_address = google_compute_global_address.cdn_public_ip[0].address
}

resource "google_compute_target_http_proxy" "authn_proxy" {
  count = var.deploy_global_http_lb ? 1 : 0
  name  = "authn-proxy-http-proxy"

  url_map = google_compute_url_map.authn_proxy_urlmap[0].id
}

resource "google_compute_url_map" "authn_proxy_urlmap" {
  count = var.deploy_global_http_lb ? 1 : 0
  name  = "authn-proxy-urlmap"

  default_service = google_compute_backend_service.authn_proxy_be.id
}

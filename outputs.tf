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

output "project_id" {
  value = data.google_project.project.project_id
}

output "project_number" {
  value = data.google_project.project.number
}

output "region" {
  value = var.region
}

output "authn_proxy_url" {
  value = google_cloud_run_service.authn_proxy.status[0].url
}

output "cdn_public_ip" {
  value = var.deploy_global_http_lb ? google_compute_global_address.cdn_public_ip[0].address : null
}

output "gcs_origin" {
  value = var.gcs_interoperability ? google_storage_bucket.gcs_origin[0].url : null
}

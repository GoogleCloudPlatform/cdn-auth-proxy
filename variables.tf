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

variable "project_id" {
  type        = string
  description = "Project to deploy the Authentication Proxy"
}

variable "region" {
  type        = string
  description = "Google Cloud region to deploy the Authentication Proxy"
  default     = "us-central1"
}

variable "gcs_interoperability" {
  type        = bool
  default     = false
  description = <<-EOT
  Instead of using an AWS S3 bucket for testing, create a GCS bucket and
  enable GCS S3 compatiblity mode.
  EOT
}

variable "s3_origin_bucket_region" {
  type        = string
  default     = "auto"
  description = <<-EOT
  AWS S3 region of the origin bucket. If gcs_interoperability is true, a GCS bucket
  will be created in var.region.
  EOT
}
variable "s3_origin_bucket_name" {
  type        = string
  default     = ""
  description = <<-EOT
  AWS S3 origin bucket name. If gcs_interoperability is true, this value will be
  ignored and a GCS bucket will be created with the name var.project_id-cdn
  EOT
}

variable "s3_origin_storage_endpoint" {
  type        = string
  default     = "s3.amazonaws.com"
  description = <<-EOT
  AWS S3 Storage API endpoint. If gcs_s3_simuilation is true, this value will be
  ignored and storage.googleapis.com will be used.
  EOT
}

variable "s3_origin_bucket_secrets" {
  type = object({
    AWS_ACCESS_KEY_ID     = string
    AWS_SECRET_ACCESS_KEY = string
  })
  default = {
    AWS_ACCESS_KEY_ID     = ""
    AWS_SECRET_ACCESS_KEY = ""
  }
  description = <<-EOT
  AWS S3 credentials with s3:GetObject permission on objects in the S3 origin
  bucket. If gcs_interoperability is true, these values will be ignored and
  instead the GCS HMAC key and secret values will be used.
  EOT
}

variable "deploy_global_http_lb" {
  type        = bool
  default     = true
  description = <<-EOT
  Create a global HTTP load balancer and wire it to the S3 Authentication Proxy
  backend. Disable if you only want terraform to create the S3 Authentication
  Proxy backend.
  EOT
}

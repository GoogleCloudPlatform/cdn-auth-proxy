# Deploying a Cloud CDN with an AWS S3 Authentication Proxy

## Let's get started

Secure your AWS S3 origin bucket by deploying a proxy in Cloud Run that
Cloud CDN uses to authenticate AWS S3 cache fill requests.

This interactive tutorial will use Terraform to build and deploy the
authentication proxy.

**Time to complete**: 10m

Click the **Start** button below to move to the next step.

## Obtain your AWS Origin bucket credentials

You'll need a bucket to serve as the origin source for the CDN.

If you don't have access to an AWS bucket you can skip this step and set
`gcs_s3_compatibility` to true in a subsequent step. This will have Terraform
create a GCS bucket and enable S3 compatibility mode for testing.

If you do have access to an AWS S3 bucket, you'll need.

   1. AWS S3 Origin bucket:
      1. Name
      2. AWS S3 Region
   2. An AWS IAM credential:
      1. `s3:GetObject` permission on the AWS S3 origin bucket.
      2. `AWS_ACCESS_KEY_ID`
      3. `AWS_SECRET_ACCESS_KEY`
   3. Create a file `test.txt` at the root of the bucket with whatever content
      you'd like to serve.

Click Next to configure Terraform.

## Create `terraform.tfvars` file

Run **ONE** of the following commands to create an initial version of the
`terraform.tfvars` configuration file.

* Run the following If you don't have an AWS S3 bucket to use as a CDN
  origin bucket and would like to test using a GCS bucket. Terraform will create

    1. A GCS bucket
    2. A service account and grant it `roles/storage.objectViewer` on the
       bucket.
    3. Create an HMAC Key and Secret assigned to the service account.

   ```bash
    cp docs/terraform.tfvars.example-gcs terraform.tfvars
   ```

OR

* Run the following command if you have and AWS S3 bucket to serve as a CDN
  origin.

   ```bash
    cp docs/terraform.tfvars.example-s3 terraform.tfvars
   ```

Click Next configure the Terraform variables.

## Configure Terraform variables

Open the <walkthrough-editor-open-file filePath="terraform.tfvars">terraform.tfvars</walkthrough-editor-open-file> file in the Cloud Shell editor and set the
Terraform variables.

You can open the <walkthrough-editor-open-file filePath="variables.tf">variables.tf</walkthrough-editor-open-file> file to see the documentation on all Terraform
variables.

When done, save the file. Next you'll provision the resources.

## Provision the resources

Terraform will provision the resources:

### Initialize Terraform

```bash
terraform init
```

### Plan the Terraform deployment


```bash
terraform plan -out plan.out
```


### Have Terraform deploy the resources


```bash
terraform apply plan.out
```

**Note**: This step can take several minutes.

While you wait for Terraform to provision the resources, continue to the next
page to see and overview of what resource are being provisioned by Terraform.

## Overview of provisioned resources

Terraform will perform the following steps to deploy the S3 authentication proxy
service.

   1. Enables the required Google Cloud APIs (e.g. `cloudbuild.googleapis.com`
      `run.googleapis.com`)
   2. Store the AWS IAM credential secrets in Google Cloud Secrets Manager
   3. Create a service account (`authn-proxy-sa`) for the AWS S3 authentication
      proxy to run under.
   4. Grant the `authn-proxy-sa` service account permission read the AWS IAM
      credential secrets from Secret Manager
   5. Build the S3 authentication proxy container with Cloud Build and
      store the container image in the container registry
   6. Deploy the AWS S3 Authentication proxy container image to Cloud Run with
      the following configuration:
      1. [Restricted network access][1] - Only allowing access from internal
         networks or an HTTP(S) load balancer
      2. Environment variables that configure the AWS S3 Authentication Proxy
      3. The `authn-proxy-sa` service account as the AWS S3 Authentication
         Proxies default service account. The container's startup script will
         use the service account to obtain the AWS IAM credentials from the
         Secrets Manager
   7. Creates a serverless network endpoint group (NEG)
   8. Creates an HTTP(S) backend that connects to the serverless NEG. The
      backend enables CDN caching
   9. Create an External HTTP Load balancer to test the AWS S3 authentication
      proxy. This consists of:
      1. A public IP address
      2. A URL map that routes all URLs to the AWS S3 authentication proxy
         backend
      3. An http target proxy that points to the URL map
      4. A global forwarding rule listening on port 80 (HTTP), connected to the
         http target proxy

See the solution: [Cloud CDN S3 Authentication Proxy][2] to learn more.

When the `terraform apply` is finished it will output details of the
deployment.

In the next step you'll test the AWS S3 Authentication proxy by downloading an
object.

## Testing the AWS S3 Authentication Proxy

It takes some time (5-10 minutes) for the load balancer to internally provision
itself and start serving traffic. While it's provisioning it will return `404`
errors.

### Access an object via the CDN

Run the following [`curl`][3] command to download and S3 object from the origin
bucket via the Cloud CDN and the S3 Authentication Proxy.

Replace `test.txt` with the name of an object in your S3 origin bucket.
The `-i` flag to `curl` will print the HTTP response headers, useful to see
the `Cache-control` and `Age` headers.

```bash
curl -i http://$(terraform output cdn_public_ip)/test.txt
```

an example output looks like:

```console
HTTP/1.1 200 OK
Last-Modified: Mon, 08 Mar 2021 19:28:10 GMT
ETag: "f1c4ad7138235b85c6a15f5d910e3a11"
accept-ranges: bytes
Content-Type: text/css
X-Cloud-Trace-Context: e0ac433ee1eb392f978315fea560ac86;o=1
Date: Mon, 15 Mar 2021 08:36:55 GMT
Server: Google Frontend
Content-Length: 36
Via: 1.1 google
Age: 83
Cache-Control: public,max-age=86400

This is a test
This is only a test
```

Continue to the next step to generate some load on the CDN.

## Generate some load

tbd

Continue to the next step to investigate inspect the Cloud CDN logs.

## Investigate the Cloud CDN logs

tbd

Continue to the next step for some additional resources to learn more.

## What's next

To avoid incurring ongoing charges to your Google Cloud Platform account you
can have Terraform remove the resources it created with the following command:

```bash
terraform destroy
```

To learn more:

   1. [Cloud CDN Authentication Proxy][2]
   2. [Cloud CDN][4]
   3. [Cloud Run][5]

Refer to the solution [Cloud CDN Authentication Proxy][2] to learn more.



[1]: https://cloud.google.com/run/docs/securing/ingress
[2]: https://TBD
[3]: https://curl.se/
[4]: https://cloud.google.com/cdn
[5]: https://cloud.google.com/run

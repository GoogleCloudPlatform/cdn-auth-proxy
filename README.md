# Deploying a Cloud CDN with an AWS S3 Authentication Proxy

This is the repo for the [Deploying a Cloud CDN origin authentication proxy][1]
tutorial.

This tutorial explains how to deploy a [Cloud CDN][2] with a private [Amazon
Simple Storage Service (S3)][3] origin bucket. The deployment uses [Cloud
Run][4] and an authentication proxy to sign CDN cache fill requests and forward
them to the Amazon S3 origin bucket.

**This is not an officially supported Google product.**

[1]: https://cloud.google.com/architecture/deploying-a-cloud-cdn-origin-authentication-proxy
[2]: https://cloud.google.com/cdn
[3]: https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingBucket.html
[4]: https://cloud.google.com/run

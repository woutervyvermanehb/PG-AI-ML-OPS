# Terraform AWS S3 Bucket Module

This module provisions an [AWS S3 Bucket](https://docs.aws.amazon.com/s3/index.html) with customizable name and tags.

It is designed for reuse in multi-environment Terraform projects and supports integration into larger infrastructure-as-code workflows.

---

## Features

- Create an S3 bucket with a specified name
- Apply custom tags (e.g., environment, purpose)
- Supports use with `for_each` to manage multiple buckets dynamically

---

## Usage

```hcl
module "s3_bucket" {
  source = "./modules/s3-bucket"

  bucket = "my-bucket-name"
  tags   = {
    environment = "dev"
  }
}

environment = "dev"
aws_region  = "eu-west-1"

# Reuse the existing Course 03 datastore bucket as the DVC remote;
# Course 04 does not create its own S3 bucket.
s3_buckets = []

# The ECR repository already exists (created earlier / by the app workflow), so
# Terraform does not manage it here. App Runner references the image by its full
# identifier string below, so it does not depend on this list.
ecr_repositories = []

# App Runner pulls the :latest image that the app pipeline pushed to ECR.
# (Account ID fixed to 774118824883.)
apprunner_services = [
  {
    key = "mlops-course-ehb-app"
    source_configuration = {
      image_repository = {
        image_identifier      = "774118824883.dkr.ecr.eu-west-1.amazonaws.com/ecr-mlops-course-ehb-repository-dev:latest"
        image_repository_type = "ECR"
        image_configuration = {
          port = 80
        }
      }
      auto_deployments_enabled = true
    }
    tags = {}
  }
]

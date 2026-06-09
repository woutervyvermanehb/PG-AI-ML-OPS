environment = "dev"
aws_region  = "eu-west-1"

# Reuse the existing Course 03 datastore bucket as the DVC remote;
# Course 04 does not create its own S3 bucket.
s3_buckets = []

ecr_repositories = [
  {
    key                  = "mlops-course-ehb-repository"
    image_tag_mutability = "MUTABLE"
    image_scanning_configuration = {
      scan_on_push = true
    }
    tags = {}
  }
]

# PHASE A: empty so Terraform creates ECR only. App Runner needs the image
# to already exist in ECR, so it is enabled in PHASE C after the app
# workflow has pushed the image. (Account ID fixed to 774118824883.)
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

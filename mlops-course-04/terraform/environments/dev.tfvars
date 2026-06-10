environment = "dev"
aws_region  = "eu-west-1"

# Reuse the existing Course 03 datastore bucket as the DVC remote;
# Course 04 does not create its own S3 bucket.
s3_buckets = []

# The ECR repository already exists (created earlier / by the app workflow), so
# Terraform does not manage it here. App Runner references the image by its full
# identifier string below, so it does not depend on this list.
ecr_repositories = []

# App Runner is NOT enabled on this AWS account: creating a service returns
# "SubscriptionRequiredException: The AWS Access Key Id needs a subscription for
# the service". This is an account-level limit (common on student/lab accounts),
# not a permissions or code issue. The App Runner module and code stay in the repo
# (apprunner_services.tf + modules/apprunner-service) to show how it WOULD deploy
# the image to a live URL; this list is kept empty so the infra pipeline stays green.
apprunner_services = []

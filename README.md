# MLOps — End-to-End Course Project

A hands-on walk through the **MLOps maturity model**, taking one machine-learning
model from a one-off laptop experiment to a system that retrains and ships itself
from a single pull request. The model is a small classifier that predicts whether
an insurance customer is interested in vehicle insurance — but the project is
really about everything *around* the model: how it's built, versioned, and shipped.

Built with **AWS · Terraform · DVC · Docker · MLflow · GitHub Actions**.

## The four parts

| Folder | Theme | What it adds |
|--------|-------|--------------|
| [`mlops-course-01`](mlops-course-01) | Infrastructure as Code | Create cloud infrastructure (an S3 bucket) from Terraform files — no console clicking. |
| [`mlops-course-02`](mlops-course-02) | Shared state & automation | Remote Terraform state in S3 + reusable modules; a **pull request** runs Terraform automatically. |
| [`mlops-course-03`](mlops-course-03) | Versioned data & packaging | Track data with **DVC** (stored in S3, versioned with tags), train the model, package it in a **Docker** container with a small API. |
| [`mlops-course-04`](mlops-course-04) | Full automation | **MLflow** experiment tracking, **ECR** image registry, and two CI/CD pipelines so a pull request retrains the model and pushes a new image on its own. |

## CI/CD pipelines

Located in [`.github/workflows`](.github/workflows):

- **Application CI/CD** (`app-cicd-dev.yml`) — on a change to `mlops-course-04/src/**`:
  pull data → retrain → build image → push to ECR.
- **Infrastructure CI/CD** (`infra-cicd-dev.yml`) — on a change to
  `mlops-course-04/terraform/**`: `terraform init → validate → plan → apply`.
- **Course-02 infra** (`tf-infra-cicd-dev.yml`) — the earlier Terraform pipeline.

> Note: App Runner (live model serving) is defined in Terraform but isn't enabled
> on the lab AWS account used here, so it is not deployed.

## Per-course guides

Each course folder has its own `README.md` with step-by-step instructions.

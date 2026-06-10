# MLOps End-to-End Pipeline

This guide demonstrates a complete MLOps pipeline: experiment tracking and model
versioning with **MLflow**, containerization with **Docker**, container storage on
**AWS ECR**, serverless serving on **AWS App Runner**, all wired together with
**GitHub Actions** CI/CD. It builds directly on courses 01-03 (Terraform, modules,
multi-environment backends, DVC).

## Prerequisites

* [Python](https://www.python.org) 3.13
* [Docker](https://docs.docker.com/get-docker/)
* [AWS CLI](https://aws.amazon.com/cli/) (configured with credentials for this account)
* [Terraform](https://developer.hashicorp.com/terraform/install)
* [GitHub](https://docs.github.com/en/get-started/start-your-journey/creating-an-account-on-github) account

## Solution Architecture

- **MLflow** — experiment tracking and (optionally) a model registry
- **AWS ECR** — Docker image storage and versioning
- **AWS App Runner** — serverless container deployment for the prediction API
- **GitHub Actions** — two pipelines: one for the app, one for the infrastructure

## 1. Project Structure

```bash
mlops-course-04/
├── src/
│   ├── data/                 # train.csv / test.csv (DVC-tracked, git-ignored)
│   ├── models/               # model.pkl produced by training (git-ignored)
│   ├── pipelines/
│   │   ├── clean.py          # Data cleaning pipeline
│   │   ├── ingest.py         # Data ingestion pipeline
│   │   ├── predict.py        # Model evaluation pipeline
│   │   └── train.py          # Model training pipeline (creates models/ on save)
│   ├── .dvc/                 # DVC configuration
│   ├── app.py                # FastAPI model-serving application
│   ├── config.yml            # ML pipeline configuration
│   ├── data.dvc              # DVC data tracking metadata
│   ├── Dockerfile            # Container definition
│   ├── main.py               # MLflow-integrated pipeline orchestrator
│   └── requirements.txt      # Python dependencies
├── terraform/
│   ├── modules/
│   │   ├── apprunner-service/   # App Runner service module
│   │   ├── ecr-repository/      # ECR repository module
│   │   └── s3-bucket/           # S3 bucket module
│   ├── backends/dev.conf        # Remote state backend config
│   ├── environments/dev.tfvars  # Environment-specific variables
│   ├── apprunner_services.tf
│   ├── ecr_repositories.tf
│   ├── provider.tf
│   ├── s3_buckets.tf
│   └── variables.tf
└── README.md

# Workflows live at the repository root:
.github/workflows/
├── app-cicd-dev.yml          # Retrain → build → push image to ECR
└── infra-cicd-dev.yml        # Terraform plan → (optional approval) → apply
```

## 2. Environment Setup

> **Before this step**
> - **Needs:** Python 3.13 installed (`py -3.13 --version`); the repo cloned; a PowerShell terminal.
> - **Creates:** `mlops-course-04/src/.venv/` (a local virtual environment).
> - **Don't create:** don't make a `data/` or `models/` folder by hand — `data/` already ships with the repo and `models/` is created by training (§3). `.venv/` is git-ignored; never commit it.

Run these from **PowerShell** in the repo root:

```powershell
cd mlops-course-04\src
py -3.13 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install --no-cache-dir -r requirements.txt
```

> **If `Activate.ps1` is blocked** by the execution policy, run this once in the
> session first: `Set-ExecutionPolicy -Scope Process -Bypass`. Alternatively, skip
> activation and call the venv Python directly everywhere below:
> `.\.venv\Scripts\python.exe` instead of `python`.
>
> `--no-cache-dir` avoids an occasional Windows pip-cache permission error.

The dataset (`data/train.csv`, `data/test.csv`) is already present in this repo, so
you can train immediately. It is also tracked with DVC in the course-03 datastore
bucket (`s3://mlops-course-ehb-datastore-dev/data`); on a fresh machine you would
first run `dvc pull` (requires AWS credentials). `data/` and `models/` are
git-ignored on purpose — data comes from DVC, and the model is a build artifact.

## 3. Train the Model (with MLflow tracking)

> **Before this step**
> - **Needs:** §2 done (venv active, deps installed); `data/train.csv` and `data/test.csv` present (they already are).
> - **Creates:** `models/model.pkl` (the `models/` folder is auto-created), plus a local `mlruns/` folder (and `mlflow.db` only if you start the UI with sqlite).
> - **Don't create:** don't `mkdir models` yourself — `save_model()` does it. `models/`, `mlruns/`, `mlflow.db` are git-ignored; never commit them.

`main.py` runs the full pipeline (ingest → clean → train → evaluate), logs the run
to MLflow, and writes `models/model.pkl` (the `models/` dir is created automatically).

```powershell
python main.py
```

Expected tail of the output:

```
Model training completed successfully
Model evaluation completed successfully
============= Model Evaluation Results ==============
Model: DecisionTreeClassifier
Accuracy Score: 0.8337, ROC AUC Score: 0.7143
...
```

To browse experiments locally, optionally start the MLflow UI:

```powershell
mlflow ui --backend-store-uri sqlite:///mlflow.db --default-artifact-root ./mlruns
# then open http://127.0.0.1:5000
```

## 4. Test the Container Locally

> **Before this step**
> - **Needs:** `models/model.pkl` from §3; **Docker Desktop running** (wait until it reports "running"; verify with `docker info`, otherwise `docker build` fails with a `dockerDesktopLinuxEngine` pipe error).
> - **Creates:** a local Docker image `mlops-course-04-image` and a running container `mlops-course-04-container` on port 80 — all **local only**.
> - **Don't create:** nothing in AWS here. Don't push this image yet (that's §5 Phase B) and don't tag it with the ECR registry name — this step is purely for local testing.

```powershell
# from mlops-course-04\src (models\model.pkl must exist from step 3)
docker build -t mlops-course-04-image .
docker run -d --name mlops-course-04-container -p 80:80 mlops-course-04-image
```

Open the API docs at `http://127.0.0.1/docs`, then test a prediction. In
**PowerShell**, use `curl.exe` (plain `curl` is an alias for `Invoke-WebRequest`
and won't accept the flags below):

```powershell
curl.exe -X POST "http://127.0.0.1/predict" `
  -H "accept: application/json" `
  -H "Content-Type: application/json" `
  -d '{ "Gender": "Male", "Age": 49, "HasDrivingLicense": 1, "RegionID": 28, "Switch": 0, "PastAccident": "1-2 Year", "AnnualPremium": 1885.05 }'
```

Expected response: `{"predicted_class":0}` (or `1`).

Stop and clean up when done: `docker rm -f mlops-course-04-container`.

## 5. Provision Infrastructure (Terraform)

The course-04 Terraform creates the **ECR repository** and the **App Runner
service**. (This account reuses the course-03 S3 datastore bucket, so
`s3_buckets = []` in `environments/dev.tfvars` — no new bucket is created here.)

App Runner needs an image to already exist in ECR, so deploy in **two phases**:

> **Prerequisite:** AWS CLI configured with credentials for account `774118824883`
> (`aws sts get-caller-identity` should succeed) and Docker Desktop running.

### Phase A — create ECR first

Temporarily set `apprunner_services = []` in `environments/dev.tfvars`, then:

```powershell
cd ..\terraform        # from mlops-course-04\src; or: cd mlops-course-04\terraform
terraform init --backend-config='backends/dev.conf'
terraform plan  --var-file='environments/dev.tfvars'
terraform apply --var-file='environments/dev.tfvars'
```

This creates the empty repository `ecr-mlops-course-ehb-repository-dev`.

### Phase B — build and push the image to ECR

```powershell
cd ..\src              # back to mlops-course-04\src
$ACCOUNT  = "774118824883"
$REGION   = "eu-west-1"
$REPO     = "ecr-mlops-course-ehb-repository-dev"
$REGISTRY = "$ACCOUNT.dkr.ecr.$REGION.amazonaws.com"

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $REGISTRY
docker build -t "${REGISTRY}/${REPO}:latest" .
docker push "${REGISTRY}/${REPO}:latest"
```

> Use `${REPO}:latest`, not `$REPO:latest` — in PowerShell a bare `:` after a
> variable is parsed as scope syntax and breaks the tag. The image identifier in
> `dev.tfvars` is pinned to:
> `774118824883.dkr.ecr.eu-west-1.amazonaws.com/ecr-mlops-course-ehb-repository-dev:latest`

### Phase C — create App Runner

Restore the populated `apprunner_services = [ ... ]` block in `dev.tfvars`, then:

```powershell
cd ..\terraform
terraform apply --var-file='environments/dev.tfvars'
```

App Runner pulls the `:latest` image and exposes a public URL.

## 6. CI/CD with GitHub Actions

Two workflows automate the above (they live at the repo root, paths-filtered so
each only runs when its own files change):

| Workflow | Trigger (PR to `main`) | What it does |
|----------|------------------------|--------------|
| `app-cicd-dev.yml`   | changes under `mlops-course-04/src/**`       | install deps → `dvc pull` → retrain → build image → push to ECR |
| `infra-cicd-dev.yml` | changes under `mlops-course-04/terraform/**` | `terraform fmt/validate/plan` → (optional manual approval) → `apply` |

> Note: `app-cicd-dev.yml` retrains via `python main.py`. The `register_model`
> step is skipped automatically in CI (no registry server), so the build is not
> blocked — `model.pkl` is still produced and baked into the image.

### Required GitHub Secrets
In **Settings → Secrets and variables → Actions**, add:
- `AWS_ACCESS_KEY_ID` — AWS access key for automation
- `AWS_SECRET_ACCESS_KEY` — AWS secret key for automation
- `ECR_REPOSITORY` — `ecr-mlops-course-ehb-repository-dev`

### Optional: manual approval gate
`infra-cicd-dev.yml` ships with a `trstringer/manual-approval` step **commented
out**. Uncomment it and set `approvers:` to your own GitHub username to require a
human to approve each plan before apply. (A non-collaborator username will make
the job hang until timeout, which is why it is off by default.)

## 7. End-to-End Flow

1. New data is pushed to the DVC remote (course-03 datastore bucket).
2. A PR changes code/config under `mlops-course-04/src/**`.
3. `app-cicd-dev.yml` pulls data, retrains, builds the image, pushes to ECR.
4. App Runner (`auto_deployments_enabled = true`) redeploys the new `:latest` image.
5. The updated model serves predictions at the App Runner URL:
   - Health check: `https://<id>.eu-west-1.awsapprunner.com/`
   - Docs: `https://<id>.eu-west-1.awsapprunner.com/docs`
   - Predict: `https://<id>.eu-west-1.awsapprunner.com/predict`

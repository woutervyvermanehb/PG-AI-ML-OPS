# Data Versioning and Model Containerization with DVC and Docker

This guide demonstrates how to implement data versioning using DVC (Data Version Control) and containerize ML models for deployment. You'll learn to track data changes, manage ML pipelines, and package models in Docker containers for scalable, reproducible MLOps workflows.


## Prerequisites

* [Python](https://www.python.org)
* [Docker](https://docs.docker.com/get-docker/)
* [AWS CLI](https://aws.amazon.com/cli/)

## Problem Statement

As ML projects mature, several challenges emerge:
- **Data Drift**: Training data changes over time, requiring versioning
- **Pipeline Reproducibility**: Need to track data transformations and model training steps
- **Model Deployment**: Models need to be packaged consistently for production
- **Collaboration**: Teams need shared access to datasets and model artifacts

![mlops-continuous-delivery-and-automation-pipelines-in-machine-learning-2-manual-ml](assets/mlops-continuous-delivery-and-automation-pipelines-in-machine-learning-2-manual-ml.svg)

## Solution Architecture

This course implements:
- **DVC for Data Versioning and Pipeline Management**: Track large datasets and automate ML pipelines
- **Docker Containerization**: Package models for consistent deployment

![mlops-code-maturity-level-1-part-0](assets/mlops-code-maturity-level-1-part-0.png)
## 1. Project Structure

```bash
mlops-course-03/
├── src/
│   ├── data/
│   ├── models/
│   ├── pipelines/
│   │   ├── clean.py          # Data cleaning pipeline
│   │   ├── ingest.py         # Data ingestion pipeline
│   │   ├── predict.py        # Model prediction pipeline
│   │   └── train.py          # Model training pipeline
│   ├── .gitignore            # Files to ignore in Git
│   ├── config.yml            # ML pipeline configuration
│   ├── main.py               # Main pipeline orchestrator
│   └── requirements.txt      # Python dependencies
├── terraform/                # Infrastructure as Code
└── README.md
```

## 2. Python Virtual Environment Setup (you can use [uv](https://docs.astral.sh/uv/) as an alternative)
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## 3. DVC Remote Storage as a datastore
The role of a datastore is to store and manage collections of data. DVC works on top of Git and is language- and framework-agnostic. It can store data locally or in storage providers such as AWS S3, Azure Blob Storage, SFTP and HDFS; in our case, we will store it in AWS S3. To avoid performing diffs on large and potentially binary files, DVC creates MD5 hash of each file instead and those are versioned by Git.

### Initialize DVC Repository
```bash
cd mlops-course-03/src
dvc init --subdir # initialize dvc inside a SCM tracked subdirectory
git commit -m "initialize dvc"
```
After running dvc init, DVC sets up the project with the necessary configuration to start tracking data. Your directory structure will look like this:
```
src/
├── .dvc/                 # DVC config and internal files
├── .dvcignore            # Like .gitignore but for DVC operations
└── (your project files)
```

### Configure Remote Storage
DVC is configured to use your S3 bucket from mlops-course-02. DVC will store all relevant information in the hidden folder .dvc, so that last step adds this folder to our Git repository (including the DVC config file .dvc/config).:
```bash
dvc remote add -d storage s3://mlops-course-ehb-datastore-dev/data # this saves a remote entry in .dvc/config:
git commit .dvc/config -m "configure dvc remote storage" # commit the config
```

### Data Version Management
That next steps allows us to define a folder where to push the data so that several members from the same project can access consistent data version, as we will see in a bit. Assuming your dataset currently live in data/:
```bash
# add data to DVC tracking
dvc add data/ 

# commit and push metadata DVC file to Git (ignore data/ in Git as well)
git add data.dvc .gitignore
git commit -m "start tracking dataset"
git tag -a "v1" -m "initial dataset"
git push
 
# push data to remote storage
dvc push

src/
├── .dvc/                 # DVC config and internal files (remote configuration)
├── .dvcignore            # Like .gitignore but for DVC operations
├── .gitignore            # Contains an entry to ignore /data
├── data/                 # Contains actual ignored by Git
├── data.dvc              # Metadata file tracked by Git
└── (your project files)
```
This created a data.dvc file containing the MD5 hash and added the actual data file to gitignore. We will see how to interact with the datastore shortly, but before let's assume you have a new version of the dataset (remove a row in data/train.csv). You can now create a new version of the data:
```bash
dvc status
dvc add data/
git add data.dvc
git commit -m "updated dataset"
git tag -a "v2" -m "deleted a row in train.csv"
git push
dvc push
```
In case you'd like to modify your dataset from a past version, you first need to pull the version you'd like to use from DVC, update it as you like and push the new version back to DVC with the appropriate tag:
```bash
git log --oneline --grep="data" # explore commit messages to get more information about each dataset version
git checkout tags/v1 data.dvc   # get data.dvc associated with v1
dvc pull                        # pull the actual dataset associated with data.dvc
dvc add data/
git add data.dvc
git commit -m "data: updated dataset"
git tag -a "v1b" -m "deleted a row in train.csv"
git push
dvc pus
```

## 4. ML Pipelines and Configuration
The `config.yml` file centralizes all pipeline parameters:

```yaml
data: 
  train_path: data/train.csv
  test_path: data/test.csv

train:
  test_size: 0.2
  random_state: 42
  shuffle: true

model:
  name: GradientBoostingClassifier
  params:
    max_depth: null
    n_estimators: 10
  store_path: models/
```
The `Ingestion` class loads training and test datasets.

The `Cleaner` class handles data preprocessing:
- Removes unnecessary columns
- Handles missing values using imputation strategies
- Removes outliers using IQR method
- Preprocesses monetary values

The `Trainer` class implements:
- **Preprocessing**: StandardScaler, MinMaxScaler, OneHotEncoder
- **SMOTE**: Handles class imbalance
- **Model Selection**: Supports multiple algorithms (RandomForest, GradientBoosting, DecisionTree)
- **Model Persistence**: Saves trained models using joblib

The `Predictor` class provides:
- Model loading from saved artifacts
- Batch prediction capabilities
- Model evaluation metrics (accuracy, ROC-AUC, classification report)

```bash
# execute complete pipeline
python main.py
```

The pipeline will:
1. **Ingest** data from configured sources
2. **Clean** and preprocess the data
3. **Train** the specified model with SMOTE balancing
4. **Evaluate** model performance on test data
5. **Save** the trained model for deployment

### Sample Output
```
INFO:root:Data ingestion completed successfully
INFO:root:Data cleaning completed successfully  
INFO:root:Model training completed successfully
INFO:root:Model evaluation completed successfully

============= Model Evaluation Results ==============
Model: GradientBoostingClassifier
Accuracy Score: 0.8547, ROC AUC Score: 0.8932

              precision    recall  f1-score   support
           0       0.86      0.95      0.90      1500
           1       0.85      0.65      0.74       500

    accuracy                           0.85      2000
   macro avg       0.85      0.80      0.82      2000
weighted avg       0.85      0.85      0.85      2000
=====================================================
```

## 5. Model Containerization
Create `Dockerfile` file in `src/`
```dockerfile
# Use the official Python base image
FROM python:3.13-slim

# Set the working directory inside the container
WORKDIR /app

# Copy the application code and models to the working directory
COPY app.py .
COPY models/ ./models/

# Copy the requirements file to the working directory
COPY requirements.txt .

# Install the Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Run the FastAPI application using uvicorn server
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "80"]
```

Create `app.py` in `src/`
```Python
from fastapi import FastAPI
from pydantic import BaseModel
import pandas as pd
import joblib

app = FastAPI()

class InputData(BaseModel):
    Gender: str
    Age: int
    HasDrivingLicense: int
    RegionID: float
    Switch: int
    PastAccident: str
    AnnualPremium: float

model = joblib.load('models/model.pkl')

@app.get("/")
async def root():
    return {"health_check": "OK"}

@app.post("/predict")
async def predict(input_data: InputData):
    
        df = pd.DataFrame([input_data.model_dump().values()], 
                          columns=input_data.model_dump().keys())
        pred = model.predict(df)
        return {"predicted_class": int(pred[0])}
```

```bash
# Build Docker image
docker build -t mlops-course-03-image .
# Run container
docker run -d --name mlops-course-03-container -p 80:80 mlops-course-03-image
```
You can access the API docs locally at `http://127.0.0.1/docs` and make predictionsat `http://127.0.0.1/predict`:
```bash
curl -X 'POST' \
  'http://127.0.0.1/predict' \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{
  "Gender": "Male",
  "Age": 49,
  "HasDrivingLicense": 1,
  "RegionID": 28,
  "Switch": 0,
  "PastAccident": "1-2 Year",
  "AnnualPremium": 1885.05
}'
```

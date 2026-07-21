# Solution Architecture & Design Decisions

## Overview

A simple "Hello World" HTTP application deployed to AWS as a serverless stack
(AWS Lambda + API Gateway HTTP API), fully managed by Terraform and deployed
through a Git-driven GitHub Actions CI/CD pipeline to two isolated environments
(dev and staging).

- **AWS account:** 122788298805
- **Region:** us-east-1
- **Runtime:** Python 3.12

---

## Architecture diagram

```
                        Internet (browser / curl)
                                  |
                                  v
                   +------------------------------+
                   |  API Gateway (HTTP API v2)   |   route: GET /
                   |  hello-dev-api / hello-       |   stage: $default (auto_deploy)
                   |  staging-api                 |
                   +------------------------------+
                                  |  AWS_PROXY integration (payload v2.0)
                                  v
                   +------------------------------+
                   |  AWS Lambda (Python 3.12)    |   env var ENVIRONMENT=dev|staging
                   |  hello-dev / hello-staging   |
                   +------------------------------+
                                  |  assumes
                                  v
                   +------------------------------+
                   |  IAM execution role          |   AWSLambdaBasicExecutionRole
                   |  (per environment)           |   -> CloudWatch Logs
                   +------------------------------+

   State backend (shared, created once by bootstrap):
     - S3 bucket  nishrisa-terraform-state-us-east-1   (versioned, encrypted, private)
     - DynamoDB   nishrisa-terraform-locks             (state locking)

   CI/CD auth (shared, created once by bootstrap):
     - GitHub OIDC provider  token.actions.githubusercontent.com
     - IAM role              github-actions-terraform
```

---

## Terraform structure

```
terraform-project/
├── modules/
│   └── lambda-api/          # Reusable module: Lambda + API Gateway + IAM
│       ├── variables.tf     # Inputs (environment, function_name, zip path, etc.)
│       ├── main.tf          # 8 resources (IAM, Lambda, API GW, integration, route, stage, permission)
│       └── outputs.tf       # api_endpoint, function_name, function_arn
├── environments/
│   ├── bootstrap/           # One-time, LOCAL state: state backend + GitHub OIDC/IAM
│   │   ├── main.tf          # S3 bucket, DynamoDB table (state backend)
│   │   └── github-oidc.tf   # OIDC provider + github-actions-terraform role
│   ├── dev/                 # Dev environment (calls the module)
│   │   ├── backend.tf       # S3 backend, key = dev/terraform.tfstate
│   │   ├── variables.tf
│   │   ├── main.tf          # module "app" { source = ../../modules/lambda-api }
│   │   └── outputs.tf
│   └── staging/             # Staging environment (same shape, key = staging/terraform.tfstate)
├── app/
│   └── app.py               # Hello World Python handler
├── .github/workflows/
│   └── deploy.yml           # CI/CD pipeline
└── docs/                    # This documentation
```

---

## Key design decisions

### 1. Serverless (Lambda + API Gateway), not EC2/ECS
Simplest platform that satisfies "infrastructure via Terraform + deploy via CI/CD."
No servers to patch, near-zero idle cost, fewer resources to manage.

### 2. No VPC / networking module
A public Lambda behind an HTTP API needs no customer VPC — Lambda runs in an
AWS-managed VPC with internet access by default (verified in AWS docs). A VPC is only
needed to reach private resources, which this app does not. Avoiding it keeps the
solution lean (best practice: don't provision unused infrastructure).

### 3. One reusable module, called by each environment
`modules/lambda-api` is written once and instantiated by both dev and staging with
different inputs. This is the DRY / modular-design requirement. Environments stay tiny
(just a module call + backend config).

### 4. Remote state in S3 + DynamoDB locking
State is stored in S3 (versioned + encrypted) with a DynamoDB lock table to prevent
concurrent applies. Chosen over the newer S3-native lockfile because it matches the
training material and is explicit/reviewable.

### 5. Environment isolation via separate state keys
Same S3 bucket, different keys (`dev/terraform.tfstate` vs `staging/terraform.tfstate`).
Each environment has its own state and its own set of AWS resources (`hello-dev` vs
`hello-staging`). See docs/environment-separation.md.

### 6. OIDC instead of stored AWS keys
GitHub Actions authenticates to AWS via OIDC (short-lived tokens), so no long-lived
AWS credentials are stored in GitHub. This is the security best practice.

### 7. `source_code_hash` drives app redeploys
The Lambda resource uses `source_code_hash = filebase64sha256(zip)`. When the app code
changes, the hash changes, so `terraform apply` redeploys the new code. This is how a
single pipeline handles both infrastructure and application deployment.

---

## Naming conventions

- Resources are named `<function_name>-<environment>` (e.g. `hello-dev`, `hello-staging`)
  via a Terraform `local`, guaranteeing no name collisions between environments in the
  same account.
- State keys are `<environment>/terraform.tfstate`.
- Common tags applied to all resources: `Project`, `Environment`, `ManagedBy`.

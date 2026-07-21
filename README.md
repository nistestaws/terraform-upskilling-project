# Terraform End-to-End Project — Serverless Hello World with CI/CD

A complete Terraform solution deploying a simple "Hello World" application to AWS
(Lambda + API Gateway HTTP API), managed entirely by Terraform and deployed through a
Git-driven GitHub Actions CI/CD pipeline to two isolated environments (dev and staging).

- **AWS account:** 122788298805 &nbsp;•&nbsp; **Region:** us-east-1 &nbsp;•&nbsp; **Runtime:** Python 3.12
- **Repo:** https://github.com/nistestaws/terraform-upskilling-project

---

## Project structure

```
terraform-project/
├── modules/
│   └── lambda-api/          # Reusable module: Lambda + API Gateway + IAM
├── environments/
│   ├── bootstrap/           # One-time: state backend (S3+DynamoDB) + GitHub OIDC/IAM
│   ├── dev/                 # Dev environment (state key: dev/terraform.tfstate)
│   └── staging/             # Staging environment (state key: staging/terraform.tfstate)
├── app/
│   └── app.py               # Hello World Python handler
├── .github/workflows/
│   └── deploy.yml           # CI/CD pipeline (plan on PR, deploy on merge)
└── docs/                    # Full documentation (see below)
```

---

## Documentation

| Doc | Contents |
|-----|----------|
| [architecture.md](docs/architecture.md) | Solution architecture, diagram, Terraform structure, design decisions |
| [environment-separation.md](docs/environment-separation.md) | How dev and staging are isolated |
| [cicd-workflow.md](docs/cicd-workflow.md) | Beginner-friendly CI/CD flow with diagram |
| [deployment.md](docs/deployment.md) | Step-by-step deployment instructions |
| [troubleshooting.md](docs/troubleshooting.md) | Common issues and fixes |
| [faq.md](docs/faq.md) | Frequently asked questions |
| [notes.md](docs/notes.md) | Limitations, assumptions, future improvements |
| [progress-report.txt](docs/progress-report.txt) | Day-by-day build log |

---

## Quick start

**One-time backend setup (manual, local state):**
```bash
cd environments/bootstrap
terraform init && terraform apply
```

**Then deploy via CI/CD:** push a branch → open a PR (runs `terraform plan`) → merge
(deploys dev automatically) → approve the staging gate (deploys staging).

See [docs/deployment.md](docs/deployment.md) for full details.

---

## How requirements are met

| Requirement | Where |
|-------------|-------|
| Terraform best practices (variables, outputs, modules, state, naming) | `modules/`, `environments/` |
| End-to-end CI/CD (infra + app) | `.github/workflows/deploy.yml` |
| Application deployment | `app/app.py` packaged + deployed by the pipeline |
| Two isolated environments | `environments/dev`, `environments/staging` |
| Git-driven workflow with approval | PR → merge → auto dev → manual approval → staging |
| Documentation | `docs/` |

---

## Verified evidence

Both environments are live in account 122788298805 (us-east-1):

```
hello-dev      -> {"message": "Hello World from Terraform!", "environment": "dev"}
hello-staging  -> {"message": "Hello World from Terraform!", "environment": "staging"}
```

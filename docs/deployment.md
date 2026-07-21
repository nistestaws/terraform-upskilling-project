# Deployment Instructions

## Prerequisites

- **Terraform** >= 1.5 (built/tested with 1.9.8)
- **AWS CLI** configured with credentials for account 122788298805
  (`aws sts get-caller-identity` should succeed)
- **AWS region:** us-east-1
- **GitHub** repository with Actions enabled
- Python 3.12 runtime is used by Lambda (no local Python needed to deploy; the pipeline zips the code)

---

## One-time setup (bootstrap) — run manually, once

The bootstrap creates the remote state backend and the GitHub OIDC trust. It uses
**local state** on purpose (you can't store state remotely before the backend exists).

```bash
cd environments/bootstrap
terraform init
terraform apply       # creates S3 bucket, DynamoDB table, OIDC provider, IAM role
```

After apply, note the output `github_actions_role_arn` — it must match `AWS_ROLE_ARN`
in `.github/workflows/deploy.yml`.

> The bootstrap is the ONLY part run manually. Everything else deploys via CI/CD.

---

## Normal deployment (via CI/CD — the intended path)

1. Create a feature branch:
   ```bash
   git checkout -b my-change
   ```
2. Make your change (e.g. edit `app/app.py` or the Terraform).
3. Push and open a Pull Request against `main`:
   ```bash
   git add -A && git commit -m "describe change" && git push -u origin my-change
   ```
4. On the PR, the **`plan`** job runs `terraform plan` (dev) — review it.
5. **Merge** the PR → `deploy-dev` applies to dev automatically.
6. `deploy-staging` waits → click **Review deployments → Approve** to deploy to staging.

That's it — infrastructure and application both deploy through the pipeline.

---

## Manual deployment (fallback / local testing)

You can also apply an environment directly from your laptop:

```bash
# build the app artifact first
cd app && zip function.zip app.py && cd ..

# deploy dev
cd environments/dev
terraform init
terraform plan
terraform apply

# deploy staging
cd ../staging
terraform init
terraform plan
terraform apply
```

The `api_endpoint` output prints the URL. Test it:

```bash
curl <api_endpoint>
# {"message": "Hello World from Terraform!", "environment": "dev"}
```

---

## Teardown (destroy everything)

Destroy the environments BEFORE the bootstrap (bootstrap owns the state backend):

```bash
cd environments/dev && terraform destroy
cd ../staging && terraform destroy
cd ../bootstrap && terraform destroy   # LAST
```

---

## Configuration reference

| Setting | Where | Value |
|--------|-------|-------|
| Region | `environments/*/variables.tf` | us-east-1 |
| State bucket | `environments/*/backend.tf` | nishrisa-terraform-state-us-east-1 |
| Lock table | `environments/*/backend.tf` | nishrisa-terraform-locks |
| State key | `environments/*/backend.tf` | `<env>/terraform.tfstate` |
| CI/CD role ARN | `.github/workflows/deploy.yml` | arn:aws:iam::122788298805:role/github-actions-terraform |
| Lambda runtime | module default | python3.12 |

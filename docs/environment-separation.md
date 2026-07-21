# Environment Separation Strategy

The project requires at least two fully isolated environments. This solution uses
**dev** and **staging**, isolated at every layer below.

---

## What "isolated" means here

| Layer | dev | staging | How they're separated |
|-------|-----|---------|-----------------------|
| **Terraform state** | `dev/terraform.tfstate` | `staging/terraform.tfstate` | Different keys in the same S3 bucket. A change to one never touches the other's state. |
| **State locking** | LockID per state file | LockID per state file | Shared DynamoDB table, but locks are per-state-file, so applies don't block each other. |
| **Config** | `environments/dev/` | `environments/staging/` | Separate folders, separate `variables.tf` / `terraform.tfvars` defaults. |
| **AWS resources** | `hello-dev`, `hello-dev-api` | `hello-staging`, `hello-staging-api` | Distinct names via `<function_name>-<environment>` local. |
| **Endpoints** | dev API URL | staging API URL | Separate API Gateway per environment. |
| **App behavior** | `ENVIRONMENT=dev` | `ENVIRONMENT=staging` | Lambda env var; the response body shows which environment served it. |
| **Deployment gate** | Auto on merge to main | Manual approval required | GitHub Environment protection rule on `staging`. |

---

## Why separate state keys (not separate buckets)?

A single versioned, encrypted S3 bucket with per-environment **keys** gives full state
isolation while keeping the backend simple to manage and audit. Separate buckets would
add operational overhead for no additional isolation benefit at this scale.

- Bucket: `nishrisa-terraform-state-us-east-1`
  - `dev/terraform.tfstate`
  - `staging/terraform.tfstate`
  - `github-oidc`/bootstrap uses local state (one-time setup, see architecture doc)

---

## Proof of isolation (evidence)

Both endpoints return the same message but a different `environment` field, proving they
are distinct deployments backed by distinct state:

```
$ curl <dev endpoint>
{"message": "Hello World from Terraform!", "environment": "dev"}

$ curl <staging endpoint>
{"message": "Hello World from Terraform!", "environment": "staging"}
```

Confirmed live in account 122788298805 (us-east-1):
- Lambda: `hello-dev`, `hello-staging`
- API Gateway: `hello-dev-api`, `hello-staging-api`

---

## How a change flows between environments

1. Change is validated on a Pull Request (`terraform plan` against dev).
2. Merge to `main` → deploys to **dev** automatically.
3. **Manual approval** → same change is promoted to **staging**.

This ordered promotion (dev first, then staging after approval) prevents an unreviewed
change from reaching staging.

---

## Adding a third environment (e.g. production) later

The design scales cleanly:
1. Copy `environments/staging/` to `environments/prod/`.
2. Change the backend `key` to `prod/terraform.tfstate` and `environment` default to `prod`.
3. Add a `prod` GitHub Environment with Required Reviewers.
4. Add a `deploy-prod` job in the workflow (needs: deploy-staging).

No module changes required — that's the benefit of the reusable module design.

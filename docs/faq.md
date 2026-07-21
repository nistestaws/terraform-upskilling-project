# Frequently Asked Questions (FAQ)

**Q: Why serverless (Lambda + API Gateway) instead of EC2 or containers?**
A: It's the simplest platform that meets the requirements (infra via Terraform, deploy via
CI/CD). No servers to manage, near-zero idle cost, and fewer resources overall.

**Q: Why is there no VPC?**
A: A public Lambda behind an HTTP API doesn't need a customer VPC — Lambda runs in an
AWS-managed VPC with internet access by default. A VPC is only needed to reach private
resources (e.g. RDS), which this app doesn't. Adding one would be unused complexity.

**Q: How are the two environments kept separate?**
A: Separate Terraform state files (different S3 keys), separate config folders, distinct
resource names (`hello-dev` vs `hello-staging`), separate API endpoints, and a manual
approval gate on staging. See docs/environment-separation.md.

**Q: Why is the bootstrap applied manually instead of through the pipeline?**
A: Chicken-and-egg: the pipeline stores Terraform state in the S3 bucket, but that bucket
is created by the bootstrap. You can't store state remotely before the backend exists, so
the backend is created once, locally, with local state. This is standard Terraform practice.

**Q: How does GitHub authenticate to AWS without stored credentials?**
A: OIDC. GitHub mints a short-lived signed token per run; AWS validates it against the
OIDC provider + IAM role trust policy and returns temporary credentials (~1 hour). No
long-lived AWS keys are stored in GitHub.

**Q: How does the application actually get deployed?**
A: The pipeline zips `app/app.py` into `function.zip`, then runs `terraform apply`. The
Lambda's `source_code_hash` detects the changed zip and deploys the new code. One pipeline
handles both infrastructure and application.

**Q: Why does `plan` show "skipped" when I merge?**
A: `plan` only runs on pull requests. Merging is a `push` event, which runs the deploy
jobs instead. "Skipped" is a normal status, not a failure.

**Q: Why DynamoDB for state locking instead of the newer S3 lockfile?**
A: DynamoDB locking matches the training material, is explicit and easy to demonstrate,
and works across Terraform versions. The S3 native lockfile is a fine alternative but was
not needed here.

**Q: What does it cost to leave this running?**
A: Almost nothing at rest. Lambda and API Gateway charge per request (idle = $0); S3 and
DynamoDB (PAY_PER_REQUEST) cost fractions of a cent for a few state files. No always-on
compute.

**Q: How do I add a production environment?**
A: Copy `environments/staging/` to `environments/prod/`, change the backend key and
environment name, add a `prod` GitHub Environment with reviewers, and add a `deploy-prod`
job. No module changes needed. See docs/environment-separation.md.

**Q: How do I tear everything down?**
A: `terraform destroy` in `environments/dev` and `environments/staging` first, then in
`environments/bootstrap` last (it owns the state backend).

**Q: Can two people apply at the same time safely?**
A: Yes. The DynamoDB lock table prevents concurrent applies to the same state file; the
second apply waits for the lock.

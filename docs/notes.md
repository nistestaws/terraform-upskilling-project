# Known Limitations, Assumptions & Future Improvements

## Assumptions

- Single AWS account (122788298805), single region (us-east-1).
- One GitHub repository with Actions enabled and permission to use OIDC.
- The application is intentionally trivial (Hello World) — the focus of the project is the
  Terraform structure and CI/CD process, not the app itself.
- The reviewer/approver for the staging gate is the repository owner.

---

## Known limitations

1. **Broad IAM permissions on the CI/CD role.**
   `github-actions-terraform` uses `lambda:*`, `apigateway:*`, `logs:*`, and wildcard
   IAM resources. This is functional but not least-privilege. Acceptable for a pilot;
   should be tightened for production.

2. **Bootstrap is applied manually.**
   The state backend + OIDC setup are created locally, once (chicken-and-egg). Not part
   of the pipeline. This is standard but means bootstrap changes aren't CI/CD-driven.

3. **Bootstrap uses local state.**
   The bootstrap's own `terraform.tfstate` lives on the operator's laptop (gitignored).
   If lost, the backend resources would need to be imported or recreated.

4. **No automated application tests.**
   The pipeline validates infrastructure (`terraform plan`) but does not run app unit
   tests or post-deploy smoke tests.

5. **Single region, no DR.**
   No multi-region or disaster-recovery design.

6. **No custom domain / HTTPS certificate management.**
   Uses the default API Gateway execute-api URL.

7. **A temporary debug step was used during OIDC troubleshooting** and then removed. Worth
   remembering it exposes token claims (not secrets) in logs if reintroduced.

---

## Future improvements

- **Tighten the CI/CD IAM policy** to least-privilege (scope to specific resource ARNs and
  the exact actions Terraform needs).
- **Add a `prod` environment** with stricter approval rules (see environment-separation.md).
- **Add post-deploy smoke tests** in the pipeline (e.g. `curl` the endpoint and assert the
  response) so a broken deploy fails fast.
- **Add `terraform fmt -check` and `terraform validate`** as PR checks for style/quality gates.
- **Add application unit tests** for `app.py`.
- **Consider OpenTofu or version pinning review** and Dependabot for the GitHub Actions
  versions.
- **Custom domain + ACM certificate** for a friendlier, branded endpoint.
- **Centralized logging/monitoring** (CloudWatch dashboards, alarms) for the Lambda/API.
- **Optional:** migrate DynamoDB locking to S3 native lockfile once standardized across the team.

---

## Build history highlights (issues solved during development)

- Empty-plan caused by unsaved editor file → save before terraform commands.
- Lock file inconsistency → `terraform init -upgrade`.
- Removed `aws_s3_bucket_acl` (ACLs disabled by default since Apr 2023).
- OIDC "Not authorized" → GitHub immutable-ID subject claim; fixed the trust policy `sub`.

See docs/troubleshooting.md for full detail on each.

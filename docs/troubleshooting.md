# Troubleshooting Guide

Common issues encountered building/running this solution and how to resolve them.
Several of these were hit and solved during the actual build.

---

## 1. OIDC: "Not authorized to perform sts:AssumeRoleWithWebIdentity"

**Symptom:** The GitHub Actions job fails at the "Configure AWS credentials" step with
`Could not assume role with OIDC: Not authorized to perform sts:AssumeRoleWithWebIdentity`.

**Meaning:** GitHub got a valid token, but AWS refused it — the IAM role's **trust
policy conditions did not match the token's claims**.

**Root cause we hit:** GitHub issued an *immutable-ID* subject claim:
```
repo:nistestaws@152171352/terraform-upskilling-project@1307393834:pull_request
```
but the trust policy expected the plain form `repo:nistestaws/terraform-upskilling-project:*`.

**How to diagnose (get facts, don't guess):** Add a temporary step before the AWS
credentials step to decode the token's claims:
```yaml
- name: Debug OIDC claims
  run: |
    TOKEN=$(curl -s -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
      "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=sts.amazonaws.com" | jq -r '.value')
    echo "$TOKEN" | cut -d '.' -f2 | base64 -d 2>/dev/null | jq '{sub, aud}'
```
Read the printed `sub`, then set the trust policy `sub` condition to match it exactly.
Remove the debug step afterward.

**Also check (with AWS CLI):**
```bash
aws iam get-role --role-name github-actions-terraform --query 'Role.AssumeRolePolicyDocument'
aws iam get-open-id-connect-provider --open-id-connect-provider-arn <arn>
```
Confirm the provider exists, `ClientIDList` = `sts.amazonaws.com`, and owner/repo casing
matches (IAM `StringLike` is case-sensitive).

---

## 2. `terraform plan` shows "No changes" / state is empty after editing

**Symptom:** You edited `main.tf` but plan reports no changes and `terraform state list` is empty.

**Cause:** The file edits were **not saved** in the editor. Terraform reads from disk, not
the editor buffer.

**Fix:** Save the file (Cmd+S) before running any terraform command.

---

## 3. "Inconsistent dependency lock file ... no version is selected"

**Symptom:**
```
Error: Inconsistent dependency lock file
- provider registry.terraform.io/hashicorp/aws: required by this configuration but no version is selected
```

**Cause:** `.terraform.lock.hcl` is out of sync with the configuration.

**Fix:**
```bash
terraform init -upgrade
```

---

## 4. `git add` fails: "pathspec did not match any files"

**Symptom:** Running `git add .github/workflows/deploy.yml` from inside the `.github`
folder gives `.github/.github/workflows/: No such file or directory`.

**Cause:** Git pathspecs are relative to your current directory; you were inside a subfolder.

**Fix:** Run git from the repo root, or use `git add -A`:
```bash
cd /path/to/terraform-project
git add .github/workflows/deploy.yml
```

---

## 5. `aws_s3_bucket_acl` error / ACLs

**Symptom:** Creating an S3 bucket ACL fails.

**Cause:** Since April 2023, new S3 buckets have ACLs disabled by default
(BucketOwnerEnforced).

**Fix:** Don't use `aws_s3_bucket_acl`. Use `aws_s3_bucket_public_access_block` for privacy
instead (this project does exactly that).

---

## 6. The "plan" job shows as "Skipped" after merging

**Not an error.** The `plan` job only runs on `pull_request` events. Merging is a `push`
event, so `plan` is correctly skipped and the deploy jobs run instead. See
docs/cicd-workflow.md section 4.

---

## 7. API endpoint returns 500 Internal Server Error

**Likely cause:** Missing `aws_lambda_permission` allowing API Gateway to invoke the Lambda.

**Fix:** Ensure the module's `aws_lambda_permission` resource exists with
`principal = "apigateway.amazonaws.com"` and `source_arn = <api>.execution_arn/*/*`.
(This is included in `modules/lambda-api/main.tf`.)

---

## 8. Staging never deploys after merge

**Cause:** The `deploy-staging` job is waiting on the manual approval gate.

**Fix:** Go to the Actions run → click **Review deployments** → select `staging` →
**Approve and deploy**. This is intended behavior (the required approval gate).

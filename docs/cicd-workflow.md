# CI/CD Workflow — How It Works (Beginner Guide)

This document explains, from the ground up, how code goes from your laptop to AWS
through GitHub. If you're new to Git and GitHub Actions, read top to bottom.

---

## 1. The core Git concepts (30-second version)

| Term | What it means |
|------|---------------|
| **Repository (repo)** | The project folder, tracked by Git and stored on GitHub. |
| **Branch** | A parallel copy of the code where you make changes safely. `main` is the "official" branch. |
| **Commit** | A saved snapshot of your changes with a message. |
| **Push** | Upload your commits from your laptop to GitHub. |
| **Pull Request (PR)** | A request to merge your branch into `main`. It's where changes get reviewed/validated before becoming official. |
| **Merge** | Combining your branch into `main` — makes your changes "official". |

The golden rule of this workflow: **you never edit `main` directly.** You branch,
push, open a PR, let checks run, then merge.

---

## 2. What is GitHub Actions?

GitHub Actions is GitHub's built-in automation. It watches your repo for **events**
(like "a PR was opened" or "code was merged to main") and runs a **workflow** —
a set of automated steps defined in a YAML file at `.github/workflows/deploy.yml`.

Think of it as: **"When X happens in Git, automatically do Y in AWS."**

---

## 3. The big picture diagram

```
   YOUR LAPTOP                     GITHUB                                   AWS
   -----------                     ------                                   ---

  edit code
      |
      | git push (to a branch)
      v
  feature branch  ----------->  Branch appears on GitHub
                                       |
                                       | you open a Pull Request
                                       v
                                +----------------------+
                                |  EVENT: pull_request |
                                +----------------------+
                                       |
                                       v
                                +----------------------+     OIDC token
                                |   JOB: plan          |  ---------------->  AWS checks trust,
                                |   terraform plan     |  <----------------  gives temp creds
                                |   (dev) - NO changes |     terraform plan
                                +----------------------+     (read only)
                                       |
                              green check on the PR
                                       |
                                       | you click "Merge"
                                       v
                                +----------------------+
                                |   EVENT: push (main) |
                                +----------------------+
                                       |
                    +------------------+------------------+
                    v                                     
            +----------------+                            
            | JOB: deploy-dev|   OIDC ---> AWS            
            | terraform apply| ---------------------->  DEV Lambda + API Gateway updated
            |   (dev) AUTO   |                            
            +----------------+                            
                    |                                     
                    | (needs: deploy-dev succeeded)       
                    v                                     
            +---------------------+                       
            | JOB: deploy-staging |                       
            | WAITS for your      |   <=== manual approval gate (Required Reviewers)
            | "Approve" click     |                       
            +---------------------+                       
                    |                                     
                    | you click "Review deployments -> Approve"
                    v                                     
            OIDC ---> AWS ------------------------->  STAGING Lambda + API Gateway updated
```

---

## 4. The two events, and which jobs run

The workflow file defines 3 jobs, each with an `if:` condition that decides when it runs.

### Event A: You open / update a Pull Request  (`pull_request`)
- **`plan`** runs → does `terraform plan` on dev. This only *previews* changes; it
  applies nothing. It's a safety check so you (and reviewers) can see what would happen.
- `deploy-dev` and `deploy-staging` are **skipped** (their condition is `push`, not `pull_request`).

### Event B: You merge the PR into `main`  (`push`)
- **`plan`** is **skipped** (its condition is `pull_request`, and this is a `push`).
  This is why you saw "plan skipped" — it's normal, not an error.
- **`deploy-dev`** runs automatically → `terraform apply` to dev.
- **`deploy-staging`** waits for your manual approval, then `terraform apply` to staging.

> "Skipped" = "this job's trigger condition wasn't met for this event." It is a
> healthy status, not a failure.

---

## 5. Why the plan/apply split?

- **Plan on PR** = look before you leap. You see the proposed changes *before* they're real.
- **Apply on merge** = merging to `main` is the deliberate "make it official" action, so
  that's when real changes get deployed.

This mirrors how professional teams work: review on the PR, deploy on merge.

---

## 6. How the pipeline logs into AWS (OIDC, in plain words)

The pipeline needs permission to change AWS. Instead of storing an AWS password in
GitHub (risky), we use **OIDC**:

1. When a job runs, GitHub creates a short-lived, signed "ID badge" (a token) that says
   *"I am a workflow from repo nistestaws/terraform-upskilling-project."*
2. The job hands that badge to AWS and asks to assume the IAM role `github-actions-terraform`.
3. AWS checks its trust rules (the OIDC provider + role trust policy we created in
   `environments/bootstrap/github-oidc.tf`). If the badge matches, AWS hands back
   **temporary credentials** (valid ~1 hour).
4. Terraform uses those temporary credentials to deploy.

No long-lived secrets are ever stored in GitHub. The temporary credentials expire on
their own.

---

## 7. The manual approval gate (staging)

In GitHub repo **Settings → Environments → staging**, we enabled **Required reviewers**.
Because the `deploy-staging` job declares `environment: staging`, GitHub pauses that job
and shows a **"Review deployments"** button. Nothing deploys to staging until a reviewer
(you) clicks **Approve**. This is the "manual approval after a Git-triggered workflow"
required by the project.

---

## 8. What actually gets deployed

Each deploy job:
1. Checks out the code.
2. **Packages the app** — zips `app/app.py` into `function.zip` (the application artifact).
3. Logs into AWS via OIDC.
4. Runs `terraform init` + `terraform apply` in the environment folder
   (`environments/dev` or `environments/staging`).
5. Terraform notices the zip changed (via `source_code_hash`) and updates the Lambda,
   and creates/updates the API Gateway.

So a single pipeline handles **both** infrastructure (API Gateway, IAM, Lambda config)
**and** application code (the zipped Python) — which is exactly what the project asks for.

---

## 9. Quick mental model

```
Branch  ->  Push  ->  Pull Request  ->  (plan runs: preview)  ->  Merge
                                                                     |
                                                          (deploy-dev runs: DEV live)
                                                                     |
                                                          (approve)  ->  (deploy-staging: STAGING live)
```

That's the whole flow. Branch, PR to preview, merge to deploy dev, approve to deploy staging.

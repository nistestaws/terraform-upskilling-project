# --- GitHub OIDC identity provider (account-level, created once) ---
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # thumbprint_list intentionally omitted - AWS validates GitHub OIDC via its
  # trusted CA library (thumbprint no longer required). Optional in provider v5.x+/v6.
}

# --- Trust policy: who can assume the role and under what conditions ---
data "aws_iam_policy_document" "github_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # Audience must be sts.amazonaws.com
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Restrict to THIS repository (any branch/environment)
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:nistestaws/terraform-upskilling-project:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "github-actions-terraform"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
}

# --- Permissions the pipeline needs to deploy the stack ---
data "aws_iam_policy_document" "github_permissions" {
  # Application infra
  statement {
    sid    = "AppInfra"
    effect = "Allow"
    actions = [
      "lambda:*",
      "apigateway:*",
      "logs:*",
    ]
    resources = ["*"]
  }

  # IAM for the Lambda execution role the module creates
  statement {
    sid    = "IamForLambda"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:PassRole",
      "iam:TagRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
    ]
    resources = ["*"]
  }

  # Remote state access
  statement {
    sid    = "StateBackend"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "s3:DeleteObject",
    ]
    resources = [
      "arn:aws:s3:::nishrisa-terraform-state-us-east-1",
      "arn:aws:s3:::nishrisa-terraform-state-us-east-1/*",
    ]
  }

  # State locking
  statement {
    sid    = "StateLock"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]
    resources = ["arn:aws:dynamodb:us-east-1:*:table/nishrisa-terraform-locks"]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "github-actions-terraform-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_permissions.json
}

# --- Output the role ARN for the GitHub Actions workflow ---
output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions to assume via OIDC."
  value       = aws_iam_role.github_actions.arn
}

# GitHub Actions -> AWS with short-lived credentials. No access keys anywhere.
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "ci_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Jobs on main get a ref-based sub; jobs that use a GitHub environment get an
    # environment-based sub instead. Both forms must be listed.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = concat(
        ["repo:${var.github_repo}:ref:refs/heads/main"],
        [for e in var.github_environments : "repo:${var.github_repo}:environment:${e}"],
      )
    }
  }
}

resource "aws_iam_role" "ci" {
  name                 = "${var.project}-ci"
  description          = "GitHub Actions (${var.github_repo}, main + environments). Manages ${var.project}-* only."
  assume_role_policy   = data.aws_iam_policy_document.ci_trust.json
  max_session_duration = 3600
}

# Scoped to this project's resources by name prefix.
# Trade-off: it can create ${var.project}-* IAM roles (possible self-escalation);
# accepted because only main of this repo can assume it. Next hardening: permissions boundary.
data "aws_iam_policy_document" "ci" {
  statement {
    sid     = "S3ProjectBuckets"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${var.project}-*",
      "arn:aws:s3:::${var.project}-*/*",
    ]
  }

  statement {
    sid     = "IamProjectRolesPolicies"
    actions = ["iam:*"]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${var.project}-*",
      "arn:aws:iam::${local.account_id}:policy/${var.project}-*",
    ]
  }

  statement {
    sid = "IamGithubOidcProvider"
    actions = [
      "iam:GetOpenIDConnectProvider", "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider", "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:AddClientIDToOpenIDConnectProvider", "iam:RemoveClientIDFromOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider", "iam:UntagOpenIDConnectProvider",
    ]
    resources = [aws_iam_openid_connect_provider.github.arn]
  }

  statement {
    sid       = "SnsProjectTopics"
    actions   = ["sns:*"]
    resources = ["arn:aws:sns:${var.aws_region}:${local.account_id}:${var.project}-*"]
  }

  statement {
    sid       = "BudgetsProject"
    actions   = ["budgets:*"]
    resources = ["arn:aws:budgets::${local.account_id}:budget/${var.project}-*"]
  }
}

resource "aws_iam_role_policy" "ci" {
  name   = "${var.project}-ci"
  role   = aws_iam_role.ci.id
  policy = data.aws_iam_policy_document.ci.json
}

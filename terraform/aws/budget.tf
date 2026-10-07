# AWS budgets ALERT; they cannot cap spend. Real caps: nothing always-on,
# plus Snowflake resource monitors.

# Not KMS-encrypted on purpose: Budgets cannot publish to a topic encrypted with
# the AWS-managed SNS key, and it fails silently. The payload holds no secrets.
resource "aws_sns_topic" "cost_alerts" {
  name = "${var.project}-cost-alerts"
}

data "aws_iam_policy_document" "cost_alerts" {
  statement {
    sid    = "DefaultAccountAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = [
      "SNS:GetTopicAttributes", "SNS:SetTopicAttributes", "SNS:AddPermission",
      "SNS:RemovePermission", "SNS:DeleteTopic", "SNS:Subscribe",
      "SNS:ListSubscriptionsByTopic", "SNS:Publish",
    ]
    resources = [aws_sns_topic.cost_alerts.arn]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"
      values   = [local.account_id]
    }
  }

  # Without this, Budgets can't publish and nothing reports an error.
  statement {
    sid    = "AllowBudgetsToPublish"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.cost_alerts.arn]

    # Confused-deputy protection: only budgets in this account.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:budgets::${local.account_id}:budget/*"]
    }
  }
}

resource "aws_sns_topic_policy" "cost_alerts" {
  arn    = aws_sns_topic.cost_alerts.arn
  policy = data.aws_iam_policy_document.cost_alerts.json
}

# Created PENDING: each address must click the confirmation email.
resource "aws_sns_topic_subscription" "cost_alerts_email" {
  for_each  = toset(var.alert_emails)
  topic_arn = aws_sns_topic.cost_alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_budgets_budget" "monthly" {
  name         = "${var.project}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = var.alert_thresholds_percent
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_sns_topic_arns  = [aws_sns_topic.cost_alerts.arn]
      subscriber_email_addresses = var.alert_emails
    }
  }

  # Fires on trajectory, before the money is spent.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_sns_topic_arns  = [aws_sns_topic.cost_alerts.arn]
    subscriber_email_addresses = var.alert_emails
  }

  depends_on = [aws_sns_topic_policy.cost_alerts]
}

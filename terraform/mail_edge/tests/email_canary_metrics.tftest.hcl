provider "aws" {
  region                      = "us-west-2"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
}

provider "archive" {}

override_data {
  target          = data.aws_caller_identity.current
  override_during = plan

  values = {
    account_id = "123456789012"
    arn        = "arn:aws:iam::123456789012:user/test"
    id         = "123456789012"
  }
}

override_data {
  target          = data.aws_partition.current
  override_during = plan

  values = {
    partition  = "aws"
    dns_suffix = "amazonaws.com"
  }
}

override_resource {
  target          = aws_sns_topic.email_canary_alerts[0]
  override_during = plan

  values = {
    arn = "arn:aws:sns:us-west-2:123456789012:test-mail-edge-alerts"
  }
}

variables {
  aws_region                      = "us-west-2"
  name_prefix                     = "test-mail-edge"
  ami_id                          = "ami-0123456789abcdef0"
  subnet_availability_zone        = "us-west-2a"
  enable_ssm_session_manager      = false
  enable_cloudwatch_observability = false
  home_wireguard_peer_public_key  = "test-home-public-key"
  wireguard_ec2_private_key       = "test-ec2-private-key"
  wireguard_ec2_public_key        = "test-ec2-public-key"
  mail_domain                     = "example.com"
  enable_ses                      = true
  enable_ses_monitoring           = false
  enable_email_canary             = true
  email_canary_from_address       = "canary@example.com"
  email_canary_to_address         = "inbox@example.net"
  email_canary_imap_secret_arn    = "arn:aws:secretsmanager:us-west-2:123456789012:secret:canary"
}

run "email_canary_metric_iam" {
  command = plan

  assert {
    condition = anytrue([
      for statement in jsondecode(data.aws_iam_policy_document.email_canary_metrics[0].json).Statement :
      try(
        statement.Effect == "Allow" &&
        statement.Action == "cloudwatch:PutMetricData" &&
        statement.Resource == "*" &&
        statement.Condition.StringEquals["cloudwatch:namespace"] == "Mailu/EmailCanary",
        false,
      )
    ])
    error_message = "The email canary role must allow PutMetricData only for the Mailu/EmailCanary namespace."
  }

  assert {
    condition     = !strcontains(data.aws_iam_policy_document.email_canary_metrics[0].json, "cloudwatch:*")
    error_message = "The email canary role must not receive broad CloudWatch permissions."
  }

  assert {
    condition     = !contains(keys(aws_lambda_function.email_canary[0].environment[0].variables), "OPEN_RELAY_PROBE_JSON")
    error_message = "The Lambda must not regain the removed TCP/25 relay probe."
  }

  assert {
    condition     = length(aws_iam_user.grafana_cloudwatch) == 1 && length(aws_iam_user_policy.grafana_cloudwatch) == 1 && length(aws_iam_access_key.grafana_cloudwatch) == 1
    error_message = "SES-enabled mail edge must retain the existing Grafana CloudWatch reader identity and access key."
  }

  assert {
    condition     = aws_iam_user.grafana_cloudwatch[0].name == "test-mail-edge-grafana-cloudwatch"
    error_message = "The restored reader must keep its existing stable IAM user name."
  }

  assert {
    condition = toset(flatten([
      for statement in jsondecode(data.aws_iam_policy_document.grafana_cloudwatch_read[0].json).Statement :
      try(tolist(statement.Action), [statement.Action])
      ])) == toset([
      "cloudwatch:DescribeAlarmsForMetric",
      "cloudwatch:DescribeAlarmHistory",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetInsightRuleReport",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
      "ec2:DescribeTags",
      "tag:GetResources",
    ])
    error_message = "The Grafana identity must retain only the established read-only CloudWatch discovery actions."
  }
}

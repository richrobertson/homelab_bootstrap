mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

mock_provider "archive" {}

variables {
  aws_region                      = "us-west-2"
  name_prefix                     = "test-mail-edge"
  ami_id                          = "ami-0123456789abcdef0"
  enable_ssm_session_manager      = true
  enable_cloudwatch_observability = true
  enable_open_relay_canary        = false
  home_wireguard_peer_public_key  = "test-home-public-key"
  wireguard_ec2_private_key       = "test-ec2-private-key"
  wireguard_ec2_public_key        = "test-ec2-public-key"
  mail_domain                     = "example.com"
  enable_ses                      = false
}

run "smtp_connection_surge_is_debounced" {
  command = plan

  assert {
    condition     = aws_cloudwatch_metric_alarm.smtp_connection_surge[0].evaluation_periods == 3 && aws_cloudwatch_metric_alarm.smtp_connection_surge[0].datapoints_to_alarm == 2
    error_message = "The SMTP connection surge alarm must require two breaching datapoints in three five-minute periods."
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.smtp_connection_surge[0].alarm_actions) == 1 && length(aws_cloudwatch_metric_alarm.smtp_connection_surge[0].ok_actions) == 0
    error_message = "The SMTP connection surge alarm must notify on ALARM without sending noisy OK notifications."
  }
}

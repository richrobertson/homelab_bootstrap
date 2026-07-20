mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

mock_provider "archive" {}

override_resource {
  target = aws_sesv2_email_identity.mail["example.com"]

  values = {
    dkim_signing_attributes = {
      tokens = ["dkim-token-1", "dkim-token-2", "dkim-token-3"]
    }
  }
}

variables {
  aws_region                      = "us-west-2"
  name_prefix                     = "test-mail-edge"
  ami_id                          = "ami-0123456789abcdef0"
  enable_ssm_session_manager      = false
  enable_cloudwatch_observability = false
  home_wireguard_peer_public_key  = "test-home-public-key"
  wireguard_ec2_private_key       = "test-ec2-private-key"
  wireguard_ec2_public_key        = "test-ec2-public-key"
  mail_domain                     = "example.com"
  enable_ses                      = true
  enable_ses_monitoring           = true
  ses_send_volume_threshold       = 100
  ses_bounce_rate_threshold       = 0.04
  ses_complaint_rate_threshold    = 0.0008
}

run "ses_monitoring_enabled" {
  command = plan

  assert {
    condition     = length(aws_ses_configuration_set.mailu) == 1
    error_message = "SES monitoring must create one configuration set."
  }

  assert {
    condition     = length(aws_ses_event_destination.cloudwatch) == 1 && length(aws_ses_event_destination.sns_failures) == 1
    error_message = "SES monitoring must create both CloudWatch and SNS event destinations."
  }

  assert {
    condition     = length(aws_sqs_queue.ses_events) == 1 && length(aws_sns_topic_subscription.ses_events_sqs) == 1
    error_message = "SES failure events must be retained in the encrypted SQS queue."
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.ses_send_volume) == 1 && length(aws_cloudwatch_metric_alarm.ses_bounce_reputation) == 1 && length(aws_cloudwatch_metric_alarm.ses_complaint_reputation) == 1
    error_message = "SES monitoring must create volume, bounce, and complaint alarms."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.ses_send_volume[0].threshold == 100
    error_message = "The send-volume alarm must use the configured threshold."
  }

  assert {
    condition     = output.ses_configuration_set_header == "X-SES-CONFIGURATION-SET: test-mail-edge-mailu"
    error_message = "The module must expose the SMTP activation header."
  }
}

run "ses_monitoring_disabled" {
  command = plan

  variables {
    enable_ses_monitoring = false
  }

  assert {
    condition     = length(aws_ses_configuration_set.mailu) == 0 && length(aws_cloudwatch_metric_alarm.ses_send_volume) == 0 && length(aws_sqs_queue.ses_events) == 0
    error_message = "Disabling SES monitoring must omit its resources."
  }

  assert {
    condition     = output.ses_configuration_set_name == null
    error_message = "The configuration-set output must be null when monitoring is disabled."
  }
}

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
  enable_open_relay_canary        = true
  home_wireguard_peer_public_key  = "test-home-public-key"
  wireguard_ec2_private_key       = "test-ec2-private-key"
  wireguard_ec2_public_key        = "test-ec2-public-key"
  home_mailu_tunnel_ip            = "10.109.196.109"
  mail_domain                     = "example.com"
  enable_ses                      = false
}

run "relay_canary_enabled" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_log_metric_filter.relay_canary_critical) == 1 && length(aws_cloudwatch_log_metric_filter.relay_canary_indeterminate) == 1 && length(aws_cloudwatch_log_metric_filter.relay_canary_heartbeat) == 1
    error_message = "The relay canary must emit critical, indeterminate, and heartbeat metrics."
  }

  assert {
    condition     = aws_cloudwatch_log_metric_filter.relay_canary_heartbeat[0].pattern == "{ $.event = \"relay_canary\" && $.heartbeat = 1 }"
    error_message = "The heartbeat filter must match the probe's numeric heartbeat field."
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.relay_canary_critical) == 1 && length(aws_cloudwatch_metric_alarm.relay_canary_indeterminate) == 1 && length(aws_cloudwatch_metric_alarm.relay_canary_heartbeat_missing) == 1
    error_message = "The relay canary must create critical, indeterminate, and missing-heartbeat alarms."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.relay_canary_heartbeat_missing[0].treat_missing_data == "breaching" && aws_cloudwatch_metric_alarm.relay_canary_heartbeat_missing[0].evaluation_periods == 3
    error_message = "Missing relay-canary heartbeats must alarm after three consecutive five-minute periods."
  }

  assert {
    condition     = strcontains(aws_ssm_association.mail_edge_observability[0].parameters["commands"], "MAIL_EDGE_RELAY_CANARY_HOST=10.109.196.109")
    error_message = "The edge-host probe must target the effective home Mailu tunnel IP."
  }

  assert {
    condition     = strcontains(aws_ssm_association.mail_edge_observability[0].parameters["commands"], "MAIL_EDGE_RELAY_CANARY_PORT=25")
    error_message = "The edge-host probe must use unauthenticated SMTP port 25."
  }

  assert {
    condition     = strcontains(aws_ssm_association.mail_edge_observability[0].parameters["commands"], "touch /var/log/mail-edge/relay-canary.log") && !strcontains(aws_ssm_association.mail_edge_observability[0].parameters["commands"], "/dev/null /var/log/mail-edge/relay-canary.log")
    error_message = "SSM association reruns must preserve the existing relay-canary log."
  }

  assert {
    condition     = strcontains(aws_ssm_association.mail_edge_observability[0].parameters["commands"], "systemctl restart mail-edge-relay-canary.timer")
    error_message = "SSM association reruns must restart the timer so schedule updates take effect."
  }

  assert {
    condition     = output.open_relay_canary_target == "10.109.196.109:25" && length(output.open_relay_canary_alarm_names) == 3
    error_message = "The module must expose the probe target and all three alarms."
  }
}

run "relay_canary_disabled" {
  command = plan

  variables {
    enable_open_relay_canary = false
  }

  assert {
    condition     = length(aws_cloudwatch_log_metric_filter.relay_canary_critical) == 0 && length(aws_cloudwatch_metric_alarm.relay_canary_heartbeat_missing) == 0
    error_message = "Disabling the relay canary must omit its CloudWatch metrics and alarms."
  }

  assert {
    condition     = output.open_relay_canary_target == null && length(output.open_relay_canary_alarm_names) == 0
    error_message = "Disabled relay-canary outputs must be empty."
  }
}

run "relay_canary_requires_ssm" {
  command = plan

  variables {
    enable_ssm_session_manager = false
  }

  expect_failures = [
    var.enable_cloudwatch_observability,
  ]
}

run "relay_canary_requires_observability" {
  command = plan

  variables {
    enable_cloudwatch_observability = false
  }

  expect_failures = [
    var.enable_open_relay_canary,
  ]
}

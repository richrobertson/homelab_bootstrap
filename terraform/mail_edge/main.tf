terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4"
    }
  }
}

locals {
  public_tcp_ports = [25, 80, 110, 143, 443, 465, 587, 993, 995, 4190]

  common_tags = merge(
    {
      ManagedBy = "terraform"
      Component = "mail-edge"
    },
    var.tags,
  )

  effective_mail_hostname              = coalesce(var.mail_hostname, "mail.${var.mail_domain}")
  effective_home_mailu_tunnel_ip       = coalesce(var.home_mailu_tunnel_ip, cidrhost(var.wireguard_tunnel_cidr, 2))
  effective_wireguard_home_allowed_ips = length(var.wireguard_home_allowed_ips) > 0 ? var.wireguard_home_allowed_ips : ["${local.effective_home_mailu_tunnel_ip}/32"]
  wireguard_ec2_tunnel_ip              = cidrhost(var.wireguard_tunnel_cidr, 1)
  wireguard_prefix_length              = split("/", var.wireguard_tunnel_cidr)[1]
  instance_name                        = "${var.name_prefix}-mail-edge"
  role_name                            = substr("${replace(var.name_prefix, "/[^A-Za-z0-9+=,.@_-]/", "-")}-mail-edge-ssm", 0, 64)
  smtp_user_name                       = substr("${replace(var.name_prefix, "/[^A-Za-z0-9+=,.@_-]/", "-")}-ses-smtp", 0, 64)
  cloudwatch_reader_user_name          = substr("${replace(var.name_prefix, "/[^A-Za-z0-9+=,.@_-]/", "-")}-grafana-cloudwatch", 0, 64)
  ses_configuration_set_name           = substr("${replace(var.name_prefix, "/[^A-Za-z0-9_-]/", "-")}-mailu", 0, 64)
  ses_event_topic_name                 = "${replace(var.name_prefix, "/[^A-Za-z0-9_-]/", "-")}-ses-events"
  ses_alert_topic_name                 = "${replace(var.name_prefix, "/[^A-Za-z0-9_-]/", "-")}-ses-alerts"
  email_canary_name                    = substr("${replace(var.name_prefix, "/[^A-Za-z0-9+=,.@_-]/", "-")}-email-canary", 0, 64)
  mail_edge_alert_topic_name           = substr("${replace(var.name_prefix, "/[^A-Za-z0-9+=,.@_-]/", "-")}-mail-edge-alerts", 0, 256)
  mail_edge_log_group_name             = "/homelab/${var.name_prefix}/mail-edge/haproxy"
  mail_edge_metric_namespace           = "Homelab/MailEdge"
  instance_architecture                = startswith(var.instance_type, "t4g.") ? "arm64" : "x86_64"
  ami_parameter_name                   = local.instance_architecture == "arm64" ? "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64" : "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  manage_ses_dns_records               = var.enable_ses && var.manage_ses_route53_records && var.route53_zone_id != null
  manage_public_mail_dns_records       = var.manage_public_mail_dns_records && var.route53_zone_id != null
  manage_eip_reverse_dns               = var.configure_eip_reverse_dns && local.manage_public_mail_dns_records
  mail_from_domain                     = "${var.ses_mail_from_subdomain}.${var.mail_domain}"
  ses_smtp_endpoint                    = "email-smtp.${var.aws_region}.amazonaws.com"
  email_canary_primary_probe = {
    name            = "external"
    from_address    = var.email_canary_from_address
    to_address      = var.email_canary_to_address
    imap_secret_arn = var.email_canary_imap_secret_arn
    timeout_seconds = var.email_canary_delivery_timeout_seconds
  }
  email_canary_mailu_dovecot_probes = var.enable_mailu_dovecot_canary ? [
    {
      name            = "mailu-dovecot"
      from_address    = coalesce(var.mailu_dovecot_canary_from_address, var.email_canary_from_address)
      to_address      = var.mailu_dovecot_canary_to_address
      imap_secret_arn = var.mailu_dovecot_canary_imap_secret_arn
      timeout_seconds = var.mailu_dovecot_canary_delivery_timeout_seconds
    }
  ] : []
  email_canary_probes           = var.enable_email_canary ? concat([local.email_canary_primary_probe], local.email_canary_mailu_dovecot_probes) : []
  email_canary_imap_secret_arns = compact([for probe in local.email_canary_probes : probe.imap_secret_arn])
  vpc_cidr                      = "10.250.80.0/24"
  public_subnet_cidr            = "10.250.80.0/26"

  effective_vpc_id    = var.create_vpc ? aws_vpc.mail_edge[0].id : coalesce(var.vpc_id, data.aws_subnet.existing[0].vpc_id)
  effective_subnet_id = var.create_vpc ? aws_subnet.public[0].id : var.subnet_id

  ses_dns_records = var.enable_ses ? concat(
    [
      for idx in range(3) : {
        name    = "${aws_sesv2_email_identity.mail[var.mail_domain].dkim_signing_attributes[0].tokens[idx]}._domainkey.${var.mail_domain}"
        type    = "CNAME"
        ttl     = 300
        records = ["${aws_sesv2_email_identity.mail[var.mail_domain].dkim_signing_attributes[0].tokens[idx]}.dkim.amazonses.com"]
      }
    ],
    [
      {
        name    = local.mail_from_domain
        type    = "MX"
        ttl     = 300
        records = ["10 feedback-smtp.${var.aws_region}.amazonses.com"]
      },
      {
        name    = local.mail_from_domain
        type    = "TXT"
        ttl     = 300
        records = ["\"v=spf1 include:amazonses.com ~all\""]
      }
    ]
  ) : []

  mail_dns_records = [
    {
      name    = local.effective_mail_hostname
      type    = "A"
      ttl     = 300
      records = [aws_eip.mail_edge.public_ip]
    },
    {
      name    = "autoconfig.${var.mail_domain}"
      type    = "CNAME"
      ttl     = 300
      records = [local.effective_mail_hostname]
    },
    {
      name    = "autodiscover.${var.mail_domain}"
      type    = "CNAME"
      ttl     = 300
      records = [local.effective_mail_hostname]
    },
    {
      name    = var.mail_domain
      type    = "MX"
      ttl     = 300
      records = ["10 ${local.effective_mail_hostname}."]
    }
  ]

  # Expose the unambiguous SES-only apex SPF policy for deliberate publication
  # when public DNS is managed outside this module.
  recommended_public_mail_security_dns_records = [
    {
      name    = var.mail_domain
      type    = "TXT"
      ttl     = 300
      records = ["v=spf1 include:amazonses.com -all"]
    }
  ]
}

data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  count = var.create_vpc && var.subnet_availability_zone == null ? 1 : 0

  state = "available"
}

data "aws_ssm_parameter" "al2023_ami" {
  count = var.ami_id == null ? 1 : 0

  name = local.ami_parameter_name
}

data "aws_subnet" "existing" {
  count = var.create_vpc ? 0 : 1
  id    = var.subnet_id
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "ses_smtp_send" {
  count = var.enable_ses ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["ses:SendRawEmail"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "grafana_cloudwatch_read" {
  count = var.enable_ses ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
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
    ]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = var.enable_cloudwatch_observability ? [1] : []

    content {
      sid    = "DiscoverAndQueryMailEdgeLogs"
      effect = "Allow"
      actions = [
        "logs:DescribeLogGroups",
        "logs:StopQuery",
      ]
      resources = ["*"]
    }
  }

  dynamic "statement" {
    for_each = var.enable_cloudwatch_observability ? [1] : []

    content {
      sid    = "ReadMailEdgeHAProxyLogs"
      effect = "Allow"
      actions = [
        "logs:GetLogGroupFields",
        "logs:GetQueryResults",
        "logs:StartQuery",
      ]
      resources = ["${aws_cloudwatch_log_group.mail_edge_haproxy[0].arn}:*"]
    }
  }
}

data "aws_iam_policy_document" "mail_edge_cloudwatch_logs" {
  count = var.enable_cloudwatch_observability ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.mail_edge_haproxy[0].arn}:*"]
  }
}

data "aws_iam_policy_document" "ses_event_topic" {
  count = var.enable_ses && var.enable_ses_monitoring ? 1 : 0

  statement {
    sid       = "AllowSESEventPublishing"
    effect    = "Allow"
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.ses_events[0].arn]

    principals {
      type        = "Service"
      identifiers = ["ses.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

data "aws_iam_policy_document" "ses_event_queue" {
  count = var.enable_ses && var.enable_ses_monitoring ? 1 : 0

  statement {
    sid       = "AllowSNSToSendMessage"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.ses_events[0].arn]

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.ses_events[0].arn]
    }
  }
}

data "aws_iam_policy_document" "lambda_assume_role" {
  count = var.enable_email_canary ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "email_canary_metrics" {
  count = var.enable_email_canary ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["Mailu/EmailCanary"]
    }
  }
}

data "aws_iam_policy_document" "email_canary" {
  count = var.enable_email_canary ? 1 : 0

  source_policy_documents = [data.aws_iam_policy_document.email_canary_metrics[0].json]

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:*:log-group:/aws/lambda/${local.email_canary_name}:*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail",
    ]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.email_canary_alerts[0].arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = local.email_canary_imap_secret_arns
  }
}

data "archive_file" "email_canary" {
  count = var.enable_email_canary ? 1 : 0

  type        = "zip"
  source_file = "${path.module}/lambda/email_canary.py"
  output_path = "${path.module}/lambda/email_canary.zip"
}

resource "aws_vpc" "mail_edge" {
  count = var.create_vpc ? 1 : 0

  cidr_block           = local.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${local.instance_name}-vpc"
  })
}

# This subnet exists exclusively for the internet-facing SMTP/WireGuard edge.
resource "aws_subnet" "public" { # nosemgrep: terraform.aws.security.aws-subnet-has-public-ip-address.aws-subnet-has-public-ip-address
  count = var.create_vpc ? 1 : 0

  vpc_id                  = aws_vpc.mail_edge[0].id
  cidr_block              = local.public_subnet_cidr
  availability_zone       = var.subnet_availability_zone != null ? var.subnet_availability_zone : try(data.aws_availability_zones.available[0].names[0], null)
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.instance_name}-public"
  })
}

resource "aws_internet_gateway" "mail_edge" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.mail_edge[0].id

  tags = merge(local.common_tags, {
    Name = "${local.instance_name}-igw"
  })
}

resource "aws_route_table" "public" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.mail_edge[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mail_edge[0].id
  }

  tags = merge(local.common_tags, {
    Name = "${local.instance_name}-public"
  })
}

resource "aws_route_table_association" "public" {
  count = var.create_vpc ? 1 : 0

  subnet_id      = aws_subnet.public[0].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_security_group" "mail_edge" {
  name_prefix = "${local.instance_name}-"
  description = "Public ingress for the Mailu edge EC2 instance"
  vpc_id      = local.effective_vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.instance_name}-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "public_tcp" {
  for_each = { for port in local.public_tcp_ports : tostring(port) => port }

  security_group_id = aws_security_group.mail_edge.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = each.value
  ip_protocol       = "tcp"
  to_port           = each.value

  tags = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "wireguard" {
  security_group_id = aws_security_group.mail_edge.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = var.wireguard_listen_port
  ip_protocol       = "udp"
  to_port           = var.wireguard_listen_port

  tags = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = var.key_name != null ? toset(var.admin_cidr_blocks) : toset([])

  security_group_id = aws_security_group.mail_edge.id
  cidr_ipv4         = each.value
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22

  tags = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.mail_edge.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  tags = local.common_tags
}

resource "aws_iam_role" "ssm" {
  count = var.enable_ssm_session_manager ? 1 : 0

  name               = local.role_name
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  count = var.enable_ssm_session_manager ? 1 : 0

  role       = aws_iam_role.ssm[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "mail_edge_cloudwatch_logs" {
  count = var.enable_cloudwatch_observability ? 1 : 0

  name   = "${local.role_name}-cloudwatch-logs"
  role   = aws_iam_role.ssm[0].id
  policy = data.aws_iam_policy_document.mail_edge_cloudwatch_logs[0].json
}

resource "aws_iam_instance_profile" "ssm" {
  count = var.enable_ssm_session_manager ? 1 : 0

  name = local.role_name
  role = aws_iam_role.ssm[0].name

  tags = local.common_tags
}

# A public address is required for inbound mail and WireGuard before the EIP is associated.
resource "aws_instance" "mail_edge" { # nosemgrep: terraform.aws.security.aws-ec2-has-public-ip.aws-ec2-has-public-ip
  ami                         = var.ami_id != null ? var.ami_id : data.aws_ssm_parameter.al2023_ami[0].value
  instance_type               = var.instance_type
  subnet_id                   = local.effective_subnet_id
  vpc_security_group_ids      = [aws_security_group.mail_edge.id]
  key_name                    = var.key_name
  iam_instance_profile        = var.enable_ssm_session_manager ? aws_iam_instance_profile.ssm[0].name : null
  associate_public_ip_address = true
  monitoring                  = false

  user_data_base64 = base64encode(templatefile("${path.module}/templates/user_data.sh.tftpl", {
    wireguard_ec2_tunnel_ip        = local.wireguard_ec2_tunnel_ip
    wireguard_prefix_length        = local.wireguard_prefix_length
    wireguard_listen_port          = var.wireguard_listen_port
    wireguard_ec2_private_key      = var.wireguard_ec2_private_key
    home_wireguard_peer_public_key = var.home_wireguard_peer_public_key
    wireguard_home_allowed_ips     = join(", ", local.effective_wireguard_home_allowed_ips)
    home_mailu_tunnel_ip           = local.effective_home_mailu_tunnel_ip
    forward_ports                  = local.public_tcp_ports
  }))

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    encrypted             = true
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  dynamic "credit_specification" {
    for_each = startswith(var.instance_type, "t3.") || startswith(var.instance_type, "t4g.") ? [1] : []
    content {
      cpu_credits = "standard"
    }
  }

  # The edge is a persistent ingress appliance. AMI and bootstrap user-data
  # upgrades must be deliberate maintenance operations; automatically chasing
  # the latest AL2023 AMI during an observability-only apply would replace it.
  lifecycle {
    ignore_changes = [
      ami,
      user_data,
      user_data_base64,
    ]
  }

  tags = merge(local.common_tags, {
    Name = local.instance_name
  })
}

resource "aws_eip" "mail_edge" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.instance_name}-eip"
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_eip_association" "mail_edge" {
  allocation_id = aws_eip.mail_edge.id
  instance_id   = aws_instance.mail_edge.id
}

# HAProxy logs contain connection metadata and public source IP addresses. The
# log group is created by Terraform so the instance only needs stream-scoped
# write permissions, not broad CloudWatchAgentServerPolicy access.
resource "aws_cloudwatch_log_group" "mail_edge_haproxy" { # nosemgrep: terraform.aws.security.aws-cloudwatch-log-group-unencrypted.aws-cloudwatch-log-group-unencrypted
  count = var.enable_cloudwatch_observability ? 1 : 0

  name              = local.mail_edge_log_group_name
  retention_in_days = var.mail_edge_log_retention_days
  tags              = local.common_tags
}

resource "aws_sns_topic" "mail_edge_alerts" {
  count = var.enable_cloudwatch_observability ? 1 : 0

  name = local.mail_edge_alert_topic_name
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "mail_edge_alerts_sms" {
  count = var.enable_cloudwatch_observability && var.mail_edge_alert_phone_number != null ? 1 : 0

  topic_arn = aws_sns_topic.mail_edge_alerts[0].arn
  protocol  = "sms"
  endpoint  = var.mail_edge_alert_phone_number
}

resource "aws_cloudwatch_log_metric_filter" "smtp_connections" {
  count = var.enable_cloudwatch_observability ? 1 : 0

  name           = "${local.instance_name}-smtp-connections"
  log_group_name = aws_cloudwatch_log_group.mail_edge_haproxy[0].name
  pattern        = "{ $.event = \"connection\" && $.frontend = \"fe_mail_25\" && $.termination_state != \"PR\" }"

  metric_transformation {
    name          = "SmtpConnections"
    namespace     = local.mail_edge_metric_namespace
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "backend_unavailable" {
  count = var.enable_cloudwatch_observability ? 1 : 0

  name           = "${local.instance_name}-backend-unavailable"
  log_group_name = aws_cloudwatch_log_group.mail_edge_haproxy[0].name
  pattern        = "\"has no server available\""

  metric_transformation {
    name          = "BackendUnavailable"
    namespace     = local.mail_edge_metric_namespace
    value         = "1"
    default_value = "0"
    unit          = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "relay_canary_critical" {
  count = var.enable_cloudwatch_observability && var.enable_open_relay_canary ? 1 : 0

  name           = "${local.instance_name}-relay-canary-critical"
  log_group_name = aws_cloudwatch_log_group.mail_edge_haproxy[0].name
  pattern        = "{ $.event = \"relay_canary\" && $.status = \"critical\" }"

  metric_transformation {
    name      = "RelayCanaryCritical"
    namespace = local.mail_edge_metric_namespace
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "relay_canary_indeterminate" {
  count = var.enable_cloudwatch_observability && var.enable_open_relay_canary ? 1 : 0

  name           = "${local.instance_name}-relay-canary-indeterminate"
  log_group_name = aws_cloudwatch_log_group.mail_edge_haproxy[0].name
  pattern        = "{ $.event = \"relay_canary\" && $.status = \"indeterminate\" }"

  metric_transformation {
    name      = "RelayCanaryIndeterminate"
    namespace = local.mail_edge_metric_namespace
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "relay_canary_heartbeat" {
  count = var.enable_cloudwatch_observability && var.enable_open_relay_canary ? 1 : 0

  name           = "${local.instance_name}-relay-canary-heartbeat"
  log_group_name = aws_cloudwatch_log_group.mail_edge_haproxy[0].name
  pattern        = "{ $.event = \"relay_canary\" && $.heartbeat = 1 }"

  metric_transformation {
    name      = "RelayCanaryHeartbeat"
    namespace = local.mail_edge_metric_namespace
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "smtp_connection_surge" {
  count = var.enable_cloudwatch_observability ? 1 : 0

  alarm_name          = "${local.instance_name}-smtp-connection-surge"
  alarm_description   = "Public SMTP connection volume at the Mailu AWS edge exceeded the expected homelab baseline in at least two of three five-minute periods. Use the HAProxy log group's source_ip field to identify top contributors."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  metric_name         = aws_cloudwatch_log_metric_filter.smtp_connections[0].metric_transformation[0].name
  namespace           = local.mail_edge_metric_namespace
  period              = 300
  statistic           = "Sum"
  threshold           = var.mail_edge_smtp_connection_alarm_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.mail_edge_alerts[0].arn]
  ok_actions          = []
  tags                = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "backend_unavailable" {
  count = var.enable_cloudwatch_observability ? 1 : 0

  alarm_name          = "${local.instance_name}-backend-unavailable"
  alarm_description   = "HAProxy reported that a Mailu backend had no available server."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.backend_unavailable[0].metric_transformation[0].name
  namespace           = local.mail_edge_metric_namespace
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.mail_edge_alerts[0].arn]
  ok_actions          = [aws_sns_topic.mail_edge_alerts[0].arn]
  tags                = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "relay_canary_critical" {
  count = var.enable_cloudwatch_observability && var.enable_open_relay_canary ? 1 : 0

  alarm_name          = "${local.instance_name}-relay-canary-critical"
  alarm_description   = "The AWS mail edge received a 2xx RCPT response for a non-local recipient through the WireGuard Mailu backend path. Treat this as an active relay-policy regression. The probe never sends DATA."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.relay_canary_critical[0].metric_transformation[0].name
  namespace           = local.mail_edge_metric_namespace
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.mail_edge_alerts[0].arn]
  ok_actions          = [aws_sns_topic.mail_edge_alerts[0].arn]
  tags                = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "relay_canary_indeterminate" {
  count = var.enable_cloudwatch_observability && var.enable_open_relay_canary ? 1 : 0

  alarm_name          = "${local.instance_name}-relay-canary-indeterminate"
  alarm_description   = "The AWS mail-edge RCPT-only probe could not conclusively verify Postfix relay rejection because of a transport, protocol, or temporary SMTP failure."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.relay_canary_indeterminate[0].metric_transformation[0].name
  namespace           = local.mail_edge_metric_namespace
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.mail_edge_alerts[0].arn]
  ok_actions          = [aws_sns_topic.mail_edge_alerts[0].arn]
  tags                = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "relay_canary_heartbeat_missing" {
  count = var.enable_cloudwatch_observability && var.enable_open_relay_canary ? 1 : 0

  alarm_name          = "${local.instance_name}-relay-canary-heartbeat-missing"
  alarm_description   = "No AWS mail-edge relay-canary result reached CloudWatch for three consecutive five-minute periods. Check the systemd timer, probe service, and CloudWatch Agent."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  metric_name         = aws_cloudwatch_log_metric_filter.relay_canary_heartbeat[0].metric_transformation[0].name
  namespace           = local.mail_edge_metric_namespace
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.mail_edge_alerts[0].arn]
  ok_actions          = [aws_sns_topic.mail_edge_alerts[0].arn]
  tags                = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "instance_status" {
  count = var.enable_cloudwatch_observability ? 1 : 0

  alarm_name          = "${local.instance_name}-instance-status"
  alarm_description   = "The EC2 mail edge failed an instance or system status check."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.mail_edge_alerts[0].arn]
  ok_actions          = [aws_sns_topic.mail_edge_alerts[0].arn]

  dimensions = {
    InstanceId = aws_instance.mail_edge.id
  }

  tags = local.common_tags
}

# State Manager configures both existing and newly created edge instances.
# Relying on user_data alone would not update an already-running instance.
resource "aws_ssm_association" "mail_edge_observability" {
  count = var.enable_cloudwatch_observability ? 1 : 0

  association_name = "${local.instance_name}-observability"
  name             = "AWS-RunShellScript"

  parameters = {
    commands = templatefile("${path.module}/templates/configure_observability.sh.tftpl", {
      aws_region                   = var.aws_region
      haproxy_log_group            = aws_cloudwatch_log_group.mail_edge_haproxy[0].name
      local_log_max_bytes          = var.mail_edge_local_log_max_bytes
      smtp_blocked_cidr_blocks     = join("\n", var.mail_edge_smtp_blocked_cidr_blocks)
      relay_canary_enabled         = var.enable_open_relay_canary
      relay_canary_host            = local.effective_home_mailu_tunnel_ip
      relay_canary_mail_from       = var.open_relay_canary_mail_from
      relay_canary_port            = var.open_relay_canary_port
      relay_canary_rcpt_to         = var.open_relay_canary_rcpt_to
      relay_canary_script_b64      = base64encode(file("${path.module}/scripts/mail_edge_relay_canary.py"))
      relay_canary_timeout_seconds = var.open_relay_canary_timeout_seconds
    })
  }

  targets {
    key    = "InstanceIds"
    values = [aws_instance.mail_edge.id]
  }

  depends_on = [
    aws_eip_association.mail_edge,
    aws_iam_role_policy.mail_edge_cloudwatch_logs,
  ]
}

resource "aws_route53_record" "mail_a" {
  count = local.manage_public_mail_dns_records ? 1 : 0

  zone_id = var.route53_zone_id
  name    = local.effective_mail_hostname
  type    = "A"
  ttl     = 300
  records = [aws_eip.mail_edge.public_ip]
}

resource "aws_route53_record" "mail_mx" {
  count = local.manage_public_mail_dns_records ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.mail_domain
  type    = "MX"
  ttl     = 300
  records = ["10 ${local.effective_mail_hostname}."]
}

resource "aws_route53_record" "mail_autoconfig" {
  for_each = local.manage_public_mail_dns_records ? toset([
    "autoconfig.${var.mail_domain}",
    "autodiscover.${var.mail_domain}",
  ]) : toset([])

  zone_id = var.route53_zone_id
  name    = each.value
  type    = "CNAME"
  ttl     = 300
  records = [local.effective_mail_hostname]
}

resource "aws_eip_domain_name" "mail_edge" {
  count = local.manage_eip_reverse_dns ? 1 : 0

  allocation_id = aws_eip.mail_edge.allocation_id
  domain_name   = aws_route53_record.mail_a[0].fqdn
}

removed {
  from = aws_ses_domain_identity.mail

  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_ses_domain_dkim.mail

  lifecycle {
    destroy = false
  }
}

resource "aws_sesv2_email_identity" "mail" {
  for_each = var.enable_ses ? toset([var.mail_domain]) : toset([])

  email_identity         = each.key
  configuration_set_name = var.enable_ses_monitoring ? aws_ses_configuration_set.mailu[0].name : null

  dkim_signing_attributes {
    next_signing_key_length = "RSA_2048_BIT"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ses_domain_mail_from" "mail" {
  count = var.enable_ses ? 1 : 0

  domain                 = aws_sesv2_email_identity.mail[var.mail_domain].email_identity
  mail_from_domain       = local.mail_from_domain
  behavior_on_mx_failure = "RejectMessage"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_record" "ses_dkim" {
  count = local.manage_ses_dns_records ? 3 : 0

  zone_id = var.route53_zone_id
  name    = "${aws_sesv2_email_identity.mail[var.mail_domain].dkim_signing_attributes[0].tokens[count.index]}._domainkey.${var.mail_domain}"
  type    = "CNAME"
  ttl     = 300
  records = ["${aws_sesv2_email_identity.mail[var.mail_domain].dkim_signing_attributes[0].tokens[count.index]}.dkim.amazonses.com"]
}

resource "aws_route53_record" "ses_mail_from_mx" {
  count = local.manage_ses_dns_records ? 1 : 0

  zone_id = var.route53_zone_id
  name    = local.mail_from_domain
  type    = "MX"
  ttl     = 300
  records = ["10 feedback-smtp.${var.aws_region}.amazonses.com"]
}

resource "aws_route53_record" "ses_mail_from_txt" {
  count = local.manage_ses_dns_records ? 1 : 0

  zone_id = var.route53_zone_id
  name    = local.mail_from_domain
  type    = "TXT"
  ttl     = 300
  records = ["\"v=spf1 include:amazonses.com ~all\""]
}

resource "aws_ses_configuration_set" "mailu" {
  count = var.enable_ses && var.enable_ses_monitoring ? 1 : 0

  name                       = local.ses_configuration_set_name
  reputation_metrics_enabled = false
  sending_enabled            = true
}

resource "aws_sesv2_account_vdm_attributes" "mailu" {
  count = var.enable_ses && var.enable_ses_vdm ? 1 : 0

  vdm_enabled = "ENABLED"

  dashboard_attributes {
    engagement_metrics = var.enable_ses_vdm_engagement_metrics ? "ENABLED" : "DISABLED"
  }

  guardian_attributes {
    optimized_shared_delivery = var.enable_ses_vdm_optimized_shared_delivery ? "ENABLED" : "DISABLED"
  }
}

resource "aws_sns_topic" "ses_events" {
  count = var.enable_ses && var.enable_ses_monitoring ? 1 : 0

  name = local.ses_event_topic_name
  tags = local.common_tags
}

resource "aws_sns_topic_policy" "ses_events" {
  count = var.enable_ses && var.enable_ses_monitoring ? 1 : 0

  arn    = aws_sns_topic.ses_events[0].arn
  policy = data.aws_iam_policy_document.ses_event_topic[0].json
}

resource "aws_sqs_queue" "ses_events" {
  count = var.enable_ses && var.enable_ses_monitoring ? 1 : 0

  name                       = local.ses_event_topic_name
  message_retention_seconds  = 1209600
  sqs_managed_sse_enabled    = true
  visibility_timeout_seconds = 60
  tags                       = local.common_tags
}

resource "aws_sqs_queue_policy" "ses_events" {
  count = var.enable_ses && var.enable_ses_monitoring ? 1 : 0

  queue_url = aws_sqs_queue.ses_events[0].url
  policy    = data.aws_iam_policy_document.ses_event_queue[0].json
}

resource "aws_sns_topic_subscription" "ses_events_sqs" {
  count = var.enable_ses && var.enable_ses_monitoring ? 1 : 0

  topic_arn            = aws_sns_topic.ses_events[0].arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.ses_events[0].arn
  raw_message_delivery = true

  depends_on = [aws_sqs_queue_policy.ses_events]
}

resource "aws_ses_event_destination" "cloudwatch" {
  count = var.enable_ses && var.enable_ses_monitoring ? 1 : 0

  name                   = "cloudwatch"
  configuration_set_name = aws_ses_configuration_set.mailu[0].name
  enabled                = true
  matching_types         = ["send", "reject", "bounce", "complaint", "delivery", "renderingFailure"]

  cloudwatch_destination {
    default_value  = aws_ses_configuration_set.mailu[0].name
    dimension_name = "ses:configuration-set"
    value_source   = "messageTag"
  }
}

resource "aws_ses_event_destination" "sns_failures" {
  count = var.enable_ses && var.enable_ses_monitoring ? 1 : 0

  name                   = "sns-failures"
  configuration_set_name = aws_ses_configuration_set.mailu[0].name
  enabled                = true
  matching_types         = ["reject", "bounce", "complaint", "renderingFailure"]

  sns_destination {
    topic_arn = aws_sns_topic.ses_events[0].arn
  }

  depends_on = [aws_sns_topic_policy.ses_events]
}

resource "aws_sns_topic" "ses_alerts" {
  count = var.enable_ses && var.enable_ses_monitoring ? 1 : 0

  name = local.ses_alert_topic_name
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "ses_alerts_sms" {
  count = var.enable_ses && var.enable_ses_monitoring && var.email_canary_alert_phone_number != null ? 1 : 0

  topic_arn = aws_sns_topic.ses_alerts[0].arn
  protocol  = "sms"
  endpoint  = var.email_canary_alert_phone_number
}

resource "aws_cloudwatch_metric_alarm" "ses_send_volume" {
  count = var.enable_ses && var.enable_ses_monitoring ? 1 : 0

  alarm_name          = "${local.ses_configuration_set_name}-send-volume"
  alarm_description   = "SES accepted at least ${var.ses_send_volume_threshold} recipients in ${var.ses_alarm_period_seconds} seconds. Investigate unexpected outbound volume."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  metric_name         = "Send"
  namespace           = "AWS/SES"
  period              = var.ses_alarm_period_seconds
  statistic           = "Sum"
  threshold           = var.ses_send_volume_threshold
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.ses_alerts[0].arn]
  tags                = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "ses_bounce_reputation" {
  count = var.enable_ses && var.enable_ses_monitoring ? 1 : 0

  alarm_name          = "${local.ses_configuration_set_name}-bounce-reputation"
  alarm_description   = "SES account bounce reputation reached ${var.ses_bounce_rate_threshold}; AWS reviews accounts above 0.05."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  metric_name         = "Reputation.BounceRate"
  namespace           = "AWS/SES"
  period              = var.ses_alarm_period_seconds
  statistic           = "Average"
  threshold           = var.ses_bounce_rate_threshold
  treat_missing_data  = "ignore"
  alarm_actions       = [aws_sns_topic.ses_alerts[0].arn]
  tags                = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "ses_complaint_reputation" {
  count = var.enable_ses && var.enable_ses_monitoring ? 1 : 0

  alarm_name          = "${local.ses_configuration_set_name}-complaint-reputation"
  alarm_description   = "SES account complaint reputation reached ${var.ses_complaint_rate_threshold}; AWS reviews accounts above 0.001."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  metric_name         = "Reputation.ComplaintRate"
  namespace           = "AWS/SES"
  period              = var.ses_alarm_period_seconds
  statistic           = "Average"
  threshold           = var.ses_complaint_rate_threshold
  treat_missing_data  = "ignore"
  alarm_actions       = [aws_sns_topic.ses_alerts[0].arn]
  tags                = local.common_tags
}

resource "aws_iam_user" "ses_smtp" {
  count = var.enable_ses ? 1 : 0

  name = local.smtp_user_name
  tags = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_user_policy" "ses_smtp" {
  count = var.enable_ses ? 1 : 0

  name   = "${local.smtp_user_name}-send"
  user   = aws_iam_user.ses_smtp[0].name
  policy = data.aws_iam_policy_document.ses_smtp_send[0].json

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_access_key" "ses_smtp" {
  count = var.enable_ses ? 1 : 0

  user = aws_iam_user.ses_smtp[0].name

  lifecycle {
    create_before_destroy = true
    replace_triggered_by  = [terraform_data.ses_smtp_credential_rotation[0]]
  }
}

resource "terraform_data" "ses_smtp_credential_rotation" {
  count = var.enable_ses ? 1 : 0

  input            = var.ses_smtp_credential_version
  triggers_replace = [var.ses_smtp_credential_version]
}

resource "aws_iam_user" "grafana_cloudwatch" {
  count = var.enable_ses ? 1 : 0

  name = local.cloudwatch_reader_user_name
  tags = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_user_policy" "grafana_cloudwatch" {
  count = var.enable_ses ? 1 : 0

  name   = "${local.cloudwatch_reader_user_name}-read"
  user   = aws_iam_user.grafana_cloudwatch[0].name
  policy = data.aws_iam_policy_document.grafana_cloudwatch_read[0].json

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_access_key" "grafana_cloudwatch" {
  count = var.enable_ses ? 1 : 0

  user = aws_iam_user.grafana_cloudwatch[0].name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_sns_topic" "email_canary_alerts" {
  count = var.enable_email_canary ? 1 : 0

  name = "${local.email_canary_name}-alerts"
  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "email_canary_sms" {
  count = var.enable_email_canary && var.email_canary_alert_phone_number != null ? 1 : 0

  topic_arn = aws_sns_topic.email_canary_alerts[0].arn
  protocol  = "sms"
  endpoint  = var.email_canary_alert_phone_number
}

# Canary logs contain delivery status only; AWS-managed encryption is sufficient here.
resource "aws_cloudwatch_log_group" "email_canary" { # nosemgrep: terraform.aws.security.aws-cloudwatch-log-group-unencrypted.aws-cloudwatch-log-group-unencrypted
  count = var.enable_email_canary ? 1 : 0

  name              = "/aws/lambda/${local.email_canary_name}"
  retention_in_days = var.email_canary_log_retention_days
  tags              = local.common_tags
}

resource "aws_iam_role" "email_canary" {
  count = var.enable_email_canary ? 1 : 0

  name               = local.email_canary_name
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role[0].json
  tags               = local.common_tags
}

resource "aws_iam_role_policy" "email_canary" {
  count = var.enable_email_canary ? 1 : 0

  name   = "${local.email_canary_name}-policy"
  role   = aws_iam_role.email_canary[0].id
  policy = data.aws_iam_policy_document.email_canary[0].json
}

# The short scheduled canary already emits structured logs and has no downstream trace propagation.
resource "aws_lambda_function" "email_canary" { # nosemgrep: terraform.aws.security.aws-lambda-x-ray-tracing-not-active.aws-lambda-x-ray-tracing-not-active
  count = var.enable_email_canary ? 1 : 0

  function_name    = local.email_canary_name
  description      = "Sends and verifies SES email canary delivery, then alerts by SMS on failures."
  role             = aws_iam_role.email_canary[0].arn
  handler          = "email_canary.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.email_canary[0].output_path
  source_code_hash = data.archive_file.email_canary[0].output_base64sha256
  timeout          = var.email_canary_lambda_timeout_seconds
  memory_size      = 128

  # These values are configuration and ARNs; secret values are fetched from Secrets Manager at runtime.
  environment { # nosemgrep: terraform.aws.security.aws-lambda-environment-unencrypted.aws-lambda-environment-unencrypted
    variables = {
      ALERT_TOPIC_ARN          = aws_sns_topic.email_canary_alerts[0].arn
      CANARY_FROM_ADDRESS      = var.email_canary_from_address
      CANARY_TO_ADDRESS        = var.email_canary_to_address
      DELIVERY_TIMEOUT_SECONDS = tostring(var.email_canary_delivery_timeout_seconds)
      IMAP_SECRET_ARN          = var.email_canary_imap_secret_arn
      MAIL_DOMAIN              = var.mail_domain
      PROBES_JSON              = jsonencode(local.email_canary_probes)
      SES_REGION               = var.aws_region
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.email_canary,
    aws_iam_role_policy.email_canary,
  ]

  tags = local.common_tags
}

resource "aws_cloudwatch_event_rule" "email_canary" {
  count = var.enable_email_canary ? 1 : 0

  name                = "${local.email_canary_name}-schedule"
  description         = "Run the SES email canary on the configured delivery-check schedule."
  schedule_expression = var.email_canary_schedule_expression
  tags                = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "email_canary_heartbeat_missing" {
  count = var.enable_email_canary ? 1 : 0

  alarm_name          = "${local.email_canary_name}-heartbeat-missing"
  alarm_description   = "The SES email canary missed two consecutive 15-minute invocation windows. Check the EventBridge schedule, Lambda function, and CloudWatch logs."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 1
  metric_name         = "Invocations"
  namespace           = "AWS/Lambda"
  period              = 900
  statistic           = "Sum"
  treat_missing_data  = "breaching"
  dimensions = {
    FunctionName = aws_lambda_function.email_canary[0].function_name
  }
  alarm_actions             = [aws_sns_topic.email_canary_alerts[0].arn]
  ok_actions                = [aws_sns_topic.email_canary_alerts[0].arn]
  insufficient_data_actions = []
  tags                      = local.common_tags
}

resource "aws_cloudwatch_event_target" "email_canary" {
  count = var.enable_email_canary ? 1 : 0

  rule      = aws_cloudwatch_event_rule.email_canary[0].name
  target_id = local.email_canary_name
  arn       = aws_lambda_function.email_canary[0].arn
}

resource "aws_lambda_permission" "allow_email_canary_schedule" {
  count = var.enable_email_canary ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.email_canary[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.email_canary[0].arn
}

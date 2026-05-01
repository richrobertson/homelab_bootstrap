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
  email_canary_name                    = substr("${replace(var.name_prefix, "/[^A-Za-z0-9+=,.@_-]/", "-")}-email-canary", 0, 64)
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

  vpc_cidr           = "10.250.80.0/24"
  public_subnet_cidr = "10.250.80.0/26"

  effective_vpc_id    = var.create_vpc ? aws_vpc.mail_edge[0].id : coalesce(var.vpc_id, data.aws_subnet.existing[0].vpc_id)
  effective_subnet_id = var.create_vpc ? aws_subnet.public[0].id : var.subnet_id

  ses_dns_records = var.enable_ses ? concat(
    [
      {
        name    = "_amazonses.${var.mail_domain}"
        type    = "TXT"
        ttl     = 300
        records = [format("\"%s\"", aws_ses_domain_identity.mail[0].verification_token)]
      }
    ],
    [
      for idx in range(3) : {
        name    = "${aws_ses_domain_dkim.mail[0].dkim_tokens[idx]}._domainkey.${var.mail_domain}"
        type    = "CNAME"
        ttl     = 300
        records = ["${aws_ses_domain_dkim.mail[0].dkim_tokens[idx]}.dkim.amazonses.com"]
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
}

data "aws_partition" "current" {}

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

data "aws_iam_policy_document" "email_canary" {
  count = var.enable_email_canary ? 1 : 0

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

resource "aws_subnet" "public" {
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

resource "aws_iam_instance_profile" "ssm" {
  count = var.enable_ssm_session_manager ? 1 : 0

  name = local.role_name
  role = aws_iam_role.ssm[0].name

  tags = local.common_tags
}

resource "aws_instance" "mail_edge" {
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

resource "aws_ses_domain_identity" "mail" {
  count = var.enable_ses ? 1 : 0

  domain = var.mail_domain

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ses_domain_dkim" "mail" {
  count = var.enable_ses ? 1 : 0

  domain = aws_ses_domain_identity.mail[0].domain

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ses_domain_mail_from" "mail" {
  count = var.enable_ses ? 1 : 0

  domain           = aws_ses_domain_identity.mail[0].domain
  mail_from_domain = local.mail_from_domain

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_record" "ses_verification" {
  count = local.manage_ses_dns_records ? 1 : 0

  zone_id = var.route53_zone_id
  name    = "_amazonses.${var.mail_domain}"
  type    = "TXT"
  ttl     = 300
  records = [format("\"%s\"", aws_ses_domain_identity.mail[0].verification_token)]
}

resource "aws_route53_record" "ses_dkim" {
  count = local.manage_ses_dns_records ? 3 : 0

  zone_id = var.route53_zone_id
  name    = "${aws_ses_domain_dkim.mail[0].dkim_tokens[count.index]}._domainkey.${var.mail_domain}"
  type    = "CNAME"
  ttl     = 300
  records = ["${aws_ses_domain_dkim.mail[0].dkim_tokens[count.index]}.dkim.amazonses.com"]
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

resource "aws_ses_domain_identity_verification" "mail" {
  count = local.manage_ses_dns_records && var.wait_for_ses_domain_verification ? 1 : 0

  domain = aws_ses_domain_identity.mail[0].domain

  depends_on = [aws_route53_record.ses_verification]

  lifecycle {
    prevent_destroy = true
  }
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

resource "aws_cloudwatch_log_group" "email_canary" {
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

resource "aws_lambda_function" "email_canary" {
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

  environment {
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
  description         = "Run the SES email canary every five minutes."
  schedule_expression = var.email_canary_schedule_expression
  tags                = local.common_tags
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

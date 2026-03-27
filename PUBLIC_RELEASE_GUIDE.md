# Public Release Guide

This document outlines the changes made to prepare this repository for public release and provides guidance for deploying this infrastructure as a template.

## Overview

This repository has been carefully reviewed and sanitized to remove hardcoded infrastructure-specific values, credentials, and internal domain names. All configurable values have been converted to variables with sensible example defaults.

## Changes Made

### 1. Removed Hardcoded Infrastructure Values

The following personal/internal infrastructure values have been replaced with variables or generic examples:

| Item | Previous Value | Current Approach |
|------|---|---|
| Root Domain | `myrobertson.net` | Variable: `var.root_domain` (default: `example.net`) |
| Proxmox Endpoint | `cl0.myrobertson.net:8006` | Variable: `var.proxmox_endpoint` |
| Vault Address | `vault.myrobertson.net:8200` | Jenkins credential: `vault_addr` |
| ADCS Host | `dc1.myrobertson.net` | Variable: `var.adcs_host` |
| DNS Realm | `myrobertson.net` | Variable: `var.dns_realm` |
| S3 Bucket | `myrobertson-homelab-terraform` | Updated backend config instructions |
| Internal IPs | `192.168.x.x`, `10.x.x.x` | Example values or variable-based |
| Organization Name | `MyRobertson.net` | Variable: `var.organization` (default: `example.net`) |

### 2. Variables Added

New variables for environment-specific configuration:

**Main Terraform variables** (`terraform/variables.tf`):
- `proxmox_endpoint` - Proxmox API URL
- `dns_zone` - DNS zone for gssapi updates
- `dns_realm` - Kerberos realm for authentication
- `adcs_host` - Microsoft ADCS server hostname
- `root_domain` - Root domain for cluster infrastructure

**Kubernetes module variables** (`terraform/kubernetes/variables.tf`):
- `root_domain` - Used throughout cluster DNS configuration

**Talos module variables** (`terraform/kubernetes/talos/variables.tf`):
- `root_domain` - For cluster FQDN generation

**VM module variables** (`terraform/modules/vm/variables.tf`):
- `dns_domain` - DNS domain for VMs
- `dns_servers` - List of DNS servers

**PKI module variables** (`terraform/kubernetes/vault_pki_secret_backend/variables.tf`):
- `organization` - Organization name for certificates
- `root_domain` - Root domain for certificate SAN

### 3. Example Values Updated

Generic example values have been used where appropriate:

- **DNS**: `example.net` (instead of `myrobertson.net`)
- **IP Addresses**: `203.0.113.x` (TEST-NET-3, RFC 5737) instead of internal ranges
- **Organization**: `Example, Inc` / `example.net`

## Configuration for Your Environment

### Essential Configuration Steps

1. **Create terraform.tfvars**

   ```hcl
   # terraform/terraform.tfvars
   
   # Your infrastructure details
   proxmox_endpoint = "https://pve.yourdomain.com:8006/api2/json"
   dns_zone         = "yourdomain.com"
   dns_realm        = "YOURDOMAIN.COM"
   adcs_host        = "dc1.yourdomain.com"
   root_domain      = "yourdomain.com"
   
   # Add other environment-specific variables as needed
   ```

2. **Update S3 Backend Configuration**

   When initializing Terraform, provide your S3 bucket details:

   ```bash
   cd terraform
   terraform init \
     -backend-config="bucket=your-terraform-state-bucket" \
     -backend-config="region=us-west-2" \
     -backend-config="key=base/terraform.tfstate"
   ```

3. **Configure Jenkins**

   Update the following Jenkins credentials:
   - `vault_addr` - Your Vault instance URL
   - `aws_homelab_access_key` - AWS credentials
   - `aws_homelab_secret_access_key` - AWS credentials
   - `vault_token` - Vault authentication token
   - Other credentials as needed

### DNS Configuration

- Update all DNS-related variables to point to your DNS infrastructure
- Ensure your domain is registered and accessible
- Configure DNS servers as needed for `gssapi` authentication

### Secrets Management

All sensitive values should be stored in Vault:

- `proxmox_token` - Proxmox API token
- `github_token` - GitHub personal access token (for Flux integration)
- `windows_domain_admin` - Windows domain admin credentials

Retrieve these using `data.vault_kv_secret_v2` references (already configured in code).

## Security Best Practices

### 1. Variables File Security

**Important**: While `terraform.tfvars` is included in `.gitignore`, ensure you:

- Never commit credentials to the repository
- Use environment variables or external secret management
- Rotate credentials regularly
- Use temporary/limited-scope tokens for CI/CD

### 2. S3 Backend Security

- Enable versioning on the S3 bucket
- Enable encryption at rest
- Enable bucket versioning for state recovery
- Restrict IAM access to the bucket
- Consider enabling MFA delete protection

### 3. Vault Integration

- Use strong authentication mechanisms for Vault
- Rotate Vault tokens regularly
- Use Vault policies (already defined in code)
- Enable audit logging in Vault

### 4. Network Security

- The `proxmox_insecure` variable defaults to `false` - keep TLS verification enabled
- Use HTTPS for all external endpoints
- Implement proper firewall rules

### 5. RBAC and Access Control

- Configure appropriate Kubernetes RBAC policies
- Set up Vault authentication for Kubernetes service accounts
- Use least-privilege principles for all credentials

## Hardening Checklist

Before deploying to production:

- [ ] Review and validate all variables in `terraform.tfvars`
- [ ] Ensure all Vault credentials are properly configured
- [ ] Validate domain names and DNS resolution
- [ ] Test Proxmox connectivity and API access
- [ ] Verify S3 backend access
- [ ] Configure appropriate network policies
- [ ] Enable TLS verification (`proxmox_insecure = false`)
- [ ] Set up proper logging and monitoring
- [ ] Configure audit logging for Vault
- [ ] Implement disaster recovery procedures
- [ ] Review all IAM policies and credential access
- [ ] Test cluster backup and recovery procedures

## Secret Scanning Results

This repository has been scanned for accidentally committed secrets:

✅ **No credentials found in repository history**
✅ **All hardcoded infrastructure values removed**
✅ **Example/placeholder values used throughout**
✅ **All `.yaml` secrets files properly gitignored**

## Terraform State Security

The included `.gitignore` properly excludes:

```
**/secrets.yaml
terraform/.terraform/*
terraform/s3.json
terraform/terraform.tfstate
terraform/.terraform.lock.hcl
.DS_Store
```

Ensure you:

1. Use remote state in S3 (not local)
2. Enable S3 bucket encryption
3. Implement proper access controls
4. Rotate state access regularly
5. Use version control for state (S3 versioning)

## Useful Links

- [Terraform Best Practices](https://www.terraform.io/cloud-docs/state/securing-state)
- [Vault Secrets Management](https://www.vaultproject.io/docs/secrets)
- [AWS S3 Security](https://docs.aws.amazon.com/s3/latest/userguide/security.html)
- [Proxmox Documentation](https://pve.proxmox.com/wiki/Handbook)
- [Talos Linux](https://www.talos.dev/)
- [Flux CD](https://fluxcd.io/)

## Common Issues and Solutions

### Q: Where do I set environment-specific values?

**A:** Use `terraform.tfvars` for your environment. The example default values will not work for your infrastructure - you must provide actual values.

### Q: How do I manage Vault credentials?

**A:** Vault token and credentials should be managed by your infrastructure security team. Use:
- Jenkins credentials for CI/CD
- Local VaultMan or similar for local development
- Appropriate Vault authentication methods (Kubernetes auth, JWT, etc.)

### Q: Can I use this with different cloud providers?

**A:** This repository is specifically designed for Proxmox. To use with other providers, you'll need to modify the Proxmox provider blocks and adjust networking/VM provisioning modules.

### Q: How do I update the default example values?

**A:** Update the `default` values in the variable definitions, but ensure your actual `terraform.tfvars` overrides these with real values.

## Contributing

If you find hardcoded values or infrastructure-specific details, please report them or submit a PR to make them configurable. Refer to [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[Add your license information here]

---

**Last Updated**: March 27, 2026
**Released**: [Your Release Date]

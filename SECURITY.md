# Security Policy

This document outlines security practices for this repository and guidance on reporting security vulnerabilities.

## Reporting Security Vulnerabilities

**DO NOT** open a public issue for security vulnerabilities.

If you discover a security vulnerability in this repository, please report it responsibly:

1. **Email**: [security@example.com](mailto:security@example.com) (Update with your contact)
2. **Include**:
   - Description of the vulnerability
   - Steps to reproduce (if applicable)
   - Potential impact
   - Suggested fix (if you have one)

3. **Response Timeline**:
   - Acknowledgment within 24 hours
   - Initial assessment within 5 days
   - Fix and patched release attempt within 30 days

## Security Best Practices

### 1. Secrets Management

#### ✅ DO:
- Store all credentials in Vault
- Use Vault policies (already implemented in code)
- Rotate credentials regularly (every 90 days minimum)
- Use Vault authentication backends (Kubernetes, JWT, OIDC)
- Enable Vault audit logging
- Use temporary/short-lived tokens in CI/CD

#### ❌ DON'T:
- Commit secrets to the repository
- Use permanent tokens in CI/CD pipelines
- Share credentials via email or chat
- Store credentials in environment variables without encryption
- Use default/hardcoded credentials

### 2. Infrastructure Code Security

#### Scanning for Secrets
This repository is scanned using:
- `git-secrets` or similar tools (configure: `git config core.hooksPath .githooks`)
- Regular manual audits
- Secret scanning in CI/CD pipelines

#### Code Review
All changes go through:
1. Automated validation (Terraform format, validate)
2. Manual security review
3. Vault policies verification
4. Network policy evaluation

### 3. Terraform State Security

#### State Files Contain Secrets
- State files contain sensitive data (passwords, API keys)
- Never commit `.tfstate` files to Git
- Always use remote state (S3 backend configured)

#### S3 Backend Protection:
```hcl
resource "aws_s3_bucket" "terraform_state" {
  bucket = "your-terraform-state-bucket"
}

# Enable versioning for recovery
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

### 4. Proxmox API Security

#### ✅ DO:
- Use API tokens (not user passwords)
- Create limited-scope tokens for specific modules
- Rotate API tokens quarterly
- Use HTTPS only (set `proxmox_insecure = false`)
- Implement rate limiting
- Monitor API access logs

#### ❌ DON'T:
- Use user passwords directly (create API tokens instead)
- Store API credentials locally in plain text
- Share Proxmox credentials
- Disable TLS verification in production

### 5. Network Security

#### Kubernetes Network Policies
✅ Implement network segmentation:
- Restrict egress from cluster pods
- Limit DNS server access
- Control inter-pod communication
- Monitor network traffic

#### Firewall Configuration
✅ GRE tunnel / Inter-VM firewall:
- Restrict control plane access to authorized networks
- Limit egress from control plane
- Implement DDoS protection
- Monitor suspicious traffic

### 6. RBAC and Access Control

#### Kubernetes RBAC
✅ Implement least-privilege access:
```
- Restrict service account permissions
- Use role bindings for teams
- Regular audit of access patterns
- Remove unused service accounts
```

#### Vault Authentication
✅ Configure Kubernetes auth:
- Use Kubernetes service account tokens
- Bind to specific namespaces and service accounts
- Implement role-based access policies
- Regular audit of authenticated entities

### 7. TLS/SSL/PKI

#### Certificate Management
✅ Currently implemented via Vault PKI:
- Intermediate CA in Vault
- Automatic certificate generation
- Short TTLs (3600s for internal certs)
- Regular certificate rotation

⚠️ Ensure:
- Root CA is securely stored
- Backup procedures for root CA
- Incident response plan for compromised CAs

### 8. Audit Logging

#### Enable Comprehensive Logging:
✅ Log the following:
- Vault authentication attempts
- API changes (Proxmox, Kubernetes, DNS)
- User actions in Kubernetes (via audit logs)
- Network policy violations
- Certificate generation and revocation

#### Log Analysis:
- Centralize logs (e.g., ELK stack, Loki)
- Monitor for suspicious patterns
- Set up alerting for security events
- Retain logs for compliance (typically 90-365 days)

### 9. Dependency Security

#### Terraform Provider Updates
✅ Regular updates:
- Monitor security advisories
- Test updates in non-production first
- Update `.terraform.lock.hcl` carefully
- Review changelogs for breaking changes

❌ Never:
- Use pinned/old versions with known vulnerabilities
- Ignore security updates
- Use unverified provider versions

### 10. Asset Security

#### Backups
✅ Implement backup security:
- Encrypt backups at rest
- Restrict backup access
- Test recovery procedures
- Store backups in separate location
- Version control backup scripts

#### VM Images
✅ Secure VM images:
- Use minimal, updated base images
- Scan for vulnerabilities before use
- Document image sources
- Version control image definitions

## Security Hardening Checklist

### Pre-Deployment
- [ ] Review all variables (ensure no secrets)
- [ ] Validate Vault configuration
- [ ] Configure S3 backend with encryption
- [ ] Set up network policies
- [ ] Configure RBAC and service accounts
- [ ] Enable audit logging
- [ ] Review TLS/certificate configuration
- [ ] Test Flux GitOps deployments
- [ ] Configure monitoring and alerting
- [ ] Document disaster recovery procedures

### Initial Deployment
- [ ] Deploy in development/staging first
- [ ] Validate all systems operational
- [ ] Verify logging is working
- [ ] Confirm backup procedures
- [ ] Test cluster scaling
- [ ] Validate networking
- [ ] Confirm Vault access
- [ ] Test failover procedures

### Ongoing Maintenance
- [ ] Monthly: Review access logs
- [ ] Monthly: Verify backups
- [ ] Quarterly: Rotate credentials
- [ ] Quarterly: Update dependencies
- [ ] Semi-annually: Security audit
- [ ] Annually: Disaster recovery test

## Common Vulnerabilities to Avoid

### 1. Hardcoded Secrets
❌ Bad:
```hcl
password = "MySecretPassword123"
api_token = "secret-token-12345"
```

✅ Good:
```hcl
password = data.vault_kv_secret_v2.admin.data["password"]
api_token = data.vault_kv_secret_v2.proxmox.data["api_token"]
```

### 2. Unencrypted Backups
❌ Bad:
```bash
# Plain backup
tar czf backup.tar.gz /data
```

✅ Good:
```bash
# Encrypted backup
tar czf - /data | openssl enc -aes-256-cbc -out backup.tar.gz.enc
```

### 3. Wide Network Access
❌ Bad:
```hcl
security_groups = ["0.0.0.0/0"]  # Open to entire internet
```

✅ Good:
```hcl
security_groups = [var.trusted_cidrs]  # Restricted to specific networks
```

### 4. Disabled TLS Verification
❌ Bad:
```hcl
insecure = true  # In production!
```

✅ Good:
```hcl
insecure = var.proxmox_insecure  # Only for dev, default false
```

### 5. Public State Files
❌ Bad:
```bash
# State file visible to world
gsutil acl ch -u AllUsers:R gs://bucket/terraform.tfstate
```

✅ Good:
```bash
# Private state file with versioning and encryption
aws s3api put-bucket-encryption \
  --bucket my-tfstate \
  --server-side-encryption-configuration rules \
  --public-access-block
```

## Compliance Considerations

### HIPAA
If handling healthcare data:
- Implement encryption at rest and in transit
- Enable audit logging
- Implement access controls
- Document security measures

### PCI DSS
If handling payment card data:
- Network segmentation (PCI requirement #1)
- Strong authentication (requirement #8)
- Encrypted transmission (requirement #4)
- Vulnerability assessment (requirement #11)

### SOC 2
- Document security practices
- Implement change management
- Enable monitoring and alerting
- Regular security audits

## Incident Response

### In Case of Security Breach:

1. **Immediately**:
   - Rotate all credentials
   - Review access logs
   - Assess scope of compromise
   - Notify affected systems

2. **Within 24 Hours**:
   - Document incident details
   - Notify relevant parties
   - Begin forensic analysis
   - Implement mitigations

3. **Follow-up**:
   - Post-mortem analysis
   - Update security measures
   - Communication to stakeholders
   - Monitor for additional incidents

## Security Resources

- [OWASP Top 10](https://owasp.org/Top10/)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/)
- [HashiCorp Vault Security](https://www.vaultproject.io/docs/secrets)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [Terraform Security](https://www.terraform.io/cloud-docs/state/securing-state)
- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)

## Questions

For security-related questions (non-vulnerability), open a Discussion or refer to the [PUBLIC_RELEASE_GUIDE.md](PUBLIC_RELEASE_GUIDE.md).

---

**Last Updated**: March 27, 2026

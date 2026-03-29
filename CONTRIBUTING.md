# Contributing to homelab_bootstrap

Thank you for your interest in contributing to this project! This document provides guidelines for making contributions that maintain the security and quality of this infrastructure-as-code repository.

## Code of Conduct

Be respectful, inclusive, and professional in all interactions. We're building something together.

## Security First

### Before You Contribute

1. **No Secrets in PRs** - Never commit:
   - API keys, tokens, or credentials
   - Private domain names
   - Internal IP addresses
   - Personal information
   - Sensitive configuration values

2. **Use Variables** - If introducing a new configurable value:
   - Add it as a Terraform variable with a default example value
   - Document the variable with clear descriptions
   - Use RFC 5737 (TEST-NET) ranges for example IPs: `203.0.113.0/24`
   - Use generic domain names for examples: `example.com`, `example.net`

3. **Review Checklist**:
   - [ ] No new hardcoded IP addresses (except RFC 5737 examples or RFC1918 ranges that are explicitly part of homelab network design); prefer variables for configurable addresses
   - [ ] No hardcoded domain names (except `example.com`, `example.net`, `example.org`)
   - [ ] No credentials or API keys
   - [ ] No personal information
   - [ ] All secrets referenced via Vault data sources
   - [ ] Example values provided for all required variables

## Getting Started

### 1. Fork and Clone
```bash
git clone https://github.com/[your-username]/homelab_bootstrap.git
cd homelab_bootstrap
```

### 2. Create a Feature Branch
```bash
git checkout -b feature/description-of-changes
# or
git checkout -b fix/description-of-fix
```

### 3. Make Your Changes

#### For Terraform Changes:
- Follow [Terraform style conventions](https://www.terraform.io/docs/language/syntax/style)
- Format code: `terraform fmt -recursive terraform/`
- Validate: `terraform validate`
- Run `terraform plan` to review changes
- Update documentation in module READMEs

#### For Documentation:
- Use clear, concise language
- Include examples where helpful
- Link to relevant resources
- Maintain consistent formatting

### 4. Test Your Changes

```bash
# Validate Terraform syntax
terraform fmt -check -recursive terraform/

# Validate all modules
for dir in terraform/modules/*/; do
  cd "$dir" && terraform init -backend=false && terraform validate && cd -
done

# Plan changes (with your actual configuration)
terraform plan -var-file=terraform.tfvars
```

### 5. Commit and Push

Write meaningful commit messages:

```
feat(module-name): Add feature description

More detailed explanation if needed.

- Bullet point for notable changes
- Another important detail

Fixes #123 (if applicable)
```

Push to your fork:
```bash
git push origin feature/description-of-changes
```

### 6. Create a Pull Request

- Provide a clear title and description
- Reference any related issues
- Include the security checklist (see below)
- Be open to review feedback

### Issues and Discussions

- Use the GitHub issue templates for bug reports and feature requests
- Keep each issue focused on a single problem or proposal
- Route sensitive security findings through [SECURITY.md](SECURITY.md), not public issues
- Include enough detail for someone outside your environment to reproduce the problem

## PR Security Checklist Template

Include this in your PR description:

```markdown
## Security Checklist

- [ ] No hardcoded secrets or credentials
- [ ] No private/internal domain names
- [ ] No internal-use IP addresses
- [ ] All configurable values are variables
- [ ] Example values use RFC 5737 (TEST-NET) or `example.com`
- [ ] Vault references used for sensitive values
- [ ] No personal information included
- [ ] Documentation updated if needed
```

## Types of Contributions

### Bug Fixes
- Clearly describe the bug
- Provide steps to reproduce
- Explain the fix
- Add tests if applicable

### Feature Additions
- Discuss the feature in an issue first (avoid wasted effort)
- Keep changes focused and single-purpose
- Add comprehensive variable documentation
- Update relevant READMEs

### Documentation Improvements
- Fix typos and unclear explanations
- Add examples for complex configurations
- Improve navigation and structure
- Keep security considerations front-and-center

### Security Improvements
- Report serious security issues privately (see Security Policy)
- Discuss enhancements in issues
- Reference security best practices
- Update documentation to reflect changes

## Code Style

### Terraform

```hcl
# Resource names use underscores
resource "proxmox_virtual_environment_vm" "example" {
  # Arguments sorted alphabetically
  name       = "example-vm"
  node_name  = "pve"
  vm_id      = 123
  
  # Nested blocks at the end
  lifecycle {
    ignore_changes = [
      agent[0].timeout
    ]
  }
}

# Variables have descriptions
variable "example_var" {
  description = "Clear, concise description"
  type        = string
  default     = "example-value"
  
  validation {
    condition     = can(regex("^[a-z]+$", var.example_var))
    error_message = "Must contain only lowercase letters."
  }
}

# Locals use descriptive names
locals {
  cluster_endpoint = "https://${var.cluster_name}.${var.root_domain}:6443"
}
```

### Comments

- Write clear comments explaining the "why", not the "what"
- Use `# ` for single-line comments
- Use `/* */` for multi-line comments
- Link to external resources when helpful

```hcl
# This ensures the cluster API is accessible from all subnets
# while restricting direct VM access to control plane nodes
resource "proxmox_virtual_environment_firewall_rules" "cluster" {
  # ...
}
```

## Documentation Standards

- Use Markdown for all documentation
- Include table of contents for long documents
- Provide examples for complex configurations
- Link to relevant external resources
- Keep security considerations visible

## Review Process

1. **Automated Checks**
   - Terraform validation
   - Style checking
   - Secret scanning (via git-secrets or similar)

2. **Manual Review**
   - Code quality and design
   - Security implications
   - Documentation clarity
   - Alignment with project goals

3. **Approval**
   - At least one maintainer must approve
   - Security maintainer may require additional review
   - CI/CD checks must pass

## Common Mistakes to Avoid

1. **❌ Hardcoding IPs**
   ```hcl
   # DON'T DO THIS
   ip4_address = "192.168.1.100/24"
   ```
   
   **✅ DO THIS**
   ```hcl
   # Use variables or cidrhost()
   ip4_address = cidrhost(var.subnet_cidr, 100)
   # OR for examples
   ip4_address = "203.0.113.100/24"
   ```

2. **❌ Personal Domain Names**
   ```hcl
   # DON'T DO THIS
   domain = "mycompany.net"
   ```
   
   **✅ DO THIS**
   ```hcl
   domain = var.root_domain  # With default = "example.net"
   ```

3. **❌ Credentials in Code**
   ```hcl
   # DON'T DO THIS
   password = "MySecretPassword123"
   ```
   
   **✅ DO THIS**
   ```hcl
   password = data.vault_kv_secret_v2.admin.data["password"]
   ```

4. **❌ No Variable Documentation**
   ```hcl
   # DON'T DO THIS
   variable "my_var" {
     type = string
   }
   ```
   
   **✅ DO THIS**
   ```hcl
   variable "my_var" {
     description = "The purpose and expected format of this variable"
     type        = string
     default     = "example-value"
   }
   ```

5. **❌ Undocumented Dependencies**
   ```hcl
   # DON'T DO THIS - relies on external setup
   depends_on = [some_external_resource]
   ```
   
   **✅ DO THIS**
   ```hcl
   # Document required setup in README or comments
   # This requires: Manual VLANsetup on Proxmox
   depends_on = [proxmox_virtual_environment_vlan.example]
   ```

## Getting Help

- **Questions**: Open a GitHub Discussion
- **Bugs**: Open a GitHub Issue with reproduction steps
- **Security**: See [SECURITY.md](SECURITY.md)
- **Documentation**: Check [PUBLIC_RELEASE_GUIDE.md](PUBLIC_RELEASE_GUIDE.md)

## License

By contributing, you agree that your contributions will be licensed under the same license as the project. Ensure you have the right to contribute (no previously licensed code without proper attribution).

---

Thank you for contributing to homelab_bootstrap! 🚀

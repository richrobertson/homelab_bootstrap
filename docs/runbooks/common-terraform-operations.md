# Common Terraform Operations

Use this runbook for day-to-day Terraform operations in
`homelab_bootstrap/terraform`.

## Select A Workspace

```bash
cd terraform
terraform init
terraform workspace select production
terraform workspace select staging
```

## Plan And Apply

```bash
cd terraform
terraform plan -out tfplan.out
terraform apply tfplan.out
```

## Export Local Cluster Context

Production:

```bash
cd terraform
terraform workspace select production
terraform output -raw kubeconfig > ~/.kube/config.prod
terraform output -raw talosconfig > ~/.talos/config.prod
```

Staging:

```bash
cd terraform
terraform workspace select staging
terraform output -raw kubeconfig > ~/.kube/config.stage
terraform output -raw talosconfig > ~/.talos/config.stage
```

## Recreate A Cluster

Use with care. This destroys and reapplies Terraform-managed infrastructure for
the active workspace:

```bash
cd terraform
terraform destroy -auto-approve
terraform apply -auto-approve
```

If the Flux repository resource ever needs to be moved back under Terraform
state management, the historic recovery commands were:

```bash
terraform state rm module.flux.github_repository.this
terraform import module.flux.github_repository.this richrobertson/homelab_flux
```

The current [Flux module](../../terraform/modules/flux/README.md) reads the
GitHub repository as data rather than creating it.

## CI/CD Flow

The [Jenkinsfile](../../Jenkinsfile) performs the same high-level sequence
expected from a human operator:

1. Check out the branch.
2. Run `terraform init`.
3. Select or create a workspace for non-main branches.
4. Run `terraform plan -detailed-exitcode`.
5. Post a compact plan summary to pull requests.
6. Require manual approval for non-PR applies.
7. Apply the saved plan.
8. Run the Talos etcd backup script on `main`.

## Related Documents

- [Terraform root](../../terraform/README.md)
- [Environment model](../design/environment-model.md)
- [Talos etcd backups](talos-etcd-backups.md)

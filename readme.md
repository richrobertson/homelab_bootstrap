# homelab_bootstrap

First-stage cluster bootstrap and orchestration before Flux management.

## Related repositories

This repository is one part of a shared homelab stack:

- [homelab_bootstrap](https://github.com/richrobertson/homelab_bootstrap) - first-stage cluster bootstrap/orchestration before Flux management.
- [homelab_ansible](https://github.com/richrobertson/homelab_ansible) - host and node configuration automation outside Kubernetes manifests.
- [homelab_flux](https://github.com/richrobertson/homelab_flux) - in-cluster GitOps state (apps, controllers, configs, and gateway resources).

## Recreating cluster
## terraform state rm module.flux.github_repository.this
terraform destroy -auto-approve  
## terraform import module.flux.github_repository.this richrobertson/homelab_flux
terraform apply -auto-approve


## Update local kubernetes context

### STAGE
terraform output -raw kubeconfig > ~/.kube/config.stage
terraform output -raw talosconfig > ~/.talos/config.stage

### PROD
terraform output -raw kubeconfig > ~/.kube/config.prod
terraform output -raw talosconfig > ~/.talos/config.prod

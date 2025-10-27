test



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

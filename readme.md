test



## Recreating cluster
## terraform state rm module.flux.github_repository.this
terraform destroy -auto-approve  
## terraform import module.flux.github_repository.this richrobertson/homelab_flux
terraform apply -auto-approve


## Update local kubernetes context

terraform output -raw kubeconfig > ~/.kube/config
locals {
  roles = {
    etcd-ca = {
      organization          = "etcd"
      validity_period_hours = 87600
      key_usage             = ["DigitalSignature", "CertSign"]
      ext_key_usage         = ["ClientAuth", "ServerAuth"]
    }
    kubernetes-ca = {
      organization          = "kubernetes"
      validity_period_hours = 87600
      key_usage             = ["DigitalSignature", "CertSign"]
      ext_key_usage         = ["ClientAuth", "ServerAuth"]
    }
    k8s-aggregator = {
      organization          = ""
      validity_period_hours = 87600
      key_usage             = ["DigitalSignature", "CertSign"]
      ext_key_usage         = ["ClientAuth", "ServerAuth"]
    }
    talos = {
      organization          = "talos"
      validity_period_hours = 87600
      key_usage             = ["DigitalSignature", "CertSign"]
      ext_key_usage         = ["ClientAuth", "ServerAuth"]
    }
  }
}
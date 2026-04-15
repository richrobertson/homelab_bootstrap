terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.9.0"
    }
  }
}


variable "cluster_name" {
  type = string
}

variable "vault_pki_secret_backend_path" {
  type = string
}

module "bootstrap_token" {
  source = "./bootstrap_token"
}

module "trustdinfo_token" {
  source = "./bootstrap_token"
}

resource "random_id" "cluster_id" {
  byte_length = 32
}

resource "random_id" "cluster_secret" {
  byte_length = 32
}

resource "random_id" "secretbox_encryption_secret" {
  byte_length = 32
}

module "etcd" {
  source    = "./ca_cert"
  role_name = "etcd-ca"
}

module "k8s" {
  depends_on = [module.etcd]
  source     = "./ca_cert"
  role_name  = "kubernetes-ca"
}

module "k8s_aggregator" {
  depends_on = [module.k8s]
  source     = "./ca_cert"
  role_name  = "k8s-aggregator"
}

resource "tls_private_key" "k8s_serviceaccount_private_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

module "os" {
  depends_on = [module.k8s_aggregator]
  source     = "./ca_cert"
  role_name  = "talos"
}


resource "tls_private_key" "client_key" {
  algorithm = "ED25519"
}

resource "tls_cert_request" "client_csr" {
  private_key_pem = tls_private_key.client_key.private_key_pem
  subject {
    organization = "os:admin"
  }
}

resource "tls_locally_signed_cert" "client_cert" {
  ca_cert_pem           = module.os.cert_pem
  ca_private_key_pem    = module.os.private_key_pem
  cert_request_pem      = tls_cert_request.client_csr.cert_request_pem
  validity_period_hours = 87650
  allowed_uses = [
    "digital_signature",
    "client_auth"
  ]
}

resource "talos_machine_secrets" "this" {}
output "machine_secrets_old" {
  value = talos_machine_secrets.this.machine_secrets
}
output "client_configuration_old" {
  value = talos_machine_secrets.this.client_configuration
}

output "machine_secrets" {
  value = {
    cluster = {
      id     = random_id.cluster_id.b64_std
      secret = random_id.cluster_secret.b64_std
    }
    secrets = {
      aescbc_encryption_secret    = null
      bootstrap_token             = module.bootstrap_token.bootstrap_token
      secretbox_encryption_secret = random_id.secretbox_encryption_secret.b64_std
    }
    trustdinfo = {
      token = module.trustdinfo_token.bootstrap_token
    }
    certs = {
      etcd = {
        # this is working
        key  = base64encode(trimspace(module.etcd.private_key_pem))
        cert = base64encode(trimspace(module.etcd.cert_chain_pem))
      }
      k8s = {
        # Some libraries require the full certificate chain to verify properly, while
        # other kubernetes components expect only one certificate to be provided. 
        # https://discuss.kubernetes.io/t/support-for-injecting-full-certificate-chain-to-resolve-verification-issues-in-k8s-clusters-with-intermediate-ca/32754
        key = talos_machine_secrets.this.machine_secrets.certs.k8s.key
        #key  = base64encode(trimspace(module.k8s.private_key_pem))
        cert = talos_machine_secrets.this.machine_secrets.certs.k8s.cert
        #cert = base64encode(trimspace(module.k8s.cert_chain_pem))
      }
      k8s_aggregator = {
        key  = base64encode(trimspace(module.k8s_aggregator.private_key_pem))
        cert = base64encode(trimspace(module.k8s_aggregator.cert_chain_pem))
      }
      k8s_serviceaccount = {
        key = base64encode(trimspace(tls_private_key.k8s_serviceaccount_private_key.private_key_pem))
      }
      os = {
        key  = base64encode(trimspace(module.os.private_key_pem))
        cert = base64encode(trimspace(module.os.cert_chain_pem))
      }
    }
  }
}

output "client_configuration" {
  value = {
    ca_certificate = base64encode(trimspace(<<-EOF
    ${module.os.cert_pem}
  -----BEGIN CERTIFICATE-----
  MIICCDCCAa+gAwIBAgIQF9zxtm7FcrlB+hsJIdZ7mzAKBggqhkjOPQQDAjBRMRMw
  EQYKCZImiZPyLGQBGRYDbmV0MRswGQYKCZImiZPyLGQBGRYLbXlyb2JlcnRzb24x
  HTAbBgNVBAMTFG15cm9iZXJ0c29uLURDMS1DQS0xMB4XDTI1MTAyMDE3MjMxNFoX
  DTQwMTAyMDE3MzMwN1owUTETMBEGCgmSJomT8ixkARkWA25ldDEbMBkGCgmSJomT
  8ixkARkWC215cm9iZXJ0c29uMR0wGwYDVQQDExRteXJvYmVydHNvbi1EQzEtQ0Et
  MTBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABK+4DJe8IQJfxAzy0rPHXzB90y6j
  VH8DIkZ7MVKDiU3I4wvijS377qYF29isRM7PAIJqoBn2qrj3tq0VXf2kVqejaTBn
  MBMGCSsGAQQBgjcUAgQGHgQAQwBBMA4GA1UdDwEB/wQEAwIBhjAPBgNVHRMBAf8E
  BTADAQH/MB0GA1UdDgQWBBRDeCmhtlyh4RyCRpNsWwmHhSQIiTAQBgkrBgEEAYI3
  FQEEAwIBADAKBggqhkjOPQQDAgNHADBEAiBanuCZDMRVikhd3L9npjlcU/RfYTM9
  KBEosp9OrdExBwIgMyq4owAejBTFfxDEco8n/Si9OBQLLZ01n+vwnwLr964=
  -----END CERTIFICATE-----
  EOF
    ))
    client_certificate = base64encode(trimspace(tls_locally_signed_cert.client_cert.cert_pem))
    client_key         = base64encode(trimspace(tls_private_key.client_key.private_key_pem))
  }
}

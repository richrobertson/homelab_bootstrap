variable "db1_password" {
  description = "Initial PostgreSQL password for substrate database bootstrap."
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key injected into substrate VMs."
  type        = string
}
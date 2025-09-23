variable "peer_ips" {
  description = "A list of IP addresses of each node in the VXLAN zone. This can be external nodes reachable at this IP address. All nodes in the cluster need to be mentioned here."
  type        = list(string)
}

variable "nodes" {
  type = list(string)
}
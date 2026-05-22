terraform {
  required_version = ">= 1.0"
}

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
variable "web_hosts" {
  description = "List of web server IPs"
  type        = list(string)
  default     = ["127.0.0.1"]
}

variable "lb_host" {
  description = "Load balancer IP / hostname"
  default     = "127.0.0.1"
}

variable "ansible_user" {
  description = "SSH user for Ansible"
  default     = "ubuntu"
}

variable "ansible_connection" {
  description = "Ansible connection type (ssh | local)"
  default     = "local"
}

# ---------------------------------------------------------------------------
# Generate Ansible inventory using the template
# ---------------------------------------------------------------------------
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    web_hosts  = var.web_hosts
    lb_host    = var.lb_host
    user       = var.ansible_user
    connection = var.ansible_connection
  })
  filename        = "${path.module}/../ansible/inventory.ini"
  file_permission = "0644"
}

output "inventory_path" {
  value = local_file.ansible_inventory.filename
}

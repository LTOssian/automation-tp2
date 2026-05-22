terraform {
  required_version = ">= 1.0"
}

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
variable "ansible_host" {
  description = "IP / hostname of the target node"
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
# Generate Ansible inventory using the Jinja2-like template
# ---------------------------------------------------------------------------
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    host       = var.ansible_host
    user       = var.ansible_user
    connection = var.ansible_connection
  })
  filename        = "${path.module}/../ansible/inventory.ini"
  file_permission = "0644"
}

output "inventory_path" {
  value = local_file.ansible_inventory.filename
}

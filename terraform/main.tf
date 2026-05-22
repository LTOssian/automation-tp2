terraform {
  required_version = ">= 1.0"
}

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
variable "web_hosts" {
  description = "List of Linux web server IPs"
  type        = list(string)
  default     = ["172.20.0.10"]   # ubuntu-target Docker container
}

variable "lb_host" {
  description = "Load balancer IP / hostname"
  default     = "127.0.0.1"
}

variable "ansible_user" {
  description = "SSH user for Linux hosts"
  default     = "ansible"
}

variable "ansible_ssh_private_key" {
  description = "Path to SSH private key for Linux hosts"
  default     = "./ssh_keys/ansible_ed25519"
}

variable "ansible_ssh_port" {
  description = "SSH port (2222 when tunnelled via Docker)"
  default     = "2222"
}

# Windows VM variables
variable "windows_host" {
  description = "IP of the Windows VM"
  default     = "192.168.56.10"   # typical VirtualBox host-only IP — override as needed
}

variable "windows_user" {
  description = "Windows administrator username"
  default     = "Administrator"
}

variable "windows_password" {
  description = "Windows administrator password"
  sensitive   = true
  default     = "CHANGE_ME"
}

variable "winrm_port" {
  description = "WinRM HTTP port"
  default     = "5985"
}

# ---------------------------------------------------------------------------
# Generate Ansible inventory
# ---------------------------------------------------------------------------
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    web_hosts               = var.web_hosts
    lb_host                 = var.lb_host
    ansible_user            = var.ansible_user
    ansible_ssh_private_key = var.ansible_ssh_private_key
    ansible_ssh_port        = var.ansible_ssh_port
    windows_host            = var.windows_host
    windows_user            = var.windows_user
    windows_password        = var.windows_password
    winrm_port              = var.winrm_port
  })
  filename        = "${path.module}/../ansible/inventory.ini"
  file_permission = "0600"
}

output "inventory_path" {
  value = local_file.ansible_inventory.filename
}

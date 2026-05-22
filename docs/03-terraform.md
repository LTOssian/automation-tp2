# 03 – Terraform & Dynamic Inventory Generation

## Purpose

Terraform replaces the static `inventory.ini` with a **dynamically generated** file each pipeline run, using a Jinja2-style template (`inventory.tpl`).

## Files

| File | Role |
|---|---|
| `terraform/main.tf` | Declares variables and the `local_file` resource |
| `terraform/inventory.tpl` | Template rendered into `ansible/inventory.ini` |
| `ansible/inventory.ini` | Generated output — **never commit this file** |

## How it works

`main.tf` calls Terraform's built-in `templatefile()` function:

```hcl
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    web_hosts  = var.web_hosts    # list of web server IPs
    lb_host    = var.lb_host      # load balancer IP
    user       = var.ansible_user
    connection = var.ansible_connection
  })
  filename = "${path.module}/../ansible/inventory.ini"
}
```

The template (`inventory.tpl`) iterates over the `web_hosts` list:

```
[webservers]
%{ for idx, h in web_hosts ~}
${h} ansible_user=${user} ansible_connection=${connection} server_id=${idx + 1}
%{ endfor ~}

[loadbalancer]
${lb_host} ansible_user=${user} ansible_connection=${connection}
```

## Variables

| Variable | Default | Override via |
|---|---|---|
| `web_hosts` | `["127.0.0.1"]` | `WEB_HOSTS` GitHub Actions var (JSON array) |
| `lb_host` | `127.0.0.1` | `LB_HOST` GitHub Actions var |
| `ansible_user` | `ubuntu` | `ANSIBLE_USER` GitHub Actions var |
| `ansible_connection` | `local` | `ANSIBLE_CONNECTION` GitHub Actions var |

## Running locally

```bash
cd terraform
terraform init
terraform apply -auto-approve
cat ../ansible/inventory.ini   # inspect the generated file
```

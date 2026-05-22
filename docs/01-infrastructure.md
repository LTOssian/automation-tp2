# 01 – Infrastructure Overview

## Architecture

```
                    ┌─────────────────────────────┐
                    │   GitHub Actions Pipeline    │
                    │   (self-hosted runner)       │
                    └────────────┬────────────────┘
                                 │
               ┌─────────────────▼──────────────────┐
               │         Ansible Controller          │
               │  (runner machine – runs playbooks)  │
               └───────┬──────────────┬─────────────┘
                       │              │
          ┌────────────▼───┐   ┌──────▼───────────┐
          │  Load Balancer │   │   Web Server(s)   │
          │  nginx (LB)    │──▶│   nginx + HTML    │
          └────────────────┘   └──────────────────┘
```

## Components

| Component | Role |
|---|---|
| GitHub Actions | CI/CD orchestration |
| Self-hosted runner | Executes pipeline jobs locally |
| Terraform | Generates `ansible/inventory.ini` from template |
| Ansible Controller | Runs playbooks against target hosts |
| nginx (webservers) | Serves the static HTML page |
| nginx (loadbalancer) | Distributes traffic across web servers |

## Host Groups (inventory)

| Group | Default IP | Purpose |
|---|---|---|
| `webservers` | `127.0.0.1` | nginx + HTML deployment targets |
| `loadbalancer` | `127.0.0.1` | nginx reverse proxy / upstream |

## Scaling

To add more web servers, set the `WEB_HOSTS` GitHub Actions variable to a JSON array:

```
["192.168.1.10", "192.168.1.11", "192.168.1.12"]
```

Terraform regenerates the inventory and Ansible reconfigures both the web servers and the load balancer upstream block automatically.
